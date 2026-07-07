/// A named **milestone** in a work type's lifecycle, layered *on top of* the
/// coarse generic [TaskStatus] machine rather than replacing it.
///
/// The insight that keeps this Open/Closed: the core status machine
/// (`pending → started → completed → waitingReview → approved|rejected`) stays
/// fixed and rules-enforced, while each work type declares its own fine-grained
/// milestones. A milestone is recorded as an ordinary `ActivityEntry` whose
/// `status` string equals the [id] — so the existing generic activity log +
/// timeline render it with **no core-enum change and no new collection**. A
/// type that needs none simply declares an empty [WorkTypeDefinition.timeline].
///
/// Pure data (Flutter-free); presentation maps a milestone to an icon/label.
class WorkEvent {
  /// Stable machine id, stored as `ActivityEntry.status`. Must not collide with
  /// a core [TaskStatus] value (they share the same string column).
  final String id;

  /// Human label for the milestone ("Dispatched", "Received").
  final String label;

  /// A one-line hint about who performs it / what it means, shown on the spine.
  final String? actorHint;

  /// Whether logging this milestone requires proof media (e.g. a handover photo
  /// or a receipt). Read by a definition's submission gate.
  final bool requiresProof;

  const WorkEvent({
    required this.id,
    required this.label,
    this.actorHint,
    this.requiresProof = false,
  });
}
