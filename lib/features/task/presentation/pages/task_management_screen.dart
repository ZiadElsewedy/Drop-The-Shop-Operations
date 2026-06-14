import 'package:flutter/material.dart';
import 'package:fbro/features/task/presentation/widgets/manager_tasks_view.dart';

/// Admin task screen (Phase 4). Global: create, assign, edit, delete and review
/// tasks across **all branches** (admin sets the branch on create). Backed by
/// [ManagerTasksView] + `TaskCubit`.
class TaskManagementScreen extends StatelessWidget {
  const TaskManagementScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ManagerTasksView(title: 'Task Management', isAdmin: true);
}
