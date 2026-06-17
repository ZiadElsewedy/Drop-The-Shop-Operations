import 'package:flutter_test/flutter_test.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/features/auth/data/models/user_model.dart';

/// Stability regression: `UserModel.fromMap` must never throw on a malformed or
/// partial `users/{uid}` document. A single bad doc used to crash an entire
/// user-list load (schedule team, assignee picker, admin lists) because `uid`
/// and `email` were cast to non-null `String`.
void main() {
  group('UserModel.fromMap is crash-proof', () {
    test('a phone-auth doc with no email parses (email → "")', () {
      final model = UserModel.fromMap({
        'uid': 'abc123',
        'phoneNumber': '+201000000000',
        'authProvider': 'phone',
      });
      expect(model.uid, 'abc123');
      expect(model.email, '');
    });

    test('an empty / totally malformed doc does not throw', () {
      expect(() => UserModel.fromMap(const {}), returnsNormally);
      final model = UserModel.fromMap(const {});
      expect(model.uid, '');
      expect(model.email, '');
      // Safe role/approval defaults still apply so access can never escalate.
      expect(model.role, UserRole.employee);
      expect(model.isActive, isTrue);
    });

    test('a well-formed doc still maps every field', () {
      final model = UserModel.fromMap({
        'uid': 'u1',
        'email': 'a@b.com',
        'displayName': 'Ada',
        'role': 'manager',
        'branchId': 'branch-1',
        'isActive': true,
        'approvalStatus': 'approved',
      });
      expect(model.uid, 'u1');
      expect(model.email, 'a@b.com');
      expect(model.displayName, 'Ada');
      expect(model.role, UserRole.manager);
      expect(model.branchId, 'branch-1');
    });
  });
}
