import 'package:flutter/material.dart';
import 'package:fbro/features/task/presentation/widgets/manager_tasks_view.dart';

/// Manager task screen (Phase 4). Create, assign, edit, delete and review tasks
/// for the manager's **own branch only** (the branch is fixed to the manager's;
/// access enforced by `firestore.rules`). Backed by [ManagerTasksView] +
/// `TaskCubit`.
class BranchTasksScreen extends StatelessWidget {
  const BranchTasksScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ManagerTasksView(title: 'Branch Tasks', isAdmin: false);
}
