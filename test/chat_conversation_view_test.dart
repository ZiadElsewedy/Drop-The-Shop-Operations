import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/chat_message_type.dart';
import 'package:drop/core/errors/failures.dart';
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
import 'package:drop/features/chat/presentation/widgets/chat_conversation_view.dart';

const _me = 'me-uuid';
const _them = 'them-uuid';
const _convId = 'conv-1';

ChatConversation _conversation() => ChatConversation(
      id: _convId,
      participantIds: const [_me, _them],
      createdAt: DateTime(2026, 7, 20),
      lastMessageAt: DateTime(2026, 7, 22, 10),
    );

ChatMessage _message(String id, int seq, String sender, String body,
        {DateTime? at}) =>
    ChatMessage(
      id: id,
      conversationId: _convId,
      senderId: sender,
      type: ChatMessageType.text,
      body: body,
      seq: BigInt.from(seq),
      status: 'SENT',
      createdAt: at ?? DateTime(2026, 7, 22, 9, seq),
    );

/// Thread-scoped fake — only the four calls the conversation cubit makes.
class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({
    required this.onHistory,
    this.onSend,
  });

  final Future<ChatMessagePage> Function({String? cursor}) onHistory;
  final Future<ChatMessage> Function(String content)? onSend;
  final List<BigInt> markedUpTo = [];

  @override
  Future<ChatConversation> getConversation(String conversationId) async =>
      _conversation();

  @override
  Future<ChatMessagePage> getMessageHistory({
    required String conversationId,
    int? limit,
    String? cursor,
  }) =>
      onHistory(cursor: cursor);

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
  }) {
    final handler = onSend;
    if (handler == null) throw UnimplementedError();
    return handler(content ?? '');
  }

  @override
  Future<ChatReadReceipt> markMessagesRead({
    required String conversationId,
    required BigInt upToSeq,
  }) async {
    markedUpTo.add(upToSeq);
    return ChatReadReceipt(
      conversationId: conversationId,
      markedCount: 1,
      readAt: DateTime(2026, 7, 22, 12),
    );
  }

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

ChatConversationCubit _cubit(_FakeChatRepository repo) => ChatConversationCubit(
      getConversation: GetConversation(repo),
      loadHistory: LoadChatHistory(repo),
      sendMessage: SendChatMessage(repo),
      markRead: MarkChatRead(repo),
      deleteForMe: DeleteChatMessageForMe(repo),
      deleteForEveryone: DeleteChatMessageForEveryone(repo),
      conversationId: _convId,
      counterpartUserId: _them,
    );

Widget _host(ChatConversationCubit cubit) => MaterialApp(
      home: Scaffold(
        body: BlocProvider.value(
            value: cubit, child: const ChatConversationView()),
      ),
    );

void main() {
  testWidgets('renders the thread with a date separator and both sides',
      (tester) async {
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async => ChatMessagePage(items: [
        _message('m1', 1, _them, 'Hey — shift swap tomorrow?',
            at: DateTime(2026, 7, 21, 18)),
        _message('m2', 2, _me, 'Works for me.',
            at: DateTime(2026, 7, 22, 9)),
      ]),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    expect(find.text('Hey — shift swap tomorrow?'), findsOneWidget);
    expect(find.text('Works for me.'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('marks the visible thread read up to the newest seq',
      (tester) async {
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async => ChatMessagePage(items: [
        _message('m1', 1, _them, 'One'),
        _message('m2', 7, _them, 'Two'),
      ]),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();
    await tester.pump(); // post-frame visible signal

    expect(repo.markedUpTo, [BigInt.from(7)]);
    await cubit.close();
  });

  testWidgets('an empty thread shows the empty line with the composer ready',
      (tester) async {
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async =>
          const ChatMessagePage(items: []),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    expect(find.text('No messages yet — say hello.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await cubit.close();
  });

  testWidgets('a first-load failure renders the full-screen retry and recovers',
      (tester) async {
    var calls = 0;
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async {
        calls++;
        if (calls == 1) throw const ServerFailure('Chat is unreachable.');
        return ChatMessagePage(items: [_message('m1', 1, _them, 'Back!')]);
      },
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();
    expect(find.text('Chat is unreachable.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Back!'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('sending appends the server message and clears the field',
      (tester) async {
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async =>
          ChatMessagePage(items: [_message('m1', 1, _them, 'Hi')]),
      onSend: (content) async => _message('m2', 2, _me, content),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'On my way');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('On my way'), findsOneWidget); // now a bubble
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    await cubit.close();
  });

  testWidgets('a failed send keeps the typed text in the composer',
      (tester) async {
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async =>
          ChatMessagePage(items: [_message('m1', 1, _them, 'Hi')]),
      onSend: (content) async =>
          throw const ServerFailure('Send failed.'),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Important reply');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Important reply');
    expect(find.text('Send failed.'), findsOneWidget); // snackbar
    await cubit.close();
  });

  testWidgets('scrolling to the top loads and prepends the older page',
      (tester) async {
    var historyCalls = 0;
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async {
        historyCalls++;
        if (cursor == null) {
          return ChatMessagePage(
            items: [
              for (var i = 30; i < 60; i++)
                _message('m$i', i, i.isEven ? _them : _me, 'Message $i',
                    at: DateTime(2026, 7, 22, 8, i)),
            ],
            nextCursor: 'older',
          );
        }
        return ChatMessagePage(items: [
          for (var i = 0; i < 30; i++)
            _message('m$i', i, _them, 'Older $i',
                at: DateTime(2026, 7, 20, 8, i)),
        ]);
      },
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();
    expect(historyCalls, 1);

    // Drag down repeatedly to reach the top of the thread.
    for (var i = 0; i < 12 && historyCalls < 2; i++) {
      await tester.drag(
          find.byType(ListView), const Offset(0, 600), warnIfMissed: false);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(historyCalls, 2);
    // The older page is prepended into the thread (the top rows themselves
    // stay lazily unbuilt above the preserved scroll position).
    final messages = cubit.state.maybeMap(
        loaded: (s) => s.messages, orElse: () => throw StateError('not loaded'));
    expect(messages.length, 60);
    expect(messages.first.body, 'Older 0');
    await cubit.close();
  });
}
