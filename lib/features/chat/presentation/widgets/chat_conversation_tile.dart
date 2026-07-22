import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/presentation/chat_format.dart';
import 'package:drop/features/task/presentation/activity_format.dart'
    show relativeTime;

/// A dense, scannable inbox row for one direct conversation — the
/// [CaseListTile] sibling (title · preview · time · unread badge · avatar).
///
/// [title], [preview] and [unreadCount] are optional overrides for when richer
/// data becomes available (identity mapping, previews, read-state on the list
/// endpoint); today they fall back to the honest placeholders in
/// `chat_format.dart`, and a null [unreadCount] hides the badge entirely.
class ChatConversationTile extends StatelessWidget {
  const ChatConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.title,
    this.preview,
    this.unreadCount,
    this.selected = false,
  });

  final ChatConversationSummary conversation;
  final VoidCallback onTap;

  /// Resolved counterpart display name. Null → deterministic fallback label.
  final String? title;

  /// Last-message body. Null → state line off `lastMessageAt`.
  final String? preview;

  /// Unread messages in this conversation. Null or 0 → no badge (the list
  /// endpoint does not expose counts yet).
  final int? unreadCount;

  /// Draws the desktop split-pane highlight (future workspace layout).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final unread = (unreadCount ?? 0) > 0;
    final when = conversation.lastMessageAt ?? conversation.createdAt;

    return Material(
      color: selected ? AppColors.primarySurface : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
              bottom: const BorderSide(color: AppColors.darkBorder, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _AvatarPlaceholder(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title ??
                                chatCounterpartLabel(
                                    conversation.counterpartUserId),
                            style: AppTypography.body.copyWith(
                                fontWeight:
                                    unread ? FontWeight.w700 : FontWeight.w600,
                                height: 1.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(relativeTime(when),
                            style: AppTypography.caption.copyWith(
                                color: unread
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary,
                                fontWeight: unread
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview ?? chatPreviewLine(conversation),
                            style: AppTypography.bodySmall.copyWith(
                                color: unread
                                    ? AppColors.textSecondary
                                    : AppColors.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: AppSpacing.sm),
                          _UnreadBadge(count: unreadCount!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Monochrome person glyph on the standard surface — stands in until real
/// counterpart avatars are resolvable.
class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.primarySurface,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person_outline_rounded,
          size: 20, color: AppColors.textSecondary),
    );
  }
}

/// Monochrome count pill — white on the dark surface (no chromatic accent),
/// the unread-dot idea from Cases scaled up to carry a number.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTypography.caption.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
