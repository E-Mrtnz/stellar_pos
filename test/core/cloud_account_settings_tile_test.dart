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
  Future<CloudAuthUser> createAccount({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<CloudAuthUser> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('clearly marks cloud account as optional', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CloudAccountSettingsTile())),
    );

    expect(find.text('Cuenta en la nube'), findsOneWidget);
    expect(find.textContaining('No es necesaria para vender'), findsOneWidget);
  });

  testWidgets('opens account screen only after tapping the settings entry',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CloudAccountSettingsTile(gateway: _FakeCloudAuthGateway()),
        ),
      ),
    );

    expect(find.text('Sin sesión en la nube'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('cloud-account-settings-tile')));
    await tester.pumpAndSettle();

    expect(find.text('Cuenta en la nube'), findsOneWidget);
    expect(find.text('Sin sesión en la nube'), findsOneWidget);
    expect(find.text('Iniciar sesión o crear cuenta'), findsOneWidget);
  });
}
