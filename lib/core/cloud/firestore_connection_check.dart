import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

enum FirestoreConnectionStatus {
  connected,
  permissionDenied,
  authRequired,
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
/// Authentication is established anonymously only for this diagnostic.
/// No Firestore document is created or modified.
class FirestoreConnectionCheck {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  FirestoreConnectionCheck({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance;

  Future<FirestoreConnectionResult> run() async {
    final projectId = Firebase.app().options.projectId;

    try {
      final existingUser = auth.currentUser;
      final user = existingUser ?? (await auth.signInAnonymously()).user;

      if (user == null) {
        return FirestoreConnectionResult(
          status: FirestoreConnectionStatus.authRequired,
          message:
              'Firebase Authentication no devolvió un usuario anónimo. '
              'Proyecto: $projectId.',
        );
      }

      await firestore.enableNetwork();

      await firestore
          .collection('_stellar_pos_diagnostics')
          .doc('connection')
          .get(const GetOptions(source: Source.server));

      return FirestoreConnectionResult(
        status: FirestoreConnectionStatus.connected,
        message:
            'Firestore respondió correctamente desde el servidor. '
            'Proyecto: $projectId. Usuario autenticado: ${user.uid}.',
      );
    } on FirebaseAuthException catch (error, stackTrace) {
      final details = [
        'Código: ${error.code}',
        'Detalle: ${error.message ?? 'sin detalle'}',
        'Plugin: ${error.plugin ?? 'sin plugin'}',
        'Stack: $stackTrace',
      ].join(' | ');

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        try {
          final native = await const MethodChannel(
            'stellar_pos/firebase_auth_native_diagnostic',
          ).invokeMapMethod<String, dynamic>('signInAnonymously');

          if (native != null) {
            final nativeMessage = native.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join(' | ');

            return FirestoreConnectionResult(
              status: FirestoreConnectionStatus.authRequired,
              message:
                  'Firebase Authentication falló también en la capa nativa '
                  'de macOS. Proyecto: $projectId. '
                  'App ID: ${Firebase.app().options.appId}. '
                  '$nativeMessage',
            );
          }
        } catch (nativeError) {
          return FirestoreConnectionResult(
            status: FirestoreConnectionStatus.authRequired,
            message:
                'Firebase Authentication falló en Flutter y el diagnóstico '
                'nativo de macOS tampoco pudo ejecutarse. '
                'Proyecto: $projectId. '
                'App ID: ${Firebase.app().options.appId}. '
                'Error nativo: $nativeError. '
                '$details',
          );
        }
      }

      return FirestoreConnectionResult(
        status: FirestoreConnectionStatus.authRequired,
        message:
            'Firebase Authentication no pudo autenticar el diagnóstico. '
            'Proyecto: $projectId. '
            'App ID: ${Firebase.app().options.appId}. '
            'Usuario previo: ${auth.currentUser?.uid ?? 'ninguno'}. '
            '$details',
      );
    } on FirebaseException catch (error, stackTrace) {
      if (error.code == 'permission-denied') {
        return FirestoreConnectionResult(
          status: FirestoreConnectionStatus.permissionDenied,
          message:
              'Firestore respondió desde el servidor, pero las reglas de '
              'seguridad denegaron la lectura. '
              'Proyecto: $projectId. '
              'Usuario autenticado: ${auth.currentUser?.uid ?? 'ninguno'}. '
              'Código: ${error.code}. '
              'Detalle: ${error.message ?? 'sin detalle'}.',
        );
      }

      if (error.code == 'unavailable' ||
          error.code == 'deadline-exceeded') {
        return FirestoreConnectionResult(
          status: FirestoreConnectionStatus.unavailable,
          message:
              'No se pudo obtener respuesta de Firestore. '
              'Proyecto: $projectId. '
              'Código: ${error.code}. '
              'Detalle: ${error.message ?? 'sin detalle'}.',
        );
      }

      return FirestoreConnectionResult(
        status: FirestoreConnectionStatus.failed,
        message:
            'Firestore devolvió un error. '
            'Proyecto: $projectId. '
            'Código: ${error.code}. '
            'Detalle: ${error.message ?? 'sin detalle'}. '
            'Stack: $stackTrace',
      );
    } catch (error, stackTrace) {
      return FirestoreConnectionResult(
        status: FirestoreConnectionStatus.failed,
        message:
            'No se pudo comprobar Firestore. '
            'Proyecto: $projectId. '
            'Detalle: $error. '
            'Stack: $stackTrace',
      );
    }
  }
}
