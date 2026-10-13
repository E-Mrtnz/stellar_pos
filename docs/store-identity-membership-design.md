# STELLAR POS — Identidad, membresías e invitaciones

**Estado:** contrato de dominio inicial; no habilita autenticación, invitaciones ni acceso remoto.

## Objetivo

Permitir que una cuenta autenticada pertenezca a una o más tiendas, sin confundir identidad, tienda, instalación o código de invitación. Hive continúa siendo la fuente local de uso diario y Firebase no debe bloquear el arranque ni las ventas sin conexión.

## Identificadores

- `uid`: identificador emitido por Firebase Authentication.
- `storeId`: identificador estable y aleatorio de la tienda; el nombre visible no es único ni sirve como autorización.
- `deviceId`: identifica una instalación y nunca concede acceso por sí solo.
- `invitationId`: ID de documento de una invitación; no es el código compartible.
- `tokenHash`: huella del código de invitación; el código en texto plano no se almacena en Firestore.
- `documentId`: ID estable de un registro de negocio, distinto de su número visible.

## Rutas propuestas

- `users/{uid}`: perfil mínimo.
- `stores/{storeId}`: nombre visible y metadatos.
- `stores/{storeId}/members/{uid}`: rol y estado de la membresía.
- `stores/{storeId}/invitations/{invitationId}`: hash del código, rol concedido, creador, vencimiento, revocación y límites de uso.

Las colecciones de ventas, productos, inventario, compras, pagos y deudas siguen fuera de este alcance.

## Roles iniciales

| Rol | Leer datos de negocio | Escribir datos de negocio | Ajustes/miembros |
|---|---|---|---|
| `owner` | Sí | Sí | Administra miembros y tienda |
| `manager` | Sí | Sí | Administra ajustes permitidos; no promueve a propietario |
| `cashier` | Sí | Sí, según las reglas de colección | No |
| `viewer` | Sí | No | No |

Los permisos en Dart solo ayudan a presentar acciones; no son una barrera de seguridad. Las reglas de Firestore deben aplicar todas las restricciones.

## Reglas para invitaciones

1. El código compartible debe tener suficiente entropía, expirar y poder revocarse.
2. Guardar solo su hash en el documento remoto, nunca el código original.
3. El propietario o un rol explícitamente autorizado crea invitaciones.
4. No permitir que una invitación otorgue el rol `owner`.
5. Aceptar una invitación requiere una sesión autenticada.
6. La aceptación debe comprobar en una transacción que no expiró, no fue revocada y no superó el máximo de usos; crear la membresía y consumir el uso deben ser atómicos.
7. El código no debe convertirse en una credencial permanente. No exponer invitaciones en consultas generales ni permitir leerlas por conocer su ID.
8. El cliente no puede asignarse un rol ni editar su membresía directamente.

La generación/validación de códigos y la operación transaccional de aceptación requieren un diseño de confianza final (por ejemplo, función backend o un protocolo de reglas que se pueda demostrar seguro). El modelo Dart recién agregado es solo un contrato y no ejecuta esas operaciones.

## Matriz mínima para reglas Emulator

- Sin autenticación: denegar lectura y escritura privada.
- Usuario autenticado sin membresía: denegar acceso a la tienda.
- Miembro activo de tienda A: permitir solo las operaciones correspondientes a su rol en A.
- Miembro de A intentando acceder a B: denegar.
- Membresía suspendida: denegar.
- Cajero intentando crear/modificar miembros, roles, invitaciones o ajustes protegidos: denegar.
- Usuario intentando cambiar su propio rol: denegar.
- Invitación inexistente, expirada, revocada o agotada: denegar aceptación.
- Invitación válida: permitir solo mediante el flujo transaccional aprobado.
- Miembro de una tienda no puede leer invitaciones privadas de otra tienda.

## Estado de seguridad actual

`firestore.rules` sigue con `allow read, write: if false`. Esto es intencional. No desplegar ni cambiar estas reglas hasta que exista una identidad autenticada integrada, el flujo de membresía esté implementado y todas las pruebas positivas y negativas pasen. El CRUD genérico de Firestore no debe conectarse aún a ventas, productos, inventario, compras, pagos o deudas.

## Próximos pasos

1. Revisar la compatibilidad de Firebase Authentication con las versiones FlutterFire fijadas en el proyecto.
2. Definir recuperación de cuenta, sesión opcional y comportamiento sin conexión; no exigir red para operar Hive.
3. Implementar alta de tienda y membresía inicial de propietario sin permitir autoasignación de privilegios.
4. Implementar invitación/aceptación transaccional mediante un componente confiable.
5. Escribir y ejecutar las pruebas Emulator de permisos positivos, negativos y aislamiento entre tiendas.
6. Integrar primero metadatos sintéticos; mantener las colecciones de negocio desconectadas hasta validar conflictos y outbox durable.
