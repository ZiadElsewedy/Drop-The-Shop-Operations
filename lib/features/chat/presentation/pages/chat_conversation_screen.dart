import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/features/chat/presentation/chat_format.dart';
import 'package:drop/features/chat/presentation/cubit/chat_conversation_cubit.dart';
import 'package:drop/features/chat/presentation/widgets/chat_conversation_view.dart';

/// One open direct-chat thread (`RouteNames.chatConversationPattern`) — the
/// [CaseConversationScreen] sibling: a fresh per-thread
/// [ChatConversationCubit] (owned + disposed by the provider) under an
/// [AdaptiveScaffold], with the shared [ChatConversationView] as the body.
class ChatConversationScreen extends StatelessWidget {
  const ChatConversationScreen({
    super.key,
    required this.conversationId,
    this.counterpartUserId,
  });

  final String conversationId;

  /// Passed by the inbox row when known (route `extra`) — enables own-message
  /// alignment before the first send. A bare deep link arrives without it.
  final String? counterpartUserId;

  @override
  Widget build(BuildContext context) {
    final counterpart = counterpartUserId;
    return BlocProvider<ChatConversationCubit>(
      create: (_) => AppDependencies.createChatConversationCubit(
        conversationId,
        counterpartUserId: counterpart,
      ),
      child: AdaptiveScaffold(
        title: counterpart == null
            ? 'Conversation'
            : chatCounterpartLabel(counterpart),
        contentMaxWidth: 820,
        body: const ChatConversationView(),
      ),
    );
  }
}
