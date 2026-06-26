import 'package:flutter/material.dart';
import 'package:fbro/core/enums/broadcast_category.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/glass_container.dart';
import 'package:fbro/features/communications/domain/entities/broadcast_entity.dart';
import 'package:fbro/features/communications/presentation/communications_format.dart';

/// The per-item action menu on a broadcast feed card.
enum BroadcastCardAction { open, repeatNow, archive, unarchive, delete }

/// A single broadcast in the Communications Center history feed (Phase 2) —
/// title, category, message preview, sender, time, delivery summary
/// (recipients · delivered · failed), status, and a per-item actions menu
/// (Open · Repeat Now · Duplicate · Schedule Again · Archive · Delete).
/// Premium monochrome (built on [GlassContainer]); colour only for an urgent
/// category / priority / status.
class BroadcastCard extends StatelessWidget {
  const BroadcastCard({
    super.key,
    required this.broadcast,
    required this.onTap,
    this.onAction,
  });

  final BroadcastEntity broadcast;
  final VoidCallback onTap;

  /// Optional per-item action handler. When null, the overflow menu is hidden
  /// (e.g. a read-only context).
  final void Function(BroadcastCardAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final category = BroadcastCategory.fromString(broadcast.category);
    final catColor = categoryColor(category);
    final dimmed = !broadcast.isActive; // archived / deleted read muted

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Opacity(
        opacity: dimmed ? 0.6 : 1,
        child: GlassContainer(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: catColor.withAlpha(category.isUrgent ? 30 : 20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: catColor.withAlpha(60)),
                    ),
                    child: Icon(categoryIcon(category), size: 20, color: catColor),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          broadcast.title,
                          style: AppTypography.label
                              .copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(category.label,
                            style: AppTypography.caption
                                .copyWith(color: catColor)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _AudiencePill(broadcast: broadcast),
                  if (onAction != null) _menu(context),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                broadcast.message,
                style: AppTypography.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(broadcast.senderName,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  _dot(),
                  Text(broadcastTimeAgo(broadcast.createdAt),
                      style: AppTypography.caption),
                  const Spacer(),
                  _DeliveryChip(broadcast: broadcast),
                ],
              ),
              if (!broadcast.isActive) ...[
                const SizedBox(height: AppSpacing.sm),
                _StatusChip(broadcast: broadcast),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final archived = broadcast.isArchived;
    return PopupMenuButton<BroadcastCardAction>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert_rounded,
          size: 20, color: AppColors.textTertiary),
      color: AppColors.darkSurfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onAction,
      itemBuilder: (context) => [
        _item(BroadcastCardAction.open, Icons.open_in_full_rounded, 'Open'),
        _item(BroadcastCardAction.repeatNow, Icons.replay_rounded, 'Repeat now'),
        if (archived)
          _item(BroadcastCardAction.unarchive, Icons.unarchive_rounded,
              'Unarchive')
        else
          _item(BroadcastCardAction.archive, Icons.archive_outlined, 'Archive'),
        _item(BroadcastCardAction.delete, Icons.delete_outline_rounded, 'Delete',
            destructive: true),
      ],
    );
  }

  PopupMenuItem<BroadcastCardAction> _item(
    BroadcastCardAction value,
    IconData icon,
    String label, {
    bool destructive = false,
    bool enabled = true,
  }) {
    final color = destructive
        ? AppColors.error
        : (enabled ? AppColors.textPrimary : AppColors.textTertiary);
    return PopupMenuItem<BroadcastCardAction>(
      value: value,
      enabled: enabled,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: AppTypography.body.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text('·', style: TextStyle(color: AppColors.textTertiary)),
      );

}

class _AudiencePill extends StatelessWidget {
  const _AudiencePill({required this.broadcast});
  final BroadcastEntity broadcast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(audienceIcon(broadcast.audience),
              size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(audienceLabel(broadcast),
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Delivery summary chip — "delivered M / N" once known, with a failed count
/// when any push failed; else "N recipients".
class _DeliveryChip extends StatelessWidget {
  const _DeliveryChip({required this.broadcast});
  final BroadcastEntity broadcast;

  @override
  Widget build(BuildContext context) {
    final recipients = broadcast.recipientCount;
    if (recipients == null) return const SizedBox.shrink();
    final delivered = broadcast.deliveredCount;
    final failed = broadcast.failedCount;
    final text = delivered != null
        ? 'Delivered $delivered/$recipients'
        : '$recipients ${recipients == 1 ? 'recipient' : 'recipients'}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.send_rounded, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(text, style: AppTypography.caption),
        if (failed != null && failed > 0) ...[
          const SizedBox(width: 6),
          Icon(Icons.error_outline_rounded, size: 12, color: AppColors.error),
          const SizedBox(width: 2),
          Text('$failed failed',
              style: AppTypography.caption.copyWith(color: AppColors.error)),
        ],
      ],
    );
  }
}

/// A small status chip shown for archived / deleted broadcasts.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.broadcast});
  final BroadcastEntity broadcast;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.archive_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(broadcastStatusLabel(broadcast),
              style: AppTypography.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}
