import 'package:drop/core/enums/chat_attachment_kind.dart';
import 'package:drop/core/enums/chat_message_type.dart';

/// A chat message — the client mirror of the backend's `MessageResponseDto`
/// (`drop-api` · `chat/messages/interface/http/dto/message.response.dto.ts`).
///
/// [seq] is the conversation-scoped ordering sequence. The backend serializes
/// it as a **string** because it is a 64-bit value; it is parsed to [BigInt]
/// here so ordering and cursor math stay exact on every platform (a web build's
/// `int` is a 53-bit JS number).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.body,
    this.attachment,
    this.replyTo,
    required this.seq,
    required this.status,
    required this.createdAt,
    this.deletedForEveryone = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final ChatMessageType type;

  /// Text content; null for an attachment-only message. When
  /// [deletedForEveryone] is true this carries the server's placeholder text.
  final String? body;

  /// Null for a text-only message.
  final ChatMessageAttachment? attachment;

  /// Shallow preview of the quoted parent when this message is a reply.
  final ChatReplyPreview? replyTo;

  /// Monotonic per-conversation sequence — the ordering key and history cursor.
  final BigInt seq;

  /// Delivery status as reported by the server. A persisted message is always
  /// at least `SENT` in V1; delivered/read transitions arrive with the
  /// realtime phase, so this is kept as the raw wire string rather than a
  /// client-invented enum that would break on new values.
  final String status;

  final DateTime createdAt;

  /// True when the message was deleted for everyone (tombstoned); [body] then
  /// holds the standard placeholder and [attachment] is gone.
  final bool deletedForEveryone;
}

/// An attachment riding on a message — mirror of `MessageAttachmentDto`.
/// [format] is kept as the raw wire string (`"PDF"`, `"JPG"`, …): received
/// history must never fail to parse because a newer server added a format.
/// The outgoing (send) side uses the strict [ChatAttachmentFormat] enum.
class ChatMessageAttachment {
  const ChatMessageAttachment({
    required this.id,
    required this.kind,
    required this.format,
    required this.mimeType,
    required this.originalFilename,
    required this.byteSize,
  });

  final String id;
  final ChatAttachmentKind kind;
  final String format;
  final String mimeType;
  final String originalFilename;

  /// Size in bytes. Serialized as a string on the wire (64-bit); parsed to
  /// [int] here — attachment sizes are bounded by the server's upload limit
  /// and comfortably fit a 53-bit web int.
  final int byteSize;
}

/// Shallow preview of the message a reply quotes — mirror of
/// `MessageReplyPreviewDto`. Reference-only: reflects the parent's *current*
/// state (a deleted-for-everyone parent shows its placeholder body) and
/// carries no `seq` and no nested reply.
class ChatReplyPreview {
  const ChatReplyPreview({
    required this.id,
    required this.senderId,
    required this.type,
    this.body,
    this.attachment,
  });

  final String id;
  final String senderId;
  final ChatMessageType type;
  final String? body;
  final ChatMessageAttachment? attachment;
}

/// A page of message history, oldest → newest within the page. Pass
/// [nextCursor] back as `cursor` to load the next **older** page; null means
/// the full history has been loaded.
class ChatMessagePage {
  const ChatMessagePage({
    required this.items,
    this.nextCursor,
  });

  final List<ChatMessage> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
