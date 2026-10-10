# STELLAR POS — Auditoría y diseño de arquitectura Firebase

**Rama revisada:** `feature/responsive-ui`  
**Fecha:** 2026-10-09  
**Estado:** auditoría/documentación solamente. No se ha conectado Firebase al flujo de ventas ni se ha cambiado la lógica funcional.

## 1. Objetivo acordado

STELLAR POS debe seguir funcionando con normalidad sin internet y sin Firebase. Hive continúa siendo el almacenamiento local primario. Firebase/Firestore será una capa remota para respaldo y sincronización entre dispositivos, no un requisito para abrir la aplicación ni para registrar una operación local.

Orden de implementación acordado:

1. Verificar e inicializar Firebase de forma opcional, sin bloquear el arranque local.
2. Diseñar y probar operaciones remotas CRUD aisladas, con rutas y permisos seguros por tienda.
3. Incorporar autenticación y vincular identidad, tienda y permisos sin confundir sus identificadores.
4. Incorporar sincronización local-first entre dispositivos, con cola durable, reintentos y resolución explícita de conflictos.

Cada fase debe tener pruebas antes de avanzar a la siguiente.

## 2. Hallazgos del repositorio

### Almacenamiento local existente

- `lib/main.dart` inicializa Hive y `StorageSchema` antes de ejecutar la aplicación. Actualmente no inicializa Firebase en el arranque.
- `lib/core/data/storage/local_storage.dart` centraliza la apertura y persistencia de cajas Hive.
- `lib/core/data/storage/storage_boxes.dart` define cajas locales para productos, clientes, ventas, compras, cuentas/movimientos de deudas y otros datos.
- Los repositorios de productos y ventas (`product_repository.dart`, `sale_repository.dart`) trabajan con Hive y documentan que la nube está desconectada intencionalmente.
- `lib/app.dart` confirma que la autenticación y la sincronización en la nube están desconectadas mientras se diseña la nueva arquitectura.

**Conclusión:** el flujo actual es local y debe conservarse como base de disponibilidad offline. No sustituir Hive por Firestore ni hacer que el inicio dependa de una conexión remota.

### Código remoto existente

- `lib/core/cloud_firebase.dart` expone inicialización perezosa y captura errores; todavía no implementa una política completa de conectividad/reintentos.
- `lib/core/cloud_firestore_repository.dart` implementa CRUD genérico directo a Firestore, pero cada operación llama a `ensureReady()` y falla si Firebase no está disponible. No es todavía una cola offline ni sincroniza cambios de Hive.
- `lib/core/cloud_paths.dart` construye rutas bajo `stores/{storeId}/{collection}/{documentId}`.
- `firebase.json` registra configuración FlutterFire para el proyecto `stellar-pos-86f0c` y sus plataformas configuradas.
- En la rama revisada no se encontró `firestore.rules` en la raíz ni en `firebase/firestore.rules`; `firebase.json` tampoco declara un archivo de reglas Firestore.

**Conclusión:** la configuración FlutterFire permite identificar el proyecto, pero no demuestra que existan reglas de seguridad listas para producción ni que el CRUD genérico esté integrado de forma segura. Antes de escribir datos reales, definir reglas, autorización y despliegue explícitos.

## 3. Arquitectura objetivo (local-first)

```text
Interfaz / Providers
        |
Casos de uso y reglas de negocio existentes
        |
Repositorios locales (Hive)  <---->  Outbox durable de cambios pendientes
        |                                      |
La operación local termina                    | cuando hay conexión y sesión válida
sin esperar a Firebase                         v
                                      Motor de sincronización
                                      - reintentos con espera incremental
                                      - idempotencia
                                      - checkpoint/estado por operación
                                      - límites de trabajo por lote
                                                |
                                             Firestore
                                                |
                                  cambios remotos autorizados
                                                |
                                  aplicar a Hive sin bucles de eco
```

La sincronización debe ser incremental y reanudable. No descargar toda una colección cada vez que cambia un registro; no mantener colas secuenciales largas que congelen la interfaz. Las operaciones locales se guardan primero y la sincronización se ejecuta en segundo plano cuando las condiciones lo permiten.

## 4. Identificadores y aislamiento

Mantener separados estos conceptos:

- **Firebase UID:** identidad de la cuenta autenticada.
- **storeId:** identificador estable de la tienda/tenant; no debe depender de que el nombre visible sea único.
- **deviceId:** identificador estable de la instalación/dispositivo para diagnóstico, procedencia y control de sincronización.
- **documentId / saleId:** identificador estable del registro local/remoto.
- **saleNumber:** número visible de venta, sujeto a asignación coordinada en la nube cuando deba ser único entre dispositivos.

El código de invitación puede resolver a una tienda, pero no sustituye a `storeId` ni concede acceso por sí solo. Las reglas de Firestore deben comprobar membresía y permisos de la cuenta para esa tienda.

## 5. Reglas de integridad para la implementación

1. **Offline primero:** vender, cobrar, registrar compras y administrar inventario/deudas debe seguir funcionando sin internet.
2. **Persistencia antes de sincronizar:** registrar localmente y dejar un evento durable pendiente; nunca perder la operación porque falle la red.
3. **Idempotencia:** reintentar una operación no debe duplicar ventas, movimientos, compras ni cambios de inventario.
4. **Conflictos explícitos:** definir estrategia por entidad/campo; no usar ciegamente “última escritura gana” para cantidades, pagos, deudas o inventario.
5. **Sin eco infinito:** los cambios descargados de la nube no deben volver a encolarse como si fueran modificaciones locales nuevas.
6. **Permisos antes del CRUD:** reglas de Firestore deben aislar cada tienda y verificar membresía. No confiar solo en un `storeId` enviado por el cliente.
7. **Sin cambios colaterales:** no alterar fórmulas ni flujos actuales de ventas, pagos, inventario, compras o deudas al añadir sincronización.
8. **Pruebas por fase:** incluir Firebase no configurado, sin red, reconexión, reintento, duplicado, conflicto, permisos denegados y dos dispositivos.

## 6. Secuencia de trabajo propuesta

### Fase 0 — Auditoría (este documento)
Identificar qué existe y qué falta antes de modificar código.

### Fase 1 — Arranque y disponibilidad
Inicialización Firebase no bloqueante, estados observables de conexión y pruebas de que la app abre/funciona con Firebase desactivado o inaccesible. Sin autenticación ni sincronización automática todavía.

### Fase 2 — Contrato de datos y seguridad
Definir esquema por entidad, rutas, reglas Firestore y estrategia de permisos. Probar CRUD con datos de prueba y aislamiento entre tiendas antes de conectar los repositorios de negocio.

### Fase 3 — Autenticación y membresía
Implementar acceso, membresía de tienda e invitaciones. El acceso remoto debe fallar cerrado, mientras los datos locales existentes siguen disponibles según la política local.

### Fase 4 — Outbox y sincronización
Añadir registro durable de cambios pendientes, reintentos e idempotencia; después sincronización incremental bidireccional y resolución de conflictos. Integrar una entidad a la vez, comenzando por una entidad de bajo riesgo antes de ventas/inventario/deudas.

### Fase 5 — Validación multiplataforma
Verificar Android, iOS, macOS y web. Comprobar diferencias de almacenamiento local por plataforma y recuperación tras reinicio/cierre inesperado.

## 7. Criterios para dar por terminada la auditoría

- La app no necesita Firebase para arrancar ni operar localmente.
- Las operaciones remotas están aisladas de las reglas de negocio.
- Existen reglas Firestore versionadas y un procedimiento de despliegue revisado.
- Cada cambio pendiente sobrevive al cierre y se reintenta sin duplicarse.
- La sincronización no bloquea la interfaz ni recarga colecciones completas.
- Las pruebas demuestran aislamiento por tienda y preservación de datos/operaciones existentes.

**Límite de esta auditoría:** se revisaron los archivos y configuraciones disponibles en `feature/responsive-ui`. No se verificaron desde aquí las reglas actualmente desplegadas en la consola Firebase, la configuración real del proyecto remoto ni la ejecución local de pruebas/builds.
