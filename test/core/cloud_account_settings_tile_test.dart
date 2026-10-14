import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_account_settings_tile.dart';
import 'package:stellar_pos/core/cloud_auth_gateway.dart';

class _FakeCloudAuthGateway implements CloudAuthGateway {
  @override
  Stream<CloudAuthUser?> authStateChanges() => Stream.value(null);
  @override
  Future<CloudAuthUser?> currentUser() async => null;
  @override
  Future<CloudAuthUser> createAccount({required String email, required String password}) => throw UnimplementedError();
  @override
  Future<CloudAuthUser> signIn({required String email, required String password}) => throw UnimplementedError();
  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}
  @override
  Future<CloudAuthUser> signInWithGoogle() => Future.error(
        UnsupportedError('El acceso con Google no está habilitado en este dispositivo.'),
      );

  @override
  Future<CloudAuthUser> signInWithApple() => Future.error(
        UnsupportedError('El acceso con Apple no está habilitado en este dispositivo.'),
      );

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('clearly marks cloud account as optional', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CloudAccountSettingsTile(gateway: _FakeCloudAuthGateway()))));
    expect(find.text('Cuenta en la nube'), findsOneWidget);
    expect(find.textContaining('No es necesaria para vender'), findsOneWidget);
  });

  testWidgets('expands and collapses inline without pushing a route', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CloudAccountSettingsTile(gateway: _FakeCloudAuthGateway()))));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cloud-account-settings-tile')));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cloud-account-settings-tile')));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('account panel scrolls on a compact desktop viewport', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CloudAccountSettingsTile(gateway: _FakeCloudAuthGateway()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);

    // The inline account form is taller than this viewport. It must remain
    // scrollable rather than overflowing the settings panel.
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

}
