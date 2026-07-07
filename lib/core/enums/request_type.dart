/// A predefined operations-request category — the *kind* of approval being
/// asked for. Kept intentionally lightweight: a type is just a label + a short
/// blurb + an icon (icons live in the presentation `request_format.dart` so this
/// enum stays Flutter-free and unit-testable). Every type collects the same one
/// thing — a short message/reason — so adding a type is a single enum value, no
/// schema, no rules change.
enum RequestType {
  employeeDiscount,
  leaveStore,
  giftApproval,
  stockRequest,
  maintenance,
  customerIssue,
  cashRequest,
  equipmentRequest,
  branchSupport,
  other;

  String get value => name;

  String get label => switch (this) {
        RequestType.employeeDiscount => 'Employee Discount',
        RequestType.leaveStore => 'Leave Store',
        RequestType.giftApproval => 'Gift Approval',
        RequestType.stockRequest => 'Stock Request',
        RequestType.maintenance => 'Maintenance',
        RequestType.customerIssue => 'Customer Issue',
        RequestType.cashRequest => 'Cash Request',
        RequestType.equipmentRequest => 'Equipment Request',
        RequestType.branchSupport => 'Branch Support',
        RequestType.other => 'Other',
      };

  /// A short one-line helper shown under the type in the picker.
  String get blurb => switch (this) {
        RequestType.employeeDiscount => 'Use your staff discount on a purchase',
        RequestType.leaveStore => 'Step out of the store during your shift',
        RequestType.giftApproval => 'Give a customer a complimentary gift',
        RequestType.stockRequest => 'Pull stock from another branch',
        RequestType.maintenance => 'Report something broken or unsafe',
        RequestType.customerIssue => 'Get your manager\'s help with a customer',
        RequestType.cashRequest => 'Ask for a cash float or change',
        RequestType.equipmentRequest => 'Ask for a tool or device',
        RequestType.branchSupport => 'Ask another branch for help or cover',
        RequestType.other => 'Anything else that needs a manager\'s OK',
      };

  /// Parses the stored string; unknown/missing → [other] (the neutral catch-all).
  static RequestType fromString(String? raw) {
    for (final t in RequestType.values) {
      if (t.name == raw) return t;
    }
    return RequestType.other;
  }
}
