import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/features/chat/domain/chat_realtime.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/usecases/get_conversations.dart';
import 'package:drop/features/chat/domain/usecases/start_conversation.dart';
import 'chat_list_state.dart';

/// Drives the chat inbox (conversation list) — REST + cursor pagination,
/// enriched live by the shared socket. Singleton, app-wide, mirroring
/// [CaseListCubit]'s role for Cases; the open thread lives in its own
/// per-conversation cubit.
///
/// The server orders by most-recent-activity and owns the pagination cursor;
/// this cubit never re-sorts on its own — it accumulates pages and dedupes by
/// id, with one exception: a live `message:new` moves its conversation to the
/// top, exactly the move the server has already made in its own ordering.
///
/// **Realtime (optional [ChatRealtime]):** the shared socket's personal
/// `user:{id}` room delivers `message:new` for every conversation with no
/// room join, so the first [load] declares inbox interest
/// ([ChatRealtime.attachInbox]) and the cubit then keeps the inbox live —
/// reorder + activity bump, a client-held last-message preview, and a
/// client-counted unread badge (the backend pushes no counts; opening a
/// conversation clears its badge via [clearUnread]). Events are deduped by
/// per-conversation `seq`, an unknown conversation falls back to a full
/// refresh (server truth — the client never invents a row), and a reconnect
/// refreshes the first page, which by design resets pagination.
class ChatListCubit extends Cubit<ChatListState> {
  final GetConversations _getConversations;
  final StartConversation _startConversation;
  final ChatRealtime? _realtime;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;
  bool _inboxAttached = false;

  List<ChatConversationSummary> _conversations = const [];
  String? _nextCursor;
  bool _hasLoaded = false;
  bool _loading = false;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _starting = false;

  // Live socket-derived enrichment, keyed by conversation id (see the state
  // docs). _previewMessageIds remembers WHICH message a preview shows so a
  // live delete-for-everyone can tombstone it; _lastSeenSeq dedupes event
  // replays and drops out-of-order stragglers.
  final Map<String, String> _previews = {};
  final Map<String, String> _previewMessageIds = {};
  final Map<String, BigInt> _lastSeenSeq = {};
  final Map<String, int> _unread = {};

  ChatListCubit({
    required this._getConversations,
    required this._startConversation,
    this._realtime,
  })  : super(const ChatListState.initial()) {
    _realtimeSub = _realtime?.events.listen(_onRealtimeEvent);
  }

  @override
  Future<void> close() async {
    await _realtimeSub?.cancel();
    if (_inboxAttached) await _realtime?.detachInbox();
    return super.close();
  }

  void _emitLoaded() {
    if (isClosed) return;
    emit(ChatListState.loaded(
      List.of(_conversations),
      refreshing: _refreshing,
      loadingMore: _loadingMore,
      hasMore: _nextCursor != null,
      starting: _starting,
      previews: Map.of(_previews),
      unreadCounts: Map.of(_unread),
    ));
  }

  /// Loads the first page. Idempotent once loaded — call with [forceRefresh]
  /// (or via [refresh]) to re-pull. A refresh keeps the current list visible
  /// ([ChatListState.loaded.refreshing]) instead of dropping to a spinner, and
  /// resets pagination to page one (the server's ordering may have changed).
  Future<void> load({bool forceRefresh = false}) async {
    if (_loading) return;
    final inError = state.maybeMap(error: (_) => true, orElse: () => false);
    if (_hasLoaded && !forceRefresh && !inError) return;

    // First load = the inbox is on screen — declare inbox interest so the
    // shared socket stays alive and `user:{id}`-room events flow. Singleton
    // cubit: interest persists for the app's life (withdrawn only on close).
    final rt = _realtime;
    if (rt != null && !_inboxAttached) {
      _inboxAttached = true;
      rt.attachInbox(); // fire-and-forget; failure just means REST-only
    }

    _loading = true;
    if (_hasLoaded && _conversations.isNotEmpty) {
      _refreshing = true;
      _emitLoaded();
    } else {
      emit(const ChatListState.loading());
    }

    try {
      final page = await _getConversations();
      _conversations = page.items;
      _nextCursor = page.nextCursor;
      _hasLoaded = true;
      _refreshing = false;
      _emitLoaded();
    } on Failure catch (e) {
      _refreshing = false;
      emit(ChatListState.error(e.message));
      // Transient when we still have a list to show (Cases convention).
      if (_hasLoaded) _emitLoaded();
    } catch (e) {
      AppLog.warning('chat', 'conversation list load failed: $e');
      _refreshing = false;
      emit(const ChatListState.error(
          'Failed to load conversations. Please try again.'));
      if (_hasLoaded) _emitLoaded();
    } finally {
      _loading = false;
    }
  }

  Future<void> refresh() => load(forceRefresh: true);

  /// Clears the unread badge for [conversationId] — called when the user
  /// opens the conversation (the client counts unread itself; the backend
  /// pushes no counts on this surface).
  void clearUnread(String conversationId) {
    if (_unread.remove(conversationId) == null) return;
    if (_hasLoaded) _emitLoaded();
  }

  // ─── Realtime (socket, shared with the thread cubits) ─────────────────

  void _onRealtimeEvent(ChatRealtimeEvent event) {
    if (isClosed) return;
    switch (event) {
      case ChatRealtimeConnected(:final isReconnect):
        // Anything could have happened in the gap (new conversations, new
        // messages, deletions) — re-pull page one, the documented refresh
        // path (list stays visible; pagination resets by design).
        if (isReconnect && _hasLoaded) load(forceRefresh: true);
      case ChatMessageReceived(:final message):
        _applyLiveMessage(message);
      case ChatMessageDeletedReceived e:
        // Only affects the inbox when the deleted message is the one being
        // previewed — swap in the placeholder (activity/order unchanged).
        if (_previewMessageIds[e.conversationId] == e.messageId) {
          _previews[e.conversationId] = chatDeletedForEveryonePlaceholder;
          if (_hasLoaded) _emitLoaded();
        }
      case ChatRealtimeDisconnected() ||
            ChatMessagesReadReceived() ||
            ChatMessageHiddenReceived():
        // Read receipts concern the thread view; a hidden message's preview
        // replacement isn't derivable client-side (next refresh corrects it);
        // a disconnect needs no UI (reconnect + refresh are automatic).
        break;
    }
  }

  /// A live message in one of my conversations (the server excludes my own
  /// sends, so this is always counterpart activity): bump the row to the top
  /// with fresh activity, update its preview, and count it unread. Deduped
  /// by per-conversation `seq` so replays and out-of-order stragglers are
  /// no-ops. An unknown conversation id → full refresh (server truth).
  void _applyLiveMessage(ChatMessage message) {
    if (!_hasLoaded) return; // nothing on screen to sync yet

    final lastSeen = _lastSeenSeq[message.conversationId];
    if (lastSeen != null && message.seq <= lastSeen) return;
    _lastSeenSeq[message.conversationId] = message.seq;

    final index =
        _conversations.indexWhere((c) => c.id == message.conversationId);
    if (index < 0) {
      // A conversation this page window doesn't hold (brand new, or beyond
      // the loaded pages). The client never invents a row — refresh instead.
      load(forceRefresh: true);
      return;
    }

    final bumped =
        _conversations[index].withLastMessageAt(message.createdAt);
    _conversations = [
      bumped,
      ..._conversations.take(index),
      ..._conversations.skip(index + 1),
    ];
    _previews[message.conversationId] = _previewOf(message);
    _previewMessageIds[message.conversationId] = message.id;
    _unread[message.conversationId] =
        (_unread[message.conversationId] ?? 0) + 1;
    _emitLoaded();
  }

  String _previewOf(ChatMessage message) {
    if (message.deletedForEveryone) return chatDeletedForEveryonePlaceholder;
    final body = (message.body ?? '').trim();
    if (body.isNotEmpty) return body;
    final attachment = message.attachment;
    return attachment != null ? attachment.originalFilename : '';
  }

  /// Loads the next (older-activity) page and appends it. No-op while a page
  /// is already in flight or when the server reported no more pages.
  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore || _loading || !_hasLoaded) return;

    _loadingMore = true;
    _emitLoaded();
    try {
      final page = await _getConversations(cursor: cursor);
      final known = {for (final c in _conversations) c.id};
      _conversations = [
        ..._conversations,
        ...page.items.where((c) => !known.contains(c.id)),
      ];
      _nextCursor = page.nextCursor;
    } on Failure catch (e) {
      emit(ChatListState.error(e.message));
    } catch (e) {
      AppLog.warning('chat', 'conversation list page failed: $e');
      emit(const ChatListState.error('Failed to load more conversations.'));
    } finally {
      _loadingMore = false;
      _emitLoaded();
    }
  }

  /// Starts (get-or-creates) the conversation with [targetUserId] — the
  /// **backend-internal** user UUID, not a Firebase uid (see the identity
  /// mapping note on [ChatRepository.startConversation]). Returns the
  /// conversation for navigation, or null on failure. Idempotent server-side,
  /// so re-tapping an existing counterpart just returns the existing thread.
  Future<ChatConversation?> startChatWith(String targetUserId) async {
    if (_starting) return null;
    _starting = true;
    _emitLoaded();
    try {
      final conversation = await _startConversation(targetUserId);
      // Surface it at the top immediately; the server list will agree on the
      // next refresh (a fresh conversation is its most recent activity).
      if (!_conversations.any((c) => c.id == conversation.id)) {
        _conversations = [
          ChatConversationSummary(
            id: conversation.id,
            counterpartUserId: targetUserId,
            participantIds: conversation.participantIds,
            createdAt: conversation.createdAt,
            lastMessageAt: conversation.lastMessageAt,
          ),
          ..._conversations,
        ];
      }
      return conversation;
    } on Failure catch (e) {
      emit(ChatListState.error(e.message));
      return null;
    } catch (e) {
      AppLog.warning('chat', 'start conversation failed: $e');
      emit(const ChatListState.error('Failed to start the conversation.'));
      return null;
    } finally {
      _starting = false;
      _emitLoaded();
    }
  }
}
