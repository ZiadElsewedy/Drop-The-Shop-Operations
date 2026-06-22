import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/notifications/domain/entities/notification_entity.dart';
import 'package:fbro/features/notifications/domain/repositories/notification_repository.dart';
import 'package:fbro/features/notifications/domain/usecases/mark_notification_read.dart';
import 'package:fbro/features/notifications/presentation/cubit/notification_state.dart';

/// Drives the in-app notification inbox (Notification System Phase 1). Subscribes
/// to the signed-in user's notification feed and exposes the unread count + the
/// mark-read actions. Mirrors `BroadcastCubit`: repository directly for the live
/// stream, a use case for the write; last-good snapshot kept on a stream error.
class NotificationCubit extends Cubit<NotificationState> {
  final NotificationRepository _repository;
  final MarkNotificationRead _markRead;

  NotificationCubit({
    required this._repository,
    required this._markRead,
  }) : super(const NotificationState.initial());

  StreamSubscription<List<NotificationEntity>>? _sub;
  String? _uid;
  bool _hasSnapshot = false;

  List<NotificationEntity> get _items =>
      state.maybeWhen(loaded: (n) => n, orElse: () => const []);

  /// Unread notifications in the current feed.
  int get unreadCount => _items.where((n) => n.isUnread).length;

  /// Subscribes to [uid]'s live notification feed. A no-op if already watching
  /// the same user.
  Future<void> load(String uid) async {
    if (_uid == uid && _sub != null) return;
    _uid = uid;
    _hasSnapshot = false;
    emit(const NotificationState.loading());
    await _sub?.cancel();
    _sub = _repository.watch(uid).listen(
      (items) {
        _hasSnapshot = true;
        emit(NotificationState.loaded(items));
      },
      onError: (Object e, StackTrace st) {
        developer.log('Notification feed stream error',
            name: 'notifications', error: e, stackTrace: st);
        if (!_hasSnapshot) emit(NotificationState.error(_message(e)));
      },
    );
  }

  /// Stops watching and resets (call on sign-out).
  Future<void> clear() async {
    await _sub?.cancel();
    _sub = null;
    _uid = null;
    _hasSnapshot = false;
    emit(const NotificationState.initial());
  }

  Future<void> markRead(String id) async {
    try {
      await _markRead(id);
      // The stream re-emits with the updated readAt — no optimistic write needed.
    } catch (e, st) {
      developer.log('markRead failed',
          name: 'notifications', error: e, stackTrace: st);
    }
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _repository.markAllRead(uid);
    } catch (e, st) {
      developer.log('markAllRead failed',
          name: 'notifications', error: e, stackTrace: st);
    }
  }

  String _message(Object e) => e is Failure
      ? e.message
      : 'Could not load notifications. Please try again.';

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
