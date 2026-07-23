import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/chat_message_type.dart';
import 'package:drop/features/chat/data/realtime/chat_realtime_payloads.dart';
import 'package:drop/features/chat/domain/chat_realtime.dart';
import 'package:drop/features/chat/domain/entities/chat_attachment_download.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/domain/entities/chat_read_receipt.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_everyone.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_me.dart';
import 'package:drop/features/chat/domain/usecases/get_conversation.dart';
import 'package:drop/features/chat/domain/usecases/load_chat_history.dart';
import 'package:drop/features/chat/domain/usecases/mark_chat_read.dart';
import 'package:drop/features/chat/domain/usecases/send_chat_message.dart';
import 'package:drop/features/chat/presentation/cubit/chat_conversation_cubit.dart';

const _me = 'me-uuid';
const _them = 'them-uuid';
const _convId = 'conv-1';

ChatMessage _message(String id, int seq, String sender, String body) =>
    ChatMessage(
      id: id,
      conversationId: _convId,
      senderId: sender,
      type: ChatMessageType.text,
      body: body,
      seq: BigInt.from(seq),
      status: 'SENT',
      createdAt: DateTime(2026, 7, 22, 9, seq % 60),
    );

/// Scripted fake for the realtime port: records joins/leaves and lets the
/// test push events into the cubit.
class _FakeRealtime implements ChatRealtime {
  final controller = StreamController<ChatRealtimeEvent>.broadcast(sync: true);
  final joined = <String>[];
  final left = <String>[];

  @override
  Stream<ChatRealtimeEvent> get events => controller.stream;

  @override
  Future<bool> joinConversation(String conversationId) async {
    joined.add(conversationId);
    return true;
  }

  @override
  Future<void> leaveConversation(String conversationId) async {
    left.add(conversationId);
  }

  @override
  Future<void> attachInbox() async {}

  @override
  Future<void> detachInbox() async {}
}

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({required this.onHistory});

  final Future<ChatMessagePage> Function({String? cursor}) onHistory;

  @override
  Future<ChatConversation> getConversation(String conversationId) async =>
      ChatConversation(
        id: _convId,
        participantIds: const [_me, _them],
        createdAt: DateTime(2026, 7, 20),
      );

  @override
  Future<ChatMessagePage> getMessageHistory({
    required String conversationId,
    int? limit,
    String? cursor,
  }) =>
      onHistory(cursor: cursor);

  @override
  Future<ChatReadReceipt> markMessagesRead({
    required String conversationId,
    required BigInt upToSeq,
  }) async =>
      ChatReadReceipt(
          conversationId: conversationId,
          markedCount: 0,
          readAt: DateTime(2026, 7, 22));

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
    void Function(int sent, int total)? onSendProgress,
  }) =>
      throw UnimplementedError();

  @override
  Future<ChatConversation> startConversation(String targetUserId) =>
      throw UnimplementedError();

  @override
  Future<ChatConversationPage> getConversations(
          {int? limit, String? cursor}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteMessageForMe(
          {required String conversationId, required String messageId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> deleteMessageForEveryone(
          {required String conversationId, required String messageId}) =>
      throw UnimplementedError();

  @override
  Future<ChatAttachmentDownload> getAttachmentDownloadUrl(
          {required String conversationId, required String messageId}) =>
      throw UnimplementedError();
}

ChatConversationCubit _cubit(_FakeChatRepository repo, _FakeRealtime rt) =>
    ChatConversationCubit(
      getConversation: GetConversation(repo),
      loadHistory: LoadChatHistory(repo),
      sendMessage: SendChatMessage(repo),
      markRead: MarkChatRead(repo),
      deleteForMe: DeleteChatMessageForMe(repo),
      deleteForEveryone: DeleteChatMessageForEveryone(repo),
      conversationId: _convId,
      counterpartUserId: _them,
      realtime: rt,
    );

List<ChatMessage> _messagesOf(ChatConversationCubit cubit) =>
    cubit.state.maybeMap(
        loaded: (s) => s.messages, orElse: () => throw StateError('not loaded'));

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('joins its conversation on creation and leaves on close', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onHistory: ({String? cursor}) async =>
              const ChatMessagePage(items: [])),
      rt,
    );
    await _settle();
    expect(rt.joined, [_convId]);
    await cubit.close();
    expect(rt.left, [_convId]);
  });

  test('a live message:new for this thread is appended once', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onHistory: ({String? cursor}) async =>
              ChatMessagePage(items: [_message('m1', 1, _them, 'Hi')])),
      rt,
    );
    await _settle();

    final live = _message('m2', 2, _them, 'Still there?');
    rt.controller.add(ChatMessageReceived(live));
    rt.controller.add(ChatMessageReceived(live)); // duplicate delivery
    expect(_messagesOf(cubit).map((m) => m.id), ['m1', 'm2']);

    // A different conversation's message is ignored.
    rt.controller.add(ChatMessageReceived(ChatMessage(
      id: 'other',
      conversationId: 'conv-9',
      senderId: _them,
      type: ChatMessageType.text,
      body: 'wrong thread',
      seq: BigInt.from(9),
      status: 'SENT',
      createdAt: DateTime(2026, 7, 22),
    )));
    expect(_messagesOf(cubit).length, 2);
    await cubit.close();
  });

  test('an out-of-order delivery is inserted at its seq position', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onHistory: ({String? cursor}) async => ChatMessagePage(items: [
                _message('m1', 1, _them, 'One'),
                _message('m3', 3, _them, 'Three'),
              ])),
      rt,
    );
    await _settle();

    rt.controller.add(ChatMessageReceived(_message('m2', 2, _them, 'Two')));
    expect(_messagesOf(cubit).map((m) => m.body), ['One', 'Two', 'Three']);
    await cubit.close();
  });

  test('message:read upgrades the listed messages to READ', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onHistory: ({String? cursor}) async => ChatMessagePage(items: [
                _message('m1', 1, _me, 'Mine'),
                _message('m2', 2, _me, 'Mine too'),
                _message('m3', 3, _them, 'Theirs'),
              ])),
      rt,
    );
    await _settle();

    rt.controller.add(ChatMessagesReadReceived(
      conversationId: _convId,
      readerId: _them,
      messageIds: const ['m1', 'm2', 'missing-id'],
      readAt: DateTime(2026, 7, 22, 10),
    ));

    final byId = {for (final m in _messagesOf(cubit)) m.id: m.status};
    expect(byId, {'m1': 'READ', 'm2': 'READ', 'm3': 'SENT'});
    await cubit.close();
  });

  test('a reconnect reconciles missed messages via REST', () async {
    final rt = _FakeRealtime();
    var page = ChatMessagePage(items: [_message('m1', 1, _them, 'Hi')]);
    final cubit = _cubit(
      _FakeChatRepository(onHistory: ({String? cursor}) async => page),
      rt,
    );
    await _settle();
    expect(_messagesOf(cubit).length, 1);

    // While disconnected the counterpart sent two messages; the newest page
    // now holds all three.
    page = ChatMessagePage(items: [
      _message('m1', 1, _them, 'Hi'),
      _message('m2', 2, _them, 'You there?'),
      _message('m3', 3, _them, 'Ping'),
    ]);
    rt.controller.add(const ChatRealtimeDisconnected());
    rt.controller.add(const ChatRealtimeConnected(isReconnect: true));
    await _settle();

    expect(_messagesOf(cubit).map((m) => m.id), ['m1', 'm2', 'm3']);
    await cubit.close();
  });

  test('the first connection does not trigger a redundant reconcile',
      () async {
    final rt = _FakeRealtime();
    var historyCalls = 0;
    final cubit = _cubit(
      _FakeChatRepository(onHistory: ({String? cursor}) async {
        historyCalls++;
        return const ChatMessagePage(items: []);
      }),
      rt,
    );
    await _settle();
    rt.controller.add(const ChatRealtimeConnected(isReconnect: false));
    await _settle();
    expect(historyCalls, 1); // only the initial load
    await cubit.close();
  });

  test('a live message:deleted tombstones the message in place', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onHistory: ({String? cursor}) async =>
              ChatMessagePage(items: [_message('m1', 1, _me, 'Regret this')])),
      rt,
    );
    await _settle();

    rt.controller.add(ChatMessageDeletedReceived(
      conversationId: _convId,
      messageId: 'm1',
      deletedBy: _me,
      deletedAt: DateTime(2026, 7, 22, 10),
    ));

    final message = _messagesOf(cubit).single;
    expect(message.deletedForEveryone, isTrue);
    expect(message.body, chatDeletedForEveryonePlaceholder);
    expect(message.seq, BigInt.one); // record preserved, only display changed
    await cubit.close();
  });

  test('a live message:deleted-for-me removes the message from this session',
      () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onHistory: ({String? cursor}) async => ChatMessagePage(items: [
                _message('m1', 1, _them, 'Keep'),
                _message('m2', 2, _them, 'Hide'),
              ])),
      rt,
    );
    await _settle();

    rt.controller.add(ChatMessageHiddenReceived(
      conversationId: _convId,
      messageId: 'm2',
      deletedAt: DateTime(2026, 7, 22, 10),
    ));

    expect(_messagesOf(cubit).map((m) => m.id), ['m1']);
    await cubit.close();
  });

  group('payload parsing (wire shapes from chat-events.ts)', () {
    test('message:new parses through the shared message model', () {
      final event = parseMessageNew({
        'id': 'm1',
        'conversationId': _convId,
        'senderId': _them,
        'type': 'TEXT',
        'body': 'hello',
        'attachment': null,
        'replyTo': null,
        'seq': '42',
        'status': 'SENT',
        'createdAt': '2026-07-22T09:00:00.000Z',
        'deletedForEveryone': false,
      });
      expect(event.message.id, 'm1');
      expect(event.message.seq, BigInt.from(42));
      expect(event.message.body, 'hello');
    });

    test('message:read parses ids and timestamp', () {
      final event = parseMessageRead({
        'conversationId': _convId,
        'readerId': _them,
        'messageIds': ['a', 'b'],
        'readAt': '2026-07-22T10:30:00.000Z',
      });
      expect(event.conversationId, _convId);
      expect(event.readerId, _them);
      expect(event.messageIds, ['a', 'b']);
      expect(event.readAt, DateTime.utc(2026, 7, 22, 10, 30));
    });

    test('message:deleted and message:deleted-for-me parse', () {
      final deleted = parseMessageDeleted({
        'conversationId': _convId,
        'messageId': 'm1',
        'deletedBy': _them,
        'deletedAt': '2026-07-22T11:00:00.000Z',
      });
      expect(deleted.messageId, 'm1');
      expect(deleted.deletedBy, _them);

      final hidden = parseMessageDeletedForMe({
        'conversationId': _convId,
        'messageId': 'm2',
        'deletedAt': '2026-07-22T11:05:00.000Z',
      });
      expect(hidden.messageId, 'm2');
    });
  });
}
