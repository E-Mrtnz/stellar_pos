import 'package:firebase_auth/firebase_auth.dart';

/// Single entry point for Firebase Authentication.
///
/// Stellar POS deliberately does not create anonymous identities. Every
/// authenticated session belongs to a permanent Firebase user UID.
class AuthService {
  final FirebaseAuth auth;

  AuthService({FirebaseAuth? auth}) : auth = auth ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => auth.authStateChanges();

  User? get currentUser => auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final name = displayName.trim();
    if (name.isNotEmpty) {
      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();
    }

    return credential;
  }

  Future<void> sendPasswordReset(String email) {
    return auth.sendPasswordResetEmail(
      email: email.trim().toLowerCase(),
    );
  }

  Future<void> signOut() => auth.signOut();

  String messageForAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'El correo o la contraseña no son correctos.';
      case 'user-not-found':
        return 'No existe una cuenta con ese correo.';
      case 'wrong-password':
        return 'La contraseña no es correcta.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'weak-password':
        return 'La contraseña es demasiado débil. Usa al menos 6 caracteres.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento y vuelve a intentarlo.';
      case 'network-request-failed':
        return 'No se pudo conectar con Firebase. Comprueba tu conexión.';
      case 'operation-not-allowed':
        return 'El acceso por correo y contraseña aún no está habilitado en Firebase.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'No se pudo completar la autenticación.';
    }
  }
}
