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
