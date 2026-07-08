import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/community/domain/entities/event_entity.dart';
import 'package:drop/features/community/presentation/event_format.dart';
import 'package:drop/features/community/presentation/widgets/event_chapter.dart';

/// A **hero image surface** shared by the cards — the event artwork when present,
/// else a quiet monochrome gradient carrying the type glyph. Never a broken image.
class EventArtwork extends StatelessWidget {
  const EventArtwork({
    super.key,
    required this.event,
    this.borderRadius,
    this.iconSize = 34,
    this.overlay = false,
  });

  final EventEntity event;
  final BorderRadius? borderRadius;
  final double iconSize;

  /// Darken the bottom for text overlaid on top (the featured card).
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.lgAll;
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkSurfaceElevated, AppColors.darkBg],
        ),
      ),
      child: Center(
        child: Icon(EventFormat.typeIcon(event.type),
            size: iconSize, color: AppColors.textTertiary),
      ),
    );

    Widget layer = event.hasHeroImage
        ? Image.network(
            event.heroImageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : fallback,
          )
        : fallback;

    if (overlay) {
      layer = Stack(
        fit: StackFit.expand,
        children: [
          layer,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // Darken top (for chips / a collapsed title) and bottom (for the
                // overlaid title block), leaving the artwork clear through the
                // middle.
                colors: [
                  Color(0x800A0A0B),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xE80A0A0B),
                ],
                stops: [0.0, 0.28, 0.52, 1.0],
              ),
            ),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox.expand(child: layer),
    );
  }
}

/// A small status pill (icon + label, status-tinted) reused by cards + the hero.
class EventStatusPill extends StatelessWidget {
  const EventStatusPill({super.key, required this.event, this.compact = false});
  final EventEntity event;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = EventFormat.statusColor(event.status);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(EventFormat.statusIcon(event.status),
              size: compact ? 10 : 12, color: color),
          const SizedBox(width: 4),
          Text(event.status.label,
              style: AppTypography.labelSmall
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// The standard hub row — artwork thumbnail, status, title, meta, prep bar.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.branchName,
  });

  final EventEntity event;
  final VoidCallback onTap;
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    final showBar =
        event.status.isActive && event.preparationProgress > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: event.isLive
                  ? AppColors.success.withAlpha(70)
                  : AppColors.darkBorder,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: EventArtwork(event: event, iconSize: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(event.type.label,
                              style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textTertiary,
                                  letterSpacing: 0.4),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        EventStatusPill(event: event, compact: true),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.title,
                      style: AppTypography.labelLarge
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _MetaRow(event: event, branchName: branchName),
                    if (showBar) ...[
                      const SizedBox(height: AppSpacing.sm + 2),
                      Row(
                        children: [
                          Expanded(
                            child: SectionBar(
                                value: event.preparationProgress, height: 5),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text('${event.preparationPercent}%',
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
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

/// The large **featured** card for the hub's top rail — cinematic artwork with
/// the title, countdown and status overlaid. This is the "poster" of an event.
class FeaturedEventCard extends StatelessWidget {
  const FeaturedEventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.branchName,
    this.width = 320,
  });

  final EventEntity event;
  final VoidCallback onTap;
  final String? branchName;
  final double width;

  @override
  Widget build(BuildContext context) {
    final countdown =
        EventFormat.countdownLabel(event.countdown, isLive: event.isLive);
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardAll,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardAll,
              border: Border.all(
                color: event.isLive
                    ? AppColors.success.withAlpha(80)
                    : AppColors.darkBorder,
              ),
            ),
            child: ClipRRect(
              borderRadius: AppRadius.cardAll,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EventArtwork(
                        event: event,
                        borderRadius: BorderRadius.zero,
                        iconSize: 46,
                        overlay: true),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              EventStatusPill(event: event),
                              const Spacer(),
                              _CountdownChip(label: countdown, live: event.isLive),
                            ],
                          ),
                          const Spacer(),
                          Text(event.type.label.toUpperCase(),
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            event.title,
                            style: AppTypography.h2
                                .copyWith(fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            EventFormat.dateLabel(event.startAt),
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownChip extends StatelessWidget {
  const _CountdownChip({required this.label, required this.live});
  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final color = live ? AppColors.success : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.black.withAlpha(90),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.success),
            )
          else ...[
            const Icon(Icons.schedule_rounded,
                size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: AppTypography.labelSmall.copyWith(
                  color: live ? AppColors.success : AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.event, this.branchName});
  final EventEntity event;
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    parts.add(_Meta(
        icon: Icons.event_outlined,
        text: EventFormat.dateLabel(event.startAt, withTime: false)));
    final loc = (event.location ?? '').trim();
    if (loc.isNotEmpty) {
      parts.add(_Meta(icon: Icons.place_outlined, text: loc));
    } else if ((branchName ?? '').trim().isNotEmpty) {
      parts.add(_Meta(icon: Icons.storefront_outlined, text: branchName!.trim()));
    }
    if (event.expectedAttendance != null) {
      parts.add(_Meta(
          icon: Icons.groups_outlined,
          text: EventFormat.compact(event.expectedAttendance!)));
    }
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts,
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(text,
            style: AppTypography.labelSmall
                .copyWith(color: AppColors.textTertiary)),
      ],
    );
  }
}
