# STELLAR POS — Protocolo de sincronización incremental (diseño)

**Estado:** protocolo de diseño con contratos de dominio y una outbox local inicial implementados. No activa sincronización comercial ni escribe datos en Firebase.

## Objetivo

Mantener Hive como almacenamiento operativo local y sincronizar automáticamente en segundo plano únicamente los cambios pendientes. Abrir la aplicación no debe desencadenar una descarga completa ni subir toda la base de datos.

## Componentes requeridos

- **Outbox durable local:** la cola actual serializa sus operaciones dentro de una instancia para evitar carreras entre altas simultáneas con el mismo ID; los tests cubren colisiones concurrentes y reconstrucción del objeto usando almacenamiento falso. Esto no sustituye una prueba de cierre/reapertura real de Hive ni garantiza atomicidad con la mutación comercial. Cada cambio local deberá generar un evento persistido junto con la mutación local, en la misma transacción Hive cuando el modelo lo permita. Un evento incluye `eventId` estable, `storeId`, tipo de entidad, `entityId`, operación, versión local, fecha de creación, origen y estado de entrega.
- **Procesador de salida:** lee solo eventos pendientes, comprueba sesión y membresía, envía lotes acotados y marca entregados únicamente tras confirmación remota. Reintenta errores transitorios con backoff; no reintenta indefinidamente errores permanentes de permisos. Ya existe una política pura `CloudSyncRetryPolicy` con espera exponencial acotada (2 segundos iniciales, máximo 15 minutos y 8 intentos por defecto); aún no está conectada a un trabajador ni clasifica errores por sí sola.
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

1. Completar pruebas unitarias aisladas de la outbox (idempotencia, colisión de IDs, aislamiento por tienda, estados y reintentos), sin conectar repositorios de negocio.
2. Probar persistencia real de la cola tras cerrar/reabrir la app y recuperación de eventos que quedaron `inFlight`, usando un gateway falso.
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

Este documento combina el contrato de diseño con el estado de implementación; todavía no existe sincronización comercial activa. No ejecutar despliegues de producción ni migraciones de Hive como parte de esta fase.


## Progreso de implementación (2026-10-14)

- Añadidos contratos de dominio puros en `lib/core/cloud_sync_protocol.dart` para eventos, estados, validación por tienda y cursores monotónicos.
- Añadida una cola local Hive en `lib/core/cloud_sync_outbox.dart`. Usa IDs estables, hace idempotente la inserción, conserva estados y permite reintentar un evento incrementando el contador de intentos. La cola valida los metadatos básicos de los eventos nuevos antes de persistirlos (tienda, estado pendiente, IDs, versión e intentos no negativos), para que los eventos mal formados fallen en el límite local.
- La cola no tiene conexión con Firebase y no se inicia automáticamente. Se añadió `recoverInterruptedEvents()` para devolver a pendientes los eventos que quedaron `inFlight` tras un cierre inesperado, aumentando el contador de intentos. Todavía no está conectada a las mutaciones de productos/ventas ni al inicio de la app.
- Antes de integrar cambios comerciales hacen falta pruebas de persistencia/reapertura real, validación de payloads corruptos, coordinación atómica entre mutación local y outbox, y un transporte remoto idempotente. La recuperación de `inFlight` puede repetir una petición cuya respuesta se perdió; no debe usarse con datos comerciales hasta tener idempotencia remota. La outbox sola no garantiza entrega remota ni sincronización.
- No ejecutar escrituras de negocio ni desplegar reglas de producción como parte de este paso.
