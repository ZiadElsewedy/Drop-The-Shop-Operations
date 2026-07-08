/// The **create-time** counterpart of `WorkContext`: what a work type needs to
/// validate a manager/admin's draft *before* the task exists. Kept separate from
/// `WorkContext` (which describes a live task being executed) so setup rules and
/// completion rules can't accidentally read each other's shape.
///
/// Carries the captured dynamic [data] plus the couple of structural facts a
/// setup rule may depend on (an inspection needs at least one checklist point;
/// a future type might require an assignee). Flutter-free + trivially built in a
/// test.
class WorkDraft {
  /// Values captured for the type's dynamic [WorkFieldSpec] fields.
  final Map<String, dynamic> data;

  /// How many generic checklist items the creator has added (inspection points
  /// reuse the checklist).
  final int checklistCount;

  final int assigneeCount;

  const WorkDraft({
    this.data = const {},
    this.checklistCount = 0,
    this.assigneeCount = 0,
  });
}
