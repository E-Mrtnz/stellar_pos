import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_auth_gateway.dart';
import 'package:stellar_pos/core/cloud_auth_screen.dart';

class _FakeCloudAuthGateway implements CloudAuthGateway {
  CloudAuthUser? signedIn;
  Object? signInError;
  String? lastEmail;
  String? lastPassword;
  int resetRequests = 0;\n  String? requestedPhone;\n  String? verifiedCode;

  @override
  Stream<CloudAuthUser?> authStateChanges() => const Stream.empty();

  @override
  Future<CloudAuthUser?> currentUser() async => signedIn;

  @override
  Future<CloudAuthUser> createAccount({
    required String email,
    required String password,
  }) async {
    lastEmail = email.trim();
    lastPassword = password;
    if (signInError != null) throw signInError!;
    return signedIn = CloudAuthUser(uid: 'uid-1', email: lastEmail);
  }

  @override
  Future<CloudAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    lastEmail = email.trim();
    lastPassword = password;
    if (signInError != null) throw signInError!;
    return signedIn = CloudAuthUser(uid: 'uid-1', email: lastEmail);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    lastEmail = email.trim();
    resetRequests++;
    if (signInError != null) throw signInError!;
  }

  @override
  Future<CloudAuthUser> signInWithGoogle() => Future.error(
        UnsupportedError('El acceso con Google no está habilitado en este dispositivo.'),
      );

  @override
  Future<CloudAuthUser> signInWithApple() => Future.error(
        UnsupportedError('El acceso con Apple no está habilitado en este dispositivo.'),
      );

  @override
  Future<void> signOut() async {
    signedIn = null;
  }
}

void main() {
  testWidgets('validates required email and password', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CloudAuthScreen(gateway: _FakeCloudAuthGateway())),
    );

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Introduce un correo válido.'), findsOneWidget);
    expect(find.text('Introduce tu contraseña.'), findsOneWidget);
  });

  testWidgets('signs in and notifies caller without gating local app',
      (tester) async {
    final gateway = _FakeCloudAuthGateway();
    CloudAuthUser? authenticated;
    await tester.pumpWidget(
      MaterialApp(
        home: CloudAuthScreen(
          gateway: gateway,
          onAuthenticated: (user) => authenticated = user,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('cloud-auth-email')),
      '  cashier@example.com ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('cloud-auth-password')),
      'secure-pass',
    );
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(gateway.lastEmail, 'cashier@example.com');
    expect(gateway.lastPassword, 'secure-pass');
    expect(authenticated?.uid, 'uid-1');
    expect(find.text('Sesión iniciada como cashier@example.com.'), findsOneWidget);
  });

  testWidgets('shows friendly authentication failures', (tester) async {
    final gateway = _FakeCloudAuthGateway()
      ..signInError = Exception('wrong-password');
    await tester.pumpWidget(
      MaterialApp(home: CloudAuthScreen(gateway: gateway)),
    );

    await tester.enterText(
      find.byKey(const ValueKey('cloud-auth-email')),
      'cashier@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('cloud-auth-password')),
      'incorrect',
    );
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
  });
  testWidgets('password can be shown and hidden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CloudAuthScreen(gateway: _FakeCloudAuthGateway())),
    );
    EditableText passwordEditor() => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('cloud-auth-password')),
        matching: find.byType(EditableText),
      ),
    );
    expect(passwordEditor().obscureText, isTrue);
    await tester.tap(find.byKey(const ValueKey('cloud-auth-toggle-password')));
    await tester.pump();
    expect(
      passwordEditor().obscureText,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('cloud-auth-toggle-password')));
    await tester.pump();
    expect(
      passwordEditor().obscureText,
      isTrue,
    );
  });

  testWidgets('phone sign-in requests and verifies an SMS code',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _FakeCloudAuthGateway();
    CloudAuthUser? authenticated;
    await tester.pumpWidget(
      MaterialApp(
        home: CloudAuthScreen(
          gateway: gateway,
          onAuthenticated: (user) => authenticated = user,
        ),
      ),
    );

    await tester.ensureVisible(find.text('Teléfono'));
    await tester.tap(find.text('Teléfono'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byLabelText('Número de teléfono'), '+50370000000');
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    expect(gateway.requestedPhone, '+50370000000');
    await tester.enterText(find.byLabelText('Código SMS'), '123456');
    await tester.tap(find.text('Verificar código'));
    await tester.pumpAndSettle();

    expect(gateway.verifiedCode, '123456');
    expect(authenticated?.uid, 'phone-user');
    expect(find.text('Sesión iniciada como phone-user.'), findsOneWidget);
  });

  testWidgets('clearly explains that social providers are not enabled yet',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: CloudAuthScreen(gateway: _FakeCloudAuthGateway())),
    );

    final googleButton = find.text('Continuar con Google');
    await tester.ensureVisible(googleButton);
    await tester.tap(googleButton);
    await tester.pump();

    expect(
      find.text(
        'El acceso con Google no está habilitado en este dispositivo.',
      ),
      findsOneWidget,
    );
  });

}
