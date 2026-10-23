# Contrato de idempotencia remota para sincronización incremental

**Estado (2026-10-16):** receptor confiable y transporte cliente implementados solo para `syntheticTestValue`, con pruebas de emulador. El contrato comercial sigue pendiente; nada está desplegado en producción ni se habilita sincronización comercial.

## Objetivo y límite de confianza

El cliente puede repetir una petición cuando pierde la respuesta del servidor. El servidor debe asegurar que repetir el mismo evento no aplique dos veces su efecto. Un ID estable en la outbox, una comprobación en Flutter o las reglas de Firestore por sí solos no garantizan esa propiedad.

El receptor debe ejecutarse en un entorno confiable (por ejemplo, una Cloud Function autenticada) y aplicar la autorización y la deduplicación en el servidor. El cliente no debe tener permiso de escribir directamente recibos de idempotencia ni eventos remotos.

## Contrato de solicitud

Cada solicitud debe contener, como mínimo:

- `eventId`: identificador opaco, estable en todos los reintentos.
- `storeId`: tienda objetivo.
- `entityType`, `entityId`, `operation` y `localVersion`.
- `schemaVersion`: versión del formato del evento.
- `payload`: contenido mínimo permitido para esa entidad; nunca aceptar campos arbitrarios como autoridad de permisos o de propiedad.

El servidor deriva el UID de la identidad autenticada. Nunca debe confiar en un UID enviado en el payload.

## Clave y recibo de idempotencia

La clave lógica debe estar delimitada por tienda y evento, por ejemplo `stores/{storeId}/syncReceipts/{eventId}`. El servidor calcula una huella canónica del contenido validado. La huella no debe depender del orden de las claves JSON ni incluir campos volátiles como la hora de recepción.

Dentro de una transacción de Firestore, el receptor debe:

1. Validar autenticación, membresía activa de la tienda, permisos de la operación, esquema y límites del payload.
2. Leer el recibo de idempotencia para la clave de tienda y evento.
3. Si existe y la huella coincide, devolver el resultado original como duplicado ya aplicado, sin repetir el efecto.
4. Si existe y la huella difiere, rechazar el evento con un error permanente de colisión de ID; nunca sobrescribir el recibo.
5. Si no existe, validar la versión/conflicto de la entidad y aplicar el cambio permitido junto con la creación del recibo en la misma transacción.
6. Devolver un resultado estable que incluya el ID del evento, el estado aplicado/duplicado y la versión remota confirmada.

Si la mutación no puede ejecutarse en la misma transacción que el recibo, esta estrategia no es suficiente; se necesita un diseño de operación durable adicional con estados y recuperación, no una escritura independiente seguida de otra escritura.

### Restricción actual de la outbox local

El receptor remoto delimita la idempotencia por tienda y evento, pero la outbox local actual almacena sus claves por `eventId` global, no por el par `(storeId, eventId)`. Por eso, si dos tiendas intentan encolar el mismo ID con contenido o identidad distinta, la segunda operación debe rechazarse sin modificar el registro existente. Esta protección evita contaminación silenciosa entre tiendas, pero no elimina el conflicto de disponibilidad: antes de permitir IDs reutilizables entre tiendas se necesita una migración compatible a claves compuestas y operaciones de estado que también reciban la tienda. No se debe solucionar sobrescribiendo el registro existente ni generando un ID nuevo automáticamente en un reintento.

## Semántica de errores para el cliente

- **Aplicado / duplicado confirmado:** marcar el evento local como entregado.
- **Transitorio** (red, límite temporal, indisponibilidad): conservar el mismo ID y contenido; reintentar con backoff limitado.
- **No autenticado / membresía revocada / permiso denegado:** detener el envío y bloquear o pausar el evento; no reintentar sin límite.
- **Validación o versión incompatible:** bloquear y presentar un error accionable.
- **Colisión de ID con contenido distinto:** bloquear, registrar diagnóstico sin datos sensibles y no generar automáticamente un nuevo ID.
- **Conflicto de versión:** resolver según política específica de la entidad. No aplicar “última escritura gana” de forma universal a inventario, ventas, pagos o deudas.

Un timeout no demuestra que la escritura haya fallado. El siguiente intento debe usar exactamente la misma clave y contenido para que el receptor devuelva el recibo anterior si el primer intento sí se confirmó.

## Reglas de seguridad requeridas

- Los clientes no pueden crear, modificar ni borrar recibos de idempotencia.
- Los clientes no pueden escribir eventos remotos ni mutar entidades comerciales mediante una ruta genérica de sincronización.
- Cada lectura/escritura debe comprobar membresía activa y que el UID autenticado corresponde al miembro.
- El servidor permite únicamente tipos de entidad, operaciones, campos y tamaños explícitamente enumerados.
- Las pruebas negativas deben verificar acceso anónimo, miembro de otra tienda, membresía revocada, intento de autoelevar permisos, campos no permitidos y escritura directa del recibo.
- No desplegar estas reglas ni una función a producción como parte de esta fase.

## Pruebas de integración que bloquean la activación

Usando exclusivamente Firebase Emulator y datos sintéticos, automatizar al menos:

1. Dos solicitudes simultáneas con la misma clave y mismo contenido: un solo efecto, mismo resultado lógico.
2. Repetición después de simular timeout tras la confirmación del servidor: no duplica el efecto.
3. Mismo ID con huella distinta: rechazo permanente y ningún segundo efecto.
4. Dos tiendas con el mismo ID de evento: aislamiento por tienda.
5. Usuario sin sesión, no miembro o miembro inactivo: rechazo y ninguna escritura.
6. Versión obsoleta y versiones concurrentes: respuesta de conflicto explícita.
7. Fallo antes de confirmar la transacción: no queda recibo sin efecto ni efecto sin recibo.
8. Cliente sin permiso de escribir directamente recibos/eventos remotos.
9. El cliente solo marca como entregado tras una respuesta confirmada; errores transitorios mantienen el ID estable.

## Puerta de activación

Hasta que el receptor confiable, las reglas y todas las pruebas anteriores estén implementados y verdes en el emulador, este contrato es solo diseño. Mantener la outbox aislada de las mutaciones comerciales y no sincronizar productos, inventario, ventas, pagos ni deudas. No realizar escrituras de negocio ni despliegues de producción durante esta fase.

## Implementación actual y siguiente puerta (2026-10-15)

El repositorio contiene una base Firebase Functions y el callable `acceptSyntheticSyncEvent`, que acepta únicamente la entidad de prueba `syntheticTestValue`. La función valida la sesión y membresía en servidor, calcula una huella canónica y aplica efecto/recibo idempotente en una transacción. Es un receptor confiable para pruebas sintéticas, no un transporte comercial ni una función desplegada en producción.

Ya se añadieron pruebas en el emulador de reglas para comprobar que incluso un miembro propietario no puede leer ni escribir directamente las rutas sintéticas `syncReceipts` y `syncEvents`. Estas pruebas verifican únicamente la frontera de reglas; no simulan ni prueban la función receptora.

### Puerta de implementación del receptor

Antes de crear el receptor, el siguiente cambio debe incorporar una base Firebase Functions aislada, con versiones fijadas y comandos locales de emulador. La función debe ser invocable solo con Firebase Auth válido, derivar el UID de `request.auth.uid`, comprobar la membresía activa en el servidor y aceptar exclusivamente un tipo de entidad sintética de prueba. No debe aceptar una ruta de colección o campos de permisos arbitrarios desde el cliente.

La transacción debe leer primero el recibo delimitado por tienda/evento; para una huella idéntica debe devolver el resultado original, para una huella diferente debe rechazar la colisión y, si no hay recibo, debe aplicar la mutación sintética y crear el recibo dentro de la misma transacción. Debe incluir pruebas de concurrencia, repetición tras timeout simulado, colisión, aislamiento entre tiendas, usuario no autenticado, membresía inactiva, versión conflictiva y fallo transaccional.

### Condición de activación

No conectar el receptor con la outbox ni con repositorios comerciales hasta que la suite de Functions Emulator cubra los casos anteriores y la suite de reglas permanezca verde. No desplegar Functions ni reglas en producción como parte de esta fase. Las pruebas existentes de reglas verdes no se deben interpretar como prueba de idempotencia de servidor.


## Estado adicional del cliente (2026-10-16)

El worker manual `CloudSyncWorker.runOnce` valida sesión/membresía, limita cada lote, conserva el mismo `eventId` en reintentos y solo marca entregado después de respuesta `applied` o `duplicate`. El transporte integrado permite únicamente la entidad sintética de prueba y rechaza otras entidades antes de enviar. La outbox persiste el payload y detecta colisiones comparando JSON canónico. La política de conflictos y el cursor local monotónico están probados de forma aislada.

No hay aún un worker programado en segundo plano, un pull remoto paginado ni coordinación atómica entre las mutaciones de las cajas Hive comerciales y la outbox. Existe `acceptCloudSale`, una callable aislada que valida el esquema de `SaleRecord` y asigna `saleNumber` junto con venta, contador y recibo idempotente en una transacción; todavía no está conectada al worker ni desplegada en producción. Estos puntos son puertas obligatorias antes de habilitar ventas, productos, inventario, pagos o deudas. Mantener las reglas y Functions sin desplegar en producción.


### Pull incremental sintético — 2026-10-16

Se añadió el callable `pullSyntheticSyncChanges`, protegido por autenticación y membresía activa, con paginación por versión global de tienda. El cliente `CloudSyncPullCoordinator` valida tienda, tipo de entidad, orden de versiones y cursor; aplica una página y solo después avanza el cursor durable por dispositivo. El aplicador debe deduplicar por `eventId`, porque un cierre inesperado después de aplicar y antes de guardar el cursor puede volver a entregar la página.

Este canal devuelve exclusivamente `syntheticTestValue`. No es una API de lectura de ventas, productos, inventario, pagos o deudas. La sincronización comercial sigue deshabilitada y no se ha desplegado ninguna Function ni regla a producción.
