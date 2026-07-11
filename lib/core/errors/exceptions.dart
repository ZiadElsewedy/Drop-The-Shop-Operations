class ServerException implements Exception {
  final String message;
  const ServerException(this.message);
}

/// A precondition on a write was not met because the server's state changed
/// under us — e.g. a task's status was no longer the expected predecessor when a
/// transactional transition ran (someone else moved it first). Distinct from a
/// [ServerException] (a real backend failure): a conflict is benign and the UI
/// surfaces it as a soft "it was just refreshed" notice, not an error.
class ConflictException implements Exception {
  final String message;
  const ConflictException(this.message);
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}

class CacheException implements Exception {
  final String message;
  const CacheException(this.message);
}
