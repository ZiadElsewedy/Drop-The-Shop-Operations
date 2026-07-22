import 'package:drop/features/chat/domain/entities/chat_conversation.dart';

/// Presentation-side formatting for the chat feature (the `case_format.dart`
/// sibling). Pure functions only.

/// A stable, human-scannable label for a conversation counterpart.
///
/// The NestJS backend exposes no user directory and its user ids are
/// backend-internal UUIDs (not Firebase uids), so a real display name cannot
/// be resolved client-side yet. Until an identity/profile endpoint lands, the
/// title is a deterministic short tag derived from the counterpart id — the
/// same counterpart always renders the same label.
String chatCounterpartLabel(String counterpartUserId) {
  final compact = counterpartUserId.replaceAll('-', '').toUpperCase();
  if (compact.isEmpty) return 'Teammate';
  final tag = compact.length > 6 ? compact.substring(0, 6) : compact;
  return 'Teammate $tag';
}

/// The preview line for a list row. The list endpoint deliberately carries no
/// last-message body (see [ChatConversationSummary]), so this renders an
/// honest state line off [ChatConversationSummary.lastMessageAt] instead;
/// swap in the real preview when the backend exposes it.
String chatPreviewLine(ChatConversationSummary conversation) =>
    conversation.lastMessageAt == null
        ? 'No messages yet — say hello'
        : 'Open to read the conversation';
