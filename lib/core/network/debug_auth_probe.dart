// ⚠️ TEMPORARY DEBUG CODE — DO NOT COMMIT. Remove this whole file (and its call
// sites in auth_cubit.dart) once the 401 investigation is done.
//
// Purpose: verify the exact Firebase ID token the app holds right after the
// session is restored / after login, so we can tell apart:
//   (1) no Authorization header, (2) an expired token, (3) a valid token the
//   NestJS backend rejects. This only READS auth state and force-refreshes the
//   token — it changes no business logic.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// ⚠️ TEMPORARY DEBUG — logs the current Firebase user and a freshly
/// force-refreshed ID token. [origin] just labels where the probe fired from.
Future<void> debugLogFirebaseAuth(String origin) async {
  final user = FirebaseAuth.instance.currentUser;
  debugPrint('🔎[AUTH-PROBE:$origin] isAuthenticated: ${user != null}');
  if (user == null) return;

  debugPrint('🔎[AUTH-PROBE:$origin] Firebase UID: ${user.uid}');
  debugPrint('🔎[AUTH-PROBE:$origin] Firebase Email: ${user.email}');
  try {
    // Force-refresh so the logged token is guaranteed fresh (not the SDK cache).
    final token = await user.getIdToken(true);
    // debugPrint truncates ~1KB per line and ID tokens are longer, so chunk it
    // to make sure the FULL token lands in the logs (paste-able into jwt.io).
    _debugPrintChunked('🔎[AUTH-PROBE:$origin] Firebase ID Token: ', token);
  } catch (e) {
    debugPrint('🔎[AUTH-PROBE:$origin] getIdToken(true) FAILED: $e');
  }
}

/// ⚠️ TEMPORARY DEBUG — prints [value] across multiple lines so long strings
/// (JWTs) are not clipped by debugPrint's per-line length cap.
void _debugPrintChunked(String prefix, String? value) {
  if (value == null) {
    debugPrint('${prefix}null');
    return;
  }
  const chunk = 800;
  debugPrint('$prefix(${value.length} chars)');
  for (var i = 0; i < value.length; i += chunk) {
    final end = (i + chunk < value.length) ? i + chunk : value.length;
    debugPrint(value.substring(i, end));
  }
}
