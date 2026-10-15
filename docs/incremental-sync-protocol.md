# STELLAR POS — Protocolo de sincronización incremental (diseño)

**Estado:** diseño previo a implementación. No activa sincronización ni escribe datos en Firebase.

## Objetivo

Mantener Hive como almacenamiento operativo local y sincronizar automáticamente en segundo plano únicamente los cambios pendientes. Abrir la aplicación no debe desencadenar una descarga completa ni subir toda la base de datos.

## Componentes requeridos

- **Outbox durable local:** cada cambio local genera un evento persistido junto con la mutación local, en la misma transacción Hive cuando el modelo lo permita. Un evento incluye `eventId` estable, `storeId`, tipo de entidad, `entityId`, operación, versión local, fecha de creación, origen y estado de entrega.
- **Procesador de salida:** lee solo eventos pendientes, comprueba sesión y membresía, envía lotes acotados y marca entregados únicamente tras confirmación remota. Reintenta errores transitorios con backoff; no reintenta indefinidamente errores permanentes de permisos.
- **Idempotencia remota:** el identificador de evento/documento es estable. Repetir una petición tras un timeout no puede crear una venta o un pago duplicado. El servidor debe poder reconocer eventos ya aplicados.
- **Cursor de entrada:** por tienda y dispositivo, conserva el último cursor/versionado confirmado. Trae únicamente cambios posteriores a ese cursor; si el cursor expiró o la historia remota no está disponible, exige una reconciliación controlada, no una descarga silenciosa de toda la base.
- **Origen de cambio:** distingue `local` de `remote` para que aplicar un cambio remoto no cree otro evento de salida y forme un bucle.
- **Resolución de conflictos:** política específica por entidad. No usar “última escritura gana” como regla universal para cantidades de inventario, ventas, pagos o deudas.

## Secuencia normal

1. La operación se confirma localmente y se registra en la outbox durable.
2. Un trabajador de fondo intenta procesar eventos pendientes cuando existe red y una sesión válida.
3. El servicio remoto autoriza la tienda y la operación; responde con el resultado y la versión aplicada.
4. El cliente marca el evento como entregado, conservando un registro mínimo para detectar reintentos duplicados.
5. El cliente pide cambios posteriores al cursor conocido y aplica solo los cambios nuevos.
6. Los cambios recibidos se guardan localmente sin generar eventos de salida.
7. Si no hay red, las ventas locales continúan y la cola queda pendiente.

## Reglas para casos difíciles

- **Cierre de sesión:** pausar envío y recepción. No borrar datos locales ni eventos pendientes.
- **Cambio de cuenta/tienda:** no enviar una cola a otra tienda. Cada evento queda vinculado a su `storeId`; validar de nuevo la membresía antes de enviar.
- **Timeout después de escritura remota:** repetir con el mismo ID idempotente y consultar el estado antes de crear un nuevo evento.
- **Dos dispositivos:** detectar versiones concurrentes; para cantidades e importes, aplicar transacciones o movimientos inmutables cuando corresponda.
- **Eliminaciones:** representar borrados con tombstones versionados para que otro dispositivo no resucite registros antiguos.
- **Errores de permisos:** detener la operación y mostrar aviso accionable; no repetir sin límite.
- **Límites y costos:** lotes acotados, consultas por cursor, paginación y métricas; nada de lecturas/escrituras continuas en cada reconstrucción de widgets.

## Orden de implementación

1. Crear modelos y pruebas unitarias de eventos/outbox, sin conectar repositorios de negocio.
2. Probar persistencia de la cola, reinicio de app, reintentos y deduplicación usando un gateway falso.
3. Definir contrato de backend y reglas de autorización para una entidad sintética.
4. Ejecutar pruebas de integración en Firebase Emulator, incluyendo dos clientes, desconexión, duplicados y permisos negativos.
5. Habilitar un piloto opt-in con datos sintéticos, métricas y mecanismo de apagado.
6. Solo después aprobar una entidad comercial a la vez. No empezar simultáneamente con ventas, inventario, pagos y deudas.

## Condiciones para darlo por listo

- No se pierde un evento al cerrar o reiniciar la app.
- Repetir el mismo evento no duplica efectos.
- La recepción de un cambio no genera un evento de salida.
- Las ventas locales funcionan sin sesión o conexión.
- Un miembro no puede leer ni escribir otra tienda.
- Los conflictos tienen pruebas por tipo de entidad.
- Los tests demuestran que abrir la app sin cambios no dispara una descarga completa.

Este documento es un contrato de diseño; todavía no existe sincronización comercial activa. No ejecutar despliegues de producción ni migraciones de Hive como parte de esta fase.
