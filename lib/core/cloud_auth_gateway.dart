import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'cloud_firebase.dart';

/// Small application-facing identity value. It deliberately contains no store
/// role or permissions: those come from a separately verified membership.
class CloudAuthUser {
  const CloudAuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = false,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;

  factory CloudAuthUser.fromFirebase(firebase_auth.User user) {
    return CloudAuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      emailVerified: user.emailVerified,
    );
  }
}

/// Authentication boundary for application services and presentation.
///
/// This API only authenticates an identity. It does not create a store, grant
/// membership, authorize Firestore access, or make Firebase required for Hive.
abstract interface class CloudAuthGateway {
  Stream<CloudAuthUser?> authStateChanges();

  Future<CloudAuthUser?> currentUser();

  Future<CloudAuthUser> createAccount({
    required String email,
    required String password,
  });

  Future<CloudAuthUser> signIn({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}

/// Firebase Authentication adapter. SDK access is lazy so constructing this
/// adapter never requires Firebase to have finished optional initialization.
class FirebaseCloudAuth implements CloudAuthGateway {
  FirebaseCloudAuth({firebase_auth.FirebaseAuth? auth}) : _providedAuth = auth;

  final firebase_auth.FirebaseAuth? _providedAuth;

  firebase_auth.FirebaseAuth get _auth =>
      _providedAuth ?? firebase_auth.FirebaseAuth.instance;

  @override
  Stream<CloudAuthUser?> authStateChanges() async* {
    await CloudFirebase.ensureReady();
    yield* _auth.authStateChanges().map(
          (user) => user == null ? null : CloudAuthUser.fromFirebase(user),
        );
  }

  @override
  Future<CloudAuthUser?> currentUser() async {
    await CloudFirebase.ensureReady();
    final user = _auth.currentUser;
    return user == null ? null : CloudAuthUser.fromFirebase(user);
  }

  @override
  Future<CloudAuthUser> createAccount({
    required String email,
    required String password,
  }) async {
    await CloudFirebase.ensureReady();
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase Authentication no devolvió un usuario.');
    }
    return CloudAuthUser.fromFirebase(user);
  }

  @override
  Future<CloudAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await CloudFirebase.ensureReady();
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase Authentication no devolvió un usuario.');
    }
    return CloudAuthUser.fromFirebase(user);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await CloudFirebase.ensureReady();
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> signOut() async {
    await CloudFirebase.ensureReady();
    await _auth.signOut();
  }
}
