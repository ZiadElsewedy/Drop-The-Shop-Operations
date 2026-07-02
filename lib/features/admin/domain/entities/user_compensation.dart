/// The private compensation record for one user (C2 fix, 2026-07-03) —
/// stored at `users/{uid}/private/compensation`, **never** on the
/// branch-readable `users/{uid}` doc (Firestore reads are document-level, so
/// anything on the parent doc is served whole to every same-branch member).
///
/// A **plain immutable value object** (not freezed) — mirrors the `SwapPolicy`
/// precedent, avoiding generated-file drift for a four-field record. Loaded
/// **on demand** (admin Details/Edit-Info/inspector, the owner's own profile);
/// the public user fetch never touches it.
class UserCompensation {
  /// Admin-managed salary amount (per [salaryType] period).
  final double? salaryAmount;

  /// `monthly` / `weekly` / `daily`.
  final String? salaryType;

  /// `cash` / `bank` / `wallet` / `instapay`.
  final String? paymentMethod;

  /// The employee's own salary-receiving number — the ONE field the owner may
  /// write themselves (Edit Profile), enforced by the subdocument rules.
  final String? paymentNumber;

  const UserCompensation({
    this.salaryAmount,
    this.salaryType,
    this.paymentMethod,
    this.paymentNumber,
  });

  static const UserCompensation empty = UserCompensation();

  bool get isEmpty =>
      salaryAmount == null &&
      (salaryType ?? '').isEmpty &&
      (paymentMethod ?? '').isEmpty &&
      (paymentNumber ?? '').isEmpty;

  /// Parses a compensation map — the subdocument's data, or (during the
  /// migration window) the same four legacy keys off a `users/{uid}` doc map.
  factory UserCompensation.fromMap(Map<String, dynamic>? map) {
    if (map == null) return empty;
    String? str(dynamic v) {
      final s = (v as String?)?.trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return UserCompensation(
      salaryAmount: (map['salaryAmount'] as num?)?.toDouble(),
      salaryType: str(map['salaryType']),
      paymentMethod: str(map['paymentMethod']),
      paymentNumber: str(map['paymentNumber']),
    );
  }

  /// The full subdocument payload. All four keys written unconditionally —
  /// null clears (an emptied admin-sheet input must remove the stale value).
  Map<String, dynamic> toMap() => {
        'salaryAmount': salaryAmount,
        'salaryType': salaryType,
        'paymentMethod': paymentMethod,
        'paymentNumber': paymentNumber,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserCompensation &&
          other.salaryAmount == salaryAmount &&
          other.salaryType == salaryType &&
          other.paymentMethod == paymentMethod &&
          other.paymentNumber == paymentNumber);

  @override
  int get hashCode =>
      Object.hash(salaryAmount, salaryType, paymentMethod, paymentNumber);

  @override
  String toString() =>
      'UserCompensation(salaryAmount: $salaryAmount, salaryType: $salaryType, '
      'paymentMethod: $paymentMethod, paymentNumber: $paymentNumber)';
}
