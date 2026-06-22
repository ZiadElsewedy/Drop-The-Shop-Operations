import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/enums/broadcast_audience.dart';
import 'package:fbro/core/enums/broadcast_category.dart';
import 'package:fbro/core/enums/broadcast_channel.dart';
import 'package:fbro/core/enums/broadcast_priority.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_search_field.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/core/widgets/user_avatar.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_dropdown_field.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/communications/domain/entities/broadcast_entity.dart';
import 'package:fbro/features/communications/domain/broadcast_permissions.dart';
import 'package:fbro/features/communications/presentation/communications_format.dart';
import 'package:fbro/features/communications/presentation/cubit/broadcast_cubit.dart';
import 'package:fbro/features/communications/presentation/cubit/broadcast_state.dart';

/// Compose Broadcast (Phase 3). Role-gated form: audience (admin: everyone /
/// branch / individual · manager: own branch / individual-in-branch), an
/// optional branch + recipient picker, category, title, body, and a sticky
/// "Send Broadcast" CTA. Sending routes through `BroadcastCubit.send` (→ the
/// callable Cloud Function); the success snackbar reports the recipient count.
class ComposeBroadcastScreen extends StatefulWidget {
  const ComposeBroadcastScreen({super.key, this.prefill});

  /// When set (e.g. "Duplicate as editable draft"), seeds the form's text,
  /// category, audience, priority and channel from an existing broadcast.
  final BroadcastEntity? prefill;

  @override
  State<ComposeBroadcastScreen> createState() => _ComposeBroadcastScreenState();
}

class _ComposeBroadcastScreenState extends State<ComposeBroadcastScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  late final UserEntity _sender;
  late final List<BroadcastAudience> _allowed;
  late BroadcastAudience _audience;
  BroadcastCategory _category = BroadcastCategory.announcement;
  BroadcastPriority _priority = BroadcastPriority.normal;
  BroadcastChannel _channel = BroadcastChannel.both;

  List<BranchEntity> _branches = const [];
  BranchEntity? _selectedBranch; // admin's chosen branch (branch / individual)
  List<UserEntity> _users = const [];
  UserEntity? _selectedUser;
  bool _loadingUsers = false;
  String _userQuery = '';
  bool _submitting = false;

  bool get _isAdmin => _sender.role.isAdmin;

  @override
  void initState() {
    super.initState();
    // The route guard guarantees an admin/manager reaches this screen.
    _sender = context.currentUser!;
    _allowed = BroadcastPermissions.allowedAudiences(_sender.role);
    _audience = _allowed.first;
    // Seed from a duplicated broadcast when provided.
    final p = widget.prefill;
    if (p != null) {
      _titleCtrl.text = p.title;
      _bodyCtrl.text = p.message;
      _category = BroadcastCategory.fromString(p.category);
      _priority = p.priority;
      _channel = p.channel;
      if (_allowed.contains(p.audience)) _audience = p.audience;
    }
    _titleCtrl.addListener(_onFormChanged);
    _bodyCtrl.addListener(_onFormChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final branches = await context.read<BroadcastCubit>().branches();
    if (!mounted) return;
    setState(() => _branches = branches);
    // A manager's individual recipients come from their own branch.
    if (!_isAdmin && _audience == BroadcastAudience.user) {
      _loadUsers(_sender.branchId ?? '');
    }
  }

  void _onFormChanged() => setState(() {});

  Future<void> _loadUsers(String branchId) async {
    setState(() {
      _loadingUsers = true;
      _users = const [];
      _selectedUser = null;
    });
    final users = await context.read<BroadcastCubit>().branchUsers(branchId);
    if (!mounted) return;
    setState(() {
      // Don't offer the sender as a recipient of their own message.
      _users = users.where((u) => u.uid != _sender.uid).toList();
      _loadingUsers = false;
    });
  }

  void _selectAudience(BroadcastAudience a) {
    setState(() {
      _audience = a;
      _selectedUser = null;
      _userQuery = '';
    });
    if (a == BroadcastAudience.user && !_isAdmin) {
      _loadUsers(_sender.branchId ?? '');
    }
  }

  /// The branch id a recipient list / branch send targets.
  String get _targetBranchId =>
      _isAdmin ? (_selectedBranch?.id ?? '') : (_sender.branchId ?? '');

  String? get _ownBranchName {
    for (final b in _branches) {
      if (b.id == _sender.branchId) return b.name;
    }
    return null;
  }

  bool get _canSend {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      return false;
    }
    switch (_audience) {
      case BroadcastAudience.allBranches:
        return true;
      case BroadcastAudience.branch:
        return _isAdmin ? _selectedBranch != null : true;
      case BroadcastAudience.user:
        return _selectedUser != null;
    }
  }

  List<UserEntity> get _filteredUsers {
    if (_userQuery.isEmpty) return _users;
    final q = _userQuery.toLowerCase();
    return _users
        .where((u) =>
            (u.displayName ?? '').toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _send() async {
    setState(() => _submitting = true);
    final count = await context.read<BroadcastCubit>().send(
          sender: _sender,
          title: _titleCtrl.text,
          message: _bodyCtrl.text,
          audience: _audience,
          branchId: _audience == BroadcastAudience.branch ? _targetBranchId : null,
          targetUserId:
              _audience == BroadcastAudience.user ? _selectedUser?.uid : null,
          targetUserBranchId: _selectedUser?.branchId,
          category: _category.value,
          priority: _priority,
          channel: _channel,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (count != null) {
      AppSnackbar.success(
        context,
        'Broadcast sent to $count ${count == 1 ? 'recipient' : 'recipients'}',
      );
      context.pop();
    }
    // On failure the cubit emits an error → surfaced by the BlocListener below.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text('New Broadcast', style: AppTypography.h3),
      ),
      bottomNavigationBar: _SendBar(
        enabled: _canSend && !_submitting,
        loading: _submitting,
        onSend: _send,
      ),
      body: BlocListener<BroadcastCubit, BroadcastState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding,
              AppSpacing.lg, AppSpacing.pagePadding, AppSpacing.xl),
          children: [
            const _Label('Audience'),
            _audienceSelector(),
            ..._audienceTarget(),
            const SizedBox(height: AppSpacing.xl),
            const _Label('Category'),
            _categorySelector(),
            const SizedBox(height: AppSpacing.xl),
            const _Label('Title'),
            AppTextField(
              controller: _titleCtrl,
              label: 'Broadcast title',
              hint: 'e.g. Stock count tonight',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _Label('Message'),
            AppTextField(
              controller: _bodyCtrl,
              label: 'Write your message',
              minLines: 4,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _audienceSelector() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final a in _allowed)
          _Choice(
            icon: audienceIcon(a),
            label: _audienceChoiceLabel(a),
            selected: _audience == a,
            onTap: () => _selectAudience(a),
          ),
      ],
    );
  }

  String _audienceChoiceLabel(BroadcastAudience a) => switch (a) {
        BroadcastAudience.allBranches => 'Everyone',
        BroadcastAudience.branch => 'Branch',
        BroadcastAudience.user => 'Individual',
      };

  /// The audience-specific picker (branch selector / recipient picker).
  List<Widget> _audienceTarget() {
    switch (_audience) {
      case BroadcastAudience.allBranches:
        return [
          const SizedBox(height: AppSpacing.md),
          const _Hint('Every active user across all branches will be notified.'),
        ];
      case BroadcastAudience.branch:
        return [
          const SizedBox(height: AppSpacing.md),
          if (_isAdmin)
            AppDropdownField<BranchEntity>(
              value: _selectedBranch,
              hint: 'Select a branch',
              prefixIcon: Icons.store_mall_directory_outlined,
              items: [
                for (final b in _branches)
                  DropdownMenuItem(value: b, child: Text(b.name)),
              ],
              onChanged: (b) => setState(() => _selectedBranch = b),
            )
          else
            _FixedTarget(
              icon: Icons.store_mall_directory_outlined,
              label: _ownBranchName ?? 'Your branch',
              caption: 'Everyone in your branch will be notified.',
            ),
        ];
      case BroadcastAudience.user:
        return [
          const SizedBox(height: AppSpacing.md),
          if (_isAdmin) ...[
            AppDropdownField<BranchEntity>(
              value: _selectedBranch,
              hint: 'Select a branch',
              prefixIcon: Icons.store_mall_directory_outlined,
              items: [
                for (final b in _branches)
                  DropdownMenuItem(value: b, child: Text(b.name)),
              ],
              onChanged: (b) {
                setState(() => _selectedBranch = b);
                if (b != null) _loadUsers(b.id);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _userPicker(),
        ];
    }
  }

  Widget _userPicker() {
    if (_isAdmin && _selectedBranch == null) {
      return const _Hint('Pick a branch to choose a recipient.');
    }
    if (_loadingUsers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5))),
      );
    }
    if (_users.isEmpty) {
      return const _Hint('No active users to message in this branch.');
    }
    final filtered = _filteredUsers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSearchField(
          hint: 'Search people',
          onChanged: (v) => setState(() => _userQuery = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (filtered.isEmpty)
          const _Hint('No people match your search.')
        else
          for (final u in filtered)
            _UserTile(
              user: u,
              selected: _selectedUser?.uid == u.uid,
              onTap: () => setState(() => _selectedUser = u),
            ),
      ],
    );
  }

  Widget _categorySelector() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final c in BroadcastCategory.values)
          _Choice(
            icon: categoryIcon(c),
            label: c.label,
            selected: _category == c,
            accent: c.isUrgent ? categoryColor(c) : null,
            onTap: () => setState(() => _category = c),
          ),
      ],
    );
  }
}

// ─── Small presentational helpers ─────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text.toUpperCase(),
            style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary, letterSpacing: 0.6)),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.bodySmall);
}

/// A selectable chip used for both the audience and category rows.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? AppColors.onPrimary
        : (accent ?? AppColors.textSecondary);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.darkBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(label,
                style: AppTypography.label
                    .copyWith(color: fg, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// A fixed (non-selectable) target tile — the manager's own branch.
class _FixedTarget extends StatelessWidget {
  const _FixedTarget(
      {required this.icon, required this.label, required this.caption});
  final IconData icon;
  final String label;
  final String caption;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.label, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(caption, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile(
      {required this.user, required this.selected, required this.onTap});
  final UserEntity user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName!
        : user.email;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.darkBorder),
        ),
        child: Row(
          children: [
            UserAvatar.fromUser(user, size: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTypography.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(user.email,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The sticky bottom Send CTA.
class _SendBar extends StatelessWidget {
  const _SendBar(
      {required this.enabled, required this.loading, required this.onSend});
  final bool enabled;
  final bool loading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.md,
          AppSpacing.pagePadding, AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: SafeArea(
        top: false,
        child: AppButton(
          label: 'Send Broadcast',
          isLoading: loading,
          onPressed: enabled ? onSend : null,
          icon: const Icon(Icons.send_rounded,
              size: 18, color: AppColors.onPrimary),
        ),
      ),
    );
  }
}
