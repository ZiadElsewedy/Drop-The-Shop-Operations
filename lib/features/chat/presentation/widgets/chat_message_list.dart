import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/presentation/chat_message_preview.dart';
import 'package:drop/features/task/presentation/activity_format.dart'
    show relativeTime;

/// The direct-chat thread — the [CaseMessageList] sibling. Messages arrive
/// ascending by `seq` (oldest first) and render bottom-anchored: left/right
/// bubbles (counterpart vs mine), day changes get a date separator, and the
/// list auto-follows the newest message unless the reader has scrolled up
/// (then a "New messages" pill appears instead — Cases convention).
///
/// Two chat-specific additions over Cases:
/// * **Scroll-back pagination** — nearing the top with older history available
///   fires [onLoadOlder]; a quiet spinner row shows while the page is in
///   flight, and the scroll position is preserved when it prepends.
/// * **Visible-read signal** — [onVisible] fires post-frame whenever messages
///   are actually on screen; the cubit's monotonic mark-read makes repeated
///   calls free.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.myUserId,
    this.hasMore = false,
    this.loadingOlder = false,
    this.onLoadOlder,
    this.onVisible,
    this.onMessageLongPress,
    this.onReply,
    this.onRetry,
    this.onImageTap,
    this.imageUrlLoader,
    this.deletingMessageId,
    this.counterpartName,
  });

  /// Ascending by `seq` — oldest first.
  final List<ChatMessage> messages;

  /// The caller's backend-internal user id, when derivable. Null → own-message
  /// alignment isn't resolvable yet (deep link into a never-messaged thread);
  /// everything renders left-aligned until the first send resolves it.
  final String? myUserId;

  /// Whether older history exists beyond the loaded window.
  final bool hasMore;

  /// An older page is in flight (top spinner row).
  final bool loadingOlder;

  /// Fired when the reader nears the top and [hasMore] — load the next older
  /// page. The cubit no-ops re-entrant calls.
  final VoidCallback? onLoadOlder;

  /// Fired post-frame while messages are on screen — the mark-read signal.
  final VoidCallback? onVisible;

  /// Long-press on a bubble — opens the message context menu (the host owns
  /// the sheet + the action). Null → long-press does nothing.
  final void Function(ChatMessage message, bool mine)? onMessageLongPress;

  /// Swipe-right on a bubble — starts a reply to it (WhatsApp gesture).
  final void Function(ChatMessage message)? onReply;

  /// Tap on a failed optimistic bubble — re-sends it.
  final void Function(ChatMessage message)? onRetry;

  /// Tap on an image attachment — opens the full-screen viewer.
  final void Function(ChatMessage message)? onImageTap;

  /// Resolves a received image's brokered URL for its inline thumbnail.
  final Future<String?> Function(ChatMessage message)? imageUrlLoader;

  /// The message with a delete in flight — its bubble dims until it resolves.
  final String? deletingMessageId;

  /// Counterpart's display name — personalizes the empty state.
  final String? counterpartName;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final _controller = ScrollController();

  /// Within this distance of the end counts as "at the bottom" — new messages
  /// auto-scroll only when the reader is already here.
  static const _bottomThreshold = 240.0;

  /// Within this distance of the top triggers the older-page load.
  static const _topThreshold = 120.0;

  bool _atBottom = true;
  bool _showJump = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _scrollToBottom(animated: false);
    _notifyVisible();
  }

  @override
  void didUpdateWidget(covariant ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.isEmpty) return;

    final grew = widget.messages.length > oldWidget.messages.length;
    final prepended =
        grew &&
        oldWidget.messages.isNotEmpty &&
        widget.messages.first.id != oldWidget.messages.first.id;
    final appended =
        grew &&
        (oldWidget.messages.isEmpty ||
            widget.messages.last.id != oldWidget.messages.last.id);

    if (prepended) {
      _preserveOffsetAfterPrepend();
    }
    if (appended) {
      // Don't yank a reader who has scrolled up to read history: follow the
      // newest message only when they're already at the bottom, or it's their
      // own send. Otherwise surface a "New messages" pill.
      final newestMine = _isMine(widget.messages.last);
      if (_atBottom || newestMine) {
        _scrollToBottom();
      } else if (!_showJump) {
        setState(() => _showJump = true);
      }
    }
    if (grew || oldWidget.messages.isEmpty) _notifyVisible();
  }

  /// An older page was prepended above the viewport — the list grew upward, so
  /// keep the message the reader was looking at exactly where it was by
  /// re-applying the pre-layout offset plus the extent the page added.
  void _preserveOffsetAfterPrepend() {
    if (!_controller.hasClients) return;
    final oldMax = _controller.position.maxScrollExtent;
    final oldOffset = _controller.offset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final delta = _controller.position.maxScrollExtent - oldMax;
      if (delta > 0) _controller.jumpTo(oldOffset + delta);
    });
  }

  void _notifyVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.messages.isNotEmpty) widget.onVisible?.call();
    });
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (widget.hasMore &&
        !widget.loadingOlder &&
        position.pixels <= _topThreshold) {
      widget.onLoadOlder?.call();
    }
    final atBottom =
        position.maxScrollExtent - position.pixels <= _bottomThreshold;
    if (atBottom != _atBottom) {
      setState(() {
        _atBottom = atBottom;
        if (atBottom) _showJump = false;
      });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final target = _controller.position.maxScrollExtent;
      if (animated) {
        _controller.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      } else {
        _controller.jumpTo(target);
      }
      if (_showJump && mounted) setState(() => _showJump = false);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  bool _isMine(ChatMessage m) =>
      // An optimistic local bubble is always the caller's own send, even before
      // `myUserId` has resolved from the first server round-trip.
      m.id.startsWith('local:') ||
      (widget.myUserId != null && m.senderId == widget.myUserId);

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return _EmptyThread(counterpartName: widget.counterpartName);
    }

    final msgs = widget.messages;
    DateTime? lastDay;
    final children = <Widget>[
      if (widget.loadingOlder) const _OlderPageSpinner(),
    ];
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      final newDay = lastDay == null || day != lastDay;
      if (newDay) {
        children.add(_DateSeparator(day: day));
        lastDay = day;
      }
      final mine = _isMine(m);
      // Resolve the quoted message's author for the reply preview label.
      final rp = m.replyTo;
      final replyAuthorLabel = rp == null
          ? null
          : (rp.senderId == widget.myUserId
              ? 'You'
              : (widget.counterpartName ?? 'Them'));
      // Group consecutive same-sender messages within the same day: only the
      // last of a run ("tail") shows the timestamp, and grouped bubbles sit
      // tight together — the iMessage/Telegram rhythm that reads as premium.
      final next = i + 1 < msgs.length ? msgs[i + 1] : null;
      final nextSameDay = next != null &&
          next.createdAt.year == m.createdAt.year &&
          next.createdAt.month == m.createdAt.month &&
          next.createdAt.day == m.createdAt.day;
      final isTail =
          next == null || next.senderId != m.senderId || !nextSameDay;
      // RepaintBoundary isolates each bubble: a list-wide rebuild (a new
      // message, a read receipt, an upload-progress tick) or the swipe-to-reply
      // translate then can't force every other bubble to re-rasterize.
      final bubble = RepaintBoundary(
        child: _Bubble(
        message: m,
        mine: mine,
        isTail: isTail,
        replyAuthorLabel: replyAuthorLabel,
        deleting: m.id == widget.deletingMessageId,
        onLongPress: widget.onMessageLongPress == null
            ? null
            : () => widget.onMessageLongPress!(m, mine),
        onRetry: widget.onRetry == null ? null : () => widget.onRetry!(m),
        onImageTap:
            widget.onImageTap == null ? null : () => widget.onImageTap!(m),
        imageUrlLoader: widget.imageUrlLoader == null
            ? null
            : () => widget.imageUrlLoader!(m),
        ),
      );
      // Swipe-right to reply — never on a tombstone or an unsent local bubble.
      final canSwipeReply = widget.onReply != null &&
          !m.deletedForEveryone &&
          !m.id.startsWith('local:');
      children.add(
        // Keyed by message id so an element follows its message across
        // prepends/appends — the entrance animation then fires only for a
        // genuinely new bubble, never re-running on an existing one.
        KeyedSubtree(
          key: ValueKey(m.id),
          child: canSwipeReply
              ? _SwipeToReply(onReply: () => widget.onReply!(m), child: bubble)
              : bubble,
        ),
      );
    }

    return Stack(
      children: [
        ListView(
          controller: _controller,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.lg,
            AppSpacing.pagePadding,
            AppSpacing.lg,
          ),
          children: children,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.md,
          child: _JumpToLatest(visible: _showJump, onTap: _scrollToBottom),
        ),
      ],
    );
  }
}

class _OlderPageSpinner extends StatelessWidget {
  const _OlderPageSpinner();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: AppSpacing.md),
    child: Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    this.isTail = true,
    this.replyAuthorLabel,
    this.deleting = false,
    this.onLongPress,
    this.onRetry,
    this.onImageTap,
    this.imageUrlLoader,
  });
  final ChatMessage message;
  final bool mine;

  /// Tap handler for a failed optimistic bubble (re-send) and for an image
  /// attachment (open full-screen). Null → the respective tap is inert.
  final VoidCallback? onRetry;
  final VoidCallback? onImageTap;

  /// Resolves this message's received-image URL for the inline thumbnail.
  final Future<String?> Function()? imageUrlLoader;

  /// Display label for the author of the quoted (replied-to) message, when
  /// this message is a reply — "You" or the counterpart's name.
  final String? replyAuthorLabel;

  /// Last message of a consecutive same-sender run — shows the timestamp and
  /// the flattened "tail" corner; grouped (non-tail) bubbles are fully rounded
  /// and sit tight against the next.
  final bool isTail;

  /// A delete for this message is in flight — dimmed until it resolves.
  final bool deleting;

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    const tailR = 5.0; // the flattened "tail" corner nearest the sender
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.lg),
      topRight: const Radius.circular(AppRadius.lg),
      bottomLeft: Radius.circular(mine || !isTail ? AppRadius.lg : tailR),
      bottomRight: Radius.circular(!mine || !isTail ? AppRadius.lg : tailR),
    );
    final body = (message.body ?? '').trim();
    final tombstone = message.deletedForEveryone;
    final attachment = message.attachment;
    final sending = message.status == 'SENDING';
    final failed = message.status == 'FAILED';
    final isImage = attachment != null &&
        !tombstone &&
        (message.localBytes != null || attachment.kind.isImage);
    final isDoc = attachment != null && !tombstone && !isImage;
    // Cap bubble width so a short line doesn't stretch edge-to-edge on tablets
    // and large phones while still tracking the viewport on small ones.
    final maxBubbleWidth =
        math.min(MediaQuery.sizeOf(context).width * 0.72, 560.0);

    // A failed bubble re-sends on tap; an image opens the full-screen viewer.
    final VoidCallback? onTap = failed
        ? onRetry
        : (isImage && !sending ? onImageTap : null);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
      ),
      child: Padding(
        // Tight gap within a group, roomier gap between senders/groups.
        padding: EdgeInsets.only(bottom: isTail ? AppSpacing.md : 2),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            AnimatedOpacity(
              // Dim while a delete resolves, and slightly while a send is in
              // flight, so "sending" reads as provisional.
              opacity: deleting ? 0.4 : (sending ? 0.7 : 1),
              duration: const Duration(milliseconds: 160),
              child: GestureDetector(
                onLongPress: (deleting || sending) ? null : onLongPress,
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isImage ? 4 : AppSpacing.md,
                      vertical: isImage ? 4 : AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          mine ? AppColors.primary : AppColors.darkSurfaceElevated,
                      borderRadius: radius,
                      border:
                          mine ? null : Border.all(color: AppColors.darkBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.replyTo != null && !tombstone) ...[
                          Padding(
                            padding: EdgeInsets.all(isImage ? 4 : 0),
                            child: _QuotedPreview(
                              mine: mine,
                              authorLabel: replyAuthorLabel ?? 'Them',
                              snippet: chatReplySnippet(
                                body: message.replyTo!.body,
                                attachment: message.replyTo!.attachment,
                              ),
                            ),
                          ),
                          if (body.isNotEmpty || attachment != null)
                            const SizedBox(height: 6),
                        ],
                        if (isImage || isDoc)
                          _SendableAttachment(
                            sending: sending,
                            progress: message.uploadProgress,
                            child: isImage
                                ? _ImageAttachment(
                                    bytes: message.localBytes,
                                    heroTag: 'chat-image-${message.id}',
                                    urlLoader: imageUrlLoader,
                                  )
                                : _FileCard(
                                    attachment: attachment, mine: mine),
                          ),
                        if (body.isNotEmpty) ...[
                          if (attachment != null) const SizedBox(height: 6),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isImage ? 6 : 0,
                              vertical: isImage ? 2 : 0,
                            ),
                            child: Text(
                              body,
                              style: AppTypography.body.copyWith(
                                color: tombstone
                                    ? (mine
                                        ? AppColors.onPrimary
                                            .withValues(alpha: 0.7)
                                        : AppColors.textTertiary)
                                    : (mine ? AppColors.onPrimary : null),
                                fontStyle:
                                    tombstone ? FontStyle.italic : null,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (failed)
              _FailedFooter(onRetry: onRetry)
            else if (isTail)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      relativeTime(message.createdAt),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                    // Delivery status on my own messages — monochrome ticks, or
                    // a clock while the optimistic send is still in flight.
                    if (mine && !tombstone) ...[
                      const SizedBox(width: 4),
                      _StatusTicks(status: message.status),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// WhatsApp-style swipe-to-reply: the bubble tracks a rightward drag, a reply
/// glyph fades/scales in behind its leading edge, a single haptic fires once
/// the trigger threshold is crossed, and the bubble springs back on release —
/// invoking [onReply] only if the threshold was reached.
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({required this.child, required this.onReply});
  final Widget child;
  final VoidCallback onReply;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _threshold = 56;
  static const double _maxDrag = 80;

  // Created eagerly in initState (not lazily): a lazy `late final` would first
  // construct the controller inside dispose(), building a Ticker on an already-
  // deactivated element.
  late final AnimationController _springBack;
  double _dx = 0;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _springBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _springBack.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    _springBack.stop();
    setState(() {
      _dx = (_dx + details.delta.dx).clamp(0.0, _maxDrag);
      if (!_armed && _dx >= _threshold) {
        _armed = true;
        HapticFeedback.mediumImpact();
      } else if (_armed && _dx < _threshold) {
        _armed = false;
      }
    });
  }

  void _onEnd(DragEndDetails details) {
    if (_armed) widget.onReply();
    _armed = false;
    final from = _dx;
    final anim = Tween<double>(begin: from, end: 0).animate(
      CurvedAnimation(parent: _springBack, curve: Curves.easeOutBack),
    );
    void tick() => setState(() => _dx = anim.value);
    anim.addListener(tick);
    _springBack.forward(from: 0).whenComplete(() {
      anim.removeListener(tick);
      _dx = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dx / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          if (_dx > 0)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Opacity(
                    opacity: progress,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * progress,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _armed
                              ? AppColors.primary
                              : AppColors.darkSurfaceElevated,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.reply_rounded,
                          size: 18,
                          color: _armed
                              ? AppColors.onPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// An inline image attachment — a rounded thumbnail wrapped in a [Hero] so it
/// flies into the full-screen viewer on tap. Local bytes (an optimistic send)
/// render immediately; a received image lazily resolves its brokered URL via
/// [urlLoader] and shows it inline, falling back to a "Photo" placeholder while
/// loading or on failure.
class _ImageAttachment extends StatefulWidget {
  const _ImageAttachment({
    required this.bytes,
    required this.heroTag,
    this.urlLoader,
  });
  final Uint8List? bytes;
  final Object heroTag;
  final Future<String?> Function()? urlLoader;

  @override
  State<_ImageAttachment> createState() => _ImageAttachmentState();
}

class _ImageAttachmentState extends State<_ImageAttachment> {
  Future<String?>? _url;

  @override
  void initState() {
    super.initState();
    if (widget.bytes == null) _url = widget.urlLoader?.call();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bytes;
    final Widget content;
    if (b != null) {
      content = Image.memory(b, width: 240, fit: BoxFit.cover);
    } else if (_url != null) {
      content = FutureBuilder<String?>(
        future: _url,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _ImagePlaceholder(loading: true);
          }
          final url = snap.data;
          if (url == null || url.isEmpty) {
            return const _ImagePlaceholder(loading: false);
          }
          return Image.network(
            url,
            width: 240,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const _ImagePlaceholder(loading: true),
            errorBuilder: (_, _, _) => const _ImagePlaceholder(loading: false),
          );
        },
      );
    } else {
      content = const _ImagePlaceholder(loading: false);
    }
    return Hero(
      tag: widget.heroTag,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: content,
        ),
      ),
    );
  }
}

/// The loading / unavailable state of an inline image (fixed footprint so the
/// bubble doesn't jump when the real image arrives).
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.loading});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 150,
      color: AppColors.darkSurface,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.textTertiary),
            )
          : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_rounded,
                    size: 30, color: AppColors.textTertiary),
                SizedBox(height: 6),
                Text('Photo', style: TextStyle(color: AppColors.textTertiary)),
              ],
            ),
    );
  }
}

/// Overlays an in-flight attachment with a progress ring while it uploads.
class _SendableAttachment extends StatelessWidget {
  const _SendableAttachment({
    required this.sending,
    required this.progress,
    required this.child,
  });

  final bool sending;
  final double? progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!sending) return child;
    return Stack(
      alignment: Alignment.center,
      children: [
        child,
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              // Indeterminate until real progress arrives, then determinate.
              value: (progress == null || progress == 0) ? null : progress,
              strokeWidth: 2.5,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
      ],
    );
  }
}

/// A premium document card — a format badge, the filename, and its size.
class _FileCard extends StatelessWidget {
  const _FileCard({required this.attachment, required this.mine});
  final ChatMessageAttachment attachment;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final onLight = mine;
    final badge = attachment.format.toUpperCase();
    final fg = onLight ? AppColors.onPrimary : AppColors.textPrimary;
    final subFg = onLight
        ? AppColors.onPrimary.withValues(alpha: 0.6)
        : AppColors.textTertiary;
    return Container(
      constraints: const BoxConstraints(minWidth: 200),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: onLight
            ? AppColors.onPrimary.withValues(alpha: 0.06)
            : const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: onLight
                  ? AppColors.onPrimary.withValues(alpha: 0.12)
                  : AppColors.darkSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.description_rounded, size: 20, color: fg),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.originalFilename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall
                      .copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '$badge · ${chatHumanBytes(attachment.byteSize)}',
                  style: AppTypography.caption.copyWith(color: subFg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The footer under a failed optimistic bubble — a quiet error line with a
/// retry affordance (the bubble itself is also tap-to-retry).
class _FailedFooter extends StatelessWidget {
  const _FailedFooter({this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
      child: GestureDetector(
        onTap: onRetry,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 13, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              'Not delivered · Tap to retry',
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }
}

/// Monochrome delivery ticks for an own message: a single check until the
/// counterpart has read it, then a brighter double check. Delivered (if the
/// server ever reports it) reads as a muted double check. Color-free by design
/// — the system has no chromatic accent, so state is carried by shape + weight.
class _StatusTicks extends StatelessWidget {
  const _StatusTicks({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    // Optimistic in-flight send → a clock, not a check.
    if (status == 'SENDING') {
      return const Icon(
        Icons.access_time_rounded,
        size: 13,
        color: AppColors.textTertiary,
        semanticLabel: 'Sending',
      );
    }
    final read = status == 'READ';
    final delivered = read || status == 'DELIVERED';
    return Icon(
      delivered ? Icons.done_all_rounded : Icons.done_rounded,
      size: 14,
      color: read ? AppColors.textSecondary : AppColors.textTertiary,
      semanticLabel: read
          ? 'Read'
          : delivered
              ? 'Delivered'
              : 'Sent',
    );
  }
}

/// The quoted-message block shown at the top of a reply bubble: an accent bar,
/// the quoted author, and a one-line snippet. Tinted to sit legibly on either
/// bubble surface — a dark tint on my white bubble, a light tint on the
/// counterpart's dark bubble.
class _QuotedPreview extends StatelessWidget {
  const _QuotedPreview({
    required this.mine,
    required this.authorLabel,
    required this.snippet,
  });

  final bool mine;
  final String authorLabel;
  final String snippet;

  @override
  Widget build(BuildContext context) {
    final bg = mine
        ? AppColors.onPrimary.withValues(alpha: 0.06)
        : const Color(0x14FFFFFF);
    final bar = mine
        ? AppColors.onPrimary.withValues(alpha: 0.45)
        : AppColors.textSecondary;
    final author = mine ? AppColors.onPrimary : AppColors.textSecondary;
    final snippetColor = mine
        ? AppColors.onPrimary.withValues(alpha: 0.65)
        : AppColors.textTertiary;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: bar,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorLabel,
                    style: AppTypography.caption.copyWith(
                      color: author,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    snippet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTypography.caption.copyWith(color: snippetColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The empty-thread state — a quiet, premium invitation to start the chat,
/// personalized with the counterpart's name when known.
class _EmptyThread extends StatelessWidget {
  const _EmptyThread({this.counterpartName});
  final String? counterpartName;

  @override
  Widget build(BuildContext context) {
    final name = (counterpartName ?? '').trim();
    final title = name.isEmpty ? 'Say hello' : 'Say hello to ${name.split(' ').first}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: AppColors.darkSurfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.waving_hand_rounded,
                  size: 30, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTypography.h3, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              'This is the beginning of your conversation.',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A floating "New messages" pill shown when a message lands while the reader
/// is scrolled up in the history. Tapping it animates back to the newest.
class _JumpToLatest extends StatelessWidget {
  const _JumpToLatest({required this.visible, required this.onTap});
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 2),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: Center(
            child: Material(
              color: AppColors.darkSurfaceElevated,
              elevation: 3,
              shadowColor: Colors.black54,
              shape: const StadiumBorder(
                side: BorderSide(color: AppColors.darkBorder),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_downward_rounded,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'New messages',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.day});
  final DateTime day;

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return AppDateFormatter.monthDayYear(day);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        // A subtle centered pill (WhatsApp/Telegram rhythm) rather than bare
        // text — reads as a quiet divider between days.
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Text(
            _label(),
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
