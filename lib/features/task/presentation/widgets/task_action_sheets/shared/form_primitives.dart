part of '../../task_action_sheets.dart';

// ─── Premium form primitives ─────────────────────────────────────
// A small, cohesive kit shared across the create sheet so every section reads
// as one system: a hero header, group dividers, a sliding segmented control,
// summary picker tiles, the deadline field and an animated validation banner.

/// The sheet's hero header — title + a one-line intent, so the form opens like
/// a workflow builder rather than a bare "New Task".
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h2),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTypography.caption),
        ],
      ),
    );
  }
}

/// A group divider — a small labelled heading with a trailing hairline that
/// visually partitions the long form into scannable sections.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(child: Divider(color: AppColors.darkBorder, height: 1)),
        ],
      ),
    );
  }
}

/// A small caption above a control (e.g. above a segmented control).
class _FieldCaption extends StatelessWidget {
  const _FieldCaption(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: AppTypography.labelSmall
          .copyWith(color: AppColors.textSecondary));
}

/// The soft rounded 36px icon tile that leads a [_PickerTile] / list row.
class _LeadIcon extends StatelessWidget {
  const _LeadIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child:
          Icon(icon, size: 18, color: AppColors.textSecondary),
    );
  }
}

/// A tappable summary row — a leading glyph, a label, and the current value (or
/// a muted placeholder). The house replacement for dropdown-style selectors:
/// the *value* stays visible in the form; the *choosing* happens in a sheet.
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    this.value,
    this.placeholder,
    this.leading,
    this.onTap,
    this.onClear,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? placeholder;
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final filled = value != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.xlAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.xlAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              leading ?? _LeadIcon(icon: icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textTertiary)),
                    const SizedBox(height: 2),
                    Text(
                      filled ? value! : (placeholder ?? ''),
                      style: AppTypography.body.copyWith(
                        color: filled
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                        fontWeight: filled ? FontWeight.w500 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (onClear != null && filled)
                GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textTertiary),
                )
              else if (enabled)
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The optional-deadline control — a summary tile plus quick "Today / Tomorrow /
/// Next week" chips, so the common cases are one tap and precise dates stay one
/// tap deeper (progressive disclosure). Empty by default; nothing is imposed.
class _DeadlineField extends StatelessWidget {
  const _DeadlineField({
    required this.value,
    required this.onPick,
    required this.onQuick,
    required this.onClear,
  });

  final DateTime? value;
  final VoidCallback onPick;
  final ValueChanged<DateTime> onQuick;
  final VoidCallback onClear;

  static String _fmt(DateTime d) => AppDateFormatter.monthDayYear(d);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final quicks = <(String, DateTime)>[
      ('Today', today),
      ('Tomorrow', today.add(const Duration(days: 1))),
      ('Next week', today.add(const Duration(days: 7))),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PickerTile(
          icon: Icons.event_outlined,
          label: 'Deadline',
          value: value == null ? null : _fmt(value!),
          placeholder: 'No deadline',
          onTap: onPick,
          onClear: onClear,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (label, date) in quicks)
              _MiniChip(
                label: label,
                selected: value != null && _sameDay(value!, date),
                onTap: () => onQuick(date),
              ),
          ],
        ),
      ],
    );
  }
}

/// A compact selectable chip for quick presets (e.g. deadline shortcuts).
class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.fullAll,
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.darkBorder),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.onPrimary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// One option in a [_Segmented] control.
class _Seg<T> {
  const _Seg(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// A premium iOS-style segmented control with a sliding thumb — the house
/// replacement for a short single-choice dropdown (priority, assignment mode,
/// recurrence). Equal-width segments; the white thumb eases to the selection.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<_Seg<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = segments.length;
    final index = segments.indexWhere((s) => s.value == value);
    // Align.x for equal-width slots: -1 at slot 0 … +1 at slot n-1.
    final thumbX = n <= 1 ? 0.0 : (2 * (index < 0 ? 0 : index) / (n - 1)) - 1;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Stack(
        children: [
          if (index >= 0)
            Positioned.fill(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment(thumbX, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final seg in segments)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(seg.value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: _SegLabel(seg: seg, selected: seg.value == value),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegLabel extends StatelessWidget {
  const _SegLabel({required this.seg, required this.selected});
  final _Seg seg;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.onPrimary : AppColors.textSecondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (seg.icon != null) ...[
          Icon(seg.icon, size: 15, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(seg.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

/// Animated, monochrome-friendly validation banner shown above the CTA. Slides
/// open when a message arrives and collapses cleanly when it clears, so an error
/// reads as a deliberate moment rather than red text jumping in.
class _FormErrorBanner extends StatelessWidget {
  const _FormErrorBanner({required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: EntranceFade(
                offset: 8,
                duration: const Duration(milliseconds: 220),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorSurface,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(color: AppColors.error.withAlpha(90)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 18, color: AppColors.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(message!,
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

