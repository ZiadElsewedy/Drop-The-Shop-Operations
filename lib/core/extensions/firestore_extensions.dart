import 'package:cloud_firestore/cloud_firestore.dart';

/// Mapping helpers for Firestore document maps, shared by every `*Model.fromMap`.
///
/// Centralises the `(map['field'] as Timestamp?)?.toDate()` boilerplate that was
/// repeated ~17 times across the models (and a per-file `ts()` helper) into one
/// place. Pure read helper — same behaviour, just not copy-pasted.
extension FirestoreMapX on Map<String, dynamic> {
  /// Reads [key] as a [DateTime], or `null` when it is absent or not a
  /// Firestore [Timestamp].
  DateTime? date(String key) {
    final value = this[key];
    return value is Timestamp ? value.toDate() : null;
  }
}
