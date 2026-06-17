import 'package:flutter/material.dart';
import 'package:fbro/core/widgets/app_empty_state.dart';

/// Centered empty placeholder for a task list. Thin alias over the shared
/// [AppEmptyState] — kept for its existing call sites and task-list semantics.
class TaskEmptyState extends StatelessWidget {
  const TaskEmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) =>
      AppEmptyState(icon: icon, message: message);
}
