import 'package:cloud_firestore/cloud_firestore.dart';

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
/// No document is created or modified. A permission-denied response is kept
/// distinct from a transport/server failure so a locked-down production ruleset
/// is not mistaken for a broken Firebase connection.
class FirestoreConnectionCheck {
  final FirebaseFirestore firestore;

  FirestoreConnectionCheck({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  Future<FirestoreConnectionResult> run() async {
    try {
      await firestore
          .collection('_stellar_pos_diagnostics')
          .doc('connection')
          .get(const GetOptions(source: Source.server));

      return const FirestoreConnectionResult(
        status: FirestoreConnectionStatus.connected,
        message: 'Firestore respondió correctamente desde el servidor.',
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return const FirestoreConnectionResult(
          status: FirestoreConnectionStatus.permissionDenied,
          message:
              'Firebase/Firestore respondió, pero las reglas de seguridad '
              'denegaron la lectura.',
        );
      }

      if (error.code == 'unavailable' ||
          error.code == 'deadline-exceeded') {
        return FirestoreConnectionResult(
          status: FirestoreConnectionStatus.unavailable,
          message:
              'Firestore no está disponible en este momento: ${error.code}.',
        );
      }

      return FirestoreConnectionResult(
        status: FirestoreConnectionStatus.failed,
        message:
            "Firestore devolvió un error (\${error.code}): \${error.message ?? 'sin detalle'}.",
      );
    } catch (error) {
      return FirestoreConnectionResult(
        status: FirestoreConnectionStatus.failed,
        message: 'No se pudo comprobar Firestore: $error',
      );
    }
  }
}
