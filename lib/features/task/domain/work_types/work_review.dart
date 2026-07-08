/// How a completed piece of work should be routed for review.
///
/// Every work type still passes through a human decision — the deployed
/// `firestore.rules` allow only a manager/admin to set the terminal `approved`
/// state, so nothing self-approves client-side. What varies per type is the
/// *disposition*: a piece of work that already reconciles (an inventory count
/// with zero variance, an inspection with no failures, a within-budget errand)
/// is surfaced as one-tap **auto-approvable** and sorted to the top of the
/// queue — the "manager fast-path" — instead of demanding the same scrutiny as
/// a mismatch. This is a domain signal the review UI reads; it never bypasses
/// the security gate.
enum ReviewDisposition {
  /// Needs a normal human decision.
  standard,

  /// Everything checks out — flag as "auto-approvable ✓" and float to the top
  /// for one-tap approval.
  fastTrack;

  bool get isFastTrack => this == ReviewDisposition.fastTrack;
}
