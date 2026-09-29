import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

enum FirestoreConnectionStatus {
  connected,
  permissionDenied,
  unavailable,
  failed,
}

class FirestoreConnectionResult {
  final FirestoreConnectionStatus status;
  final String message;

  const FirestoreConnectionResult({
    required this.status,
    required this.message,
  });

  bool get isConnected => status == FirestoreConnectionStatus.connected;
}

/// Performs a read-only server request against Firestore.
///
/// No document is created or modified. The diagnostic explicitly enables the
/// Firestore network before requesting the server so a disabled SDK network
/// state is not mistaken for a backend connectivity problem.
class FirestoreConnectionCheck {
  final FirebaseFirestore firestore;

  FirestoreConnectionCheck({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  Future<FirestoreConnectionResult> run() async {
    final projectId = Firebase.app().options.projectId;

    try {
      await firestore.enableNetwork();

      await firestore
          .collection('_stellar_pos_diagnostics')
          .doc('connection')
          .get(const GetOptions(source: Source.server));

      return FirestoreConnectionResult(
        status: FirestoreConnectionStatus.connected,
        message:
            'Firestore respondió correctamente desde el servidor. '
            'Proyecto: $projectId.',
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return FirestoreConnectionResult(
          status: FirestoreConnectionStatus.permissionDenied,
          message:
              'Firestore respondió desde el servidor, pero las reglas de '
              'seguridad denegaron la lectura. '
              'Proyecto: $projectId. '
              'Código: ${{error.code}. '
              'Detalle: ${{error.message ?? 'sin detalle'}.',
        );
      }

      if (error.code == 'unavailable' ||
          error.code == 'deadline-exceeded') {
        return FirestoreConnectionResult(
          status: FirestoreConnectionStatus.unavailable,
          message:
              'No se pudo obtener respuesta de Firestore. '
              'Proyecto: $projectId. '
              'Código: ${{error.code}. '
              'Detalle: ${{error.message ?? 'sin detalle'}.',
        );
      }

      return FirestoreConnectionResult(
        status: FirestoreConnectionStatus.failed,
        message:
            'Firestore devolvió un error. '
            'Proyecto: $projectId. '
            'Código: ${{error.code}. '
            'Detalle: ${{error.message ?? 'sin detalle'}.',
      );
    } catch (error) {
      return FirestoreConnectionResult(
        status: FirestoreConnectionStatus.failed,
        message:
            'No se pudo comprobar Firestore. '
            'Proyecto: $projectId. '
            'Detalle: ${$error',
      );
    }
  }
}
