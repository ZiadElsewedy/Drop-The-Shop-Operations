import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/event_type.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/features/community/presentation/cubit/community_hub_cubit.dart';
import 'package:drop/features/community/presentation/cubit/community_hub_state.dart';
import 'package:drop/features/community/presentation/event_format.dart';

/// Create an event — a focused, premium flow (admin + manager only). It captures
/// just enough to give the event a home (name, kind, date, place); every
/// operational section is then built inside the workspace. On save it opens the
/// new workspace directly.
class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _attendance = TextEditingController();

  EventType _type = EventType.collectionLaunch;
  DateTime? _start;
  String? _branchId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = context.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<CommunityHubCubit>().load(user),
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    _attendance.dispose();
    super.dispose();
  }

  bool get _valid => _title.text.trim().isNotEmpty && !_submitting;

  Future<void> _submit() async {
    if (!_valid) return;
    setState(() => _submitting = true);
    final created = await context.read<CommunityHubCubit>().createEvent(
          title: _title.text,
          type: _type,
          branchId: _branchId,
          location: _location.text.trim(),
          description: _description.text.trim(),
          startAt: _start,
          expectedAttendance: int.tryParse(_attendance.text.trim()),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (created != null) {
      context.pushReplacement(RouteNames.eventDetail(created.id));
    } else {
      context.showError('Could not create the event. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.isAdmin;
    return AdaptiveScaffold(
      title: 'New event',
      subtitle: 'Give it a home the team can run from',
      contentMaxWidth: 640,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.huge),
        children: [
          _Label('Title'),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            style: AppTypography.h3,
            decoration: const InputDecoration(hintText: 'Name your event'),
          ),
          _Label('Kind of event'),
          _TypeGrid(
            selected: _type,
            onSelect: (t) => setState(() => _type = t),
          ),
          if (isAdmin) ...[
            _Label('Branch'),
            _BranchPicker(
              branchId: _branchId,
              onPick: (id) => setState(() => _branchId = id),
            ),
          ],
          _Label('Date & time'),
          _DateTile(
            date: _start,
            onPick: (d) => setState(() => _start = d),
          ),
          _Label('Location'),
          TextField(
            controller: _location,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(hintText: 'Venue / address'),
          ),
          _Label('Description'),
          TextField(
            controller: _description,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration:
                const InputDecoration(hintText: 'What is this event about?'),
          ),
          _Label('Expected attendance'),
          TextField(
            controller: _attendance,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'e.g. 150'),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _valid ? _submit : null,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : const Text('Create event'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
        child: Text(text.toUpperCase(),
            style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600)),
      );
}

class _TypeGrid extends StatelessWidget {
  const _TypeGrid({required this.selected, required this.onSelect});
  final EventType selected;
  final ValueChanged<EventType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final t in EventType.values)
          _TypeChip(
            type: t,
            active: t == selected,
            onTap: () => onSelect(t),
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(
      {required this.type, required this.active, required this.onTap});
  final EventType type;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.fullAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.darkSurface,
          borderRadius: AppRadius.fullAll,
          border: Border.all(
              color: active ? AppColors.primary : AppColors.darkBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(EventFormat.typeIcon(type),
                size: 16,
                color: active ? AppColors.onPrimary : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(type.label,
                style: AppTypography.labelSmall.copyWith(
                    color:
                        active ? AppColors.onPrimary : AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _BranchPicker extends StatelessWidget {
  const _BranchPicker({required this.branchId, required this.onPick});
  final String? branchId;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityHubCubit, CommunityHubState>(
      builder: (context, state) {
        final names = state.branchNames;
        final label = branchId == null
            ? 'All branches'
            : (names[branchId] ?? 'Selected branch');
        return InkWell(
          onTap: () => _openSheet(context, names),
          borderRadius: AppRadius.lgAll,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                    child: Text(label,
                        style: AppTypography.body
                            .copyWith(color: AppColors.textPrimary))),
                const Icon(Icons.expand_more_rounded,
                    size: 20, color: AppColors.textTertiary),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSheet(BuildContext context, Map<String, String> names) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const Icon(Icons.public_rounded,
                  color: AppColors.textSecondary),
              title: Text('All branches', style: AppTypography.label),
              onTap: () {
                onPick(null);
                Navigator.of(context).pop();
              },
            ),
            for (final entry in names.entries)
              ListTile(
                leading: const Icon(Icons.storefront_outlined,
                    color: AppColors.textSecondary),
                title: Text(entry.value, style: AppTypography.label),
                trailing: branchId == entry.key
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  onPick(entry.key);
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, required this.onPick});
  final DateTime? date;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    final label = date == null
        ? 'Pick a date'
        : EventFormat.dateLabel(date);
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? now.add(const Duration(days: 7)),
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 3),
        );
        if (picked == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(
              date ?? now.copyWith(hour: 18, minute: 0)),
        );
        onPick(DateTime(picked.year, picked.month, picked.day,
            time?.hour ?? 18, time?.minute ?? 0));
      },
      borderRadius: AppRadius.lgAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
                child: Text(label,
                    style: AppTypography.body.copyWith(
                        color: date == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary))),
            if (date != null)
              GestureDetector(
                onTap: () => onPick(null),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textTertiary),
              ),
          ],
        ),
      ),
    );
  }
}
