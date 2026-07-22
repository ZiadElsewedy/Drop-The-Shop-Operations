import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/presentation/chat_format.dart';
import 'package:drop/features/chat/presentation/widgets/chat_conversation_tile.dart';

void main() {
  final active = ChatConversationSummary(
    id: 'conv-1',
    counterpartUserId: 'b7e2a1c4-0000-4000-8000-000000000000',
    participantIds: const ['me', 'b7e2a1c4-0000-4000-8000-000000000000'],
    createdAt: DateTime(2026, 7, 20, 9),
    lastMessageAt: DateTime(2026, 7, 22, 10),
  );

  final empty = ChatConversationSummary(
    id: 'conv-2',
    counterpartUserId: 'b7e2a1c4-0000-4000-8000-000000000000',
    participantIds: const ['me', 'b7e2a1c4-0000-4000-8000-000000000000'],
    createdAt: DateTime(2026, 7, 21, 9),
  );

  Widget host(ChatConversationSummary c,
          {String? title, String? preview, int? unreadCount}) =>
      MaterialApp(
        home: Scaffold(
          body: ChatConversationTile(
            conversation: c,
            title: title,
            preview: preview,
            unreadCount: unreadCount,
            onTap: () {},
          ),
        ),
      );

  testWidgets('renders the deterministic counterpart label as the title',
      (tester) async {
    await tester.pumpWidget(host(active));
    expect(find.text(chatCounterpartLabel(active.counterpartUserId)),
        findsOneWidget);
  });

  testWidgets('a provided title overrides the fallback label', (tester) async {
    await tester.pumpWidget(host(active, title: 'Sara K.'));
    expect(find.text('Sara K.'), findsOneWidget);
  });

  testWidgets('a never-messaged conversation shows the empty preview line',
      (tester) async {
    await tester.pumpWidget(host(empty));
    expect(find.text('No messages yet — say hello'), findsOneWidget);
  });

  testWidgets('a provided preview overrides the state line', (tester) async {
    await tester.pumpWidget(host(active, preview: 'See you at 5'));
    expect(find.text('See you at 5'), findsOneWidget);
  });

  testWidgets('unread badge shows the count and bolds the title',
      (tester) async {
    await tester.pumpWidget(host(active, unreadCount: 3));
    expect(find.text('3'), findsOneWidget);
    final title = tester.widget<Text>(
        find.text(chatCounterpartLabel(active.counterpartUserId)));
    expect(title.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('no badge when the count is absent or zero', (tester) async {
    await tester.pumpWidget(host(active));
    expect(find.text('0'), findsNothing);
    await tester.pumpWidget(host(active, unreadCount: 0));
    expect(find.text('0'), findsNothing);
  });

  testWidgets('caps the badge at 99+', (tester) async {
    await tester.pumpWidget(host(active, unreadCount: 120));
    expect(find.text('99+'), findsOneWidget);
  });
}
