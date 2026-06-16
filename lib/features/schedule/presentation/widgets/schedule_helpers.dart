import 'package:fbro/features/auth/domain/entities/user_entity.dart';

/// Best display name for a user — their display name, falling back to email.
String userDisplayName(UserEntity u) =>
    (u.displayName != null && u.displayName!.isNotEmpty)
        ? u.displayName!
        : u.email;

/// Resolves a uid to a display name from a list of branch [members].
String nameForUid(String uid, List<UserEntity> members) {
  final u = userForUid(uid, members);
  return u == null ? 'Unknown' : userDisplayName(u);
}

/// Resolves a uid to its [UserEntity] from a list of branch [members], or null.
UserEntity? userForUid(String uid, List<UserEntity> members) {
  for (final m in members) {
    if (m.uid == uid) return m;
  }
  return null;
}
