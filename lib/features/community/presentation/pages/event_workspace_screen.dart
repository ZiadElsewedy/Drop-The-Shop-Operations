import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/enums/event_phase.dart';
import 'package:drop/core/enums/event_status.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_dialog.dart';
import 'package:drop/core/widgets/drop_loading_state.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/community/domain/entities/event_entity.dart';
import 'package:drop/features/community/domain/entities/event_sections.dart';
import 'package:drop/features/community/domain/event_readiness.dart';
import 'package:drop/features/community/presentation/cubit/event_workspace_cubit.dart';
import 'package:drop/features/community/presentation/cubit/event_workspace_state.dart';
import 'package:drop/features/community/presentation/event_format.dart';
import 'package:drop/features/community/presentation/widgets/event_card.dart';
import 'package:drop/features/community/presentation/widgets/event_chapter.dart';
import 'package:drop/features/community/presentation/widgets/event_edit_sheets.dart';
import 'package:drop/features/community/presentation/widgets/readiness_panel.dart';

/// The **Event Workspace** — the flagship. Not a form with tabs: a cinematic,
/// collapsing hero, then the operational content revealed as chapters as you
/// scroll (Overview → Readiness → Timeline → Team → Tasks → Inventory →
/// Logistics → Budget → Communication → After). The workspace visibly evolves
/// with the event: preparation grows the hero bar, a **live** event becomes a
/// command center at the top, and a completed one settles into its archive.
class EventWorkspaceScreen extends StatelessWidget {
  const EventWorkspaceScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EventWorkspaceCubit>(
      create: (ctx) =>
          AppDependencies.createEventWorkspaceCubit(eventId, ctx.currentUser),
      child: const _WorkspaceView(),
    );
  }
}

class _WorkspaceView extends StatelessWidget {
  const _WorkspaceView();

  @override
  Widget build(BuildContext context) {
    final canEdit = context.isAdmin || context.isManager;
    return BlocConsumer<EventWorkspaceCubit, EventWorkspaceState>(
      listenWhen: (p, c) => c.error != null && c.error != p.error,
      listener: (context, state) {
        if (state.error != null) context.showError(state.error!);
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.darkBg,
            body: DropLoadingState(message: 'Opening event…'),
          );
        }
        if (state.isNotFound || state.event == null) {
          return _NotFound();
        }
        return _Loaded(event: state.event!, state: state, canEdit: canEdit);
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded(
      {required this.event, required this.state, required this.canEdit});
  final EventEntity event;
  final EventWorkspaceState state;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EventWorkspaceCubit>();
    final liveMode = event.isLive || state.liveMode;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        slivers: [
          _HeroSliver(event: event, canEdit: canEdit),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.huge),
                  child: _Chapters(
                    event: event,
                    readiness: state.readiness,
                    canEdit: canEdit,
                    liveMode: liveMode,
                    cubit: cubit,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────
class _HeroSliver extends StatelessWidget {
  const _HeroSliver({required this.event, required this.canEdit});
  final EventEntity event;
  final bool canEdit;

  static const double _expanded = 384;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final minExtent = kToolbarHeight + topPad;

    return SliverAppBar(
      pinned: true,
      expandedHeight: _expanded,
      backgroundColor: AppColors.darkBg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      actions: [
        if (event.isLive)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Center(child: _LivePulse()),
          ),
        if (canEdit) _WorkspaceMenu(event: event),
        const SizedBox(width: 4),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final current = constraints.maxHeight;
          final t = ((current - minExtent) / (_expanded - minExtent))
              .clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              EventArtwork(
                  event: event,
                  borderRadius: BorderRadius.zero,
                  iconSize: 64,
                  overlay: true),
              // Expanded hero content — fades out as the bar collapses.
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: IgnorePointer(
                  ignoring: t < 0.4,
                  child: Opacity(
                    opacity: (t * 1.4).clamp(0.0, 1.0),
                    child: _ExpandedHero(event: event),
                  ),
                ),
              ),
              // Collapsed title — fades in as the bar collapses.
              Positioned(
                top: topPad,
                left: 56,
                right: 96,
                height: kToolbarHeight,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.h3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExpandedHero extends StatelessWidget {
  const _ExpandedHero({required this.event});
  final EventEntity event;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            EventStatusPill(event: event),
            const Spacer(),
            _HeroCountdown(event: event),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(event.type.label.toUpperCase(),
            style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          event.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.h1.copyWith(
              fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _HeroMeta(
                icon: Icons.event_outlined,
                text: EventFormat.dateLabel(event.startAt)),
            if ((event.location ?? '').trim().isNotEmpty)
              _HeroMeta(
                  icon: Icons.place_outlined, text: event.location!.trim()),
            if (event.expectedAttendance != null)
              _HeroMeta(
                  icon: Icons.groups_outlined,
                  text:
                      '${EventFormat.compact(event.expectedAttendance!)} expected'),
          ],
        ),
        if (event.status.isActive && event.preparationProgress > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SectionBar(value: event.preparationProgress, height: 6),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('${event.preparationPercent}% ready',
                  style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ],
    );
  }
}

class _HeroCountdown extends StatelessWidget {
  const _HeroCountdown({required this.event});
  final EventEntity event;

  @override
  Widget build(BuildContext context) {
    final live = event.isLive;
    final label = EventFormat.countdownLabel(event.countdown, isLive: live);
    final color = live ? AppColors.success : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.black.withAlpha(110),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(live ? Icons.sensors_rounded : Icons.schedule_rounded,
              size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.label.copyWith(
                  color: live ? AppColors.success : AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(text,
            style: AppTypography.labelSmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _LivePulse extends StatefulWidget {
  const _LivePulse();
  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(28),
          borderRadius: AppRadius.fullAll,
          border: Border.all(color: AppColors.success.withAlpha(120)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.success),
            ),
            const SizedBox(width: 6),
            Text('LIVE',
                style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4)),
          ],
        ),
      ),
    );
  }
}

// ─── Workspace overflow menu ────────────────────────────────────────────
class _WorkspaceMenu extends StatelessWidget {
  const _WorkspaceMenu({required this.event});
  final EventEntity event;

  Future<void> _pickCover(BuildContext context) async {
    final cubit = context.read<EventWorkspaceCubit>();
    try {
      // imageQuality re-encodes the pick → strips EXIF/GPS metadata and shrinks
      // the upload (the hero cover has no other compression step).
      final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 2000, imageQuality: 80);
      if (picked == null) return;
      await cubit.setHeroImage(File(picked.path));
    } catch (_) {
      if (context.mounted) context.showError('Could not pick an image.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EventWorkspaceCubit>();
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded),
      color: AppColors.darkSurfaceElevated,
      onSelected: (v) async {
        switch (v) {
          case 'edit':
            EventEditSheets.editDetails(context, cubit, event);
            break;
          case 'cover':
            await _pickCover(context);
            break;
          case 'live':
            cubit.toggleLiveMode();
            break;
          case 'cancel':
            final okCancel = await showConfirmDialog(
              context,
              title: 'Cancel event?',
              message:
                  'This marks the event cancelled. You can still see its record.',
              confirmLabel: 'Cancel event',
              destructive: true,
            );
            if (okCancel == true) cubit.cancelEvent();
            break;
          case 'delete':
            final okDelete = await showConfirmDialog(
              context,
              title: 'Delete event?',
              message:
                  'The event is removed from the hub. This keeps a record.',
              confirmLabel: 'Delete',
              destructive: true,
            );
            if (okDelete == true) {
              await cubit.deleteEvent();
              if (context.mounted) Navigator.of(context).maybePop();
            }
            break;
        }
      },
      itemBuilder: (context) => [
        _item('edit', Icons.edit_outlined, 'Edit details'),
        _item('cover', Icons.image_outlined, 'Change cover'),
        if (event.status.isActive && !event.isLive)
          _item('live', Icons.sensors_rounded,
              context.read<EventWorkspaceCubit>().state.liveMode
                  ? 'Exit live view'
                  : 'Live view'),
        if (event.status.canCancel)
          _item('cancel', Icons.cancel_outlined, 'Cancel event'),
        _item('delete', Icons.delete_outline_rounded, 'Delete'),
      ],
    );
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label) =>
      PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Text(label, style: AppTypography.label),
          ],
        ),
      );
}

// ─── Chapters ───────────────────────────────────────────────────────────
class _Chapters extends StatelessWidget {
  const _Chapters({
    required this.event,
    required this.readiness,
    required this.canEdit,
    required this.liveMode,
    required this.cubit,
  });

  final EventEntity event;
  final EventReadiness? readiness;
  final bool canEdit;
  final bool liveMode;
  final EventWorkspaceCubit cubit;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    void chapter(Widget w) {
      if (children.isNotEmpty) {
        children.add(const _ChapterGap());
      }
      children.add(w);
    }

    // Live command center rises to the top while the event is live.
    if (liveMode && event.status.isActive) {
      chapter(_LiveCenter(event: event, canEdit: canEdit, cubit: cubit));
    }

    chapter(_OverviewChapter(event: event, canEdit: canEdit, cubit: cubit));

    final r = readiness;
    if (event.status.isPreparing && r != null) {
      chapter(EventChapter(
        eyebrow: 'Intelligence',
        title: 'Readiness',
        icon: Icons.insights_rounded,
        child: ReadinessPanel(readiness: r),
      ));
    }

    chapter(_TimelineChapter(event: event, canEdit: canEdit, cubit: cubit));
    chapter(_TasksChapter(event: event, canEdit: canEdit, cubit: cubit));
    chapter(_TeamChapter(event: event, canEdit: canEdit, cubit: cubit));
    chapter(_InventoryChapter(event: event, canEdit: canEdit, cubit: cubit));
    chapter(_LogisticsChapter(event: event, canEdit: canEdit, cubit: cubit));
    chapter(_BudgetChapter(event: event, canEdit: canEdit, cubit: cubit));
    chapter(
        _CommunicationChapter(event: event, canEdit: canEdit, cubit: cubit));

    if (event.isTerminal || (event.outcome != null && !event.outcome!.isEmpty)) {
      chapter(_AfterChapter(event: event, canEdit: canEdit, cubit: cubit));
    }

    // The lifecycle control closes the workspace.
    if (canEdit && !event.isTerminal) {
      chapter(_StatusControl(event: event, cubit: cubit));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _ChapterGap extends StatelessWidget {
  const _ChapterGap();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Divider(height: 1, color: AppColors.darkBorder),
      );
}

// ─── Overview ───────────────────────────────────────────────────────────
class _OverviewChapter extends StatelessWidget {
  const _OverviewChapter(
      {required this.event, required this.canEdit, required this.cubit});
  final EventEntity event;
  final bool canEdit;
  final EventWorkspaceCubit cubit;

  @override
  Widget build(BuildContext context) {
    final desc = event.description.trim();
    return EventChapter(
      eyebrow: 'Overview',
      title: 'The event',
      icon: Icons.auto_awesome_outlined,
      action: canEdit
          ? ChapterAddButton(
              onTap: () => EventEditSheets.editDetails(context, cubit, event),
              tooltip: 'Edit details')
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.isNotEmpty) ...[
            Text(desc,
                style: AppTypography.bodyLarge
                    .copyWith(color: AppColors.textSecondary, height: 1.6)),
            const SizedBox(height: AppSpacing.lg),
          ],
          _FactsGrid(event: event),
          if (event.hasOwner) ...[
            const SizedBox(height: AppSpacing.lg),
            _OwnerRow(event: event),
          ],
        ],
      ),
    );
  }
}

class _FactsGrid extends StatelessWidget {
  const _FactsGrid({required this.event});
  final EventEntity event;

  @override
  Widget build(BuildContext context) {
    final facts = <_Fact>[
      _Fact(Icons.event_outlined, 'When',
          EventFormat.dateLabel(event.startAt)),
      _Fact(Icons.place_outlined, 'Where',
          (event.location ?? '').trim().isEmpty ? '—' : event.location!.trim()),
      if (event.expectedAttendance != null)
        _Fact(Icons.groups_outlined, 'Expected',
            '${EventFormat.compact(event.expectedAttendance!)} people'),
      _Fact(Icons.checklist_rounded, 'Preparation',
          '${event.preparationPercent}% ready'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 520 ? 2 : 1;
      final rowW = (c.maxWidth - (cols - 1) * AppSpacing.md) / cols;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final f in facts) SizedBox(width: rowW, child: _FactTile(fact: f)),
        ],
      );
    });
  }
}

class _Fact {
  final IconData icon;
  final String label;
  final String value;
  const _Fact(this.icon, this.label, this.value);
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.fact});
  final _Fact fact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Icon(fact.icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fact.label.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(fact.value,
                    style: AppTypography.label
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerRow extends StatelessWidget {
  const _OwnerRow({required this.event});
  final EventEntity event;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.darkSurfaceElevated,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: const Icon(Icons.shield_moon_outlined,
              size: 19, color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EVENT OWNER',
                style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(event.ownerName ?? 'Assigned',
                style:
                    AppTypography.label.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

// ─── Live command center ────────────────────────────────────────────────
class _LiveCenter extends StatelessWidget {
  const _LiveCenter(
      {required this.event, required this.canEdit, required this.cubit});
  final EventEntity event;
  final bool canEdit;
  final EventWorkspaceCubit cubit;

  @override
  Widget build(BuildContext context) {
    final open = event.tasks.where((t) => !t.done).toList();
    final done = event.doneTasks;
    return GlassContainer(
      glow: AppColors.success,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LivePulse(),
              const Spacer(),
              Text('$done of ${event.tasks.length} done',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Command center', style: AppTypography.h2),
          const SizedBox(height: 4),
          Text('Everything you need while the doors are open.',
              style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.md),
          if (open.isEmpty)
            const SectionEmpty(
                message: 'All tasks are done. Enjoy the moment.',
                icon: Icons.celebration_outlined)
          else
            ...open.take(6).map((t) => CheckRow(
                  done: t.done,
                  title: t.title,
                  subtitle: (t.ownerName ?? '').trim().isEmpty
                      ? null
                      : t.ownerName,
                  leadingTint: AppColors.success,
                  enabled: canEdit,
                  onToggle: () => cubit.toggleTask(t.id),
                )),
          if (canEdit) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _LiveAction(
                    icon: Icons.campaign_outlined,
                    label: 'Post update',
                    onTap: () => EventEditSheets.announce(context, cubit),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _LiveAction(
                    icon: Icons.add_task_rounded,
                    label: 'Add task',
                    onTap: () => EventEditSheets.addTask(context, cubit),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveAction extends StatelessWidget {
  const _LiveAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: AppColors.textPrimary),
            const SizedBox(width: AppSpacing.sm),
            Text(label,
                style: AppTypography.label
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Timeline ───────────────────────────────────────────────────────────
class _TimelineChapter extends StatelessWidget {
  const _TimelineChapter(
      {required this.event, required this.canEdit, required this.cubit});
  final EventEntity event;
  final bool canEdit;
  final EventWorkspaceCubit cubit;

  @override
  Widget build(BuildContext context) {
    final byPhase = <EventPhase, List<EventMilestone>>{};
    for (final m in event.milestones) {
      byPhase.putIfAbsent(m.phase, () => []).add(m);
    }
    final done = event.doneMilestones;
    return EventChapter(
      eyebrow: 'Timeline',
      title: 'Milestones',
      icon: Icons.timeline_rounded,
      subtitle: event.milestones.isEmpty
          ? null
          : '$done of ${event.milestones.length} complete',
      action: canEdit
          ? ChapterAddButton(
              onTap: () => EventEditSheets.addMilestone(context, cubit))
          : null,
      child: event.milestones.isEmpty
          ? const SectionEmpty(
              message: 'Map the journey — Planning to Post-event review.',
              icon: Icons.route_outlined)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final phase in EventPhase.values)
                  if (byPhase[phase] != null) ...[
                    _PhaseLabel(
                        phase: phase,
                        done: byPhase[phase]!.where((m) => m.done).length,
                        total: byPhase[phase]!.length),
                    for (final m in byPhase[phase]!)
                      CheckRow(
                        done: m.done,
                        title: m.title,
                        subtitle: m.dueAt == null
                            ? null
                            : 'Due ${EventFormat.shortDate(m.dueAt)}',
                        leadingTint: m.isOverdue
                            ? AppColors.warning
                            : AppColors.primary,
                        enabled: canEdit,
                        onToggle: () => cubit.toggleMilestone(m.id),
                        onLongPress: canEdit
                            ? () => cubit.removeMilestone(m.id)
                            : null,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ),
    );
  }
}

class _PhaseLabel extends StatelessWidget {
  const _PhaseLabel(
      {required this.phase, required this.done, required this.total});
  final EventPhase phase;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 2),
      child: Row(
        children: [
          Text(phase.label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: AppSpacing.sm),
          Text('$done/$total',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

// ─── Tasks ──────────────────────────────────────────────────────────────
class _TasksChapter extends StatelessWidget {
  const _TasksChapter(
      {required this.event, required this.canEdit, required this.cubit});
  final EventEntity event;
  final bool canEdit;
  final EventWorkspaceCubit cubit;

  @override
  Widget build(BuildContext context) {
    final tasks = [...event.tasks]
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        return b.priority.index.compareTo(a.priority.index);
      });
    return EventChapter(
      eyebrow: 'Operations',
      title: 'Task list',
      icon: Icons.checklist_rounded,
      subtitle: event.tasks.isEmpty
          ? null
          : '${event.doneTasks} of ${event.tasks.length} done'
              '${event.unownedTasks > 0 ? ' · ${event.unownedTasks} unassigned' : ''}',
      action: canEdit
          ? ChapterAddButton(
              onTap: () => EventEditSheets.addTask(context, cubit))
          : null,
      child: event.tasks.isEmpty
          ? const SectionEmpty(
              message: 'Break the event into tasks so preparation can be tracked.',
              icon: Icons.add_task_outlined)
          : Column(
              children: [
                if (event.tasks.isNotEmpty) ...[
                  SectionBar(
                      value: event.doneTasks /
                          (event.tasks.isEmpty ? 1 : event.tasks.length),
                      height: 6),
                  const SizedBox(height: AppSpacing.sm),
                ],
                for (final t in tasks)
                  CheckRow(
                    done: t.done,
                    title: t.title,
                    subtitle: _taskSubtitle(t),
                    leadingTint: t.isOverdue
                        ? AppColors.warning
                        : AppColors.success,
                    trailing: t.priority.isHigh && !t.done
                        ? const _HighPriorityTag()
                        : null,
                    enabled: canEdit,
                    onToggle: () => cubit.toggleTask(t.id),
                    onLongPress:
                        canEdit ? () => cubit.removeTask(t.id) : null,
                  ),
              ],
            ),
    );
  }

  String? _taskSubtitle(EventTask t) {
    final parts = <String>[];
    if ((t.ownerName ?? '').trim().isNotEmpty) {
      parts.add(t.ownerName!.trim());
    } else {
      parts.add('Unassigned');
    }
    if (t.dueAt != null) parts.add('Due ${EventFormat.shortDate(t.dueAt)}');
    return parts.join(' · ');
  }
}

class _HighPriorityTag extends StatelessWidget {
  const _HighPriorityTag();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(28),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: AppColors.warning.withAlpha(80)),
      ),
      child: Text('High',
          style: AppTypography.caption.copyWith(
              color: AppColors.warning, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Team ───────────────────────────────────────────────────────────────
class _TeamChapter extends StatelessWidget {
  const _TeamChapter(
      {required this.event, required this.canEdit, required this.cubit});
  final EventEntity event;
  final bool canEdit;
  final EventWorkspaceCubit cubit;

  @override
  Widget build(BuildContext context) {
    return EventChapter(
      eyebrow: 'People',
      title: 'Team',
      icon: Icons.diversity_3_outlined,
      subtitle: event.team.isEmpty
          ? null
          : '${event.confirmedTeam} of ${event.team.length} confirmed',
      action: canEdit
          ? ChapterAddButton(
              onTap: () => EventEditSheets.addTeam(context, cubit))
          : null,
      child: event.team.isEmpty
          ? const SectionEmpty(
              message: 'Add the people who will make this happen.',
              icon: Icons.person_add_alt_outlined)
          : Column(
              children: [
                for (final a in event.team)
                  _TeamRow(
                    assignment: a,
                    canEdit: canEdit,
                    onToggle: () => cubit.toggleTeamConfirmed(a.id),
                    onRemove: () => cubit.removeTeamMember(a.id),
                  ),
              ],
            ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.assignment,
    required this.canEdit,
    required this.onToggle,
    required this.onRemove,
  });
  final EventAssignment assignment;
  final bool canEdit;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final subtitle = [
      if (a.role.trim().isNotEmpty) a.role.trim(),
      if ((a.department ?? '').trim().isNotEmpty) a.department!.trim(),
    ].join(' · ');
    return InkWell(
      onTap: canEdit ? onToggle : null,
      onLongPress: canEdit ? onRemove : null,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.darkSurfaceElevated,
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Text(_initials(a.name),
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.textSecondary)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name,
                      style: AppTypography.label
                          .copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTypography.labelSmall
                            .copyWith(color: AppColors.textTertiary)),
                  ],
                ],
              ),
            ),
            _ConfirmTag(confirmed: a.confirmed),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class _ConfirmTag extends StatelessWidget {
  const _ConfirmTag({required this.confirmed});
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final color = confirmed ? AppColors.success : AppColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              confirmed
                  ? Icons.check_rounded
                  : Icons.hourglass_empty_rounded,
              size: 11,
              color: color),
          const SizedBox(width: 4),
          Text(confirmed ? 'Confirmed' : 'Pending',
              style: AppTypography.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Inventory ──────────────────────────────────────────────────────────
class _InventoryChapter extends StatelessWidget {
  const _InventoryChapter(
      {required this.event, required this.canEdit, required this.cubit});
  final EventEntity event;
  final bool canEdit;
  final EventWorkspaceCubit cubit;

  @override
  Widget build(BuildContext context) {
    return EventChapter(
      eyebrow: 'Resources',
      title: 'Inventory',
      icon: Icons.inventory_2_outlined,
      subtitle: event.inventory.isEmpty
          ? null
          : '${event.readyInventory} of ${event.inventory.length} ready',
      action: canEdit
          ? ChapterAddButton(
              onTap: () => EventEditSheets.addInventory(context, cubit))
          : null,
      child: event.inventory.isEmpty
          ? const SectionEmpty(
              message: 'List the products, assets and equipment the event needs.',
              icon: Icons.inventory_2_outlined)
          : Column(
              children: [
                for (final i in event.inventory)
                  CheckRow(
                    done: i.ready,
                    title: i.quantity > 1 ? '${i.name} ×${i.quantity}' : i.name,
                    subtitle: [
                      if (i.category.trim().isNotEmpty) i.category.trim(),
                      if ((i.ownerName ?? '').trim().isNotEmpty)
                        i.ownerName!.trim(),
                    ].join(' · '),
                    leadingTint: AppColors.success,
                    enabled: canEdit,
                    onToggle: () => cubit.toggleInventoryReady(i.id),
                    onLongPress:
                        canEdit ? () => cubit.removeInventory(i.id) : null,
                  ),
              ],
            ),
    );
  }
}

// ─── Logistics ──────────────────────────────────────────────────────────
class _LogisticsChapter extends StatelessWidget {
  const _LogisticsChapter(
      {required this.event, required this.canEdit, required this.cubit});
  final EventEntity event;
  final bool canEdit;
  final EventWorkspaceCubit cubit;

  @override
  Widget build(BuildContext context) {
    return EventChapter(
      eyebrow: 'On the ground',
      title: 'Logistics',
      icon: Icons.local_shipping_outlined,
      subtitle: event.logistics.isEmpty
          ? null
          : '${event.doneLogistics} of ${event.logistics.length} arranged',
      action: canEdit
          ? ChapterAddButton(
              onTap: () => EventEditSheets.addLogistics(context, cubit))
          : null,
      child: event.logistics.isEmpty
          ? const SectionEmpty(
              message:
                  'Transport, setup, vendors, security, power, internet — track it here.',
              icon: Icons.handyman_outlined)
          : Column(
              children: [
                for (final l in event.logistics)
                  CheckRow(
                    done: l.done,
                    title: l.title,
                    subtitle: [
                      if ((l.detail ?? '').trim().isNotEmpty) l.detail!.trim(),
                      if ((l.vendor ?? '').trim().isNotEmpty)
                        'Vendor: ${l.vendor!.trim()}',
                    ].join(' · '),
                    leadingTint: AppColors.success,
                    enabled: canEdit,
                    onToggle: () => cubit.toggleLogistics(l.id),
                    onLongPress:
                        canEdit ? () => cubit.removeLogistics(l.id) : null,
                  ),
              ],
            ),
    );
  }
}

// ─── Budget ─────────────────────────────────────────────────────────────
class _BudgetChapter extends StatelessWidget {
  const _BudgetChapter(
      {required this.event, required this.canEdit, required this.cubit});
  final EventEntity event;
  final bool canEdit;
  final EventWorkspaceCubit cubit;

  @override
  Widget build(BuildContext context) {
    return EventChapter(
      eyebrow: 'Money',
      title: 'Budget',
      icon: Icons.account_balance_wallet_outlined,
      action: canEdit
          ? ChapterAddButton(
              onTap: () => EventEditSheets.addBudget(context, cubit))
          : null,
      child: event.budget.isEmpty
          ? const SectionEmpty(
              message: 'Add budget lines to track estimated vs actual spend.',
              icon: Icons.savings_outlined)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BudgetSummary(event: event),
                const SizedBox(height: AppSpacing.md),
                for (final b in event.budget)
                  _BudgetRow(
                    line: b,
                    canEdit: canEdit,
                    onActual: () =>
                        EventEditSheets.setActual(context, cubit, b),
                    onApprove: () => cubit.toggleBudgetApproved(b.id),
                    onRemove: () => cubit.removeBudgetLine(b.id),
                  ),
              ],
            ),
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.event});
  final EventEntity event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkSurfaceElevated, AppColors.darkSurface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.cardAll,
        border: Border.all(
          color: event.isOverBudget
              ? AppColors.error.withAlpha(80)
              : AppColors.darkBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _BudgetStat(
                  label: 'Estimated',
                  value: EventFormat.money(event.budgetEstimated)),
              _BudgetStat(
                  label: 'Actual', value: EventFormat.money(event.budgetActual)),
              _BudgetStat(
                label: 'Remaining',
                value: EventFormat.money(event.budgetRemaining),
                color: event.isOverBudget
                    ? AppColors.error
                    : AppColors.success,
              ),
            ],
          ),
          if (event.budgetEstimated > 0) ...[
            const SizedBox(height: AppSpacing.md),
            SectionBar(
              value: event.budgetActual /
                  (event.budgetEstimated == 0 ? 1 : event.budgetEstimated),
              color: event.isOverBudget ? AppColors.error : AppColors.primary,
              height: 6,
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetStat extends StatelessWidget {
  const _BudgetStat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.label.copyWith(
                  color: color ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.line,
    required this.canEdit,
    required this.onActual,
    required this.onApprove,
    required this.onRemove,
  });
  final EventBudgetLine line;
  final bool canEdit;
  final VoidCallback onActual;
  final VoidCallback onApprove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final actualText = line.actual == null
        ? 'Est. ${EventFormat.money(line.estimated)}'
        : '${EventFormat.money(line.actual!)} of ${EventFormat.money(line.estimated)}';
    return InkWell(
      onLongPress: canEdit ? onRemove : null,
      onTap: canEdit ? onActual : null,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            InkWell(
              onTap: canEdit ? onApprove : null,
              borderRadius: AppRadius.fullAll,
              child: Icon(
                line.approved
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 20,
                color:
                    line.approved ? AppColors.success : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.label,
                      style: AppTypography.label
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(actualText,
                      style: AppTypography.labelSmall.copyWith(
                          color: line.isOverEstimate
                              ? AppColors.error
                              : AppColors.textTertiary)),
                ],
              ),
            ),
            if (canEdit)
              const Icon(Icons.edit_outlined,
                  size: 15, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── Communication ──────────────────────────────────────────────────────
class _CommunicationChapter extends StatelessWidget {
  const _CommunicationChapter(
      {required this.event, required this.canEdit, required this.cubit});
  final EventEntity event;
  final bool canEdit;
  final EventWorkspaceCubit cubit;

  @override
  Widget build(BuildContext context) {
    final posts = event.orderedAnnouncements;
    return EventChapter(
      eyebrow: 'Comms',
      title: 'Updates',
      icon: Icons.campaign_outlined,
      action: canEdit
          ? ChapterAddButton(
              onTap: () => EventEditSheets.announce(context, cubit))
          : null,
      child: posts.isEmpty
          ? const SectionEmpty(
              message: 'Post announcements, updates and important notices here.',
              icon: Icons.notifications_none_rounded)
          : Column(
              children: [
                for (final a in posts)
                  _AnnouncementCard(
                    post: a,
                    canEdit: canEdit,
                    onPin: () => cubit.togglePinned(a.id),
                    onRemove: () => cubit.removeAnnouncement(a.id),
                  ),
              ],
            ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.post,
    required this.canEdit,
    required this.onPin,
    required this.onRemove,
  });
  final EventAnnouncement post;
  final bool canEdit;
  final VoidCallback onPin;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = post.important ? AppColors.warning : AppColors.darkBorder;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
            color: post.important ? accent.withAlpha(90) : AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (post.pinned) ...[
                const Icon(Icons.push_pin_rounded,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 5),
              ],
              if (post.important) ...[
                const Icon(Icons.priority_high_rounded,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  [
                    if ((post.authorName ?? '').trim().isNotEmpty)
                      post.authorName!.trim(),
                    EventFormat.relative(post.createdAt),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ),
              if (canEdit)
                _PostMenu(onPin: onPin, onRemove: onRemove, pinned: post.pinned),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(post.body,
              style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary, height: 1.5)),
        ],
      ),
    );
  }
}

class _PostMenu extends StatelessWidget {
  const _PostMenu(
      {required this.onPin, required this.onRemove, required this.pinned});
  final VoidCallback onPin;
  final VoidCallback onRemove;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      width: 28,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        iconSize: 16,
        color: AppColors.darkSurfaceElevated,
        icon: const Icon(Icons.more_horiz_rounded,
            color: AppColors.textTertiary),
        onSelected: (v) => v == 'pin' ? onPin() : onRemove(),
        itemBuilder: (context) => [
          PopupMenuItem(
              value: 'pin',
              child: Text(pinned ? 'Unpin' : 'Pin',
                  style: AppTypography.label)),
          PopupMenuItem(
              value: 'remove',
              child: Text('Delete', style: AppTypography.label)),
        ],
      ),
    );
  }
}

// ─── After event ────────────────────────────────────────────────────────
class _AfterChapter extends StatelessWidget {
  const _AfterChapter(
      {required this.event, required this.canEdit, required this.cubit});
  final EventEntity event;
  final bool canEdit;
  final EventWorkspaceCubit cubit;

  @override
  Widget build(BuildContext context) {
    final o = event.outcome;
    final empty = o == null || o.isEmpty;
    return EventChapter(
      eyebrow: 'After',
      title: 'The story it left',
      icon: Icons.verified_outlined,
      action: canEdit
          ? ChapterAddButton(
              onTap: () => EventEditSheets.editOutcome(context, cubit, o))
          : null,
      child: empty
          ? const SectionEmpty(
              message:
                  'Capture the numbers, the wins and the lessons once it wraps.',
              icon: Icons.auto_stories_outlined)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (o.hasNumbers) ...[
                  Row(
                    children: [
                      if (o.revenue != null)
                        _OutcomeStat(
                            label: 'Revenue',
                            value: EventFormat.money(o.revenue!)),
                      if (o.visitors != null)
                        _OutcomeStat(
                            label: 'Visitors',
                            value: EventFormat.compact(o.visitors!)),
                      if (o.productsSold != null)
                        _OutcomeStat(
                            label: 'Sold',
                            value: EventFormat.compact(o.productsSold!)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (o.summary.trim().isNotEmpty) ...[
                  Text(o.summary.trim(),
                      style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary, height: 1.6)),
                  const SizedBox(height: AppSpacing.md),
                ],
                _OutcomeList(
                    label: 'Wins', items: o.wins, icon: Icons.emoji_events_outlined),
                _OutcomeList(
                    label: 'Lessons',
                    items: o.lessons,
                    icon: Icons.lightbulb_outline_rounded),
                _OutcomeList(
                    label: 'Recommendations',
                    items: o.recommendations,
                    icon: Icons.tips_and_updates_outlined),
              ],
            ),
    );
  }
}

class _OutcomeStat extends StatelessWidget {
  const _OutcomeStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary, letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _OutcomeList extends StatelessWidget {
  const _OutcomeList(
      {required this.label, required this.items, required this.icon});
  final String label;
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(label.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7, right: 8),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.textTertiary),
                  ),
                  Expanded(
                    child: Text(item,
                        style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Lifecycle status control ───────────────────────────────────────────
class _StatusControl extends StatelessWidget {
  const _StatusControl({required this.event, required this.cubit});
  final EventEntity event;
  final EventWorkspaceCubit cubit;

  @override
  Widget build(BuildContext context) {
    final advanceLabel = event.status.advanceLabel;
    if (advanceLabel == null) return const SizedBox.shrink();
    final next = event.status.advanceTo!;
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lifecycle',
              style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary, letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Text('This event is ${event.status.label}',
              style: AppTypography.h3),
          const SizedBox(height: 4),
          Text(_nextHint(next), style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => cubit.advanceStatus(),
              icon: Icon(EventFormat.statusIcon(next), size: 18),
              label: Text(advanceLabel),
            ),
          ),
        ],
      ),
    );
  }

  String _nextHint(EventStatus next) => switch (next) {
        EventStatus.planning => 'Move it into active planning.',
        EventStatus.ready => 'Mark it ready once preparation is complete.',
        EventStatus.live => 'Open the doors — the workspace becomes a command center.',
        EventStatus.completed => 'Wrap it up and capture the outcome.',
        EventStatus.archived => 'File it into the archive.',
        _ => '',
      };
}

// ─── Not found ──────────────────────────────────────────────────────────
class _NotFound extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(backgroundColor: AppColors.darkBg),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_rounded,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text('This event no longer exists',
                style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            Text('It may have been deleted.',
                style: AppTypography.body),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}
