class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic details;

  ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() {
    return 'ApiException{statusCode: $statusCode, message: $message, details: $details}';
  }
}
