import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/utils/uuid.dart';
import 'package:drop/features/chat/domain/chat_realtime.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_everyone.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_me.dart';
import 'package:drop/features/chat/domain/usecases/get_conversation.dart';
import 'package:drop/features/chat/domain/usecases/load_chat_history.dart';
import 'package:drop/features/chat/domain/usecases/mark_chat_read.dart';
import 'package:drop/features/chat/domain/usecases/send_chat_message.dart';
import 'chat_conversation_state.dart';

/// Drives ONE open chat thread — created per opened conversation (mirroring
/// [CaseConversationCubit]'s lifecycle) and REST-only for now: new incoming
/// messages arrive with the socket phase, which will feed this same cubit.
///
/// **Send idempotency (backend-aligned):** every logical send mints one UUID
/// `idempotencyKey`. If the send fails and the user retries the *same* text,
/// the key is **reused**, so a send whose response was lost in transit can
/// never duplicate the message server-side — this is the exact retry contract
/// the backend's dedupe was built for. No fake optimistic bubble is shown: the
/// authoritative message (with its server-assigned `seq`) comes back in the
/// send response and is appended then. Pending/failed bubble states belong to
/// the realtime phase, where reconciliation makes them worth their complexity.
///
/// **Identity note:** the API exposes no "who am I" endpoint, so the caller's
/// backend-internal id is *derived* — from [counterpartUserId] (known when
/// opened from the list) or from the first sent message's `senderId`. On a
/// deep link into a never-messaged thread it stays null until one of those
/// resolves; a `GET /users/me` endpoint would remove this dance entirely.
///
/// **Realtime (optional [ChatRealtime]):** REST stays the source of truth and
/// the only write path; the socket just delivers facts early. The cubit joins
/// its conversation's room for its lifetime, applies live `message:new`
/// (insert in `seq` order, deduped — the server never echoes the caller's own
/// sends) and `message:read` (upgrade the listed messages to READ), and on a
/// **reconnect** reconciles by re-fetching the newest history page and merging
/// it — the backend's documented recovery contract (delivery is best-effort;
/// clients catch up over REST). Realtime failures are silent: without a socket
/// the thread simply behaves like the REST-only build.
class ChatConversationCubit extends Cubit<ChatConversationState> {
  final GetConversation _getConversation;
  final LoadChatHistory _loadHistory;
  final SendChatMessage _sendMessage;
  final MarkChatRead _markRead;
  final DeleteChatMessageForMe _deleteForMe;
  final DeleteChatMessageForEveryone _deleteForEveryone;
  final ChatRealtime? _realtime;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;

  final String conversationId;

  /// The other participant's backend-internal id, when the opener knows it
  /// (list rows carry it); enables own-message alignment before the first send.
  final String? counterpartUserId;

  ChatConversation? _conversation;
  List<ChatMessage> _messages = const [];
  String? _nextCursor;
  String? _myUserId;
  bool _loading = false;
  bool _sending = false;
  bool _loadingOlder = false;
  String? _deletingMessageId;
  BigInt? _lastMarkedSeq;
  _FailedSend? _failedSend;

  ChatConversationCubit({
    required this._getConversation,
    required this._loadHistory,
    required this._sendMessage,
    required this._markRead,
    required this._deleteForMe,
    required this._deleteForEveryone,
    required this.conversationId,
    this.counterpartUserId,
    this._realtime,
  })  : super(const ChatConversationState.loading()) {
    final rt = _realtime;
    if (rt != null) {
      _realtimeSub = rt.events.listen(_onRealtimeEvent);
      // Fire-and-forget: a refused/failed join leaves the thread REST-only
      // (and the service keeps retrying the connection underneath).
      rt.joinConversation(conversationId);
    }
    load();
  }

  @override
  Future<void> close() async {
    await _realtimeSub?.cancel();
    await _realtime?.leaveConversation(conversationId);
    return super.close();
  }

  void _emit() {
    if (isClosed) return;
    final conversation = _conversation;
    if (conversation == null) return;
    emit(ChatConversationState.loaded(
      conversation,
      List.of(_messages),
      myUserId: _myUserId,
      sending: _sending,
      loadingOlder: _loadingOlder,
      hasMore: _nextCursor != null,
      deletingMessageId: _deletingMessageId,
    ));
  }

  /// Derives the caller's internal id once the conversation and counterpart
  /// are both known: my id is the participant that isn't the counterpart.
  void _deriveMyUserId() {
    if (_myUserId != null) return;
    final counterpart = counterpartUserId;
    final conversation = _conversation;
    if (counterpart == null || conversation == null) return;
    for (final id in conversation.participantIds) {
      if (id != counterpart) {
        _myUserId = id;
        return;
      }
    }
  }

  /// Initial load (also the full-screen retry): conversation + newest history
  /// page in parallel. Loading history does NOT mark anything read — that's
  /// [markVisibleRead], fired by the UI when messages are actually on screen.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    if (_conversation == null) emit(const ChatConversationState.loading());
    try {
      final results = await Future.wait<dynamic>([
        _getConversation(conversationId),
        _loadHistory(conversationId: conversationId),
      ]);
      _conversation = results[0] as ChatConversation;
      final page = results[1] as ChatMessagePage;
      _messages = page.items;
      _nextCursor = page.nextCursor;
      _deriveMyUserId();
      _emit();
    } on Failure catch (e) {
      emit(ChatConversationState.error(e.message));
      _emit(); // transient when the thread is already on screen
    } catch (e) {
      AppLog.warning('chat', 'conversation load failed: $e');
      emit(const ChatConversationState.error(
          'Failed to load the conversation. Please try again.'));
      _emit();
    } finally {
      _loading = false;
    }
  }

  /// Loads the next **older** page and prepends it (scroll-back). No-op while
  /// one is in flight or when the full history has been loaded.
  Future<void> loadOlder() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingOlder || _conversation == null) return;

    _loadingOlder = true;
    _emit();
    try {
      final page = await _loadHistory(
        conversationId: conversationId,
        cursor: cursor,
      );
      final known = {for (final m in _messages) m.id};
      _messages = [
        ...page.items.where((m) => !known.contains(m.id)),
        ..._messages,
      ];
      _nextCursor = page.nextCursor;
    } on Failure catch (e) {
      emit(ChatConversationState.error(e.message));
    } catch (e) {
      AppLog.warning('chat', 'history page failed: $e');
      emit(const ChatConversationState.error('Failed to load older messages.'));
    } finally {
      _loadingOlder = false;
      _emit();
    }
  }

  /// Sends a text message (optionally quoting [replyToMessageId]). Returns
  /// whether it was sent — the composer keys its input-clearing off this, so a
  /// failed send never loses what the user typed (Cases convention). On
  /// success the server's authoritative message is appended to the thread.
  Future<bool> sendMessage(String text, {String? replyToMessageId}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending || _conversation == null) return false;

    // A retry of the exact same failed send reuses its idempotency key — the
    // server then returns the already-persisted message (if the failure was
    // only a lost response) instead of writing a duplicate.
    final failed = _failedSend;
    final idempotencyKey =
        (failed != null && failed.matches(trimmed, replyToMessageId))
            ? failed.idempotencyKey
            : UuidV4.generate();

    _sending = true;
    _emit();
    try {
      final sent = await _sendMessage(
        conversationId: conversationId,
        idempotencyKey: idempotencyKey,
        content: trimmed,
        replyToMessageId: replyToMessageId,
      );
      _failedSend = null;
      _myUserId ??= sent.senderId; // authoritative "me" from my own send
      // Append (or replace, on an idempotent replay already in the list).
      final index = _messages.indexWhere((m) => m.id == sent.id);
      _messages = index >= 0
          ? ([..._messages]..[index] = sent)
          : [..._messages, sent];
      return true;
    } on Failure catch (e) {
      _failedSend = _FailedSend(trimmed, replyToMessageId, idempotencyKey);
      emit(ChatConversationState.error(e.message));
      return false;
    } catch (e) {
      AppLog.warning('chat', 'send failed: $e');
      _failedSend = _FailedSend(trimmed, replyToMessageId, idempotencyKey);
      emit(const ChatConversationState.error('Failed to send your message.'));
      return false;
    } finally {
      _sending = false;
      _emit();
    }
  }

  // ─── Message deletion (REST — the socket only echoes the fact) ────────

  /// Hides [messageId] from this user's view only (the counterpart is
  /// unaffected — strictly one-sided, backend INV-19). Returns whether it
  /// succeeded; failures surface through the transient-error convention.
  /// One delete in flight at a time.
  Future<bool> deleteMessageForMe(String messageId) async {
    if (_deletingMessageId != null || _conversation == null) return false;
    _deletingMessageId = messageId;
    _emit();
    try {
      await _deleteForMe(
          conversationId: conversationId, messageId: messageId);
      _messages = [..._messages]..removeWhere((m) => m.id == messageId);
      return true;
    } on Failure catch (e) {
      emit(ChatConversationState.error(e.message));
      return false;
    } catch (e) {
      AppLog.warning('chat', 'delete for me failed: $e');
      emit(const ChatConversationState.error(
          'Failed to delete the message.'));
      return false;
    } finally {
      _deletingMessageId = null;
      _emit();
    }
  }

  /// Deletes [messageId] for **both** participants. The server enforces every
  /// rule — original sender only, within its time window — and refuses with a
  /// clear 403 message otherwise; the client never pre-computes permission.
  /// On success the server's tombstone (placeholder body) replaces the
  /// message in place. Idempotent server-side.
  Future<bool> deleteMessageForEveryone(String messageId) async {
    if (_deletingMessageId != null || _conversation == null) return false;
    _deletingMessageId = messageId;
    _emit();
    try {
      final tombstone = await _deleteForEveryone(
          conversationId: conversationId, messageId: messageId);
      _insertBySeq(tombstone);
      return true;
    } on Failure catch (e) {
      emit(ChatConversationState.error(e.message));
      return false;
    } catch (e) {
      AppLog.warning('chat', 'delete for everyone failed: $e');
      emit(const ChatConversationState.error(
          'Failed to delete the message.'));
      return false;
    } finally {
      _deletingMessageId = null;
      _emit();
    }
  }

  // ─── Realtime (socket) ────────────────────────────────────────────────

  void _onRealtimeEvent(ChatRealtimeEvent event) {
    if (isClosed) return;
    switch (event) {
      case ChatRealtimeConnected(:final isReconnect):
        // The connection was down for a while — messages sent in the gap were
        // never pushed. Rooms are already re-joined by the service; catch up
        // through REST, the source of truth.
        if (isReconnect) _reconcile();
      case ChatMessageReceived(:final message):
        if (message.conversationId != conversationId) return;
        if (_conversation == null) return; // initial load will fetch it
        _insertBySeq(message);
        _emit();
      case ChatMessagesReadReceived e:
        if (e.conversationId != conversationId) return;
        _applyReadReceipt(e);
      case ChatMessageDeletedReceived e:
        // Deleted for everyone (by either side) — re-render the placeholder.
        if (e.conversationId != conversationId) return;
        final index = _messages.indexWhere((m) => m.id == e.messageId);
        if (index < 0 || _messages[index].deletedForEveryone) return;
        _messages = [..._messages]
          ..[index] = _messages[index].asDeletedForEveryone();
        _emit();
      case ChatMessageHiddenReceived e:
        // This user hid the message on another of their own sessions —
        // mirror it here (strictly one-sided; nothing reaches the other side).
        if (e.conversationId != conversationId) return;
        final before = _messages.length;
        _messages = [..._messages]..removeWhere((m) => m.id == e.messageId);
        if (_messages.length != before) _emit();
      case ChatRealtimeDisconnected():
        // No UI — reconnect + reconcile are automatic.
        break;
    }
  }

  /// Inserts a live message at its `seq` position (dedup by id — an id already
  /// present is replaced, keeping the newer server view). Almost always a
  /// plain append; the ordered path covers late deliveries after a reconcile.
  void _insertBySeq(ChatMessage message) {
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      _messages = [..._messages]..[index] = message;
      return;
    }
    if (_messages.isEmpty || message.seq > _messages.last.seq) {
      _messages = [..._messages, message];
      return;
    }
    final at = _messages.indexWhere((m) => m.seq > message.seq);
    _messages = [..._messages]..insert(at < 0 ? _messages.length : at, message);
  }

  /// The counterpart read a batch of my messages — upgrade their status. The
  /// server excludes the reader's own sockets, so no self-check is needed;
  /// ids not currently loaded are simply skipped (history re-fetch would show
  /// the same truth).
  void _applyReadReceipt(ChatMessagesReadReceived receipt) {
    final ids = receipt.messageIds.toSet();
    var changed = false;
    final updated = <ChatMessage>[];
    for (final m in _messages) {
      if (ids.contains(m.id) && m.status != 'READ') {
        updated.add(m.withStatus('READ'));
        changed = true;
      } else {
        updated.add(m);
      }
    }
    if (!changed) return;
    _messages = updated;
    _emit();
  }

  /// Post-reconnect catch-up: re-fetch the newest history page and merge it —
  /// new ids are inserted in `seq` order, known ids take the server's view.
  /// A gap larger than one page is left for scroll-back to fill (the loaded
  /// window stays contiguous at its newest edge, which is what the thread
  /// shows). Failures are silent: the next reconnect or manual refresh
  /// reconciles, and stale-but-consistent beats an error banner mid-thread.
  Future<void> _reconcile() async {
    if (_conversation == null) return; // first load hasn't succeeded yet
    try {
      final page = await _loadHistory(conversationId: conversationId);
      for (final message in page.items) {
        _insertBySeq(message);
      }
      if (_messages.isEmpty) _nextCursor = page.nextCursor;
      _emit();
    } on Failure catch (e) {
      AppLog.warning('chat', 'reconnect reconcile failed: ${e.message}');
    } catch (e) {
      AppLog.warning('chat', 'reconnect reconcile failed: $e');
    }
  }

  /// Marks the thread read up to the newest loaded message — call when the
  /// messages are actually **visible** (the backend treats mark-read as the
  /// opened-and-visible signal, not a fetch side effect). Monotonic and
  /// fire-and-forget: failures are logged, never surfaced — a missed read
  /// receipt isn't worth an error banner.
  Future<void> markVisibleRead() async {
    if (_messages.isEmpty) return;
    final upToSeq = _messages.last.seq;
    final already = _lastMarkedSeq;
    if (already != null && upToSeq <= already) return;

    _lastMarkedSeq = upToSeq; // set first so concurrent calls no-op
    try {
      await _markRead(conversationId: conversationId, upToSeq: upToSeq);
    } on Failure catch (e) {
      if (_lastMarkedSeq == upToSeq) _lastMarkedSeq = already;
      AppLog.warning('chat', 'mark-read failed: ${e.message}');
    } catch (e) {
      if (_lastMarkedSeq == upToSeq) _lastMarkedSeq = already;
      AppLog.warning('chat', 'mark-read failed: $e');
    }
  }
}

/// The one remembered failed send, so an identical retry can reuse its
/// idempotency key (see [ChatConversationCubit.sendMessage]).
class _FailedSend {
  final String content;
  final String? replyToMessageId;
  final String idempotencyKey;

  const _FailedSend(this.content, this.replyToMessageId, this.idempotencyKey);

  bool matches(String content, String? replyToMessageId) =>
      this.content == content && this.replyToMessageId == replyToMessageId;
}
