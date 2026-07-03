import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Lightweight product telemetry for the homepage feed (Home Dashboard
/// redesign). Records **counter** events (preset usage, sort mode, expansion
/// opens, quick approvals, note creation) so we can compare real usage before
/// investing in more ranking complexity.
///
/// Design goals — deliberately minimal:
///  * **One aggregate doc** `usageStats/feed` of `FieldValue.increment` counters
///    (no per-event document explosion, nothing to query-index).
///  * **Debounced flush** — events accumulate in memory and flush at most once
///    per [_flushEvery], so a burst of expansions is a single write (avoids the
///    ~1 write/sec single-doc contention limit).
///  * **Best-effort** — failures are swallowed; telemetry never affects the UI.
///  * **Test-safe** — a no-op until [init] is called (so widget tests that
///    trigger tracked actions don't leave a pending timer or hit Firestore).
class UsageTracker {
  UsageTracker._();

  static FirebaseFirestore? _db;
  static final Map<String, int> _pending = {};
  static Timer? _timer;
  static const _flushEvery = Duration(seconds: 20);

  /// Wire the Firestore sink once at startup. Until this is called, [track] is a
  /// no-op.
  static void init(FirebaseFirestore db) => _db = db;

  /// Records one occurrence of [event] (a stable snake_case key, e.g.
  /// `preset_overdue`, `sort_smart`, `expansion_open`, `quick_approve`,
  /// `note_create`). Cheap: increments an in-memory counter + schedules a flush.
  static void track(String event) {
    if (_db == null) return; // not initialized (tests) → no-op, no timer
    _pending.update(event, (v) => v + 1, ifAbsent: () => 1);
    _timer ??= Timer(_flushEvery, _flush);
  }

  static Future<void> _flush() async {
    _timer = null;
    final db = _db;
    if (db == null || _pending.isEmpty) return;
    final batch = Map<String, int>.from(_pending);
    _pending.clear();
    final data = <String, Object>{
      for (final e in batch.entries) e.key: FieldValue.increment(e.value),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      await db
          .collection('usageStats')
          .doc('feed')
          .set(data, SetOptions(merge: true));
    } catch (_) {
      // Best-effort telemetry — never surface to the UI.
    }
  }
}
