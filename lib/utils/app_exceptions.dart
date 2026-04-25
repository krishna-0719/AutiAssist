/// Base exception for all app-specific errors.
class AppException implements Exception {
  final String message;
  final Object? originalError;

  const AppException(this.message, {this.originalError});

  @override
  String toString() => 'AppException: $message';
}

/// Thrown when a network operation fails (timeout, no connection, API error).
class NetworkException extends AppException {
  final int? statusCode;

  const NetworkException(super.message, {super.originalError, this.statusCode});

  @override
  String toString() => 'NetworkException($statusCode): $message';
}

/// Thrown when authentication or authorization fails.
class AuthException extends AppException {
  const AuthException(super.message, {super.originalError});

  @override
  String toString() => 'AuthException: $message';
}

/// Thrown when data operations fail (parse error, missing data, DB error).
class DataException extends AppException {
  const DataException(super.message, {super.originalError});

  @override
  String toString() => 'DataException: $message';
}

/// Thrown when the app is misconfigured (missing env vars, invalid config).
class ConfigException extends AppException {
  const ConfigException(super.message, {super.originalError});

  @override
  String toString() => 'ConfigException: $message';
}
