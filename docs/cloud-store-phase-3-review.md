# STELLAR POS — Revisión de creación segura de tiendas

**Rama:** `feature/cloud-storage-v2`  
**Fecha:** 2026-10-14  
**Alcance:** alta/consulta explícita de tiendas y ciclo de vida de cuenta. No conecta el almacenamiento local ni habilita sincronización de datos de negocio.

## Hallazgos confirmados

- `lib/main.dart` inicializa Hive y el esquema local antes de mostrar la app. Firebase se inicializa en segundo plano y no es requisito para abrir la caja.
- `CloudAuthGateway` identifica al usuario, pero no le concede acceso a una tienda.
- `CloudStoreRole` / `StoreMembership` y el contrato de invitaciones ya existían como modelos de dominio; no ejecutaban operaciones remotas.
- `CloudFirestoreRepository` ofrece CRUD genérico, pero no debe conectarse directamente a los repositorios de productos, ventas, compras, inventario, clientes o deudas.
- `firestore.rules` denegaba todas las operaciones. Esta postura evitaba escrituras accidentales, pero también impedía cualquier alta de tienda.

## Cambio acotado en esta fase

Se añade `CloudStoreRepository.createStore`, que realiza una operación explícita y pequeña:

1. Requiere una sesión autenticada.
2. Valida el nombre visible (1–80 caracteres).
3. Genera un `storeId` aleatorio, independiente del nombre.
4. Envía un único batch atómico de dos documentos: metadatos de la tienda y membresía inicial del propietario.
5. Devuelve los metadatos de la tienda; no consulta ni sube registros locales.

La regla de Firestore acepta el alta solo si ambos documentos se crean en la misma operación y el UID autenticado coincide con el propietario y la membresía `owner`. Se permite leer los metadatos y membresías de una tienda solo a miembros autenticados activos. La política continúa denegando actualizaciones/eliminaciones de tiendas y membresías, invitaciones, y todas las rutas de negocio no especificadas.

**Presupuesto de escritura de la operación:** dos documentos por alta de tienda, una sola vez por acción explícita del usuario. No se ejecuta al arrancar la app, iniciar sesión, abrir una pantalla ni editar productos. La interfaz de Cuenta en la nube ya permite consultar tiendas y crear una tienda de forma explícita; también explica que las invitaciones aún no están disponibles.

## Por qué no se habilita todavía la sincronización

Las invitaciones seguras requieren un flujo de aceptación confiable y atómico; no se deben resolver exponiendo el hash de un código o permitiendo que el cliente cambie su propio rol. La outbox local, la idempotencia de eventos de negocio y la prevención de bucles de eco también siguen pendientes. Por tanto, esta fase no toca Hive, ventas, productos, inventario, compras, pagos ni deudas.

## Validación automatizada

El workflow de GitHub Actions se amplía para ejecutar:
- pruebas Flutter de acceso a nube, rutas y construcción perezosa de repositorios;
- pruebas de reglas con Firebase Emulator Suite sobre el proyecto ficticio `demo-stellar-pos`.

Los casos de reglas deben demostrar tanto el alta atómica válida como el rechazo de alta sin membresía, suplantación del propietario y escrituras de productos. Las pruebas del emulador no despliegan reglas ni acceden al proyecto real `stellar-pos-86f0c`.

## Estado y siguientes pasos

La interfaz para crear tiendas mediante acción explícita, consultar tiendas y reintentar una consulta fallida ya está implementada y cubierta por pruebas. Tras crear una tienda, el usuario puede crear otra desde la misma sesión; el control de estado evita solicitudes duplicadas mientras una operación está en curso.

Pendiente antes de conectar datos de negocio:

1. Ejecutar localmente `npm run test:rules` y las pruebas Flutter en el entorno del desarrollador.
2. Revisar las reglas y desplegarlas explícitamente a Firebase solo tras confirmar el proyecto destino y la aprobación del propietario.
3. Diseñar invitaciones mediante un flujo confiable y probar permisos positivos/negativos.
4. Diseñar una outbox durable y sincronización incremental con datos sintéticos, sin activar aún escrituras de negocio.

No crear colecciones manualmente ni cargar el inventario actual durante esta fase.
