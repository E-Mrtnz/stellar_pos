# Pruebas de persistencia de la outbox

**Estado:** las pruebas descritas en los puntos 1–3 están implementadas y pasan en GitHub Actions en la rama `feature/cloud-storage-v2`. Estas pruebas validan persistencia local; no demuestran entrega remota ni sincronización comercial.

## Casos cubiertos

1. Guardar un evento pendiente, cerrar Hive, reabrir la misma caja y comprobar que se conservan el ID, la versión, el estado y la fecha.
2. Guardar un evento, marcarlo como entregado, cerrar y reabrir Hive; comprobar que no vuelve a aparecer en la lista de pendientes y que el estado persistido sigue siendo `delivered`.
3. Dejar un evento en `inFlight`, simular el reinicio cerrando/reabriendo Hive y comprobar que `recoverInterruptedEvents()` lo devuelve a `pending` y aumenta el contador de intentos.
4. Aislar cada caso en un directorio temporal y cerrar Hive al terminar.

## Límites que siguen vigentes

- La prueba utiliza una caja Hive real con almacenamiento de prueba adaptado al contrato de la outbox; no valida el ciclo de vida completo de `LocalStorage` de la aplicación.
- La recuperación de `inFlight` puede repetir una solicitud que el servidor ya aplicó si se perdió la confirmación. No conectar datos comerciales hasta que el transporte remoto garantice idempotencia con un ID estable.
- La mutación de negocio y el registro de outbox todavía no forman una operación atómica común.
- La cola aún no tiene trabajador de red, cursor remoto durable ni política de conflictos por entidad.

No habilitar sincronización de productos, inventario, ventas, pagos o deudas ni desplegar reglas de producción como parte de estas pruebas. El siguiente paso seguro es diseñar y probar un contrato remoto idempotente y autorización en Firebase Emulator con datos sintéticos, antes de conectar repositorios comerciales.