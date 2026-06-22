import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/enums/broadcast_category.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_empty_state.dart';
import 'package:fbro/core/widgets/glass_container.dart';
import 'package:fbro/features/communications/domain/entities/broadcast_entity.dart';
import 'package:fbro/features/communications/presentation/communications_format.dart';
import 'package:fbro/features/communications/presentation/cubit/broadcast_cubit.dart';
import 'package:fbro/features/communications/presentation/cubit/broadcast_state.dart';

/// Broadcast detail (Phase 3) — opened at `/communications/:broadcastId`. Shows
/// the full message, sender, category, audience, time, and the delivery summary
/// (recipient + delivered counts). Resolves the broadcast from the `extra`
/// passed by the feed, falling back to the live feed list by id.
class BroadcastDetailScreen extends StatelessWidget {
  const BroadcastDetailScreen({
    super.key,
    required this.broadcastId,
    this.broadcast,
  });

  final String broadcastId;
  final BroadcastEntity? broadcast;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text('Broadcast', style: AppTypography.h3),
      ),
      body: BlocBuilder<BroadcastCubit, BroadcastState>(
        builder: (context, state) {
          // Prefer the live feed copy (freshest delivery counts); fall back to
          // the entity passed in via `extra`.
          final fromFeed = state.maybeWhen(
            loaded: (list, _) => _byId(list, broadcastId),
            orElse: () => null,
          );
          final b = fromFeed ?? broadcast;
          if (b == null) return _missing();
          return _detail(context, b);
        },
      ),
    );
  }

  BroadcastEntity? _byId(List<BroadcastEntity> list, String id) {
    for (final b in list) {
      if (b.id == id) return b;
    }
    return null;
  }

  Widget _missing() => const AppEmptyState(
        icon: Icons.campaign_outlined,
        title: 'Broadcast unavailable',
        message: 'Open this broadcast from the Communications feed.',
      );

  Widget _detail(BuildContext context, BroadcastEntity b) {
    final category = BroadcastCategory.fromString(b.category);
    final catColor = categoryColor(category);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.lg,
          AppSpacing.pagePadding, AppSpacing.xxxl),
      children: [
        // Header
        GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: catColor.withAlpha(category.isUrgent ? 30 : 20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: catColor.withAlpha(60)),
                    ),
                    child:
                        Icon(categoryIcon(category), color: catColor, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.label,
                            style: AppTypography.caption
                                .copyWith(color: catColor)),
                        const SizedBox(height: 2),
                        Text(b.title, style: AppTypography.h2),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(audienceIcon(b.audience),
                      size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 6),
                  Text(audienceLabel(b), style: AppTypography.caption),
                  const Spacer(),
                  Text(broadcastTimeAgo(b.createdAt),
                      style: AppTypography.caption),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Message
        const _SectionLabel('Message'),
        GlassContainer(
          child: Text(b.message,
              style: AppTypography.bodyLarge
                  .copyWith(color: AppColors.textPrimary)),
        ),
        const SizedBox(height: AppSpacing.md),

        // Delivery summary
        const _SectionLabel('Delivery'),
        GlassContainer(
          child: Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.group_outlined,
                  label: 'Recipients',
                  value: b.recipientCount?.toString() ?? '—',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.darkBorder,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              Expanded(
                child: _Stat(
                  icon: Icons.mark_email_read_outlined,
                  label: 'Delivered',
                  value: b.deliveredCount?.toString() ??
                      (b.recipientCount == null ? '—' : 'Pending'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Details
        const _SectionLabel('Details'),
        GlassContainer(
          child: Column(
            children: [
              _MetaRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Sender',
                  value: b.senderName),
              _MetaRow(
                  icon: audienceIcon(b.audience),
                  label: 'Audience',
                  value: audienceLabel(b)),
              _MetaRow(
                  icon: categoryIcon(category),
                  label: 'Category',
                  value: category.label),
              _MetaRow(
                  icon: Icons.schedule_rounded,
                  label: 'Sent',
                  value: broadcastFullDate(b.createdAt),
                  last: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
        child: Text(text.toUpperCase(),
            style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary, letterSpacing: 0.6)),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.caption),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTypography.h2),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: AppTypography.body),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: AppTypography.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
