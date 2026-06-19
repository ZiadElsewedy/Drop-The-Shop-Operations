/// Approval lifecycle for a user account. DROP is an internal operations system,
/// so a brand-new self-registration is **not** allowed straight in: it starts
/// [pending] (and inactive) and is confined to the Pending Approval screen until
/// a manager/admin approves it (sets it [approved] + active, assigns role/branch).
///
/// Stored as a string in `users/{uid}.approvalStatus`.
///
/// [fromString] defaults unknown/missing values to [approved] so that user
/// documents created BEFORE the approval system existed keep working — only
/// brand-new accounts are explicitly seeded [pending]. An account can never
/// self-elevate to [approved]: `firestore.rules` requires self-registration to
/// be `pending` + `isActive == false`, and only an admin/own-branch manager may
/// flip it.
enum ApprovalStatus {
  pending,
  approved,
  rejected;

  /// The string persisted in Firestore (`users/{uid}.approvalStatus`).
  String get value => name;

  bool get isPending => this == ApprovalStatus.pending;
  bool get isApproved => this == ApprovalStatus.approved;
  bool get isRejected => this == ApprovalStatus.rejected;

  /// Parses the stored Firestore string. Unknown/missing → [approved] so legacy
  /// documents (predating the approval system) are never accidentally locked out.
  static ApprovalStatus fromString(String? raw) {
    switch (raw) {
      case 'pending':
        return ApprovalStatus.pending;
      case 'rejected':
        return ApprovalStatus.rejected;
      case 'approved':
      default:
        return ApprovalStatus.approved;
    }
  }
}
