import 'package:fbro/features/communications/domain/entities/broadcast_template_entity.dart';

/// Contract for broadcast templates (Communications Center — Phase 2). Access is
/// enforced server-side by `firestore.rules` (`broadcastTemplates/{id}`, mirroring
/// `task_templates`): admin reads/writes any (global or branch); a manager
/// reads/writes their own branch's templates; employees have no access.
abstract class BroadcastTemplateRepository {
  Future<List<BroadcastTemplateEntity>> getTemplates();
  Future<BroadcastTemplateEntity> create(BroadcastTemplateEntity template);
  Future<void> update(BroadcastTemplateEntity template);
  Future<void> setFavorite(String id, bool favorite);
  Future<void> incrementUsage(String id);
  Future<void> delete(String id);
}
