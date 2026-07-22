import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';

/// The long-press context menu for one chat message — a bottom sheet in the
/// house style (`chip_action_sheet` chrome), followed by a Cases-style
/// confirmation dialog. Selection only: the caller owns the actual delete.
///
/// Which actions appear:
/// * **Delete for me** — always (the backend allows hiding sent *and*
///   received messages, tombstones included).
/// * **Delete for everyone** — only on the caller's **own**, not-yet-deleted
///   messages. That's an identity fact the UI already renders (bubble
///   alignment), not a permission check: the real rules — original sender
///   only, within the server's time window — stay entirely server-side, and
///   a refusal surfaces the server's own 403 message.
Future<ChatMessageAction?> showChatMessageActions(
  BuildContext context, {
  required ChatMessage message,
  required bool mine,
}) async {
  final canDeleteForEveryone = mine && !message.deletedForEveryone;
  final action = await showModalBottomSheet<ChatMessageAction>(
    context: context,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.darkBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ActionRow(
            icon: Icons.visibility_off_outlined,
            label: 'Delete for me',
            detail: 'Removes it from your view only.',
            onTap: () =>
                Navigator.of(sheetContext).pop(ChatMessageAction.deleteForMe),
          ),
          if (canDeleteForEveryone)
            _ActionRow(
              icon: Icons.delete_forever_outlined,
              label: 'Delete for everyone',
              detail: 'Replaced by a placeholder for both of you.',
              destructive: true,
              onTap: () => Navigator.of(sheetContext)
                  .pop(ChatMessageAction.deleteForEveryone),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return null;

  final confirmed = await _confirm(context, action);
  return confirmed ? action : null;
}

enum ChatMessageAction { deleteForMe, deleteForEveryone }

Future<bool> _confirm(BuildContext context, ChatMessageAction action) async {
  final forEveryone = action == ChatMessageAction.deleteForEveryone;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.darkSurfaceElevated,
      title: Text(forEveryone ? 'Delete for everyone?' : 'Delete for me?'),
      content: Text(forEveryone
          ? 'Both of you will see "This message was deleted" instead. '
              'This cannot be undone.'
          : 'The message disappears from your view only — the other person '
              'still sees it.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.body.copyWith(
                          color: color, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(detail,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
