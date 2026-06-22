/// Who a broadcast (Communications Center) is addressed to.
///
/// - [allBranches] — an org-wide announcement to **every user**, visible to
///   every signed-in user. Only an admin may send one. Stored with an empty
///   `branchId` sentinel.
/// - [branch] — scoped to a single store branch (its manager + employees + any
///   admin). Stored with that branch's `branchId`.
/// - [user] — a direct message to one individual (Phase 2). Stored with a
///   non-branch `branchId` marker + the recipient's `targetUserId`, so it never
///   surfaces in a branch / all feed and is readable only by the recipient + an
///   admin.
///
/// The audience is the human-facing intent; the queryable dimension for the
/// branch/all feed is the broadcast's `branchId` (`''` for [allBranches]), so
/// reads stay index-free and provably safe under `firestore.rules` (a
/// `whereIn: [branch, '']` query).
enum BroadcastAudience {
  allBranches,
  branch,
  user;

  /// The string persisted in Firestore (`broadcasts/{id}.audience`).
  String get value => name;

  /// Capitalized label for the UI.
  String get label => switch (this) {
        BroadcastAudience.allBranches => 'All branches',
        BroadcastAudience.branch => 'Branch',
        BroadcastAudience.user => 'Individual',
      };

  bool get isAllBranches => this == BroadcastAudience.allBranches;
  bool get isBranch => this == BroadcastAudience.branch;
  bool get isUser => this == BroadcastAudience.user;

  /// Parses the stored string; unknown / missing → [allBranches] (the widest,
  /// least-surprising default for a legacy or malformed document).
  static BroadcastAudience fromString(String? raw) => switch (raw) {
        'branch' => BroadcastAudience.branch,
        'user' => BroadcastAudience.user,
        _ => BroadcastAudience.allBranches,
      };
}
