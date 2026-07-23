import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/presentation/chat_attachment_picker.dart';
import 'package:drop/features/chat/presentation/chat_message_preview.dart';
import 'package:drop/features/chat/presentation/pages/image_viewer_screen.dart';
import 'package:drop/features/chat/presentation/pages/message_info_screen.dart';
import 'package:drop/features/chat/presentation/cubit/chat_conversation_cubit.dart';
import 'package:drop/features/chat/presentation/cubit/chat_conversation_state.dart';
import 'package:drop/features/chat/presentation/widgets/chat_composer.dart';
import 'package:drop/features/chat/presentation/widgets/chat_message_actions.dart';
import 'package:drop/features/chat/presentation/widgets/chat_message_list.dart';

/// The conversation body — thread + composer over [ChatConversationCubit],
/// the [CaseConversationView] sibling (no header bar: the screen's app bar
/// already names the counterpart, and there is no status to control).
///
/// Error contract (matches the cubit): a failure **after** the thread is on
/// screen is transient — the cubit re-emits the last loaded state right after,
/// so it surfaces as a snackbar. A **first-load** failure is terminal and
/// renders the full-screen retry.
class ChatConversationView extends StatefulWidget {
  const ChatConversationView({
    super.key,
    this.counterpartName,
    this.attachmentSource,
  });

  /// Counterpart display name — personalizes the empty state and reply banner.
  final String? counterpartName;

  /// Source for the composer's attachment button. Null → no attachments.
  final ChatAttachmentSource? attachmentSource;

  @override
  State<ChatConversationView> createState() => _ChatConversationViewState();
}

class _ChatConversationViewState extends State<ChatConversationView> {
  /// The message the next send will quote, or null. Presentation-only compose
  /// state: the cubit already accepts `replyToMessageId`, so nothing about the
  /// domain or the write path changes — this just remembers the target and is
  /// cleared once the send lands (or the user cancels).
  ChatMessage? _replyTarget;

  /// The id of the message my own participant sent, when known — resolves the
  /// reply author label ("You" vs the counterpart).
  String? _myUserId;

  void _startReply(ChatMessage message) =>
      setState(() => _replyTarget = message);

  void _cancelReply() => setState(() => _replyTarget = null);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatConversationCubit, ChatConversationState>(
      listenWhen: (prev, next) =>
          next.maybeMap(error: (_) => true, orElse: () => false) &&
          prev.maybeMap(loaded: (_) => true, orElse: () => false),
      listener: (context, state) => state.mapOrNull(
        error: (e) => context.showError(e.message),
      ),
      builder: (context, state) {
        final cubit = context.read<ChatConversationCubit>();
        return state.when(
          loading: () => const _ThreadSkeleton(),
          error: (message) => _ErrorView(
            message: message,
            onRetry: cubit.load,
          ),
          loaded: (conversation, messages, myUserId, sending, loadingOlder,
                  hasMore, deletingMessageId) {
            _myUserId = myUserId;
            final reply = _replyTarget;
            return Column(
              children: [
                Expanded(
                  child: ChatMessageList(
                    messages: messages,
                    myUserId: myUserId,
                    hasMore: hasMore,
                    loadingOlder: loadingOlder,
                    onLoadOlder: cubit.loadOlder,
                    onVisible: cubit.markVisibleRead,
                    deletingMessageId: deletingMessageId,
                    counterpartName: widget.counterpartName,
                    onMessageLongPress: (message, mine) =>
                        _onMessageLongPress(context, message, mine),
                    onReply: _startReply,
                    onRetry: (message) => cubit.retrySend(message.id),
                    onImageTap: (message) => _openImage(context, cubit, message),
                    imageUrlLoader: (message) =>
                        cubit.attachmentDownloadUrl(message.id),
                  ),
                ),
                ChatComposer(
                  sending: sending,
                  attachmentSource: widget.attachmentSource,
                  header: reply == null
                      ? null
                      : ReplyComposerBanner(
                          authorLabel: _authorLabel(reply.senderId),
                          snippet: chatReplySnippet(
                            body: reply.body,
                            attachment: reply.attachment,
                          ),
                          onCancel: _cancelReply,
                        ),
                  onSend: (text, attachment) => _send(cubit, text, attachment),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Sends through the cubit, quoting the active reply target when set, and
  /// clears the reply banner only on success — a failed send keeps the target
  /// (and, via the composer, the text) so the retry quotes the same message.
  Future<bool> _send(
    ChatConversationCubit cubit,
    String text,
    ChatOutgoingAttachment? attachment,
  ) async {
    final ok = await cubit.sendMessage(
      text,
      replyToMessageId: _replyTarget?.id,
      attachment: attachment,
    );
    if (ok && mounted && _replyTarget != null) {
      setState(() => _replyTarget = null);
    }
    return ok;
  }

  String _authorLabel(String senderId) =>
      senderId == _myUserId ? 'You' : (widget.counterpartName ?? 'Them');

  void _openImage(
    BuildContext context,
    ChatConversationCubit cubit,
    ChatMessage message,
  ) {
    ImageViewerScreen.push(
      context,
      bytes: message.localBytes,
      urlLoader: message.localBytes == null
          ? () => cubit.attachmentDownloadUrl(message.id)
          : null,
      title: message.attachment?.originalFilename,
      heroTag: 'chat-image-${message.id}',
    );
  }

  /// Long-press → context menu → the chosen action. Reply/Copy are handled
  /// here in the presentation layer; deletes go to the cubit, where the backend
  /// enforces the actual rules (sender-only, time window) and a refusal surfaces
  /// through the transient-error snackbar.
  Future<void> _onMessageLongPress(
      BuildContext context, ChatMessage message, bool mine) async {
    final cubit = context.read<ChatConversationCubit>();
    final action =
        await showChatMessageActions(context, message: message, mine: mine);
    if (action == null || !context.mounted) return;
    switch (action) {
      case ChatMessageAction.reply:
        _startReply(message);
      case ChatMessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.body ?? ''));
        if (context.mounted) context.showSuccess('Copied to clipboard');
      case ChatMessageAction.messageInfo:
        await MessageInfoScreen.push(
          context,
          message: message,
          mine: mine,
          senderLabel: mine ? 'You' : (widget.counterpartName ?? 'Them'),
          replyAuthorLabel: message.replyTo == null
              ? null
              : (message.replyTo!.senderId == _myUserId
                  ? 'You'
                  : (widget.counterpartName ?? 'Them')),
        );
      case ChatMessageAction.deleteForMe:
        await cubit.deleteMessageForMe(message.id);
      case ChatMessageAction.deleteForEveryone:
        await cubit.deleteMessageForEveryone(message.id);
    }
  }
}

/// A shimmering placeholder for the first-open load — a handful of alternating
/// bubble skeletons, bottom-anchored like the real thread. A re-opened
/// conversation paints from cache instead and never shows this.
class _ThreadSkeleton extends StatelessWidget {
  const _ThreadSkeleton();

  // (mine, width) for a natural back-and-forth rhythm.
  static const _rows = <(bool, double)>[
    (false, 180),
    (false, 120),
    (true, 210),
    (false, 90),
    (true, 150),
    (true, 240),
    (false, 160),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (final (mine, width) in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Skeleton(
                  width: width,
                  height: 40,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The "Replying to …" banner shown inside the composer surface while a reply
/// is being composed — a left accent bar, the quoted author + snippet, and a
/// cancel affordance. Presentation-only; the parent owns the reply target.
class ReplyComposerBanner extends StatelessWidget {
  const ReplyComposerBanner({
    super.key,
    required this.authorLabel,
    required this.snippet,
    required this.onCancel,
  });

  final String authorLabel;
  final String snippet;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replying to $authorLabel',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    snippet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.textTertiary,
              visualDensity: VisualDensity.compact,
              tooltip: 'Cancel reply',
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.textTertiary, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
