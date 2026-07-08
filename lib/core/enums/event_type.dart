/// The *kind* of DROP event — a Collection Launch, a Pop-up, a Community
/// Gathering, an internal Training… Each event in the Community Hub is one of
/// these. Deliberately Flutter-free (icons + accent live in the presentation
/// `event_format.dart`) so the enum stays pure and unit-testable. Adding a new
/// kind of event is a single enum value — no schema, no rules change.
///
/// The list spans DROP's two worlds: **outward** brand/community experiences
/// (launches, collabs, pop-ups, VIP nights) and **inward** operations
/// (training, team building, warehouse sales, branch openings).
enum EventType {
  collectionLaunch,
  brandCollab,
  popUp,
  communityGathering,
  creatorMeet,
  branchOpening,
  warehouseSale,
  internalTraining,
  teamBuilding,
  seasonalCampaign,
  vipEvent,
  other;

  String get value => name;

  String get label => switch (this) {
        EventType.collectionLaunch => 'Collection Launch',
        EventType.brandCollab => 'Brand Collaboration',
        EventType.popUp => 'Pop-up Store',
        EventType.communityGathering => 'Community Gathering',
        EventType.creatorMeet => 'Creator Meet & Greet',
        EventType.branchOpening => 'Branch Opening',
        EventType.warehouseSale => 'Warehouse Sale',
        EventType.internalTraining => 'Internal Training',
        EventType.teamBuilding => 'Team Building',
        EventType.seasonalCampaign => 'Seasonal Campaign',
        EventType.vipEvent => 'VIP Event',
        EventType.other => 'Event',
      };

  /// A short one-line helper shown under the type in the picker.
  String get blurb => switch (this) {
        EventType.collectionLaunch => 'Debut a new drop or collection',
        EventType.brandCollab => 'A partnership moment with another brand',
        EventType.popUp => 'A temporary store or activation',
        EventType.communityGathering => 'Bring the DROP community together',
        EventType.creatorMeet => 'Host a creator for the community',
        EventType.branchOpening => 'Open a new DROP location',
        EventType.warehouseSale => 'A high-volume clearance moment',
        EventType.internalTraining => 'Level up the team',
        EventType.teamBuilding => 'Time together, off the floor',
        EventType.seasonalCampaign => 'A season-long brand campaign',
        EventType.vipEvent => 'An exclusive, invite-only night',
        EventType.other => 'Something else worth planning well',
      };

  /// Whether this event faces the **community / customers** (outward) rather
  /// than being an internal operations moment. Drives a subtle hub grouping.
  bool get isPublicFacing => switch (this) {
        EventType.internalTraining ||
        EventType.teamBuilding =>
          false,
        _ => true,
      };

  /// Parses the stored string; unknown/missing → [other] (the neutral catch-all).
  static EventType fromString(String? raw) {
    for (final t in EventType.values) {
      if (t.name == raw) return t;
    }
    return EventType.other;
  }
}
