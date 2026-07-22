import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
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
    this.deletingMessageId,
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

  /// The message with a delete in flight — its bubble dims until it resolves.
  final String? deletingMessageId;

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
      widget.myUserId != null && m.senderId == widget.myUserId;

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet — say hello.',
          style: AppTypography.bodySmall,
        ),
      );
    }

    DateTime? lastDay;
    final children = <Widget>[
      if (widget.loadingOlder) const _OlderPageSpinner(),
    ];
    for (final m in widget.messages) {
      final day = DateTime(
        m.createdAt.year,
        m.createdAt.month,
        m.createdAt.day,
      );
      if (lastDay == null || day != lastDay) {
        children.add(_DateSeparator(day: day));
        lastDay = day;
      }
      final mine = _isMine(m);
      children.add(
        _Bubble(
          message: m,
          mine: mine,
          deleting: m.id == widget.deletingMessageId,
          onLongPress: widget.onMessageLongPress == null
              ? null
              : () => widget.onMessageLongPress!(m, mine),
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
    this.deleting = false,
    this.onLongPress,
  });
  final ChatMessage message;
  final bool mine;

  /// A delete for this message is in flight — dimmed until it resolves.
  final bool deleting;

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    const tail = 4.0; // the flattened "tail" corner nearest the sender
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.lg),
      topRight: const Radius.circular(AppRadius.lg),
      bottomLeft: Radius.circular(mine ? AppRadius.lg : tail),
      bottomRight: Radius.circular(mine ? tail : AppRadius.lg),
    );
    final body = (message.body ?? '').trim();
    final tombstone = message.deletedForEveryone;
    final attachment = message.attachment;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          AnimatedOpacity(
            opacity: deleting ? 0.4 : 1,
            duration: const Duration(milliseconds: 160),
            child: GestureDetector(
              onLongPress: deleting ? null : onLongPress,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: mine
                        ? AppColors.primary
                        : AppColors.darkSurfaceElevated,
                    borderRadius: radius,
                    border: mine
                        ? null
                        : Border.all(color: AppColors.darkBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (body.isNotEmpty)
                        Text(
                          body,
                          style: AppTypography.body.copyWith(
                            color: tombstone
                                ? (mine
                                      ? AppColors.onPrimary.withValues(
                                          alpha: 0.7,
                                        )
                                      : AppColors.textTertiary)
                                : (mine ? AppColors.onPrimary : null),
                            fontStyle: tombstone ? FontStyle.italic : null,
                          ),
                        ),
                      // Attachments have no download UI yet (a later phase) — an
                      // attachment received in history still shows honestly as a
                      // named chip instead of silently vanishing.
                      if (attachment != null && !tombstone) ...[
                        if (body.isNotEmpty) const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_file_rounded,
                              size: 13,
                              color: mine
                                  ? AppColors.onPrimary.withValues(alpha: 0.7)
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                attachment.originalFilename,
                                style: AppTypography.caption.copyWith(
                                  color: mine
                                      ? AppColors.onPrimary.withValues(
                                          alpha: 0.7,
                                        )
                                      : AppColors.textTertiary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: Text(
              relativeTime(message.createdAt),
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
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
        child: Text(
          _label(),
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
