import 'package:flutter/material.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_bottom_nav.dart' show AppNavItem;
import 'package:drop/core/widgets/drop_wordmark.dart';

/// Premium persistent left navigation for the desktop / macOS layout.
///
/// This is the native-desktop counterpart to [AppBottomNav]: instead of a
/// stretched mobile tab bar, wide windows get a quiet, Linear/Notion-style
/// vertical rail with the DROP wordmark, hover-reactive destinations, a clear
/// active state (accent pill + leading bar), and a pinned footer for the
/// signed-in user. Strictly monochrome to match the design system.
///
/// Stateless: the host ([RoleScaffold]) owns [currentIndex] and routes taps,
/// exactly like the bottom nav — so navigation semantics are unchanged.
class DesktopNavSidebar extends StatelessWidget {
  const DesktopNavSidebar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.footer,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Pinned to the bottom of the rail (typically the user avatar + name).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Breakpoints.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(right: BorderSide(color: AppColors.darkBorder)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand header.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Row(
                children: [
                  const DropWordmark(fontSize: 24),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'OPERATIONS',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Destinations.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var i = 0; i < items.length; i++)
                    _SidebarItem(
                      item: items[i],
                      selected: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                ],
              ),
            ),
            if (footer != null) ...[
              const Divider(height: 1, color: AppColors.darkBorder),
              Padding(
                padding: const EdgeInsets.all(12),
                child: footer,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single hover-reactive destination row.
class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final Color fg = selected
        ? AppColors.primary
        : (_hovered ? AppColors.textPrimary : AppColors.textSecondary);
    final Color bg = selected
        ? AppColors.primarySurface
        : (_hovered ? const Color(0x12FFFFFF) : AppColors.transparent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Leading active bar.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  height: selected ? 18 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 9),
                Icon(
                  selected ? widget.item.activeIcon : widget.item.icon,
                  size: 20,
                  color: fg,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.item.label,
                  style: AppTypography.label.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
