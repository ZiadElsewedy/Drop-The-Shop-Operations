/// The stages a task submission moves through, reported through `TaskState` so
/// the shared loading overlay can show a real sequence instead of a frozen
/// screen. (Thumbnails are generated locally at view time, not at submit, so
/// there is no upload/“generating thumbnail” stage.)
enum SubmissionStage {
  preparing,
  uploading,
  finalizing;

  /// User-facing stage label for the loading overlay.
  String get label => switch (this) {
        SubmissionStage.preparing => 'Preparing media',
        SubmissionStage.uploading => 'Uploading attachments',
        SubmissionStage.finalizing => 'Finalizing submission',
      };
}

/// A snapshot of submission progress — the current [stage] and, while uploading,
/// the aggregate bytes transferred / total across all files (so the overlay can
/// show a real bar, a percentage, and "X.X / Y.Y MB").
class SubmissionProgress {
  const SubmissionProgress(
    this.stage, {
    this.transferredBytes = 0,
    this.totalBytes = 0,
  });

  final SubmissionStage stage;
  final int transferredBytes;
  final int totalBytes;

  /// Upload progress 0–1, or null when the size isn't known yet (indeterminate).
  double? get fraction =>
      totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : null;

  /// Whole-percent for display, or null when indeterminate.
  int? get percent => fraction == null ? null : (fraction! * 100).round();

  /// "32.4 / 47.8 MB", or null when the size isn't known yet.
  String? get sizeLabel =>
      totalBytes > 0 ? '${_mb(transferredBytes)} / ${_mb(totalBytes)} MB' : null;

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}
