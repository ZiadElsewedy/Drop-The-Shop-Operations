import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:drop/features/chat/domain/entities/chat_attachment_download.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/domain/entities/chat_read_receipt.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';

/// [ChatRepository] backed by the NestJS API. Follows the project's repository
/// pattern: datasource exceptions (thrown by [ApiClient]'s error translation)
/// are mapped to the corresponding [Failure]s here, so cubits only ever handle
/// the failure vocabulary. Models → entities mapping happens in the models
/// themselves; message payloads already arrive as entities (no local shape to
/// reconcile — the API is the single source of truth).
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remote;

  ChatRepositoryImpl(this._remote);

  /// One seam for the exception → failure mapping so every method stays a
  /// single expression. `AuthException` → [AuthFailure] (session dead),
  /// `ConflictException` → [ConflictFailure] (benign race),
  /// `ServerException` → [ServerFailure] (everything else, incl. 400/404 with
  /// the server's message).
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } on ConflictException catch (e) {
      throw ConflictFailure(e.message);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<ChatConversation> startConversation(String targetUserId) => _guard(
      () async => (await _remote.createConversation(targetUserId)).toEntity());

  @override
  Future<ChatConversationPage> getConversations({int? limit, String? cursor}) =>
      _guard(() => _remote.listConversations(limit: limit, cursor: cursor));

  @override
  Future<ChatConversation> getConversation(String conversationId) => _guard(
      () async => (await _remote.getConversation(conversationId)).toEntity());

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
  }) =>
      _guard(() => _remote.sendMessage(
            conversationId: conversationId,
            idempotencyKey: idempotencyKey,
            content: content,
            attachment: attachment,
            replyToMessageId: replyToMessageId,
          ));

  @override
  Future<ChatMessagePage> getMessageHistory({
    required String conversationId,
    int? limit,
    String? cursor,
  }) =>
      _guard(() => _remote.loadHistory(
            conversationId: conversationId,
            limit: limit,
            cursor: cursor,
          ));

  @override
  Future<ChatReadReceipt> markMessagesRead({
    required String conversationId,
    required BigInt upToSeq,
  }) =>
      _guard(() => _remote.markRead(
            conversationId: conversationId,
            upToSeq: upToSeq,
          ));

  @override
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
  }) =>
      _guard(() => _remote.deleteForMe(
            conversationId: conversationId,
            messageId: messageId,
          ));

  @override
  Future<ChatMessage> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) =>
      _guard(() => _remote.deleteForEveryone(
            conversationId: conversationId,
            messageId: messageId,
          ));

  @override
  Future<ChatAttachmentDownload> getAttachmentDownloadUrl({
    required String conversationId,
    required String messageId,
  }) =>
      _guard(() => _remote.getAttachmentDownloadUrl(
            conversationId: conversationId,
            messageId: messageId,
          ));
}
