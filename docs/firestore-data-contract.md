# STELLAR POS — Contrato inicial de datos Firestore

**Estado:** propuesta versionada para revisión; todavía no conecta Firestore con ventas, inventario ni otros repositorios locales.

## 1. Principios obligatorios

- Hive sigue siendo la fuente local inmediata. Una operación local no espera una llamada remota.
- Firestore almacena una réplica remota autorizada; no reemplaza los repositorios locales.
- Los identificadores de tienda, usuario, dispositivo y documento son conceptos distintos.
- Los permisos se validan en reglas de Firestore. Ocultar opciones en la interfaz o validar rutas en Dart no es autorización.
- No desplegar reglas permisivas ni comenzar sincronización automática hasta completar pruebas de aislamiento entre tiendas.

## 2. Identidades y membresía

### Identificadores

| Campo | Significado | Regla |
|---|---|---|
| `uid` | UID de Firebase Authentication | Identidad de cuenta; no se genera a partir del nombre visible. |
| `storeId` | Identificador estable de la tienda | No usar el nombre de tienda como ID ni asumir que el nombre es único. |
| `deviceId` | Instalación/dispositivo | Separado de usuario y tienda; no concede acceso. |
| `documentId` | ID estable de entidad | Se conserva durante reintentos para permitir idempotencia. |
| `saleNumber` | Número visible de venta | No usarlo como ID técnico ni asumir unicidad entre dispositivos sin asignación coordinada. |

### Rutas propuestas

- `users/{uid}`: perfil mínimo de cuenta; no contiene permisos globales que sustituyan la membresía de cada tienda.
- `stores/{storeId}`: metadatos de la tienda, incluido el nombre visible.
- `stores/{storeId}/members/{uid}`: membresía y rol del usuario en esa tienda.
- `stores/{storeId}/devices/{deviceId}`: registro opcional de dispositivos autorizados; su existencia por sí sola no reemplaza la autorización del usuario.
- `stores/{storeId}/invitations/{invitationId}`: invitaciones con estado, vencimiento y límites de uso; el código de invitación no es una identidad ni debe ser una credencial permanente.
- `stores/{storeId}/products/{documentId}`
- `stores/{storeId}/sales/{documentId}`
- `stores/{storeId}/purchases/{documentId}`
- `stores/{storeId}/clients/{documentId}`
- `stores/{storeId}/distributors/{documentId}`
- `stores/{storeId}/debts/{documentId}`
- `stores/{storeId}/debtMovements/{documentId}`
- `stores/{storeId}/inventoryMovements/{documentId}`
- `stores/{storeId}/settings/{documentId}`

Las rutas de negocio anteriores son el espacio de nombres previsto, no una instrucción para crear colecciones manualmente ni para subir datos actuales. Firestore crea documentos/colecciones al escribir; antes de ello se debe cerrar el contrato de campos y permisos.

## 3. Contrato común para documentos sincronizables

Cada entidad debe mantener su esquema de negocio propio y, cuando se integre a la sincronización, incluir metadatos técnicos equivalentes a:

- `schemaVersion`: entero para versionar la forma del documento.
- `createdAt`, `updatedAt`: marcas de tiempo coherentes y validadas; definir quién las asigna antes de implementar.
- `originDeviceId`: dispositivo que originó el cambio, si aplica.
- `deletedAt` o una estrategia explícita de tombstones para eliminaciones sincronizadas.
- `revision` o precondición de versión cuando una entidad requiera detectar modificaciones concurrentes.
- Un ID estable e idempotente para cada operación de sincronización; no generar un ID nuevo en cada reintento.

No agregar estos campos a las entidades Hive existentes de forma masiva todavía. Primero se diseñará un adaptador/DTO remoto para evitar migraciones locales accidentales.

## 4. Reglas de acceso previstas

Las reglas definitivas deben aplicar, como mínimo, estas condiciones:

1. La cuenta debe estar autenticada para cualquier lectura/escritura privada.
2. El UID debe tener una membresía válida en el `storeId` solicitado.
3. Las operaciones administrativas (cambiar miembros, roles, invitaciones o ajustes críticos) requieren permisos específicos.
4. Un miembro de una tienda no puede leer ni modificar documentos de otra tienda.
5. El cliente no puede asignarse a sí mismo roles elevados ni modificar arbitrariamente la lista de miembros.
6. Validar tipos y campos permitidos por colección, además de limitar campos sensibles que un usuario puede cambiar.
7. Las invitaciones deben ser de uso limitado, revocables y con expiración; conocer el código no debe conceder acceso permanente sin un flujo de aceptación controlado.

La regla temporal en `firestore.rules` deniega todo acceso. Se mantiene así hasta que las condiciones anteriores estén implementadas y probadas. No se debe cambiar a `allow read, write: if request.auth != null`, porque eso no aísla las tiendas.

## 5. Estrategia de sincronización (aún no implementada)

- Guardar primero en Hive y registrar un evento durable en una outbox local en la misma unidad lógica de escritura.
- Procesar cambios pendientes en segundo plano con reintentos limitados y espera incremental.
- Reutilizar el mismo ID de operación/documento en los reintentos.
- Aplicar cambios remotos por documento/cambio incremental; evitar descargar colecciones enteras tras cada modificación.
- No reenviar como cambio local una actualización que se acaba de aplicar desde Firestore.
- Definir conflictos por entidad: inventario, pagos, deudas y ventas no deben resolverse a ciegas con “última escritura gana”.
- Mantener la cola durable y los datos locales aunque la cuenta cierre sesión o Firebase no esté disponible.

## 6. Plan de validación antes de conectar datos reales

1. Unit tests de rutas, validación de DTO y reglas.
2. Pruebas de reglas con Firebase Emulator Suite: sin sesión, usuario sin membresía, miembro de tienda A intentando acceder a B, y roles insuficientes.
3. Pruebas de CRUD con documentos sintéticos, nunca con datos reales del negocio.
4. Probar dos dispositivos con la misma tienda y con tiendas diferentes.
5. Probar offline, reconexión, reintentos, duplicados, cierre inesperado y conflicto concurrente.
6. Solo entonces integrar una entidad de bajo riesgo; ventas, inventario, pagos y deudas requieren validación específica antes de habilitarse.

## 7. Alcance de esta entrega

Este documento define un contrato inicial para revisión. No crea usuarios, tiendas, miembros, invitaciones ni documentos remotos; no cambia modelos Hive; no activa autenticación ni sincronización; y no despliega reglas. Las reglas actuales siguen cerradas por defecto.
