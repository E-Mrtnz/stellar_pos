# Prueba de persistencia de la outbox

Antes de habilitar la sincronización comercial, la cola debe probarse contra Hive real en un directorio temporal:

1. Guardar un evento pendiente, cerrar Hive, reabrir la misma caja y comprobar que el evento y sus metadatos se conservan.
2. Guardar un evento, marcarlo como entregado, cerrar y reabrir Hive; comprobar que no vuelve a aparecer en la lista de pendientes.
3. Simular un evento `inFlight` persistido, reabrir y comprobar recuperación controlada a `pending` con el contador incrementado.
4. Ejecutar los tests en aislamiento y limpiar la caja/directorio temporal entre casos.

No activar un worker ni conectar repositorios comerciales hasta que exista idempotencia remota, autorización del servidor y política de conflictos por entidad.