/// The kind of a broadcast (Communications Center — Phase 3). Stored as a string
/// in `broadcasts/{id}.category` and carried in the FCM `data` payload so the
/// client can route / group / style the notification.
///
/// Pure Dart (no Flutter) like every `core/enums` value — the icon/colour mapping
/// lives in the presentation layer (`communications_format.dart`).
enum BroadcastCategory {
  announcement,
  reminder,
  emergency;

  /// The string persisted in Firestore / sent in the push payload.
  String get value => name;

  /// Capitalized label for the UI.
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';

  /// Whether this category should read with an attention colour (status-only
  /// colour, per the monochrome design language).
  bool get isUrgent => this == BroadcastCategory.emergency;

  // ── Delivery is derived from the category (2026-06-24) — there is no separate
  // priority / channel dial. Announcement = quiet inbox-only; reminder + emergency
  // push; emergency rides at high FCM priority. The Cloud Function mirrors this.

  /// Whether a send of this category fires an FCM push (announcement is
  /// inbox-only). Mirrored by the `dispatchBroadcast` Cloud Function.
  bool get sendsPush => this != BroadcastCategory.announcement;

  /// Whether the push rides at **high** FCM priority — emergency only.
  bool get isHighPriority => this == BroadcastCategory.emergency;

  /// A short delivery summary for the composer preview.
  String get deliverySummary => switch (this) {
        BroadcastCategory.announcement => 'Inbox only',
        BroadcastCategory.reminder => 'Push + Inbox',
        BroadcastCategory.emergency => 'Push + Inbox · High priority',
      };

  /// Parses the stored string; unknown / missing (incl. the legacy `'general'`
  /// and the retired `'alert'` value) → [announcement].
  static BroadcastCategory fromString(String? raw) => switch (raw) {
        'reminder' => BroadcastCategory.reminder,
        'emergency' => BroadcastCategory.emergency,
        _ => BroadcastCategory.announcement,
      };
}
