sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class EngineFailure    extends Failure { const EngineFailure(super.message); }
final class NetworkFailure   extends Failure { const NetworkFailure(super.message); }
final class DatabaseFailure  extends Failure { const DatabaseFailure(super.message); }
final class PermissionFailure extends Failure { const PermissionFailure(super.message); }
final class SOSFailure       extends Failure { const SOSFailure(super.message); }
final class UnexpectedFailure extends Failure { const UnexpectedFailure(super.message); }
