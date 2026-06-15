import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fbro/core/constants/app_constants.dart';

/// Firebase Cloud Messaging foundation (Phase 6). Requests notification
/// permission, persists the device's FCM token on the user's document, and
/// surfaces foreground messages via [onForeground]. No history / inbox / chat —
/// just simple push. Sending the [NotificationType] events on their triggers
/// needs a server (out of scope: no Cloud Functions); this is the client side.
class NotificationService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  /// The signed-in uid whose token we keep current (for token refreshes).
  String? _uid;

  /// Set by the app to show foreground notifications in-app (e.g. a snackbar).
  void Function(String? title, String? body)? onForeground;

  NotificationService(this._messaging, this._firestore);

  /// One-time setup at app start: permission + message listeners. Best-effort —
  /// never throws (FCM is unsupported on some platforms).
  Future<void> init() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n != null) onForeground?.call(n.title, n.body);
      });
      _messaging.onTokenRefresh.listen((token) {
        final uid = _uid;
        if (uid != null) _saveToken(uid, token);
      });
    } catch (_) {
      // FCM not available on this platform/build — ignore.
    }
  }

  /// Persist the device token for [uid] (call after the user is authenticated).
  Future<void> registerToken(String uid) async {
    _uid = uid;
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(uid, token);
    } catch (_) {
      // Best-effort; push is non-critical to app function.
    }
  }

  /// Stop tracking the token (call on sign-out).
  void forgetUser() => _uid = null;

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-fatal.
    }
  }
}
