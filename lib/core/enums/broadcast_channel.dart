/// Where a broadcast is delivered (Communications Center — Phase 2).
///
/// - [push] — an FCM push notification only (no persisted inbox entry beyond the
///   broadcast doc itself).
/// - [inbox] — written to each recipient's in-app Notification Center only, with
///   **no** FCM push (a quiet, in-app-only message).
/// - [both] — push **and** inbox (the default, full-reach delivery).
///
/// Stored as a string in `broadcasts/{id}.channel`. The `sendBroadcast` Cloud
/// Function reads it to decide whether to run the FCM multicast and/or write the
/// per-recipient `notifications` docs. Pure Dart (no Flutter) like every
/// `core/enums` value.
enum BroadcastChannel {
  push,
  inbox,
  both;

  /// The string persisted in Firestore / sent in the callable payload.
  String get value => name;

  /// Capitalized label for the UI.
  String get label => switch (this) {
        BroadcastChannel.push => 'Push only',
        BroadcastChannel.inbox => 'Inbox only',
        BroadcastChannel.both => 'Push + Inbox',
      };

  /// Whether a send on this channel should fire an FCM push.
  bool get sendsPush =>
      this == BroadcastChannel.push || this == BroadcastChannel.both;

  /// Whether a send on this channel should write per-recipient inbox docs.
  bool get writesInbox =>
      this == BroadcastChannel.inbox || this == BroadcastChannel.both;

  /// Parses the stored string; unknown / missing → [both] (the widest, safest
  /// default for a legacy or malformed document).
  static BroadcastChannel fromString(String? raw) => switch (raw) {
        'push' => BroadcastChannel.push,
        'inbox' => BroadcastChannel.inbox,
        _ => BroadcastChannel.both,
      };
}
