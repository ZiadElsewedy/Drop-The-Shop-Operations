/// A direct (1:1) chat conversation between two DROP users — the client mirror
/// of the backend's `ConversationResponseDto` (`drop-api` ·
/// `chat/conversations/interface/http/dto/conversation-response.dto.ts`).
///
/// Plain immutable value objects (not freezed) — mirroring the [CaseIdentity]
/// precedent: they cross the data boundary and are held by cubit states later,
/// but state equality is handled at the state level, so no codegen is needed
/// in this layer.
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.participantIds,
    required this.createdAt,
    this.lastMessageAt,
  });

  /// Conversation UUID.
  final String id;

  /// Both participants' internal user UUIDs (always exactly two in V1).
  final List<String> participantIds;

  final DateTime createdAt;

  /// Timestamp of the newest message; null for an empty conversation. The
  /// server orders the conversation list by this (most recent activity first).
  final DateTime? lastMessageAt;

  /// The other participant relative to [myUserId] — for a conversation fetched
  /// by id (the list endpoint provides this pre-computed, see
  /// [ChatConversationSummary.counterpartUserId]).
  String counterpartOf(String myUserId) => participantIds.firstWhere(
        (id) => id != myUserId,
        orElse: () => myUserId,
      );
}

/// One row of the caller's conversation list — the client mirror of the
/// backend's `ConversationListItemResponseDto`. Identical to
/// [ChatConversation] plus the server-computed [counterpartUserId]. Unread
/// counts and last-message previews are deliberately absent — the backend does
/// not expose them on this endpoint (see backend-improvement notes).
class ChatConversationSummary {
  const ChatConversationSummary({
    required this.id,
    required this.counterpartUserId,
    required this.participantIds,
    required this.createdAt,
    this.lastMessageAt,
  });

  final String id;

  /// The other participant relative to the requester, resolved server-side.
  final String counterpartUserId;

  final List<String> participantIds;
  final DateTime createdAt;
  final DateTime? lastMessageAt;

  /// This row with a fresher [lastMessageAt] — how a live `message:new`
  /// bumps a conversation's activity without a REST round trip.
  ChatConversationSummary withLastMessageAt(DateTime at) =>
      ChatConversationSummary(
        id: id,
        counterpartUserId: counterpartUserId,
        participantIds: participantIds,
        createdAt: createdAt,
        lastMessageAt: at,
      );
}

/// A page of the conversation list with an opaque keyset cursor. Pass
/// [nextCursor] back as `cursor` to load the next page; null means no more.
class ChatConversationPage {
  const ChatConversationPage({
    required this.items,
    this.nextCursor,
  });

  final List<ChatConversationSummary> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
