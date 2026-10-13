import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_account_screen.dart';
import 'package:stellar_pos/core/cloud_auth_gateway.dart';

class _FakeCloudAuthGateway implements CloudAuthGateway {
  final StreamController<CloudAuthUser?> controller =
      StreamController<CloudAuthUser?>.broadcast();
  CloudAuthUser? user;
  int signOutCalls = 0;

  @override
  Stream<CloudAuthUser?> authStateChanges() => controller.stream;

  @override
  Future<CloudAuthUser?> currentUser() async => user;

  @override
  Future<CloudAuthUser> createAccount({
    required String email,
    required String password,
  }) async {
    final created = CloudAuthUser(uid: 'uid-1', email: email);
    user = created;
    controller.add(created);
    return created;
  }

  @override
  Future<CloudAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final signedIn = CloudAuthUser(uid: 'uid-1', email: email);
    user = signedIn;
    controller.add(signedIn);
    return signedIn;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> signOut() async {
    signOutCalls++;
    user = null;
    controller.add(null);
  }

  Future<void> dispose() => controller.close();
}

void main() {
  testWidgets('explains that local checkout does not require cloud login',
      (tester) async {
    final gateway = _FakeCloudAuthGateway();
    await tester.pumpWidget(
      MaterialApp(home: CloudAccountScreen(gateway: gateway)),
    );
    await tester.pump();

    expect(find.text('Sin sesión en la nube'), findsOneWidget);
    expect(find.textContaining('No es necesario iniciar sesión'), findsOneWidget);
    expect(find.text('Iniciar sesión o crear cuenta'), findsOneWidget);

    await gateway.dispose();
  });

  testWidgets('opens the opt-in authentication screen', (tester) async {
    final gateway = _FakeCloudAuthGateway();
    await tester.pumpWidget(
      MaterialApp(home: CloudAccountScreen(gateway: gateway)),
    );
    await tester.pump();

    await tester.tap(find.text('Iniciar sesión o crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Cuenta en la nube'), findsOneWidget);

    await gateway.dispose();
  });

  testWidgets('shows identity without implying store permissions',
      (tester) async {
    final gateway = _FakeCloudAuthGateway();
    await tester.pumpWidget(
      MaterialApp(home: CloudAccountScreen(gateway: gateway)),
    );
    await tester.pump();

    gateway.controller.add(
      const CloudAuthUser(uid: 'uid-1', email: 'owner@example.com'),
    );
    await tester.pump();

    expect(find.text('Sesión iniciada'), findsOneWidget);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(
      find.textContaining('todavía no concede acceso a una tienda'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cerrar sesión en la nube'));
    await tester.pump();
    expect(gateway.signOutCalls, 1);

    await gateway.dispose();
  });
}
