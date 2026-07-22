import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_state.dart';
import 'package:drop/features/chat/presentation/widgets/chat_conversation_tile.dart';

/// Direct-chat inbox — the caller's conversations, most-recent-activity first
/// (server-ordered; the cubit never re-sorts). Mirrors the Cases mobile inbox
/// shape: full-screen first-load spinner, branded empty state, full-screen
/// retry on a data-less failure, pull-to-refresh, and a scroll-driven older
/// page (the NestJS list is cursor-paginated, unlike Cases).
///
/// Tapping a row pushes the conversation route; the thread UI itself is the
/// next phase.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ChatListCubit>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Chat',
      subtitle: 'Direct messages with your team',
      body: BlocConsumer<ChatListCubit, ChatListState>(
        // A failure while a list is on screen is transient (the cubit
        // immediately re-emits the last loaded list) — surface it as a
        // snackbar instead of losing the data. A first-load failure falls
        // through to the full-screen retry below.
        listenWhen: (prev, next) =>
            next.maybeMap(error: (_) => true, orElse: () => false) &&
            prev.maybeMap(loaded: (_) => true, orElse: () => false),
        listener: (context, state) {
          state.mapOrNull(
            error: (e) => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(e.message))),
          );
        },
        builder: (context, state) {
          return state.when(
            initial: () => const _Loading(),
            loading: () => const _Loading(),
            error: (message) => _ErrorView(
              message: message,
              onRetry: () => context.read<ChatListCubit>().refresh(),
            ),
            loaded: (conversations, refreshing, loadingMore, hasMore, _,
                    previews, unreadCounts) =>
                RefreshIndicator(
              onRefresh: () => context.read<ChatListCubit>().refresh(),
              color: AppColors.primary,
              child: conversations.isEmpty
                  ? const DropEmptyState(
                      title: 'No conversations yet',
                      message:
                          'Direct messages with your teammates will appear here.',
                    )
                  : _ConversationList(
                      conversations: conversations,
                      loadingMore: loadingMore,
                      hasMore: hasMore,
                      previews: previews,
                      unreadCounts: unreadCounts,
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.loadingMore,
    required this.hasMore,
    required this.previews,
    required this.unreadCounts,
  });

  final List<ChatConversationSummary> conversations;
  final bool loadingMore;
  final bool hasMore;

  /// Live socket-derived enrichment (see [ChatListState.loaded]) — fills the
  /// tile's override slots; absent key → the tile's honest fallback.
  final Map<String, String> previews;
  final Map<String, int> unreadCounts;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Near the bottom → pull the next (older-activity) page. The cubit
        // no-ops while a page is in flight or when the cursor is exhausted.
        if (hasMore && notification.metrics.extentAfter < 400) {
          context.read<ChatListCubit>().loadMore();
        }
        return false;
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.huge),
        itemCount: conversations.length + (loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == conversations.length) return const _PageSpinnerRow();
          final conversation = conversations[index];
          final preview = previews[conversation.id];
          return ChatConversationTile(
            conversation: conversation,
            preview: preview == null || preview.isEmpty ? null : preview,
            unreadCount: unreadCounts[conversation.id],
            onTap: () {
              // Opening the conversation clears its unread badge (Cases'
              // markSeen convention).
              context.read<ChatListCubit>().clearUnread(conversation.id);
              context.push(
                RouteNames.chatConversation(conversation.id),
                extra: conversation.counterpartUserId,
              );
            },
          );
        },
      ),
    );
  }
}

class _PageSpinnerRow extends StatelessWidget {
  const _PageSpinnerRow();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
