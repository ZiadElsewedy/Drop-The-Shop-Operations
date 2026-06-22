import 'package:flutter_test/flutter_test.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/presentation/widgets/task_badge.dart';

/// Verifies the task lifecycle badge mapping (Notification System Phase 1 —
/// Part 5): NEW (monochrome) · REWORK #n (amber) · Rejected (red) · Approved
/// (green), with the documented precedence.
void main() {
  group('taskBadgeFor', () {
    test('a fresh pending task → NEW (monochrome)', () {
      final badge = taskBadgeFor(const TaskEntity(id: '1', title: 't'));
      expect(badge?.label, 'NEW');
      expect(badge?.color, AppColors.primary);
    });

    test('a task awaiting rework → REWORK #n (amber), with the revision number',
        () {
      final badge = taskBadgeFor(const TaskEntity(
        id: '1',
        title: 't',
        status: TaskStatus.rejected,
        requiresRework: true,
        revisionNumber: 2,
      ));
      expect(badge?.label, 'REWORK #2');
      expect(badge?.color, AppColors.warning);
    });

    test('a terminally rejected task → Rejected (red)', () {
      final badge = taskBadgeFor(const TaskEntity(
        id: '1',
        title: 't',
        status: TaskStatus.rejected,
        // requiresRework stays false → terminal reject, not rework.
      ));
      expect(badge?.label, 'Rejected');
      expect(badge?.color, AppColors.error);
    });

    test('an approved task → Approved (green)', () {
      final badge = taskBadgeFor(const TaskEntity(
        id: '1',
        title: 't',
        status: TaskStatus.approved,
      ));
      expect(badge?.label, 'Approved');
      expect(badge?.color, AppColors.success);
    });

    test('rework outranks the rejected status (precedence)', () {
      final badge = taskBadgeFor(const TaskEntity(
        id: '1',
        title: 't',
        status: TaskStatus.rejected,
        requiresRework: true,
        revisionNumber: 1,
      ));
      expect(badge?.label, 'REWORK #1');
    });

    test('an in-progress task has no badge', () {
      expect(
        taskBadgeFor(const TaskEntity(
            id: '1', title: 't', status: TaskStatus.started)),
        isNull,
      );
    });
  });
}
