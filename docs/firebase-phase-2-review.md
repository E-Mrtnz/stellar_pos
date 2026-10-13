# STELLAR POS — Revisión técnica de la fase 2

**Rama:** `feature/cloud-storage-v2`  
**Fecha:** 2026-10-10  
**Alcance:** revisión estática del código versionado; las pruebas Flutter reportadas por el usuario pasaron (5 pruebas) y `flutter analyze` reportó cero problemas. Las pruebas de reglas Firestore en Node aún deben ejecutarse localmente.

## Hallazgo corregido: resolución prematura de Firestore

El constructor de `CloudFirestoreRepository` evaluaba `FirebaseFirestore.instance` inmediatamente. Si algún consumidor construía el repositorio antes de terminar la inicialización opcional de Firebase, podía fallar aunque todavía no se hubiera solicitado una operación remota.

Se cambió a resolución perezosa: el constructor guarda únicamente una instancia inyectada opcionalmente y el SDK predeterminado se consulta después de `CloudFirebase.ensureReady()` dentro de cada operación. Se agregó una prueba unitaria que verifica que construir el repositorio no requiere inicializar Firebase.

## Preparación del emulador de reglas

Se añadió configuración de Firestore Emulator a `firebase.json`, un conjunto de pruebas con `@firebase/rules-unit-testing` y un script npm. Las pruebas están aisladas al proyecto ficticio `demo-stellar-pos`; no despliegan reglas ni deben conectarse al proyecto real `stellar-pos-86f0c`.

Para ejecutarlas desde la raíz:

```bash
npm install
npm run test:rules
```

El conjunto comprueba que las reglas actuales deniegan lectura a usuarios anónimos y autenticados, y deniegan creación, actualización y eliminación. Esto verifica la postura temporal fail-closed, no la futura política de membresías. **La configuración y los tests están versionados, pero todavía no se han ejecutado en este entorno.**

## Estado y límites que permanecen

- Hive sigue siendo la dependencia requerida para el arranque y la persistencia local.
- Firebase se inicializa de manera asíncrona después de `runApp`; los errores se capturan y se exponen mediante `CloudFirebase.status`.
- `CloudFirestoreRepository` es un adaptador CRUD genérico. No debe conectarse todavía a ventas, productos, inventario, compras, pagos ni deudas.
- `firestore.rules` continúa denegando todas las lecturas y escrituras. Es la postura segura temporal; el CRUD remoto fallará por permisos hasta que se diseñen, implementen y prueben reglas por membresía.
- La validación de `CloudPaths` evita rutas malformadas, pero no autoriza usuarios ni tiendas.
- `firebase_options.dart` no configura Firebase para Windows ni Linux. La inicialización en esas plataformas queda como no disponible y debe seguir sin impedir el uso local.
- Esta revisión no verifica qué reglas están actualmente desplegadas en la consola de Firebase.

## Siguiente secuencia segura

1. Ejecutar `npm install` y `npm run test:rules` y confirmar que el emulador local pasa.
2. Definir el flujo de autenticación, creación de tienda, membresía y aceptación de invitaciones; el código de invitación no debe ser una credencial permanente.
3. Implementar reglas por membresía y roles junto con pruebas positivas y negativas: dueño, miembro, usuario sin membresía, acceso cruzado entre tiendas y cambios de roles no autorizados.
4. Solo después habilitar CRUD limitado a datos sintéticos.
5. Más adelante diseñar una outbox durable y sincronización incremental, manteniendo operaciones locales independientes de la red.

No desplegar reglas permisivas ni usar datos reales hasta pasar las pruebas de aislamiento.

## Evidencia

- El usuario informó que `flutter test test/core/cloud_paths_test.dart test/core/cloud_firestore_repository_test.dart` terminó con `00:04 +5: All tests passed!`.
- El usuario informó que `flutter analyze` produjo cero problemas.
- Los tests del emulador se agregaron al repositorio, pero aún falta ejecutarlos en el equipo local.


## Fase siguiente: contrato de identidad y membresías (2026-10-12)

Se agregaron los siguientes artefactos de dominio/documentación en `feature/cloud-storage-v2`:

- `lib/core/cloud_store_access.dart`: roles `owner`, `manager`, `cashier` y `viewer`; estado de membresía; metadatos de invitación con hash, expiración, revocación y límites de uso.
- `test/cloud_store_access_test.dart`: pruebas unitarias para permisos de rol de dominio, validación de UID/identificadores, valores de rol desconocidos y límites de invitaciones.
- `docs/store-identity-membership-design.md`: contrato de identidad, rutas, roles, protocolo de invitación y matriz de pruebas para el emulador.

**Límite importante:** estos modelos no son un mecanismo de autorización ni crean/aceptan invitaciones. No se añadió Firebase Authentication ni se conectó ningún repositorio de negocio. Las reglas de Firestore siguen denegando todas las operaciones remotas hasta que el flujo autenticado y las reglas positivas/negativas estén implementados.

### Validación local informada por el usuario

El usuario instaló Eclipse Temurin OpenJDK 21.0.12.1 y ejecutó `npm run test:rules` en el proyecto ficticio `demo-stellar-pos`. El registro compartido muestra:

- 4 pruebas de reglas aprobadas.
- 0 fallidas.
- El emulador terminó correctamente.

Esas cuatro pruebas verifican únicamente la postura temporal fail-closed. Las nuevas pruebas Dart de `cloud_store_access.dart` aún deben ejecutarse en el equipo local. No se desplegaron reglas y no se accedió a datos reales.


## Fase siguiente: puerta de autenticación (2026-10-13)

Se añadió una primera capa aislada de Firebase Authentication:

- `lib/core/cloud_auth_gateway.dart` define `CloudAuthUser`, `CloudAuthGateway` y el adaptador `FirebaseCloudAuth`.
- Expone cambios de sesión, consulta de usuario actual, registro con correo/contraseña, inicio de sesión, recuperación por correo y cierre de sesión.
- La instancia de Firebase Auth se resuelve de forma perezosa y cada operación explícita espera a `CloudFirebase.ensureReady()`. Instanciar el adaptador no inicializa Firebase.
- Se agregó `firebase_auth: 5.3.4`, versión alineada con `firebase_core: 3.8.1`, `cloud_firestore: 5.5.1` y Firebase iOS SDK 11.4.0 según la matriz de versiones FlutterFire.

**No se conectó esta capa a pantallas ni al arranque local.** Hive sigue funcionando como antes. La autenticación por correo/contraseña debe habilitarse en Firebase Console antes de probarla con el proyecto real. El estado autenticado no concede acceso a ninguna tienda: las reglas de Firestore continúan denegando todo, y las membresías/invitaciones todavía no se crean ni se aceptan.

### Validación pendiente en el equipo local

El usuario informó el 2026-10-13 que:
- `flutter test test/cloud_store_access_test.dart`: 8 pruebas aprobadas.
- `flutter analyze`: sin problemas.
- `npm run test:rules`: 4 pruebas aprobadas, 0 fallidas; solo confirma la política fail-closed.

Esos resultados corresponden al código anterior a esta capa de autenticación. Después de incorporar `firebase_auth`, hay que ejecutar `flutter pub get`, `flutter test` y `flutter analyze`. No se han ejecutado desde este entorno. No desplegar reglas ni conectar datos de negocio.


### Fase siguiente: interfaz de cuenta opcional (2026-10-13)

Se añadió `lib/core/cloud_auth_screen.dart`, una pantalla reutilizable de acceso a la nube con:
- Inicio de sesión y creación de cuenta por correo/contraseña.
- Recuperación de contraseña por correo.
- Validación de campos, indicador de carga y mensajes de error en español.
- Un `CloudAuthGateway` inyectado, para probar la interfaz sin Firebase real.

La pantalla **no es la ruta inicial ni se conectó al panel principal**. Esto es deliberado: no debe bloquear la caja local ni forzar una cuenta para vender sin conexión. El callback `onAuthenticated` solo notifica la identidad autenticada; no concede acceso a una tienda ni cambia las reglas.

Se agregó `test/core/cloud_auth_screen_test.dart` con pruebas de validación, inicio de sesión simulado y errores de credenciales. Estas pruebas aún deben ejecutarse localmente. Antes de probar contra el proyecto real, habilitar el proveedor Email/Password en Firebase Authentication Console. La aceptación de invitaciones, creación de membresías y permisos de Firestore continúan sin implementar; las reglas permanecen en denegación total.


### Fase siguiente: gestión explícita de sesión (2026-10-13)

Se agregó `lib/core/cloud_account_screen.dart` como pantalla reutilizable para acciones de cuenta:
- Muestra el estado de sesión mediante `CloudAuthGateway.authStateChanges()`.
- Si no hay sesión, permite abrir la pantalla de acceso/registro.
- Si hay sesión, muestra el correo o UID y permite cerrar sesión.
- Explica en la interfaz que autenticarse no concede membresía ni permisos de tienda.
- Los errores de sesión no bloquean ni cambian el flujo local de caja.

La pantalla sigue siendo opt-in y no se conectó automáticamente al inicio ni al menú de ajustes; el acceso de navegación debe integrarse después de validar la UI en los dispositivos objetivo. Se agregaron `test/core/cloud_account_screen_test.dart` para ausencia de sesión, identidad y cierre de sesión.

### Validación local informada el 2026-10-13

El usuario confirmó que `flutter test test/core/cloud_auth_gateway_test.dart test/core/cloud_auth_screen_test.dart test/cloud_store_access_test.dart` terminó con 13 pruebas aprobadas, y `npm run test:rules` con 4 pruebas aprobadas y 0 fallidas. `flutter analyze` había terminado sin problemas antes de la pantalla de cuenta. La nueva pantalla de cuenta y sus pruebas aún requieren `flutter test` y `flutter analyze`.

**Seguridad:** no hay flujo de membresía/aceptación de invitaciones ni reglas positivas implementadas. `firestore.rules` continúa denegando todas las operaciones. No desplegar reglas ni conectar datos de negocio.


### Integración de cuenta en Ajustes (2026-10-13)

La pantalla de cuenta ahora tiene una entrada explícita en **Ajustes → General → Cuenta y nube**:

- `lib/core/cloud_account_settings_tile.dart` encapsula la navegación a la pantalla de cuenta.
- `lib/presentation/settings/printer_settings_layout.dart` muestra la entrada tanto en el diseño general como en el diseño móvil, dentro del contenido de Ajustes generales.
- La pantalla solo se abre cuando el usuario toca la entrada; no se solicita autenticación al arrancar ni antes de registrar ventas.
- El texto aclara que la cuenta en la nube no es necesaria para vender localmente.
- `test/core/cloud_account_settings_tile_test.dart` cubre la indicación de opcionalidad y la navegación bajo demanda.

El usuario confirmó el 2026-10-13 que las 16 pruebas de `cloud_auth_gateway`, `cloud_auth_screen`, `cloud_account_screen` y `cloud_store_access` pasaron. Las nuevas pruebas de integración de la entrada de Ajustes se deben ejecutar localmente con el resto del conjunto.

**Límites de seguridad sin cambios:** Firestore continúa denegando todas las lecturas y escrituras; no se desplegaron reglas. Todavía no existe flujo de creación de tienda/membresía/invitaciones, ni se conectaron datos de negocio a la nube.
