import 'package:fbro/features/communications/domain/entities/broadcast_entity.dart';
import 'package:fbro/features/communications/domain/repositories/broadcast_repository.dart';

/// Sends a broadcast (manager / admin) and returns it with its generated id.
class SendBroadcast {
  final BroadcastRepository _repository;
  const SendBroadcast(this._repository);

  Future<BroadcastEntity> call(BroadcastEntity broadcast) =>
      _repository.sendBroadcast(broadcast);
}
