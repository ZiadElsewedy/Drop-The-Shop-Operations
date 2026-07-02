import 'package:flutter/material.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_context_menu.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';

/// Payload carried while dragging an [AssignmentChip] between grid cells:
/// who is being moved and which slot they came from.
class ChipDragData {
  const ChipDragData({
    required this.uid,
    required this.day,
    required this.shift,
  });

  final String uid;
  final ScheduleDay day;
  final ScheduleShift shift;
}

/// One person on a shift — the atomic unit of the schedule grid. Each chip is
/// a click target (cell details), a drag handle (desktop: move between slots),
/// a context-menu anchor (right-click on desktop, long-press on touch), and —
/// when [onSwapDrop] is set — a **drop target**: dropping another person onto
/// this chip trades their slots (drag Ziad onto Richard → they switch shifts).
/// A double-booked person carries a red hairline + dot; strictly monochrome
/// otherwise.
class AssignmentChip extends StatefulWidget {
  const AssignmentChip({
    super.key,
    required this.user,
    required this.day,
    required this.shift,
    this.conflicted = false,
    this.canEdit = false,
    this.canMoveToOpposite = true,
    this.onRemove,
    this.onMoveToOpposite,
    this.onSwapDrop,
    this.onOpenActions,
    this.onSwapWith,
  });

  final UserEntity user;
  final ScheduleDay day;
  final ScheduleShift shift;

  /// This person is on both shifts of this day (double-booked).
  final bool conflicted;

  final bool canEdit;

  /// False when the opposite shift already contains this person — the move
  /// action shows disabled instead of silently double-booking them.
  final bool canMoveToOpposite;

  final VoidCallback? onRemove;
  final VoidCallback? onMoveToOpposite;

  /// Another chip was dropped onto this one (desktop): trade the two slots.
  /// The payload is the dragged person; this chip's (user, day, shift) is the
  /// other side of the exchange.
  final void Function(ChipDragData data)? onSwapDrop;

  /// Touch long-press → the premium action sheet (move · switch · remove).
  /// When set, it replaces the bare context menu on mobile (Schedule 4.0).
  final VoidCallback? onOpenActions;

  /// Desktop context-menu "Switch shifts with…" — the guided switch flow for
  /// people who don't discover chip-onto-chip drag.
  final VoidCallback? onSwapWith;

  @override
  State<AssignmentChip> createState() => _AssignmentChipState();
}

class _AssignmentChipState extends State<AssignmentChip> {
  bool _hovered = false;

  void _showMenu(Offset globalPosition) {
    final opposite = widget.shift.opposite;
    showAppContextMenu(
      context: context,
      position: globalPosition,
      items: [
        AppContextMenuItem(
          icon: opposite == ScheduleShift.morning
              ? Icons.wb_sunny_rounded
              : Icons.nightlight_round,
          label: 'Move to ${opposite.label.toLowerCase()}',
          enabled: widget.canMoveToOpposite,
          onSelected: widget.onMoveToOpposite,
        ),
        if (widget.onSwapWith != null)
          AppContextMenuItem(
            icon: Icons.swap_horiz_rounded,
            label: 'Switch shifts with…',
            onSelected: widget.onSwapWith,
          ),
        AppContextMenuItem(
          icon: Icons.person_remove_outlined,
          label: 'Remove from shift',
          destructive: true,
          onSelected: widget.onRemove,
        ),
      ],
    );
  }

  Widget _visual(
      {required bool hovered, bool dragging = false, bool swapTarget = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(3, 3, 8, 3),
      decoration: BoxDecoration(
        color: hovered || dragging || swapTarget
            ? const Color(0xFF232327)
            : AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: swapTarget
              ? AppColors.primary
              : widget.conflicted
                  ? AppColors.error.withAlpha(190)
                  : hovered
                      ? AppColors.accentBorder
                      : AppColors.darkBorder,
          width: swapTarget ? 1.4 : 1,
        ),
        boxShadow: dragging
            ? [
                BoxShadow(
                  color: AppColors.black.withAlpha(120),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar.fromUser(widget.user, size: 17),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              shortName(widget.user),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
          // Hovering a dragged person over this chip → "drop to switch" cue.
          if (swapTarget) ...[
            const SizedBox(width: 5),
            const Icon(Icons.swap_horiz_rounded,
                size: 12, color: AppColors.primary),
          ] else if (widget.conflicted) ...[
            const SizedBox(width: 5),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;

    Widget content({bool swapTarget = false}) => MouseRegion(
          cursor: widget.canEdit && isDesktop
              ? SystemMouseCursors.grab
              : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onSecondaryTapDown:
                widget.canEdit ? (d) => _showMenu(d.globalPosition) : null,
            // Touch: long-press opens the premium action sheet (move · switch
            // · remove, Schedule 4.0); the bare context menu remains only as
            // a fallback when no sheet callback is wired.
            onLongPressStart: widget.canEdit && !isDesktop
                ? (d) => widget.onOpenActions != null
                    ? widget.onOpenActions!()
                    : _showMenu(d.globalPosition)
                : null,
            child: _visual(hovered: _hovered, swapTarget: swapTarget),
          ),
        );

    Widget chip = content();

    // Person-onto-person drop = trade slots. The chip target sits INSIDE the
    // cell's DragTarget, so it wins the hit test when hovered directly; the
    // cell's empty space still means "move here".
    if (widget.canEdit && isDesktop && widget.onSwapDrop != null) {
      chip = DragTarget<ChipDragData>(
        onWillAcceptWithDetails: (d) =>
            d.data.uid != widget.user.uid &&
            // Trading places inside the SAME slot changes nothing — reject so
            // the drop doesn't pretend to do something.
            !(d.data.day == widget.day && d.data.shift == widget.shift),
        onAcceptWithDetails: (d) => widget.onSwapDrop!(d.data),
        builder: (context, candidates, _) =>
            content(swapTarget: candidates.isNotEmpty),
      );
    }

    // Drag-to-move is a desktop affordance; on touch the cell sheet handles
    // assignment, so chips stay plain tappable content there.
    if (widget.canEdit && isDesktop) {
      chip = Draggable<ChipDragData>(
        data: ChipDragData(
            uid: widget.user.uid, day: widget.day, shift: widget.shift),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(
            scale: 1.06,
            child: _visual(hovered: false, dragging: true),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: chip),
        child: chip,
      );
    }
    return chip;
  }
}
