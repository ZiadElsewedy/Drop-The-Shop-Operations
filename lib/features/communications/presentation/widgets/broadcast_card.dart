import 'package:flutter/material.dart';
import 'package:fbro/core/enums/broadcast_category.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/glass_container.dart';
import 'package:fbro/features/communications/domain/entities/broadcast_entity.dart';
import 'package:fbro/features/communications/presentation/communications_format.dart';

/// A single broadcast in the Communications Center feed — title, body preview,
/// sender, audience, time, and the delivery summary. Tapping opens the detail.
/// Premium monochrome (built on [GlassContainer]); colour only for an urgent
/// category badge.
class BroadcastCard extends StatelessWidget {
  const BroadcastCard({super.key, required this.broadcast, required this.onTap});

  final BroadcastEntity broadcast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = BroadcastCategory.fromString(broadcast.category);
    final catColor = categoryColor(category);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
                          style: AppTypography.caption.copyWith(color: catColor)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _AudiencePill(broadcast: broadcast),
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
          ],
        ),
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

/// Delivery summary chip — "delivered M / N" once known, else "N recipients".
class _DeliveryChip extends StatelessWidget {
  const _DeliveryChip({required this.broadcast});
  final BroadcastEntity broadcast;

  @override
  Widget build(BuildContext context) {
    final recipients = broadcast.recipientCount;
    if (recipients == null) return const SizedBox.shrink();
    final delivered = broadcast.deliveredCount;
    final text = delivered != null
        ? 'Delivered $delivered/$recipients'
        : '$recipients ${recipients == 1 ? 'recipient' : 'recipients'}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.send_rounded, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(text, style: AppTypography.caption),
      ],
    );
  }
}
