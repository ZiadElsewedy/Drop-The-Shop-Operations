import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/chat/presentation/chat_format.dart';
import 'package:drop/features/chat/presentation/chat_thread_args.dart';
import 'package:drop/features/chat/presentation/cubit/chat_conversation_cubit.dart';
import 'package:drop/features/chat/presentation/widgets/chat_conversation_view.dart';

/// One open direct-chat thread (`RouteNames.chatConversationPattern`) — the
/// [CaseConversationScreen] sibling: a fresh per-thread
/// [ChatConversationCubit] (owned + disposed by the provider) under an
/// [AdaptiveScaffold] whose header shows the counterpart's avatar + name.
class ChatConversationScreen extends StatelessWidget {
  const ChatConversationScreen({
    super.key,
    required this.conversationId,
    this.args,
  });

  final String conversationId;

  /// Resolved counterpart (name/avatar) + backend id, passed by the opener
  /// (inbox / picker). A bare deep link arrives without it → generic header.
  final ChatThreadArgs? args;

  @override
  Widget build(BuildContext context) {
    final counterpartId = args?.counterpartUserId;
    final name = (args?.counterpartName?.trim().isNotEmpty ?? false)
        ? args!.counterpartName!.trim()
        : (counterpartId == null
            ? 'Conversation'
            : chatCounterpartLabel(counterpartId));
    return BlocProvider<ChatConversationCubit>(
      create: (_) => AppDependencies.createChatConversationCubit(
        conversationId,
        counterpartUserId: counterpartId,
      ),
      child: AdaptiveScaffold(
        title: name,
        titleWidget: _Header(name: name, photoUrl: args?.counterpartPhotoUrl),
        contentMaxWidth: 820,
        body: ChatConversationView(
          counterpartName: args?.counterpartName,
          attachmentSource: AppDependencies.chatAttachmentSource,
        ),
      ),
    );
  }
}

/// Avatar + name lockup for the thread app bar.
class _Header extends StatelessWidget {
  const _Header({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(imageUrl: photoUrl, name: name, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(name,
              style: AppTypography.h3,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
