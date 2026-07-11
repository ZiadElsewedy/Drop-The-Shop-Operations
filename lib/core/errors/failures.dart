abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// A write lost a race against a concurrent change (see [ConflictException]).
/// Carried as a [Failure] so it flows through the same cubit error channel, but
/// callers may treat it as benign (the realtime stream will deliver the true
/// state moments later).
class ConflictFailure extends Failure {
  const ConflictFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
