import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';

/// A clean, monochrome search field used across the admin module.
///
/// Built as a single rounded surface that fully **neutralises** the global
/// [InputDecorationTheme] (no inherited fill, border, or 18px padding) so it
/// renders as ONE crisp box — not a field-inside-a-field. The border and leading
/// magnifier brighten on focus, and a circular clear button appears when there's
/// text. Black / white / grey only.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChange);
  bool _hasText = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus != _focused) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  void _onChanged(String v) {
    final has = v.isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _focused ? AppColors.textSecondary : AppColors.textTertiary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused ? AppColors.textSecondary : AppColors.darkBorder,
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              cursorColor: AppColors.textPrimary,
              cursorWidth: 1.5,
              style: AppTypography.body
                  .copyWith(color: AppColors.textPrimary, fontSize: 15),
              // Fully neutralise the global InputDecorationTheme so the field
              // doesn't draw its own fill/border/padding inside this surface.
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: widget.hint,
                hintStyle: AppTypography.body
                    .copyWith(color: AppColors.textTertiary, fontSize: 15),
              ),
            ),
          ),
          if (_hasText) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                _controller.clear();
                _onChanged('');
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.darkSurfaceElevated,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
