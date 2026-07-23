import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';

/// What the user chose in the attachment sheet.
enum ChatAttachmentChoice { camera, gallery, document }

/// A modern bottom sheet offering the three attachment sources — Camera,
/// Gallery, Documents — as large, tappable tiles. Returns the choice (or null
/// if dismissed); the caller runs the matching picker.
Future<ChatAttachmentChoice?> showChatAttachmentSheet(BuildContext context) {
  return showModalBottomSheet<ChatAttachmentChoice>(
    context: context,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                _SourceTile(
                  icon: Icons.photo_camera_rounded,
                  label: 'Camera',
                  onTap: () => Navigator.of(sheetContext)
                      .pop(ChatAttachmentChoice.camera),
                ),
                const SizedBox(width: AppSpacing.md),
                _SourceTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () => Navigator.of(sheetContext)
                      .pop(ChatAttachmentChoice.gallery),
                ),
                const SizedBox(width: AppSpacing.md),
                _SourceTile(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Document',
                  onTap: () => Navigator.of(sheetContext)
                      .pop(ChatAttachmentChoice.document),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.darkBorder),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 26, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
