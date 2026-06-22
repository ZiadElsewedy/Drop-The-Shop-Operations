/// The delivery urgency of a broadcast (Communications Center — Phase 2).
///
/// Distinct from [BroadcastCategory] (the semantic *kind* — announcement /
/// alert / reminder / emergency): priority drives **delivery behaviour** — the
/// FCM push priority, the UI emphasis, and (later) the quiet-hours bypass. A
/// "reminder" can be `high`, an "announcement" can be `low`; the two axes are
/// orthogonal.
///
/// Stored as a string in `broadcasts/{id}.priority` and carried in the FCM
/// `data` payload. Pure Dart (no Flutter) like every `core/enums` value — the
/// icon/colour mapping lives in the presentation layer.
enum BroadcastPriority {
  low,
  normal,
  high,
  emergency;

  /// The string persisted in Firestore / sent in the push payload.
  String get value => name;

  /// Capitalized label for the UI.
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';

  /// Whether this priority should ride at **high** FCM priority (`high` +
  /// `emergency`) — mirrored by the `sendBroadcast` Cloud Function.
  bool get isHighDelivery =>
      this == BroadcastPriority.high || this == BroadcastPriority.emergency;

  /// Whether this priority warrants the strongest UI treatment (accent border /
  /// banner) — `emergency` only.
  bool get isEmergency => this == BroadcastPriority.emergency;

  /// Parses the stored string; unknown / missing → [normal] (the safe default
  /// for a legacy or malformed document).
  static BroadcastPriority fromString(String? raw) => switch (raw) {
        'low' => BroadcastPriority.low,
        'high' => BroadcastPriority.high,
        'emergency' => BroadcastPriority.emergency,
        _ => BroadcastPriority.normal,
      };
}
