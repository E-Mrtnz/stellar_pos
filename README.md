# STELLAR POS

Aplicación de punto de venta construida con Flutter. La caja y los datos operativos locales usan almacenamiento local para permitir trabajar sin iniciar sesión ni depender de Internet.

## Estado de la nube

- Inicio de sesión opcional y administración explícita de tiendas.
- Invitaciones de tienda mediante Firebase Callable Functions: generar, aceptar y revocar códigos con vencimiento y usos limitados.
- Pruebas automatizadas para Flutter, reglas de Firestore y funciones con Firebase Emulator Suite.
- Existe una outbox local experimental y un receptor remoto de **datos sintéticos exclusivamente**.
- **La sincronización de productos, ventas, inventario, compras, pagos y deudas no está habilitada.** No se suben datos comerciales locales al crear una tienda o iniciar sesión.

## Validación

En la rama `feature/cloud-storage-v2`, los workflows de GitHub Actions ejecutan:

- `flutter pub get`, `flutter analyze` y `flutter test`.
- `npm run test:rules` para las reglas de Firestore en el emulador.
- `npm run test:receiver` para el receptor sintético y las funciones de invitaciones.

Para trabajar localmente, instala Flutter estable 3.35.0, Node.js 20 y las dependencias del proyecto. No despliegues reglas ni funciones a producción sin verificar el proyecto Firebase seleccionado y aprobar explícitamente el despliegue.

Documentación técnica: `docs/firestore-data-contract.md`, `docs/incremental-sync-protocol.md`, `docs/cloud-sync-idempotency-contract.md` y `docs/cloud-store-phase-3-review.md`.
