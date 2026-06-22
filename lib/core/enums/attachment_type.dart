/// The kind of media a [TaskAttachment] holds. Stored lower-case in
/// `tasks/{id}.activityLog[].attachments[].type`.
enum AttachmentType {
  image,
  video;

  /// The string persisted in Firestore (the lower-case name).
  String get value => name;

  bool get isImage => this == AttachmentType.image;
  bool get isVideo => this == AttachmentType.video;

  /// Parses the stored string; unknown/missing → [image] (the safe default —
  /// an image renders directly; a mis-tagged video would just show its poster).
  static AttachmentType fromString(String? raw) =>
      raw == 'video' ? AttachmentType.video : AttachmentType.image;
}
