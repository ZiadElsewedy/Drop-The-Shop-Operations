import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:fbro/core/enums/attachment_type.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/features/task/domain/entities/task_attachment.dart';
import 'package:fbro/features/task/presentation/cubit/task_cubit.dart';
import 'package:fbro/features/task/presentation/widgets/video_thumbnail_image.dart';

/// Submission media picker (Phase 10) — lets an employee attach multiple images
/// and videos (gallery or camera) before submitting / re-submitting a task.
/// Shows the selected media as removable thumbnails and enforces the count /
/// size limits in [AttachmentLimits]. Parent owns the list; this calls
/// [onChanged] with the new selection.
class AttachmentPickerField extends StatelessWidget {
  const AttachmentPickerField({
    super.key,
    required this.attachments,
    required this.onChanged,
  });

  final List<PickedAttachment> attachments;
  final ValueChanged<List<PickedAttachment>> onChanged;

  int get _images => attachments.where((a) => a.type.isImage).length;
  int get _videos => attachments.where((a) => a.type.isVideo).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attachment_rounded,
                  size: 16, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Text('Attachments', style: AppTypography.labelSmall),
              const Spacer(),
              Text(
                'Photos $_images/${AttachmentLimits.maxImages} · '
                'Videos $_videos/${AttachmentLimits.maxVideos}',
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < attachments.length; i++)
                _SelectedTile(
                  attachment: attachments[i],
                  onRemove: () => _removeAt(i),
                ),
              _AddTile(onTap: () => _openMenu(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add photos (≤${AttachmentLimits.maxImageMb} MB) or videos '
            '(≤${AttachmentLimits.maxVideoMb} MB) as proof. Photos are '
            'compressed before upload.',
            style: AppTypography.caption
                .copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  void _removeAt(int i) {
    final next = [...attachments]..removeAt(i);
    onChanged(next);
  }

  // ── Add menu ─────────────────────────────────────────────────────
  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _MenuRow(
              icon: Icons.photo_library_outlined,
              label: 'Choose photos',
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickPhotos(context);
              },
            ),
            _MenuRow(
              icon: Icons.video_library_outlined,
              label: 'Choose a video',
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickVideo(context, ImageSource.gallery);
              },
            ),
            _MenuRow(
              icon: Icons.photo_camera_outlined,
              label: 'Take a photo',
              onTap: () {
                Navigator.pop(sheetCtx);
                _takePhoto(context);
              },
            ),
            _MenuRow(
              icon: Icons.videocam_outlined,
              label: 'Record a video',
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickVideo(context, ImageSource.camera);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  // ── Pickers ──────────────────────────────────────────────────────
  // Photos are resized + recompressed by image_picker before upload (the
  // pre-upload optimization), per AttachmentLimits.
  Future<void> _pickPhotos(BuildContext context) async {
    try {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: AttachmentLimits.imageQuality,
        maxWidth: AttachmentLimits.imageMaxWidth,
      );
      if (picked.isEmpty) return;
      if (!context.mounted) return;
      await _commit(
          context, [for (final x in picked) (x, AttachmentType.image, null)]);
    } catch (_) {
      if (context.mounted) AppSnackbar.error(context, 'Could not add photos.');
    }
  }

  Future<void> _takePhoto(BuildContext context) async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: AttachmentLimits.imageQuality,
        maxWidth: AttachmentLimits.imageMaxWidth,
      );
      if (x == null || !context.mounted) return;
      await _commit(context, [(x, AttachmentType.image, null)]);
    } catch (_) {
      if (context.mounted) AppSnackbar.error(context, 'Could not take a photo.');
    }
  }

  Future<void> _pickVideo(BuildContext context, ImageSource source) async {
    try {
      final x = await ImagePicker().pickVideo(
          source: source, maxDuration: AttachmentLimits.maxVideoDuration);
      if (x == null) return;
      final durationMs = await _videoDurationMs(x.path); // no context use
      if (!context.mounted) return;
      await _commit(context, [(x, AttachmentType.video, durationMs)]);
    } catch (_) {
      if (context.mounted) AppSnackbar.error(context, 'Could not add the video.');
    }
  }

  /// Best-effort video length (ms) read locally via a throwaway controller. Null
  /// on any failure — duration is a nice-to-have, never blocks the attachment.
  Future<int?> _videoDurationMs(String path) async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      final ms = controller.value.duration.inMilliseconds;
      return ms > 0 ? ms : null;
    } catch (_) {
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  /// Validates each picked file against the count + size limits, appends the
  /// accepted ones, and surfaces the first rejection reason (once).
  Future<void> _commit(BuildContext context,
      List<(XFile, AttachmentType, int?)> incoming) async {
    final next = [...attachments];
    String? reason;
    for (final (file, type, durationMs) in incoming) {
      final r = await _rejectReason(next, file, type);
      if (r != null) {
        reason ??= r;
        continue;
      }
      next.add(PickedAttachment(File(file.path), type, durationMs: durationMs));
    }
    onChanged(next);
    if (reason != null && context.mounted) AppSnackbar.error(context, reason);
  }

  /// Why a picked file can't be added (count / per-type size), or null if it's
  /// fine. Pure of [BuildContext] so it never crosses an async gap with the UI.
  Future<String?> _rejectReason(
      List<PickedAttachment> current, XFile file, AttachmentType type) async {
    final images = current.where((a) => a.type.isImage).length;
    final videos = current.where((a) => a.type.isVideo).length;
    if (type.isImage && images >= AttachmentLimits.maxImages) {
      return 'Up to ${AttachmentLimits.maxImages} photos.';
    }
    if (type.isVideo && videos >= AttachmentLimits.maxVideos) {
      return 'Up to ${AttachmentLimits.maxVideos} videos.';
    }
    final size = await File(file.path).length();
    if (size > AttachmentLimits.maxBytesFor(type)) {
      final what = type.isVideo ? 'video' : 'photo';
      return 'Each $what must be under ${AttachmentLimits.maxMbFor(type)} MB.';
    }
    return null;
  }
}

class _SelectedTile extends StatelessWidget {
  const _SelectedTile({required this.attachment, required this.onRemove});
  final PickedAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: SizedBox(
              width: size,
              height: size,
              child: attachment.type.isImage
                  ? Image.file(attachment.file, fit: BoxFit.cover)
                  : VideoThumbnailImage(source: attachment.file.path),
            ),
          ),
          if (attachment.type.isVideo)
            const Positioned.fill(
              child: Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white70, size: 26),
              ),
            ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.darkBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 13, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.darkBg,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 22, color: AppColors.textSecondary),
            SizedBox(height: 2),
            Text('Add', style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label, style: AppTypography.label),
      onTap: onTap,
    );
  }
}
