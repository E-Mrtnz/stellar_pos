# STELLAR POS — Revisión de creación segura de tiendas

**Rama:** `feature/cloud-storage-v2`  
**Fecha:** 2026-10-14  
**Alcance:** alta/consulta explícita de tiendas y ciclo de vida de cuenta. No conecta el almacenamiento local ni habilita sincronización de datos de negocio.

## Hallazgos confirmados

- `lib/main.dart` inicializa Hive y el esquema local antes de mostrar la app. Firebase se inicializa en segundo plano y no es requisito para abrir la caja.
- `CloudAuthGateway` identifica al usuario, pero no le concede acceso a una tienda.
- `CloudStoreRole` / `StoreMembership` y el contrato de invitaciones ya existían como modelos de dominio; no ejecutaban operaciones remotas.
- `CloudFirestoreRepository` ofrece CRUD genérico, pero no debe conectarse directamente a los repositorios de productos, ventas, compras, inventario, clientes o deudas.
- `firestore.rules` denegaba todas las operaciones. Esta postura evitaba escrituras accidentales, pero también impedía cualquier alta de tienda.

## Cambio acotado en esta fase

Se añade `CloudStoreRepository.createStore`, que realiza una operación explícita y pequeña:

1. Requiere una sesión autenticada.
2. Valida el nombre visible (1–80 caracteres).
3. Genera un `storeId` aleatorio, independiente del nombre.
4. Envía un único batch atómico de dos documentos: metadatos de la tienda y membresía inicial del propietario.
5. Devuelve los metadatos de la tienda; no consulta ni sube registros locales.

La regla de Firestore acepta el alta solo si ambos documentos se crean en la misma operación y el UID autenticado coincide con el propietario y la membresía `owner`. Se permite leer los metadatos y membresías de una tienda solo a miembros autenticados activos. La política continúa denegando actualizaciones/eliminaciones de tiendas y membresías, invitaciones, y todas las rutas de negocio no especificadas.

**Presupuesto de escritura de la operación:** dos documentos por alta de tienda, una sola vez por acción explícita del usuario. No se ejecuta al arrancar la app, iniciar sesión, abrir una pantalla ni editar productos. La interfaz de Cuenta en la nube ya permite consultar tiendas y crear una tienda de forma explícita; también explica que las invitaciones aún no están disponibles.

## Por qué no se habilita todavía la sincronización

Las invitaciones seguras requieren un flujo de aceptación confiable y atómico; no se deben resolver exponiendo el hash de un código o permitiendo que el cliente cambie su propio rol. La outbox local, la idempotencia de eventos de negocio y la prevención de bucles de eco también siguen pendientes. Por tanto, esta fase no toca Hive, ventas, productos, inventario, compras, pagos ni deudas.

## Validación automatizada

El workflow de GitHub Actions se amplía para ejecutar:
- pruebas Flutter de acceso a nube, rutas y construcción perezosa de repositorios;
- pruebas de reglas con Firebase Emulator Suite sobre el proyecto ficticio `demo-stellar-pos`.

Los casos de reglas deben demostrar tanto el alta atómica válida como el rechazo de alta sin membresía, suplantación del propietario y escrituras de productos. Las pruebas del emulador no despliegan reglas ni acceden al proyecto real `stellar-pos-86f0c`.

## Estado y siguientes pasos

La interfaz para crear tiendas mediante acción explícita, consultar tiendas y reintentar una consulta fallida ya está implementada y cubierta por pruebas. Tras crear una tienda, el usuario puede crear otra desde la misma sesión; el control de estado evita solicitudes duplicadas mientras una operación está en curso.

Pendiente antes de conectar datos de negocio:

1. Ejecutar localmente `npm run test:rules` y las pruebas Flutter en el entorno del desarrollador.
2. Revisar las reglas y desplegarlas explícitamente a Firebase solo tras confirmar el proyecto destino y la aprobación del propietario.
3. Diseñar invitaciones mediante un flujo confiable y probar permisos positivos/negativos.
4. Diseñar una outbox durable y sincronización incremental con datos sintéticos, sin activar aún escrituras de negocio.

No crear colecciones manualmente ni cargar el inventario actual durante esta fase.


## Diagnóstico en macOS: tiendas no se pueden listar ni crear

Si la interfaz muestra errores al listar y crear tiendas, la sesión de Firebase Authentication por sí sola no confirma que las reglas de Firestore estén desplegadas ni que la cuenta tenga una membresía activa. La configuración FlutterFire del repositorio apunta al proyecto `stellar-pos-86f0c`; confirmar el proyecto activo antes de cualquier despliegue.

Comprobaciones seguras desde la terminal del desarrollador:

```bash
firebase projects:list
firebase use
```

El identificador de proyecto de `lib/firebase_options.dart` y `firebase.json` debe coincidir con el proyecto seleccionado. Revisar las reglas locales y ejecutar las pruebas del emulador antes de desplegar:

```bash
npm run test:rules
```

**No desplegar reglas a producción automáticamente desde esta fase.** Si el proyecto correcto ha sido confirmado por el propietario y las pruebas pasan, el despliegue debe ser una acción explícita y consciente del desarrollador, usando el ID confirmado; no usar `firebase use` a ciegas ni confiar únicamente en el alias local. Una respuesta `permission-denied` normalmente apunta a reglas no desplegadas/incorrectas o a una consulta que las reglas no pueden autorizar. Un error de conexión apunta a disponibilidad o red, no a permisos.

La creación válida escribe solo dos documentos en un batch atómico. La consulta de tiendas consulta membresías activas y luego los metadatos de cada tienda; no consulta colecciones de productos ni ventas.

## Diseño aprobado para sincronización incremental (todavía no activado)

La sincronización prevista será automática en segundo plano, sin pedir al usuario que aplique cada cambio manualmente. No debe descargar ni subir toda la base al abrir la app. Antes de habilitarla se necesita:

1. Registrar cada cambio local en una outbox durable junto con la escritura local, con ID de evento/documento estable.
2. Procesar solo eventos pendientes, con reintentos idempotentes y confirmación explícita de evento aplicado.
3. Mantener un cursor o versión remota para traer solo cambios posteriores; no confiar únicamente en comparar snapshots completos.
4. Evitar bucles de eco marcando el origen de cada cambio y distinguir cambios locales de cambios aplicados desde la nube.
5. Definir conflictos por tipo de dato. El inventario, las ventas, pagos y deudas no deben resolverse con una política genérica de “última escritura gana”.
6. Aplicar autorización por tienda y rol en Firestore Rules, y probar desconexión, reintentos, duplicados, cierre de sesión y dos dispositivos concurrentes con datos sintéticos.

Hasta implementar y probar todos estos componentes, la sincronización de datos comerciales permanece apagada. Esta documentación no modifica datos de Firebase ni despliega reglas.


## Revisión adicional — 2026-10-15

### Límite del backend existente

Se inspeccionó `functions/src/index.js`. El callable `acceptSyntheticSyncEvent` es un receptor de pruebas que solo admite la entidad `syntheticTestValue`; valida la membresía activa en servidor y aplica recibos idempotentes en una transacción. No es un backend de invitaciones y no debe reutilizarse como si ya autorizara altas de miembros.

No se implementan invitaciones en esta etapa: falta una función dedicada que genere y almacene un secreto de invitación de forma segura, limite su vigencia/uso, valide el usuario autenticado y cree la membresía dentro de una transacción confiable. Las reglas de Firestore deben seguir rechazando escrituras directas a `invitations` y membresías nuevas fuera del alta inicial de tienda.

### Estado de las pruebas de interfaz

Se amplió `test/core/cloud_account_settings_tile_test.dart` para que el gateway falso falle en la primera consulta y funcione en el reintento. El caso verifica que la acción Reintentar recupera el formulario de autenticación sin excepciones en un viewport compacto.

En `test/core/cloud_auth_screen_test.dart`, la prueba de proveedor social ahora usa un viewport de 320 × 568 para ejercitar la pantalla en un ancho de teléfono reducido.

### Verificación de ejecución

Los archivos se publicaron en la rama de GitHub, pero no se ejecutó `flutter test`, `flutter analyze` ni la suite de Firebase Emulator desde esta sesión. La consulta de estado de checks para el commit revisado no devolvió checks; por tanto, no debe interpretarse como una ejecución exitosa. Antes de considerar cerrada esta fase, ejecutar localmente las pruebas Flutter y `npm run test:rules`. La prueba del receptor requiere los emuladores Auth, Firestore y Functions mediante `npm run test:receiver`.

Se mantiene la restricción: no desplegar reglas en Firebase real y no conectar ventas, productos, inventario, pagos o deudas a la nube.

## Cierre de validación de la fase — 2026-10-16

La validación automática publicada en GitHub Actions para el commit `5e7ac8988e94b5ce7a977e69a6120d635bb99ee5` terminó correctamente:

- [STELLAR POS validation](https://github.com/E-Mrtnz/stellar_pos/actions/runs/38835184578): Flutter analyze/tests, pruebas del receptor sintético y pruebas de reglas Firestore, todos en verde.
- [Flutter and cloud access regression tests](https://github.com/E-Mrtnz/stellar_pos/actions/runs/38835184676): pruebas de regresión de acceso a nube, en verde.

La suite de reglas se amplió después para comprobar el comportamiento de una membresía revocada: el usuario pierde acceso a los metadatos de la tienda, pero puede consultar su propio documento de membresía para conocer su estado. La ejecución de CI para ese nuevo cambio debe confirmarse en el commit posterior.

### Criterios de salida de esta fase

Se considera validada la infraestructura de prueba, el control de acceso actual para tiendas, y el receptor **exclusivamente sintético**. No se considera implementada la sincronización comercial ni el flujo de invitaciones. Los siguientes requisitos son trabajo de una fase posterior y no deben resolverse habilitando escrituras genéricas:

1. Diseñar una outbox durable conectada atómicamente a los cambios locales.
2. Definir resolución de conflictos por entidad y cursores/versiones remotos.
3. Implementar invitaciones con función confiable, expiración, uso limitado y aceptación atómica.
4. Crear contratos y reglas específicos para cada tipo de dato comercial, con pruebas de dos dispositivos y modo offline.
5. Desplegar reglas solo mediante una acción explícita tras confirmar el proyecto Firebase de destino.

Los workflows de prueba usan el proyecto ficticio `demo-stellar-pos`; no despliegan reglas ni escriben en Firebase de producción. La caja local sigue siendo independiente de autenticación y conectividad, y las colecciones de ventas, productos, inventario, compras, pagos y deudas continúan cerradas a la nube.



## Implementación de invitaciones confiables — 2026-10-16

Se incorporan dos callable functions del backend:

- `createStoreInvitation`: exige membresía activa de propietario y que el UID coincida con `ownerUid`; permite solo los roles `manager`, `cashier` y `viewer`; limita la vigencia a 1–168 horas y los usos a 1–10. Genera un código aleatorio de alta entropía, devuelve el código una sola vez y guarda únicamente su hash SHA-256.
- `acceptStoreInvitation`: exige sesión autenticada, valida el código y la tienda en el servidor y, dentro de una transacción, comprueba vigencia, revocación y límite de usos, crea la membresía activa con el rol autorizado y consume el uso. No permite que el cliente elija su UID o rol.

Las reglas de Firestore continúan cerrando las escrituras directas a invitaciones y membresías; las funciones usan Admin SDK para la operación confiable. El código de invitación es un secreto tipo bearer: debe compartirse solo con la persona deseada y no registrarse en logs. La membresía de un usuario que ya tenga un documento —incluido uno revocado— no se reactiva automáticamente.

La suite del emulador añade pruebas para propietario/no propietario, rol inválido, límites de expiración, falta de autenticación, aceptación de un solo uso y vinculación del código a la tienda. Las funciones todavía no se despliegan a Firebase de producción; para usarlas allí se necesita una publicación explícita y revisar el proyecto destino.

## Límite pendiente: sincronización comercial

Esta entrega **no activa** sincronización de ventas, productos, inventario, compras, pagos o deudas. El receptor existente sigue siendo solo sintético. No hay aún una outbox durable atómica con las escrituras Hive existentes, ni un adaptador comercial probado que mantenga IDs locales estables, asigne números remotos idempotentes y resuelva conflictos por tipo de entidad. Activar escrituras comerciales sin esos componentes podría duplicar ventas o perder cambios al desconectarse.

Por ello, los siguientes criterios siguen abiertos y deben completarse antes de declarar terminada la sincronización comercial:
1. Integrar una outbox durable con las transacciones/escrituras locales de cada repositorio.
2. Definir y probar el contrato de cada entidad comercial y sus permisos de lectura/escritura.
3. Implementar cursor remoto, reintentos, deduplicación, reconciliación y conflictos por entidad.
4. Probar reinicios, desconexión, dos dispositivos concurrentes y cierres de sesión con datos sintéticos.
5. Desplegar las funciones solo después de confirmar configuración y aprobación del propietario.

La caja local permanece independiente de red/autenticación. No se modifica la base de datos de producción ni se despliegan reglas automáticamente.
