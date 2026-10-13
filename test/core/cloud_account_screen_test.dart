import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_auth_gateway.dart';
import 'package:stellar_pos/core/cloud_account_screen.dart';

class _FakeGateway implements CloudAuthGateway {
  final controller = StreamController<CloudAuthUser?>.broadcast();
  CloudAuthUser? current;
  int signOutCalls = 0;

  @override
  Stream<CloudAuthUser?> authStateChanges() => controller.stream;

  @override
  Future<CloudAuthUser?> currentUser() async => current;

  @override
  Future<CloudAuthUser> createAccount({
    required String email,
    required String password,
  }) async {
    current = CloudAuthUser(uid: 'uid-1', email: email);
    controller.add(current);
    return current!;
  }

  @override
  Future<CloudAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    current = CloudAuthUser(uid: 'uid-1', email: email);
    controller.add(current);
    return current!;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> signOut() async {
    signOutCalls++;
    current = null;
    controller.add(null);
  }

  Future<void> dispose() => controller.close();
}

void main() {
  testWidgets('shows optional sign-in when there is no cloud session',
      (tester) async {
    final gateway = _FakeGateway();
    addTearDown(gateway.dispose);
    await tester.pumpWidget(
      MaterialApp(home: CloudAccountScreen(gateway: gateway)),
    );
    gateway.controller.add(null);
    await tester.pump();

    expect(find.text('Sin sesión en la nube'), findsOneWidget);
    expect(find.text('Iniciar sesión o crear cuenta'), findsOneWidget);
  });

  testWidgets('shows account identity and signs out through the gateway',
      (tester) async {
    final gateway = _FakeGateway()
      ..current = const CloudAuthUser(
        uid: 'uid-1',
        email: 'owner@example.com',
      );
    addTearDown(gateway.dispose);
    await tester.pumpWidget(
      MaterialApp(home: CloudAccountScreen(gateway: gateway)),
    );
    gateway.controller.add(gateway.current);
    await tester.pump();

    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.textContaining('no concede acceso a una tienda'), findsOneWidget);

    await tester.tap(find.text('Cerrar sesión en la nube'));
    await tester.pump();
    await tester.pump();

    expect(gateway.signOutCalls, 1);
  });
}
