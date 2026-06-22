/// The kind of a broadcast (Communications Center — Phase 3). Stored as a string
/// in `broadcasts/{id}.category` and carried in the FCM `data` payload so the
/// client can route / group / style the notification.
///
/// Pure Dart (no Flutter) like every `core/enums` value — the icon/colour mapping
/// lives in the presentation layer (`communications_format.dart`).
enum BroadcastCategory {
  announcement,
  alert,
  reminder,
  emergency;

  /// The string persisted in Firestore / sent in the push payload.
  String get value => name;

  /// Capitalized label for the UI.
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';

  /// Whether this category should read with an attention colour (status-only
  /// colour, per the monochrome design language).
  bool get isUrgent =>
      this == BroadcastCategory.alert || this == BroadcastCategory.emergency;

  /// Parses the stored string; unknown / missing (incl. the legacy `'general'`
  /// default) → [announcement].
  static BroadcastCategory fromString(String? raw) => switch (raw) {
        'alert' => BroadcastCategory.alert,
        'reminder' => BroadcastCategory.reminder,
        'emergency' => BroadcastCategory.emergency,
        _ => BroadcastCategory.announcement,
      };
}
