# Receptor sintético de sincronización: pruebas locales

Este paquete implementa únicamente un receptor de prueba para el tipo de entidad sintética `syntheticTestValue`. No acepta productos, ventas, inventario, pagos, deudas ni rutas de colección proporcionadas por el cliente. No está conectado a la outbox de Flutter.

## Ejecutar

Desde la raíz del repositorio:

```sh
npm install
npm --prefix functions install
npm run test:receiver
```

El comando inicia Auth, Firestore y Functions Emulator con el proyecto de demostración `demo-stellar-pos`, ejecuta las pruebas de integración y detiene los emuladores. No apunta al proyecto de producción.

## Garantías que se prueban

- Identidad obtenida de Firebase Auth y membresía activa consultada por el servidor.
- Validación de esquema y rechazo de campos extra.
- Recibo delimitado por tienda/evento, con huella SHA-256 de una proyección canónica.
- Mutación sintética y recibo dentro de la misma transacción de Firestore.
- Repetición idéntica, colisión de contenido, aislamiento por tienda, falta de autenticación, membresía inactiva y conflicto de versión.

## Límites actuales

El receptor no está desplegado ni conectado al cliente. Esta fase no cambia reglas ni datos de producción. La suite de pruebas todavía debe confirmar el comportamiento real de los emuladores en CI antes de considerar el contrato validado. Las entidades comerciales siguen bloqueadas y requieren políticas de conflicto e integración específicas antes de cualquier activación.
