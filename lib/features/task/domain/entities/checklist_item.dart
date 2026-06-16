import 'package:freezed_annotation/freezed_annotation.dart';

part 'checklist_item.freezed.dart';

/// A single checklist line on a **task** (Phase 9). When a task is created from a
/// checklist template, one of these is generated per template item; the
/// executing employee ticks them off as they go.
///
/// A task cannot be marked completed until every [isRequired] item is
/// [completed] (enforced in `TaskCubit.completeTask`).
@freezed
class ChecklistItem with _$ChecklistItem {
  const factory ChecklistItem({
    required String id,
    required String title,
    @Default(true) bool isRequired,
    @Default(false) bool completed,
    DateTime? completedAt,
  }) = _ChecklistItem;
}

/// A single checklist line on a **template** (Phase 9). Templates are reusable
/// checklists ("Open Shop", "Close Shop"); each item is just a [title] + whether
/// it is [isRequired]. Instantiated into a [ChecklistItem] via [toTaskItem] when
/// a task is created from the template.
@freezed
class ChecklistItemTemplate with _$ChecklistItemTemplate {
  const ChecklistItemTemplate._();

  const factory ChecklistItemTemplate({
    required String id,
    required String title,
    @Default(true) bool isRequired,
  }) = _ChecklistItemTemplate;

  /// Creates the task-level (uncompleted) checklist item for this template line.
  ChecklistItem toTaskItem() =>
      ChecklistItem(id: id, title: title, isRequired: isRequired);
}
