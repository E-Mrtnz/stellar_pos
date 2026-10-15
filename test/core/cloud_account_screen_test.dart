import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_account_screen.dart';
import 'package:stellar_pos/core/cloud_auth_gateway.dart';
import 'package:stellar_pos/core/cloud_store_repository.dart';

class _FakeCloudAuthGateway implements CloudAuthGateway {
  final StreamController<CloudAuthUser?> controller =
      StreamController<CloudAuthUser?>.broadcast();
  CloudAuthUser? user;
  int signOutCalls = 0;
  Object? signOutError;

  @override
  Stream<CloudAuthUser?> authStateChanges() async* {
    yield user;
    yield* controller.stream;
  }

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
  Future<CloudAuthUser> signInWithGoogle() => Future<CloudAuthUser>.error(
        UnsupportedError('Google no está habilitado en este fake.'),
      );

  @override
  Future<CloudAuthUser> signInWithApple() => Future<CloudAuthUser>.error(
        UnsupportedError('Apple no está habilitado en este fake.'),
      );

  @override
  Future<void> sendPhoneVerificationCode({required String phoneNumber}) =>
      Future<void>.error(
        UnsupportedError('SMS no está habilitado en este fake.'),
      );

  @override
  Future<CloudAuthUser> verifyPhoneCode({required String smsCode}) =>
      Future<CloudAuthUser>.error(
        UnsupportedError('SMS no está habilitado en este fake.'),
      );

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
    user = null;
    controller.add(null);
  }

  Future<void> dispose() => controller.close();
}

class _FakeCloudStoreGateway implements CloudStoreGateway {
  String? lastName;
  int createCalls = 0;
  int listCalls = 0;
  int _nextStoreId = 0;
  List<CloudStore> stores = <CloudStore>[];
  Object? listError;
  Object? error;

  @override
  Future<List<CloudStore>> listMyStores() async {
    listCalls++;
    if (listError != null) throw listError!;
    return stores;
  }

  @override
  Future<CloudStore> createStore({required String name}) async {
    createCalls++;
    lastName = name;
    if (error != null) throw error!;
    _nextStoreId++;
    return CloudStore(
      id: 'store-test-$_nextStoreId',
      name: name.trim(),
      ownerUid: 'uid-1',
    );
  }
}

void main() {
  testWidgets('local checkout does not require cloud login', (tester) async {
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

  testWidgets('shows account identity and explicit store creation', (tester) async {
    final gateway = _FakeCloudAuthGateway()
      ..user = const CloudAuthUser(uid: 'uid-1', email: 'owner@example.com');
    final storeGateway = _FakeCloudStoreGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: CloudAccountScreen(
          gateway: gateway,
          storeGateway: storeGateway,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sesión iniciada'), findsOneWidget);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('Crear una tienda'), findsOneWidget);
    expect(find.text('Compartir una tienda'), findsOneWidget);
    expect(find.textContaining('Las invitaciones todavía no están habilitadas'), findsOneWidget);
    expect(find.text('Nombre de la tienda'), findsOneWidget);
    expect(find.textContaining('no sube tus productos ni tus ventas'), findsOneWidget);
    expect(storeGateway.createCalls, 0);

    await tester.ensureVisible(find.text('Cerrar sesión en la nube'));
    await tester.tap(find.text('Cerrar sesión en la nube'));
    await tester.pumpAndSettle();
    expect(gateway.signOutCalls, 1);
    expect(storeGateway.createCalls, 0);
    expect(find.text('Sin sesión en la nube'), findsOneWidget);
    expect(find.text('Iniciar sesión o crear cuenta'), findsOneWidget);

    await gateway.dispose();
  });


  testWidgets('keeps the cloud session visible when sign-out fails', (tester) async {
    final gateway = _FakeCloudAuthGateway()
      ..user = const CloudAuthUser(uid: 'uid-1', email: 'owner@example.com')
      ..signOutError = StateError('network-unavailable');
    final storeGateway = _FakeCloudStoreGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: CloudAccountScreen(
          gateway: gateway,
          storeGateway: storeGateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cerrar sesión en la nube'));
    await tester.tap(find.text('Cerrar sesión en la nube'));
    await tester.pumpAndSettle();

    expect(gateway.signOutCalls, 1);
    expect(find.text('Sesión iniciada'), findsOneWidget);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(
      find.textContaining('No se pudo cerrar la sesión en la nube'),
      findsOneWidget,
    );
    expect(storeGateway.createCalls, 0);

    await gateway.dispose();
  });

  testWidgets('recovers active stores for the signed-in account', (tester) async {
    final gateway = _FakeCloudAuthGateway()
      ..user = const CloudAuthUser(uid: 'uid-1', email: 'owner@example.com');
    final storeGateway = _FakeCloudStoreGateway()
      ..stores = const [
        CloudStore(id: 'store-a1', name: 'Tienda El Edén', ownerUid: 'uid-1'),
        CloudStore(id: 'store-b2', name: 'Sucursal Centro', ownerUid: 'uid-2'),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: CloudAccountScreen(
          gateway: gateway,
          storeGateway: storeGateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(storeGateway.listCalls, 1);
    expect(find.text('Mis tiendas'), findsOneWidget);
    expect(find.text('Tienda El Edén'), findsOneWidget);
    expect(find.text('Sucursal Centro'), findsOneWidget);
    expect(find.textContaining('todavía no se han sincronizado'), findsNothing);

    await gateway.dispose();
  });

  testWidgets('recovers store list after a cloud query error', (tester) async {
    final gateway = _FakeCloudAuthGateway()
      ..user = const CloudAuthUser(uid: 'uid-1', email: 'owner@example.com');
    final storeGateway = _FakeCloudStoreGateway()
      ..listError = StateError('unavailable');

    await tester.pumpWidget(
      MaterialApp(
        home: CloudAccountScreen(
          gateway: gateway,
          storeGateway: storeGateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron recuperar tus tiendas.'), findsOneWidget);
    expect(storeGateway.createCalls, 0);

    storeGateway
      ..listError = null
      ..stores = const [
        CloudStore(id: 'store-recovered', name: 'Tienda recuperada', ownerUid: 'uid-1'),
      ];

    await tester.ensureVisible(find.text('Reintentar'));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(storeGateway.listCalls, 2);
    expect(find.text('Tienda recuperada'), findsOneWidget);
    expect(find.text('No se pudieron recuperar tus tiendas.'), findsNothing);
    expect(storeGateway.createCalls, 0);

    await gateway.dispose();
  });

  testWidgets('creates a store only after explicit confirmation', (tester) async {
    final gateway = _FakeCloudAuthGateway()
      ..user = const CloudAuthUser(uid: 'uid-1', email: 'owner@example.com');
    final storeGateway = _FakeCloudStoreGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: CloudAccountScreen(
          gateway: gateway,
          storeGateway: storeGateway,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Tienda El Edén');
    expect(storeGateway.createCalls, 0);
    await tester.ensureVisible(find.text('Crear tienda'));
    await tester.tap(find.text('Crear tienda'));
    await tester.pumpAndSettle();

    expect(storeGateway.createCalls, 1);
    expect(storeGateway.lastName, 'Tienda El Edén');
    expect(find.text('Tienda creada'), findsOneWidget);
    expect(find.text('store-test-1'), findsOneWidget);
    expect(find.textContaining('todavía no se han sincronizado'), findsOneWidget);

    await gateway.dispose();
  });

  testWidgets('does not attempt a remote write for an empty store name',
      (tester) async {
    final gateway = _FakeCloudAuthGateway()
      ..user = const CloudAuthUser(uid: 'uid-1', email: 'owner@example.com');
    final storeGateway = _FakeCloudStoreGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: CloudAccountScreen(
          gateway: gateway,
          storeGateway: storeGateway,
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Crear tienda'));
    await tester.tap(find.text('Crear tienda'));
    await tester.pump();

    expect(storeGateway.createCalls, 0);
    expect(find.text('Escribe el nombre de la tienda.'), findsOneWidget);

    await gateway.dispose();
  });

  testWidgets('shows a safe message when store creation fails', (tester) async {
    final gateway = _FakeCloudAuthGateway()
      ..user = const CloudAuthUser(uid: 'uid-1', email: 'owner@example.com');
    final storeGateway = _FakeCloudStoreGateway()..error = StateError('permission-denied');

    await tester.pumpWidget(
      MaterialApp(
        home: CloudAccountScreen(
          gateway: gateway,
          storeGateway: storeGateway,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Tienda de prueba');
    await tester.ensureVisible(find.text('Crear tienda'));
    await tester.tap(find.text('Crear tienda'));
    await tester.pumpAndSettle();

    expect(storeGateway.createCalls, 1);
    expect(find.textContaining('tus datos locales no se han modificado'), findsOneWidget);
    expect(find.byKey(const ValueKey('created-store-result')), findsNothing);

    await gateway.dispose();
  });

  testWidgets('allows creating another store after a successful creation', (tester) async {
    final gateway = _FakeCloudAuthGateway()
      ..user = const CloudAuthUser(uid: 'uid-1', email: 'owner@example.com');
    final storeGateway = _FakeCloudStoreGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: CloudAccountScreen(
          gateway: gateway,
          storeGateway: storeGateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Tienda principal');
    await tester.ensureVisible(find.text('Crear tienda'));
    await tester.tap(find.text('Crear tienda'));
    await tester.pumpAndSettle();

    expect(storeGateway.createCalls, 1);
    expect(find.text('store-test-1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Sucursal nueva');
    await tester.ensureVisible(find.text('Crear tienda'));
    await tester.tap(find.text('Crear tienda'));
    await tester.pumpAndSettle();

    expect(storeGateway.createCalls, 2);
    expect(storeGateway.lastName, 'Sucursal nueva');
    expect(find.text('store-test-2'), findsOneWidget);

    await gateway.dispose();
  });
}
