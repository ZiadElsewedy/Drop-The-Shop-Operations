import 'package:flutter/material.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/branch/presentation/cubit/branch_cubit.dart';

/// Create or edit a branch (admin).
Future<void> showBranchFormSheet({
  required BuildContext context,
  required BranchCubit cubit,
  BranchEntity? existing,
}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BranchFormSheet(cubit: cubit, existing: existing),
    );

class _BranchFormSheet extends StatefulWidget {
  const _BranchFormSheet({required this.cubit, required this.existing});
  final BranchCubit cubit;
  final BranchEntity? existing;

  @override
  State<_BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends State<_BranchFormSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _location =
      TextEditingController(text: widget.existing?.location ?? '');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Branch name is required.');
      return;
    }
    final location = _location.text.trim().isEmpty ? null : _location.text.trim();
    final existing = widget.existing;
    if (existing == null) {
      widget.cubit.createBranch(name: name, location: location);
    } else {
      widget.cubit.editBranch(existing.copyWith(name: name, location: location));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pagePadding,
        right: AppSpacing.pagePadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null ? 'New Branch' : 'Edit Branch',
              style: AppTypography.h3),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _name,
            label: 'Branch name',
            hint: 'e.g. Cairo Festival City',
            prefixIcon: Icons.store_mall_directory_outlined,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _location,
            label: 'Location (optional)',
            prefixIcon: Icons.place_outlined,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!,
                style: AppTypography.caption.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: widget.existing == null ? 'Create Branch' : 'Save Changes',
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
