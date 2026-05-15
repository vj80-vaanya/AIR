class EngineException implements Exception {
  const EngineException(this.message);
  final String message;
  @override
  String toString() => 'EngineException: $message';
}

class DatabaseException implements Exception {
  const DatabaseException(this.message);
  final String message;
  @override
  String toString() => 'DatabaseException: $message';
}

class NetworkException implements Exception {
  const NetworkException(this.message, {this.statusCode});
  final String message;
  final int?   statusCode;
  @override
  String toString() => 'NetworkException($statusCode): $message';
}

class PermissionException implements Exception {
  const PermissionException(this.permission);
  final String permission;
  @override
  String toString() => 'PermissionException: $permission not granted';
}

class SOSException implements Exception {
  const SOSException(this.message);
  final String message;
  @override
  String toString() => 'SOSException: $message';
}
