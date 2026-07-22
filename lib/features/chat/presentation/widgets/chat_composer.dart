import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';

/// The message composer pinned at the bottom of a chat thread — the
/// [CaseComposer] minus attachments (a later phase). Text only.
///
/// [onSend] returns whether the send **succeeded**: the composer only clears
/// the input on success, so a failed send never silently loses what the user
/// typed (Cases convention — and the cubit reuses the idempotency key on an
/// identical retry). Focus returns to the field after a successful send, so
/// consecutive replies flow without re-tapping.
///
/// Desktop: the field autofocuses on mount and Enter sends (Shift+Enter →
/// newline). Mobile keeps the keyboard down until the user taps the field —
/// auto-popping it over the thread would hide the history they opened to read.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.sending,
  });

  final Future<bool> Function(String text) onSend;
  final bool sending;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  late final FocusNode _node = FocusNode(onKeyEvent: _handleKey);

  /// Desktop only: Enter sends, Shift+Enter inserts a newline. Recomputed each
  /// build from the layout width.
  bool _enterToSend = false;
  bool _autofocused = false;

  @override
  void dispose() {
    _controller.dispose();
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (_enterToSend &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (widget.sending || text.isEmpty) return;
    // Keep the text until the send resolves — only clear on success, so a
    // network failure lets the user retry, not retype.
    final ok = await widget.onSend(text);
    if (!mounted || !ok) return;
    _controller.clear();
    // Keep the keyboard/caret ready for the next message.
    _node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    _enterToSend = context.isDesktop;
    if (_enterToSend && !_autofocused) {
      _autofocused = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _node.requestFocus();
      });
    }
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.sm,
          AppSpacing.pagePadding, AppSpacing.sm + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceElevated,
                borderRadius: AppRadius.xlAll,
                border: Border.all(color: AppColors.darkBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextField(
                controller: _controller,
                focusNode: _node,
                minLines: 1,
                maxLines: 5,
                style: AppTypography.body,
                keyboardType: TextInputType.multiline,
                textInputAction: _enterToSend
                    ? TextInputAction.newline
                    : TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Write a message…',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: _enterToSend ? null : (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.sending ? null : _send,
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: widget.sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary))
                    : const Icon(Icons.arrow_upward_rounded,
                        color: AppColors.onPrimary, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
