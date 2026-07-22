import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
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
class ChatConversationView extends StatelessWidget {
  const ChatConversationView({super.key});

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
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (message) => _ErrorView(
            message: message,
            onRetry: cubit.load,
          ),
          loaded: (conversation, messages, myUserId, sending, loadingOlder,
                  hasMore, deletingMessageId) =>
              Column(
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
                  onMessageLongPress: (message, mine) =>
                      _onMessageLongPress(context, message, mine),
                ),
              ),
              ChatComposer(
                onSend: cubit.sendMessage,
                sending: sending,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Long-press → context menu → confirm → cubit. The sheet decides which
  /// actions to *offer* from identity facts only; the backend enforces the
  /// actual rules (sender-only, time window) and a refusal surfaces its own
  /// message through the transient-error snackbar.
  Future<void> _onMessageLongPress(
      BuildContext context, ChatMessage message, bool mine) async {
    final cubit = context.read<ChatConversationCubit>();
    final action =
        await showChatMessageActions(context, message: message, mine: mine);
    if (action == null) return;
    switch (action) {
      case ChatMessageAction.deleteForMe:
        await cubit.deleteMessageForMe(message.id);
      case ChatMessageAction.deleteForEveryone:
        await cubit.deleteMessageForEveryone(message.id);
    }
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
