import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/presentation/chat_attachment_picker.dart';
import 'package:drop/features/chat/presentation/chat_message_preview.dart';
import 'package:drop/features/chat/presentation/widgets/chat_attachment_sheet.dart';

/// The message composer pinned at the bottom of a chat thread — a premium,
/// iMessage/Telegram-style bar: a paperclip attachment button, a generously
/// padded rounded input that grows with multiline text (1–6 lines), and a
/// circular send button that animates in only when there is something to send
/// (text or a staged attachment).
///
/// [onSend] returns whether the send was accepted; the composer clears the
/// input and any staged attachment only then, so a rejected send never loses
/// what the user prepared. With optimistic sending this returns almost
/// immediately (the network resolves on the bubble), so the bar never blocks.
///
/// Desktop: the field autofocuses on mount and Enter sends (Shift+Enter →
/// newline). Mobile keeps the keyboard down until the user taps the field.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.sending,
    this.header,
    this.attachmentSource,
  });

  /// Sends the composed message. Returns whether it was accepted.
  final Future<bool> Function(String text, ChatOutgoingAttachment? attachment)
      onSend;

  final bool sending;

  /// Optional banner rendered above the input row, inside the composer surface
  /// (e.g. the "Replying to …" preview). Null → just the input row.
  final Widget? header;

  /// Source for the paperclip button. Null → attachments are unavailable and
  /// the paperclip is hidden (e.g. in tests, or an unsupported platform).
  final ChatAttachmentSource? attachmentSource;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  late final FocusNode _node = FocusNode(onKeyEvent: _handleKey);

  bool _enterToSend = false;
  bool _autofocused = false;
  bool _picking = false;

  /// Whether the input holds focus — drives the pill's focus animation.
  bool _focused = false;

  /// The staged attachment awaiting send (preview shown above the input).
  ChatOutgoingAttachment? _pending;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted && _node.hasFocus != _focused) {
      setState(() => _focused = _node.hasFocus);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
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

  bool get _canSend =>
      !widget.sending &&
      (_controller.text.trim().isNotEmpty || _pending != null);

  Future<void> _send() async {
    final text = _controller.text.trim();
    final attachment = _pending;
    if (widget.sending || (text.isEmpty && attachment == null)) return;
    final ok = await widget.onSend(text, attachment);
    if (!mounted || !ok) return;
    _controller.clear();
    setState(() => _pending = null);
    _node.requestFocus();
  }

  Future<void> _pickAttachment() async {
    final source = widget.attachmentSource;
    if (source == null || _picking) return;
    final choice = await showChatAttachmentSheet(context);
    if (choice == null || !mounted) return;
    setState(() => _picking = true);
    try {
      final picked = switch (choice) {
        ChatAttachmentChoice.camera => await source.pickCameraImage(),
        ChatAttachmentChoice.gallery => await source.pickGalleryImage(),
        ChatAttachmentChoice.document => await source.pickDocument(),
      };
      if (picked != null && mounted) setState(() => _pending = picked);
    } on UnsupportedAttachmentException catch (e) {
      if (mounted) context.showError(e.message);
    } catch (_) {
      if (mounted) context.showError('Could not attach that file.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
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
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 8 + safeBottom),
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        border: Border(top: BorderSide(color: AppColors.darkBorder, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply banner + staged-attachment preview animate in above the row
          // and share the composer surface so they read as one control.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.header ?? const SizedBox(width: double.infinity),
                if (_pending != null)
                  _PendingAttachmentPreview(
                    attachment: _pending!,
                    onRemove: () => setState(() => _pending = null),
                  ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.attachmentSource != null) ...[
                _RoundIconButton(
                  icon: Icons.add_rounded,
                  onTap: _picking ? null : _pickAttachment,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                // The pill lifts subtly on focus: a brighter, slightly heavier
                // border animates in — a premium touch cue without a loud glow.
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  constraints: const BoxConstraints(minHeight: 46),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceElevated,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _focused
                          ? AppColors.textTertiary
                          : AppColors.darkBorder,
                      width: _focused ? 1.5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _controller,
                    focusNode: _node,
                    minLines: 1,
                    maxLines: 6,
                    style: AppTypography.body.copyWith(height: 1.35),
                    cursorColor: AppColors.primary,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: _enterToSend
                        ? TextInputAction.newline
                        : TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: AppTypography.body
                          .copyWith(color: AppColors.textTertiary),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: _enterToSend ? null : (_) => _send(),
                  ),
                ),
              ),
              // The send button appears only when there is something to send,
              // animating its width in/out for a smooth idle↔typing transition.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  final canSend = _canSend;
                  return AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.centerRight,
                    child: canSend || widget.sending
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _SendButton(
                              active: canSend,
                              sending: widget.sending,
                              onTap: widget.sending ? null : _send,
                            ),
                          )
                        : const SizedBox(height: 46),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A staged attachment shown above the input before sending — an image
/// thumbnail or a compact file row, with a remove affordance.
class _PendingAttachmentPreview extends StatelessWidget {
  const _PendingAttachmentPreview({
    required this.attachment,
    required this.onRemove,
  });

  final ChatOutgoingAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isImage = attachment.kind.isImage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            if (isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  attachment.bytes,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.originalFilename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${attachment.format.value} · '
                    '${chatHumanBytes(attachment.bytes.length)}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.textTertiary,
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove attachment',
            ),
          ],
        ),
      ),
    );
  }
}

/// A 46pt circular outline icon button (the paperclip / add-attachment control).
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Icon(icon, size: 24, color: AppColors.textSecondary),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.active,
    required this.sending,
    required this.onTap,
  });

  final bool active;
  final bool sending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.darkSurface,
          shape: BoxShape.circle,
          border: active ? null : Border.all(color: AppColors.darkBorder),
        ),
        child: sending
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.onPrimary),
              )
            : Icon(
                Icons.arrow_upward_rounded,
                size: 22,
                color: active ? AppColors.onPrimary : AppColors.textTertiary,
              ),
      ),
    );
  }
}
