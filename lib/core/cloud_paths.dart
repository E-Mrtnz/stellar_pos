/// Centralizes Firestore paths and validates each path segment.
///
/// This validation prevents malformed paths in the client; it is not a
/// security boundary. Firestore Security Rules must independently enforce
/// authentication and store membership before any remote data is accessible.
class CloudPaths {
  CloudPaths._();

  static String document(String storeId, String collection, String documentId) {
    _validateSegment('storeId', storeId);
    _validateSegment('collection', collection);
    _validateSegment('documentId', documentId);

    return 'stores/$storeId/$collection/$documentId';
  }

  static void _validateSegment(String name, String value) {
    if (value.trim().isEmpty || value.contains('/')) {
      throw ArgumentError.value(
        value,
        name,
        'Debe ser un segmento no vacío y no puede contener "/".',
      );
    }
  }
}
