# STELLAR POS — Protocolo de sincronización incremental (diseño)

**Estado (2026-10-16):** contratos de eventos con payload, outbox local, política de conflictos por entidad, cursor local monotónico y un trabajador manual limitado a eventos sintéticos implementados. No activa sincronización comercial ni se inicia automáticamente.

## Objetivo

Mantener Hive como almacenamiento operativo local y sincronizar automáticamente en segundo plano únicamente los cambios pendientes. Abrir la aplicación no debe desencadenar una descarga completa ni subir toda la base de datos.

## Componentes requeridos

- **Outbox durable local:** la cola actual serializa sus operaciones dentro de una instancia para evitar carreras entre altas simultáneas con el mismo ID; los tests cubren colisiones concurrentes y reconstrucción del objeto usando almacenamiento falso. Esto no sustituye una prueba de cierre/reapertura real de Hive ni garantiza atomicidad con la mutación comercial. Cada cambio local deberá generar un evento persistido junto con la mutación local, en la misma transacción Hive cuando el modelo lo permita. Un evento incluye `eventId` estable, `storeId`, tipo de entidad, `entityId`, operación, versión local, fecha de creación, origen y estado de entrega.
- **Procesador de salida:** existe `CloudSyncWorker.runOnce`, con límite de lote, comprobación de sesión/membresía, reintentos y bloqueo de errores permanentes. Su transporte integrado acepta exclusivamente `syntheticTestValue`; las entidades comerciales se bloquean antes de la red. El worker es manual, no está conectado al arranque/lifecycle ni a repositorios de negocio. La política pura `CloudSyncRetryPolicy` define backoff exponencial (2 segundos iniciales, máximo 15 minutos y 8 intentos), pero la planificación temporal de reintentos debe ser proporcionada por un coordinador futuro.
- **Idempotencia remota:** el identificador de evento/documento es estable. Repetir una petición tras un timeout no puede crear una venta o un pago duplicado. El servidor debe poder reconocer eventos ya aplicados.
- **Cursor de entrada:** `CloudSyncCursorStore` persiste el cursor local por tienda y dispositivo, y rechaza movimientos hacia atrás o cursores de otra tienda. Todavía no hay lector remoto de cambios ni aplicación de páginas; el cursor solo se debe avanzar después de aplicar una página completa de forma durable.
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


## Fase de aislamiento remoto (2026-10-15)

- Se ampliaron las pruebas de reglas para verificar explícitamente que un miembro activo no pueda leer los metadatos de otra tienda sin membresía, consultar la membresía de otro usuario en otra tienda ni escribir documentos sintéticos de eventos de sincronización.
- Estas pruebas usan únicamente el Firebase Emulator y documentos sintéticos; no cambian reglas ni datos del proyecto de producción.
- El transporte remoto idempotente sigue pendiente: todavía no hay trabajador ni escritura de eventos en Firestore. Por tanto, estas pruebas validan límites de autorización, no demuestran aún idempotencia de un backend real.
- La sincronización comercial permanece deshabilitada. No conectar ventas, inventario, productos, pagos o deudas hasta que exista un receptor remoto idempotente y pruebas de integración que demuestren deduplicación ante reintentos y timeouts.

## Registro de avance — 2026-10-15

- La suite de CI para el protocolo, outbox, recuperación Hive, política de reintentos y reglas Firestore terminó correctamente en el commit `6b9407a`.
- Se agregó una prueba negativa para asegurar que los clientes, incluso miembros activos, no puedan leer ni escribir directamente `syncReceipts` ni `syncEvents`. Esto protege las rutas reservadas al futuro receptor confiable.
- La validación del protocolo ahora tiene pruebas explícitas para `attemptCount < 0` y `localVersion < 0`.
- Se actualizó `docs/cloud-sync-idempotency-contract.md` para dejar explícita la puerta que falta: no hay todavía un paquete Firebase Functions ni receptor remoto implementado. Las pruebas actuales no demuestran idempotencia del servidor.
- No se modificaron repositorios de negocio ni el flujo de arranque; no hay escrituras de negocio ni despliegue de producción.

**Estado actualizado (2026-10-16):** contratos de dominio y outbox local bajo pruebas; permisos directos de cliente cerrados; existe un receptor confiable exclusivamente sintético (`acceptSyntheticSyncEvent`) con transacción idempotente y pruebas de Firebase Functions Emulator. Este receptor no acepta entidades comerciales ni está conectado a la outbox. No habilitar sincronización comercial.


## Implementación segura — 2026-10-16

- Los eventos de outbox ahora conservan su payload en Hive. La detección de reutilización de `eventId` compara contenido JSON canónico, de modo que el orden de claves de un mapa no cambia la identidad y un payload diferente se rechaza.
- Se añadió `CloudSyncCursorStore`, con cursor local monotónico por `storeId` y `deviceId`, validación de corrupción y pruebas aisladas.
- Se añadieron decisiones explícitas de conflicto: metadatos descriptivos pueden usar comparación de versión; inventario debe usar movimientos; ventas, pagos y deudas requieren reconciliación específica y no usan última escritura gana.
- Se añadió `CloudSyncWorker.runOnce` y un transporte callable para `acceptSyntheticSyncEvent`. El worker consulta la membresía activa, limita el lote y solo envía `syntheticTestValue`; los eventos `sale`, `product`, `inventory`, `payment` y `debt` quedan bloqueados. También existe `pullSyntheticSyncChanges` y `CloudSyncPullCoordinator` para traer páginas sintéticas por cursor y persistir el cursor tras aplicar la página completa. Nada está conectado al arranque de la app ni a mutaciones locales, por lo que no cambia el comportamiento de la caja offline.
- El pull remoto por cursor y su coordinador de cliente están implementados exclusivamente para cambios sintéticos: el backend pagina por versión global de tienda, el cliente valida la página y solo persiste el cursor después de aplicar todos los cambios. La outbox aún no es atómica con los repositorios Hive de negocio porque la persistencia comercial actual y la cola usan cajas separadas y no existe una transacción multi-caja confirmada.
- `SaleRecord` ya mantiene `id`/ `saleId` como identidad local y un campo `saleNumber` nullable. No se ha implementado la asignación de número secuencial en una transacción de servidor junto con la aceptación idempotente de la venta; por tanto, no debe anunciarse como terminado ni conectarse a ventas reales.
- Pendiente antes de piloto comercial: integración atómica/recoverable entre los cambios Hive y la outbox; conectar el worker con `acceptCloudSale` sin enviar el resto de entidades; pull remoto de ventas con aplicación local sin eco; planificador/reanudación del worker; políticas por entidad y pruebas end-to-end de dos dispositivos, desconexión, timeout y reconciliación. No desplegar funciones/reglas a producción ni habilitar sincronización comercial en esta fase.


## Progreso adicional (2026-10-16)

- Añadido `CloudMutationJournal` como diario write-ahead durable: persiste la intención antes de aplicar la mutación local, vuelve a intentar el upsert idempotente, encola el evento con ID estable y registra el avance de cada etapa. La recuperación está limitada por tienda y tamaño de lote. El applier debe ser idempotente; no existe una transacción atómica entre cajas Hive distintas.
- Añadido `pullCloudSales` en Functions: pagina un registro de cambios de ventas por cursor monotónico de tienda, comprueba autenticación y membresía activa, y permite lectura a los roles de tienda. La aceptación de cada venta escribe la venta, el recibo de idempotencia, la secuencia comercial y el registro de cambio dentro de la misma transacción.
- Añadido el coordinador cliente `CloudSalesPullCoordinator`, que valida tienda, tipo de entidad, identidad, versión consecutiva y número de venta; aplica toda la página antes de persistir el cursor. La aplicación concreta debe hacer upsert por ID y no generar un evento de salida.
- Estos componentes no activan sincronización al iniciar la app, no se despliegan a producción y no habilitan automáticamente ventas ni otras entidades comerciales. El worker de salida sigue limitado a datos sintéticos. El coordinador de ventas remoto aún necesita conectarse al punto de entrada local con un applier idempotente real y completar la aceptación cliente-número con persistencia local, antes de habilitarse a usuarios.
- Productos, movimientos de inventario, compras, pagos y deudas siguen bloqueados; necesitan contratos específicos, ledger y pruebas de reconciliación antes de activarse.

- Añadidos `CloudSaleSyncCoordinator` y `SaleRepositoryCloudRemoteApplier`: el primero consulta la membresía, usa el ID estable para repetir la aceptación y guarda el número devuelto por el servidor; el segundo hace upsert local idempotente y rechaza conflictos de contenido. Son servicios explícitos, no se llaman automáticamente desde el checkout.
- Añadido `CloudSyncScheduler` con inicio explícito, pausa en segundo plano, ejecución al reanudar, coalescencia de ejecuciones concurrentes y backoff. No se registra automáticamente en el arranque de la aplicación; debe permanecer inactivo hasta que exista una pantalla de consentimiento y un flujo de activación probado.


## Ledger comercial inmutable — avance (2026-10-16)

- Se añadió el receptor callable `acceptCloudLedgerEntry` para movimientos de inventario firmados, compras, movimientos de deuda y transacciones de saldo electrónico. El backend valida identidad, tipos, cantidades/importes, fechas, límites de tamaño y campos de los artículos de compra.
- Cada entrada se almacena con un recibo idempotente dentro de una transacción Firestore y genera una versión en un feed paginado por tienda. Repetir el mismo ID y contenido devuelve el resultado anterior; reutilizarlo con contenido distinto se rechaza. Los miembros activos con rol de caja/gestión pueden escribir; los lectores activos pueden recibir el feed.
- Se añadió `CloudFunctionsLedgerGateway` en Dart para llamar al receptor y leer páginas. Valida tienda, identidad, tipos de entidad, orden de versiones y cursor antes de entregar los datos al coordinador.
- El inventario remoto usa movimientos firmados e inmutables, no una sobrescritura de `Product.stock`. La recepción de páginas aún requiere un applier local que proyecte movimientos de manera idempotente y un cursor Hive conectado a esa aplicación.
- **No es todavía sincronización comercial completa ni activada.** La cola general sigue limitada a eventos sintéticos; el gateway ledger no se conecta automáticamente a repositorios ni al planificador. Productos descriptivos, proyección de inventario, recepción/aplicación de compras y movimientos monetarios necesitan coordinadores locales y pruebas end-to-end antes de habilitarse. No desplegar Functions ni reglas en producción.


## Applier local durable para ledger — 2026-10-16

- Se añadió `DurableCloudLedgerRemoteApplier`, un dispatcher local con recibos durables por evento. Valida identidad y contenido, evita volver a ejecutar eventos cuyo recibo ya existe y guarda el recibo después de que el manejador de entidad termina correctamente.
- El dispatcher exige un manejador explícito para cada tipo; si falta, falla de forma cerrada. Esto evita fingir que ya existen reglas de proyección para inventario, compras, deudas o saldo electrónico.
- Cada manejador sigue obligado a ser idempotente por ID de evento/entidad: una interrupción puede ocurrir después de guardar la proyección local y antes del recibo. Los recibos en una caja separada no garantizan atomicidad entre la proyección comercial y el cursor.
- Se añadieron pruebas para repetición, colisión de contenido, fallo de persistencia y manejador ausente, integradas en CI.
- **Estado pendiente:** los manejadores reales aún no están conectados a los repositorios de negocio; el envío comercial general sigue bloqueado y el scheduler no está activado. No habilitar sincronización comercial ni desplegar Functions/reglas a producción hasta cerrar esa integración y validar los flujos completos en emuladores.


## Recibos remotos persistentes en Hive — 2026-10-18

- Se añadió `HiveCloudLedgerApplyReceiptStore`, que guarda recibos de aplicación por ID de evento en una caja Hive separada y permite recuperarlos tras cerrar/reabrir la base local.
- El test de persistencia cubre que el recibo y su ámbito de tienda sobreviven a la reapertura. El dispatcher durable y esta implementación se incluyen en el análisis y las pruebas de CI.
- Esto cierra la persistencia del recibo, pero no la atomicidad entre recibo y proyección comercial. Los handlers de cada entidad todavía deben hacer upsert idempotente y no generar eventos de salida al aplicar cambios remotos. Por esa razón, no se activa el pull comercial en la interfaz ni en el inicio de la app.


## Aplicación local de registros del ledger — 2026-10-18

- Se añadieron manejadores que hacen upsert idempotente por ID para registros de compra, movimientos de deuda y transacciones de saldo electrónico, rechazando reutilizaciones del mismo ID con contenido diferente.
- Los movimientos de inventario remoto se conservan en una caja local inmutable con validación de producto y delta. **Todavía no modifican `Product.stock`**: hace falta una estrategia de proyección recuperable para evitar aplicar el delta dos veces si la app se interrumpe entre la escritura del stock y la del recibo.
- Estos manejadores se conectan al dispatcher mediante un mapa explícito y no crean eventos de salida, pero todavía no se han conectado al pull comercial ni al scheduler. La sincronización sigue desactivada por defecto.


## Coordinador explícito de envío del ledger — 2026-10-18

- Se añadió `CloudLedgerSyncCoordinator`: antes de enviar una entrada inmutable valida IDs estables y exige sesión/membresía activa. No reintenta con IDs nuevos ni altera el registro local.
- Incluye pruebas de membresía denegada, identidad estable y aceptación explícita.
- Sigue siendo un punto de entrada manual para quien lo integre; no está enlazado a mutaciones de repositorios, checkout ni ejecución en segundo plano. La sincronización automática permanece deshabilitada hasta completar la proyección de inventario y la integración recoverable con el diario local.


- Se añadió una fábrica de composición que conecta el dispatcher durable, los recibos Hive y los manejadores locales actuales. La fábrica solo construye servicios: no inicia pulls, no activa el scheduler ni cambia el comportamiento de caja.
