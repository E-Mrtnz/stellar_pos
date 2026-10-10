# STELLAR POS — Revisión técnica de la fase 2

**Rama:** `feature/cloud-storage-v2`  
**Fecha:** 2026-10-10  
**Alcance:** revisión estática del código versionado; no se ejecutó Flutter ni se accedió a la consola de Firebase desde esta revisión.

## Hallazgo corregido

### El adaptador Firestore se resolvía demasiado pronto

Antes, el constructor de `CloudFirestoreRepository` evaluaba `FirebaseFirestore.instance` inmediatamente. Si algún consumidor construía el repositorio antes de terminar la inicialización opcional de Firebase, el constructor podía fallar aunque todavía no se hubiera solicitado una operación remota.

Se cambió a resolución perezosa: el constructor guarda únicamente una instancia inyectada opcionalmente, y el SDK predeterminado se consulta después de `CloudFirebase.ensureReady()` dentro de cada operación. Se agregó una prueba unitaria que verifica que construir el repositorio no requiere inicializar Firebase.

## Estado y límites que permanecen

- Hive sigue siendo la dependencia requerida para el arranque y la persistencia local.
- Firebase se inicializa de manera asíncrona después de `runApp`; los errores se capturan y se exponen mediante `CloudFirebase.status`.
- `CloudFirestoreRepository` es un adaptador CRUD genérico. No debe conectarse todavía a ventas, productos, inventario, compras, pagos ni deudas.
- `firestore.rules` continúa denegando todas las lecturas y escrituras. Es la postura segura temporal; el CRUD remoto fallará por permisos hasta que se diseñen, implementen y prueben reglas por membresía.
- La validación de `CloudPaths` evita rutas malformadas, pero no autoriza usuarios ni tiendas.
- `firebase_options.dart` no configura Firebase para Windows ni Linux. La inicialización en esas plataformas queda como no disponible y debe seguir sin impedir el uso local. Antes de ofrecer nube en esas plataformas, hay que configurar y validar sus opciones.
- El archivo `firebase.json` identifica el archivo local de reglas, pero esta revisión no verifica qué reglas están actualmente desplegadas en el proyecto remoto.

## Siguiente secuencia segura

1. Ejecutar `flutter test test/core/cloud_paths_test.dart test/core/cloud_firestore_repository_test.dart` y `flutter analyze` en el entorno local.
2. Preparar pruebas de reglas con Firebase Emulator Suite, incluyendo usuario sin sesión, usuario sin membresía, aislamiento entre tiendas y permisos por rol.
3. Implementar autenticación y membresía solo después de acordar el flujo de invitación y los permisos administrativos.
4. Recién entonces habilitar un CRUD limitado a datos sintéticos y, más adelante, diseñar la outbox local durable y sincronización incremental.
5. No desplegar reglas permisivas ni usar datos reales hasta pasar las pruebas de aislamiento.

## Evidencia

Esta revisión fue estática, basada en los archivos de la rama. La prueba agregada está versionada, pero todavía no se ha ejecutado en el equipo del usuario ni en CI desde esta revisión.
