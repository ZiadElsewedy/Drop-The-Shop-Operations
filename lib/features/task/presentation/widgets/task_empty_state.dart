import 'package:flutter/material.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';

/// Centered, **brand-led** empty placeholder for a task list (§9b) — delegates
/// to [DropEmptyState] so a cleared/empty list reads as a quiet DROP touchpoint
/// (the faded mark leads instead of a grey glyph). Full-screen empties only;
/// never a list row.
class TaskEmptyState extends StatelessWidget {
  const TaskEmptyState({super.key, required this.message, this.title});

  final String message;
  final String? title;

  @override
  Widget build(BuildContext context) =>
      DropEmptyState(title: title, message: message);
}
