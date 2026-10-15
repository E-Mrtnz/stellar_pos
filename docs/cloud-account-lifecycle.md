# STELLAR POS — Ciclo de vida de la cuenta en la nube

**Estado:** contrato de comportamiento para la fase de cuenta/tienda. No habilita sincronización ni cambia datos de producción.

## Decisiones

1. **La caja local no depende de una sesión.** Hive y los flujos de venta locales deben iniciar y seguir funcionando aunque Firebase no inicialice, no haya red o la cuenta cierre sesión.
2. **Autenticación no equivale a autorización.** Firebase Authentication identifica una cuenta. El acceso a cada tienda depende de una membresía activa comprobada por Firestore Rules.
3. **Cerrar sesión solo cierra la sesión de nube.** No borra la cuenta, tienda, membresías, productos locales, ventas locales ni datos de Hive. Tampoco intenta eliminar documentos remotos.
4. **Cambiar de cuenta no cambia la tienda activa de la caja.** La pantalla de cuenta vuelve a consultar las tiendas de la nueva identidad. La selección de tienda sigue siendo informativa hasta que exista un flujo de cambio de contexto probado.
5. **Errores remotos no deben bloquear ventas locales.** Un error al consultar tiendas o cerrar sesión se muestra en la zona de nube; no debe descartar ni modificar el estado local.
6. **Sincronización aún apagada.** No existe una outbox de negocio aprobada, resolución de conflictos ni protocolo de idempotencia completo. Ningún repositorio de Hive debe conectarse al CRUD genérico de Firestore en esta fase.

## Flujo esperado

- **Sin sesión:** la pantalla de cuenta explica que el usuario puede iniciar sesión, pero no necesita hacerlo para vender localmente.
- **Sesión iniciada:** se consultan solo las membresías activas del UID actual y sus metadatos de tienda.
- **Error al consultar:** se ofrece reintentar; no se borra información local.
- **Cerrar sesión:** Firebase Auth finaliza la sesión. El cambio de estado de autenticación devuelve la pantalla a “Sin sesión en la nube”. Si la operación falla, se muestra un aviso y se mantiene el estado reportado por Firebase.
- **Sin conexión:** las operaciones que necesitan Firebase pueden fallar con mensajes comprensibles; la venta local continúa usando Hive.

## Pruebas mínimas de regresión

- Arranque y flujo local sin sesión de nube.
- Abrir cuenta no crea tiendas ni escribe datos automáticamente.
- Crear tienda solo tras acción explícita.
- Error de nube muestra un mensaje seguro y no anuncia éxito.
- Cerrar sesión no invoca creación de tienda ni borra datos de negocio.
- Después de cerrar sesión, la UI de cuenta vuelve al estado sin sesión.
- Las reglas deniegan escritura en colecciones de negocio e invitaciones.

## Límites y pasos bloqueados

Las invitaciones requieren una operación confiable de aceptación, con expiración, revocación, límite de uso y creación de membresía atómica. La aceptación cliente-only no es aceptable. Antes de implementarla hay que escoger y aprobar una arquitectura que no conceda permisos a partir de una escritura del propio usuario. No se agregan Cloud Functions ni servicios con posibles requisitos de facturación sin aprobación expresa.

La sincronización requerirá una outbox durable escrita junto a cada cambio local, IDs estables, reintentos idempotentes, detección de eco y reglas por colección/rol. Inventario, ventas, pagos y deudas necesitan tratamiento específico de concurrencia. No desplegar reglas de producción ni probar con datos reales como parte de este contrato.
