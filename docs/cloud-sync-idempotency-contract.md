# Contrato de idempotencia remota para sincronización incremental

**Estado:** especificación pendiente de implementación. No es un receptor desplegado ni habilita sincronización comercial.

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
