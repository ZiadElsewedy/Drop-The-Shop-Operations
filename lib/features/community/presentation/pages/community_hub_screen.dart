import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_search_field.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/core/widgets/drop_loading_state.dart';
import 'package:drop/features/community/domain/entities/event_entity.dart';
import 'package:drop/features/community/domain/event_ordering.dart';
import 'package:drop/features/community/presentation/cubit/community_hub_cubit.dart';
import 'package:drop/features/community/presentation/cubit/community_hub_state.dart';
import 'package:drop/features/community/presentation/widgets/event_card.dart';

/// The **Community Hub** — DROP's home for every event, internal and external.
/// Not a calendar: a curated surface where upcoming events show as cinematic
/// spotlight posters up top and the archive of past events settles below. Every
/// role sees it (self-scoped: admin all branches · manager + employee own
/// branch); only admin + manager get the "New event" entry point.
class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen> {
  String _query = '';

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

  bool get _canCreate => context.isAdmin || context.isManager;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Community Hub',
      subtitle: context.isAdmin
          ? 'Every DROP event, across all branches'
          : 'Events at your branch',
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(RouteNames.communityCreate),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New event'),
            )
          : null,
      body: BlocBuilder<CommunityHubCubit, CommunityHubState>(
        builder: (context, state) {
          if (state.isLoading || state.status == HubStatus.initial) {
            return const DropLoadingState(message: 'Loading events…');
          }
          if (state.isError && state.events.isEmpty) {
            return _ErrorState(
              message: state.error ?? 'Failed to load events.',
              onRetry: () => context.read<CommunityHubCubit>().refresh(),
            );
          }
          return _Body(
            events: state.events,
            branchNames: state.branchNames,
            query: _query,
            onQuery: (q) => setState(() => _query = q),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.events,
    required this.branchNames,
    required this.query,
    required this.onQuery,
  });

  final List<EventEntity> events;
  final Map<String, String> branchNames;
  final String query;
  final ValueChanged<String> onQuery;

  bool _matches(EventEntity e) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = [
      e.title,
      e.type.label,
      e.location ?? '',
      e.ownerName ?? '',
      branchNames[e.branchId ?? ''] ?? '',
    ].join(' ').toLowerCase();
    return hay.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = events.where(_matches).toList();
    final upcoming = upcomingEvents(filtered);
    final past = pastEvents(filtered);

    return RefreshIndicator(
      onRefresh: () => context.read<CommunityHubCubit>().refresh(),
      color: AppColors.primary,
      backgroundColor: AppColors.darkSurface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.huge),
        children: [
          AppSearchField(hint: 'Search events', onChanged: onQuery),
          const SizedBox(height: AppSpacing.lg),
          if (filtered.isEmpty)
            _EmptyState(hasAny: events.isNotEmpty)
          else ...[
            if (upcoming.isNotEmpty) ...[
              _SectionLabel(
                  label: 'Spotlight',
                  count: upcoming.length,
                  hint: 'Coming up'),
              const SizedBox(height: AppSpacing.md),
              _SpotlightRail(
                  events: upcoming.take(8).toList(), branchNames: branchNames),
              const SizedBox(height: AppSpacing.xl),
            ],
            if (upcoming.isNotEmpty) ...[
              _SectionLabel(label: 'All upcoming', count: upcoming.length),
              const SizedBox(height: AppSpacing.md),
              for (final e in upcoming) _row(context, e),
            ],
            if (past.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel(label: 'Archive', count: past.length),
              const SizedBox(height: AppSpacing.md),
              for (final e in past) _row(context, e),
            ],
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, EventEntity e) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: EventCard(
          event: e,
          branchName: branchNames[e.branchId ?? ''],
          onTap: () => context.push(RouteNames.eventDetail(e.id)),
        ),
      );
}

class _SpotlightRail extends StatelessWidget {
  const _SpotlightRail({required this.events, required this.branchNames});
  final List<EventEntity> events;
  final Map<String, String> branchNames;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 234,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) {
          final e = events[i];
          return FeaturedEventCard(
            event: e,
            width: 300,
            branchName: branchNames[e.branchId ?? ''],
            onTap: () => context.push(RouteNames.eventDetail(e.id)),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.count, this.hint});
  final String label;
  final int count;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: AppTypography.h3),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Text('$count',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary)),
        ),
        const Spacer(),
        if (hint != null)
          Text(hint!,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAny});
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final canCreate = context.isAdmin || context.isManager;
    final String message;
    if (hasAny) {
      message = 'No events match your search.';
    } else if (canCreate) {
      message =
          'Plan your first event — a launch, a pop-up, a community night — and '
          'give it a home the whole team can run from.';
    } else {
      message = 'Events happening at your branch will show up here.';
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxxl),
      child: DropEmptyState(
        title: hasAny ? 'Nothing here' : 'No events yet',
        message: message,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 44, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.lg),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
