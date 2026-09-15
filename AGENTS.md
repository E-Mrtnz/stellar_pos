# STELLAR POS APP — Documento Maestro de Contexto para Codex

> Fuente principal de contexto del proyecto. Leer antes de modificar código.
> Las instrucciones explícitas más recientes del usuario tienen prioridad.

## 1. Proyecto

**Proyecto:** STELLAR POS APP  
**Repositorio:** `E-Mrtnz/stellar_pos`  
**Stack:** Flutter / Dart  
**Objetivo:** construir un POS completo para un negocio de abarrotes, con productos,
inventario, compras, ventas, proveedores/distribuidoras, caja, costos, precios,
reportes y finanzas.

Prioridades: funcionamiento local confiable, arquitectura mantenible, cálculos comerciales
correctos, separación de responsabilidades y capacidad de evolucionar posteriormente a nube.

---

## 2. Git — REGLA CRÍTICA

### Rama actual de trabajo

**`feature/finalization`**

Todo trabajo actual debe hacerse únicamente en `feature/finalization`.

**NO modificar:**
- `main`
- `feature/local-storage`

No cambiar de rama por iniciativa propia.

No hacer `commit` ni `push` automáticamente. Flujo:

1. modificar;
2. revisar diff;
3. validar;
4. informar;
5. esperar autorización explícita;
6. commit/push en la rama correcta.

---

## 3. Forma de trabajo

El usuario prefiere desarrollo directo y práctico.

- Inspeccionar el código real antes de modificarlo.
- Hacer el cambio mínimo necesario.
- Mantener la arquitectura y estilo existentes.
- Evitar refactors innecesarios.
- No repetir explicaciones ya resueltas.
- No pedir `git status`/`git log` repetidamente si no hay un problema Git que lo requiera.
- No asumir que un cambio histórico sigue presente: verificar el árbol actual.

---

## 4. Arquitectura

El proyecto sigue **Clean Architecture** y principios **SOLID**.

Capas conceptuales:
- Presentation
- Domain
- Data
- Core

Cuando una funcionalidad esté organizada por feature, mantener la separación:

```text
feature/
├── data/
├── domain/
└── presentation/
```

Respetar la dirección de dependencias de Clean Architecture.

### SOLID
Aplicar SOLID de forma práctica:
- Single Responsibility
- Open/Closed
- Liskov Substitution
- Interface Segregation
- Dependency Inversion

No crear abstracciones artificiales solo para aumentar archivos.

---

## 5. Estado

La preferencia del proyecto es **Provider**, no BLoC/Cubit.

No introducir BLoC/Cubit salvo petición explícita.

---

## 6. Persistencia

El proyecto está trabajando en persistencia local.

`feature/local-storage` contiene trabajo relacionado con local storage y **no debe tocarse
actualmente**.

La arquitectura debe permitir evolucionar posteriormente hacia:
- Firebase / Firestore;
- Cloud Storage;
- sincronización;
- backups.

No implementar nube anticipadamente si no corresponde a la tarea.

---

## 7. Modelos y NoSQL

Se contempla almacenamiento NoSQL para productos y entidades del POS.

Considerar:
- IDs estables;
- inventario;
- precios;
- costos;
- unidades/presentaciones;
- proveedores/distribuidoras;
- historial cuando sea necesario.

Evitar duplicación de datos que pueda producir inconsistencias.

---

# 8. REGLAS DE NEGOCIO DE COMPRAS — CRÍTICAS

Estas reglas deben conservarse.

## 8.1 Precio de presentación

El formulario de compra trabaja con un precio correspondiente a la **presentación**.

Ejemplo real:

```text
Producto: Gillette Venus Simply
Presentación: 8 unidades
Precio sin descuento: $11.31
Descuento: 10%
Precio con descuento: $10.18
IVA: $1.17
Total pagado: $10.18
```

El descuento se aplica al precio de presentación:

```text
precioConDescuento =
    precioOriginal * (1 - descuento / 100)
```

---

## 8.2 `unitCost` = costo de UNA unidad individual

Esta es una regla fundamental.

```text
Precio original de presentación = $11.31
Unidades por presentación       = 8

unitCost = 11.31 / 8
         = 1.41375
         ≈ $1.41
```

`unitCost` NO representa el costo de toda la presentación.

Al guardar:

```text
unitCost = originalPresentationPrice / unitsPerPresentation
```

Al reabrir:

```text
originalPresentationPrice =
    unitCost * unitsPerPresentation
```

Editar y guardar repetidamente NO debe volver a dividir el costo.

---

## 8.3 `unitsPerPresentation`

Indica cuántas unidades individuales contiene una presentación.

Afecta:
- stock recibido;
- conversión de precio de presentación a costo unitario.

NO debe multiplicarse otra vez por el precio de presentación para calcular el total monetario
de la factura.

---

## 8.4 Cantidad comprada y unidades recibidas

Si:

```text
purchasedQuantity = presentaciones compradas
unitsPerPresentation = unidades por presentación
bonusQuantity = unidades bonificadas
```

entonces:

```text
received =
    purchasedQuantity * unitsPerPresentation
    + bonusQuantity
```

Ejemplo:

```text
1 × 8 + 0 = 8 unidades recibidas
```

Las bonificaciones son unidades individuales.

---

## 8.5 Total pagado

```text
totalCost =
    discountedPresentationPrice * purchasedQuantity
```

NO:

```text
discountedPrice * unitsPerPresentation
```

`unitsPerPresentation` convierte a inventario; no vuelve a multiplicar el importe monetario.

---

## 8.6 IVA

En el flujo actual el precio final ya contiene IVA cuando corresponde.

Ejemplo:

```text
Precio con descuento / ventas gravadas = $10.18
IVA = $1.17

Base sin IVA:
10.18 - 1.17 = 9.01
```

NO sumar IVA nuevamente al precio final.

Si existe IVA:

```text
netSubtotal =
    (discountedPresentationPrice - ivaPerPresentation)
    * purchasedQuantity
```

Mientras:

```text
totalCost =
    discountedPresentationPrice * purchasedQuantity
```

---

## 8.7 Descuento

Relación:

```text
discountedPresentationPrice =
    originalPresentationPrice
    * (1 - discountPercent / 100)
```

El costo unitario de inventario se basa en el precio de presentación original definido por
el negocio, no debe cambiarse a costo descontado salvo instrucción explícita.

---

## 8.8 Costo y precio de venta

Los modelos contemplan:

```dart
final double? previousCost;
final double? previousSalePrice;
final int unitsPerPresentation;
final double? discountPercent;
final double? iva;
```

`unitCost` es costo unitario individual.

Respetar la lógica existente de:
- `updateCostIds`
- `updatePriceIds`

No alterar la semántica sin revisar todos sus usos.

---

## 8.9 Eliminación

Las compras pueden eliminarse.

Al eliminar:
- ajustar stock usando `totalQuantity`;
- restaurar valores anteriores cuando corresponda;
- solo restaurar `previousCost`/`previousSalePrice` si existen;
- verificar que el producto todavía coincide con el valor generado por la compra antes de
  sobrescribir;
- usar tolerancia aproximada `0.0001` en comparaciones numéricas cuando corresponda.

---

## 8.10 Edición repetida

Debe funcionar:

```text
crear → guardar → abrir → editar → guardar → abrir → editar → guardar
```

Sin reducir/dividir el costo repetidamente.

---

# 9. Formulario de compras

Archivo especialmente relevante:

```text
lib/presentation/purchases/purchase_creation_dialog.dart
```

Campos de entrada y campos calculados deben distinguirse claramente.

### Pendiente conocido: "Con descuento"

Actualmente existe un problema: el campo **Con descuento** estaba usando `_readonly`.

Debe ser editable.

Agregar:

```dart
late final TextEditingController _discountedController;
```

Cuando el usuario edite directamente **Con descuento**:

1. actualizar `discountedPresentationPrice`;
2. recalcular:

```text
discountPercent =
    (1 - discountedPrice / originalPrice) * 100
```

3. actualizar `Desc. %`.

Limitar:

```text
0 <= discountedPrice <= originalPresentationPrice
```

Cuando se edite `Desc. %`:

```text
discountedPrice =
    originalPrice * (1 - discountPercent / 100)
```

Los dos campos deben permanecer sincronizados.

El controller debe:
- inicializarse;
- sincronizarse en `didUpdateWidget`;
- liberarse en `dispose`;
- usar el mecanismo `_updating` existente para evitar ciclos.

No romper los cálculos actuales de costo, total, stock o IVA.

---

## 10. Estado conocido de `purchase_creation_dialog.dart`

Ya existen correcciones previas de tipos numéricos. No revertirlas.

Entre ellas:
- `_total` usa acumulador `0.0`;
- `totalPaid` tiene fallback `0.0`;
- `ivaPerPresentation` se trata como `double?`;
- `discountPercent ?? 0.0`;
- fallbacks numéricos usan `0.0`;
- `netSubtotal` usa `ivaPerPresentation ?? 0.0`;
- `unitCost` usa fallback `0.0`;
- folds de `double` comienzan en `0.0`.

---

# 11. Dropdowns de distribuidora

Existe un problema conocido observado en:
- Inventario;
- Compras.

Al seleccionar una distribuidora:
- no debe lanzar excepciones;
- debe mostrar el valor seleccionado;
- debe conservar la selección;
- debe respetar el tipo esperado por el widget;
- debe funcionar también al editar registros existentes.

Antes de cambiarlo, inspeccionar la implementación actual.

---

# 12. Inventario

Debe contemplar:
- producto;
- stock;
- unidad de medida;
- presentación;
- contenido/cantidad de presentación;
- costo unitario;
- precio de venta;
- distribuidora/proveedor;
- código de barras.

Distinción crítica:

```text
cantidad/contenido = contenido de la presentación
stock = cantidad física disponible
```

Ejemplo:

```text
Coca-Cola
cantidad: 354 ml
stock: 25
```

No confundirlos.

---

# 13. Productos por peso

El POS debe contemplar:
- productos vendidos por unidad;
- productos vendidos por peso.

Ejemplo:

```text
Pollo
1.50 lb
```

Se ha estudiado el uso de etiquetas de balanza y códigos de barras que pueden codificar
producto/peso/precio según el estándar utilizado.

El análisis matemático de esos códigos fue principalmente conceptual. No implementarlo
automáticamente sin especificar el estándar real que utilizará el negocio.

---

# 14. Código de barras

La evolución prevista incluye:
- códigos fijos para productos;
- códigos de productos pesables;
- scanner;
- impresión de etiquetas.

No asumir un estándar específico sin verificar el formato utilizado.

---

# 15. Cash Drawer / Hardware

Hardware contemplado:
- cajón de dinero;
- RJ12/RJ11;
- solenoide de aproximadamente 24 V;
- impresora térmica portátil de 80 mm;
- señal de impresora de aproximadamente 5 V;
- fuente independiente de 24 V.

Concepto trabajado:

```text
Impresora
   │ señal 5 V
   ▼
Circuito de disparo
   │
   ▼
Fuente 24 V
   │
   ▼
Solenoide
```

Se consideró NE555 monoestable para aproximadamente 300 ms y una etapa de conmutación
adecuada.

Esto corresponde al hardware; no mezclarlo innecesariamente con la arquitectura Flutter.

---

# 16. Flujo general del negocio

```text
PROVEEDOR / DISTRIBUIDORA
          ↓
       COMPRA
          ↓
      INVENTARIO
          ↓
        VENTA
          ↓
         CAJA
          ↓
      REPORTES
          ↓
      FINANZAS
```

Compras alimentan inventario. Inventario alimenta ventas. Ventas alimentan caja y reportes.

---

# 17. Finanzas

El sistema deberá eventualmente permitir:
- ventas;
- costos;
- utilidad;
- caja;
- caja chica;
- métodos de pago;
- obligaciones con proveedores;
- análisis de márgenes.

El dinero de proveedores no implica separar físicamente el efectivo por proveedor.

---

# 18. Pagos con tarjeta

Se ha estudiado el tratamiento de comisiones de tarjeta.

No hardcodear una comisión del 6%.

Si se implementa una comisión:
- debe ser configurable;
- debe tener tratamiento claramente separado del precio del producto.

---

# 19. Historial de trabajo relevante

Commits históricos importantes:

```text
c7a66a4962cb9b040b76b0ac4b815199da95c110
fix: align purchase card with invoice calculations

45472b9ddd61eab237624a4cb145870f48944b93
fix: compact purchase card and repair unit-cost edit logic

1c6aa441777b25d0f6473d730f3692cac72ce2c3
feat: add purchase deletion and timestamp

9e823631c81c6c50e2878298f3666868c110c603
fix: redesign purchase deletion confirmation

854d9064b262e91ea4704eca3b7e1e835eba150f
fix: repair purchase detail dialog syntax
```

Son contexto histórico. Siempre inspeccionar el código actual.

---

# 20. Incidente temporal de GitHub Actions

Se creó temporalmente:

```text
.github/workflows/finalize_payment_dialog.yml
```

Hubo un error en una validación que buscaba:

```bash
grep -q "'_discountedController"
```

cuando debía buscar el identificador sin esa comilla.

No considerar ese workflow como parte de la arquitectura del proyecto.

El desarrollo actual debe aprovechar el acceso local de Codex al workspace en vez de depender
de workflows temporales para cambios locales.

---

# 21. Flujo recomendado con Codex

```text
1. Leer AGENTS.md
2. Inspeccionar código relacionado
3. Identificar causa real
4. Implementar cambio mínimo
5. Revisar diff
6. flutter analyze
7. flutter test (cuando corresponda)
8. Informar resultado
9. Esperar autorización
10. Commit
11. Push
```

No hacer commit/push sin autorización explícita.

---

# 22. Validación

Después de cambios Flutter/Dart:

```bash
flutter analyze
```

y cuando existan pruebas pertinentes:

```bash
flutter test
```

Distinguir warnings preexistentes de errores introducidos por el cambio.

---

# 23. Convenciones

Mantener:
- null-safety;
- tipos claros;
- nombres descriptivos;
- componentes pequeños cuando la arquitectura actual ya los separa;
- lógica de negocio separada de UI cuando corresponda;
- estilo existente.

Evitar:
- `dynamic` innecesario;
- casts inseguros;
- duplicación;
- hardcodes comerciales;
- refactors masivos sin relación con la tarea.

---

# 24. Cambios de modelos

Antes de modificar un modelo:
1. buscar todos sus usos;
2. revisar providers;
3. revisar persistencia;
4. revisar formularios;
5. revisar listados/detalles;
6. revisar edición/eliminación;
7. considerar registros antiguos.

No romper compatibilidad con campos opcionales existentes sin razón explícita.

---

# 25. Dinero y cálculos

Antes de cambiar una fórmula, identificar exactamente qué representa cada valor:

- precio unitario;
- precio de presentación;
- subtotal;
- total;
- costo;
- precio de venta;
- IVA incluido/excluido;
- descuento.

Reglas fundamentales:

```text
unitCost ≠ presentationPrice
totalPaid ≠ stockReceived
```

---

# 26. Plan general del proyecto

### Etapa A — Base
- modelos;
- arquitectura;
- navegación;
- productos;
- inventario;
- proveedores/distribuidoras.

### Etapa B — Compras
- creación;
- edición;
- eliminación;
- costos;
- descuento;
- IVA;
- bonificaciones;
- unidades por presentación;
- actualización de inventario.

### Etapa C — Ventas
- carrito;
- scanner;
- productos por unidad;
- productos pesables;
- métodos de pago;
- ticket.

### Etapa D — Caja
- apertura/cierre;
- efectivo;
- métodos de pago;
- cash drawer;
- movimientos.

### Etapa E — Finanzas/reportes
- ventas;
- costos;
- utilidad;
- proveedores;
- caja;
- reportes.

### Etapa F — Nube
- robustecer local storage;
- migraciones;
- Firebase/Firestore;
- sincronización;
- backup.

El orden puede ajustarse según las necesidades reales. No implementar funcionalidades futuras
prematuramente.

---

# 27. Estado inmediato

El foco actual es terminar correctamente el flujo de compras y su interfaz/cálculos.

Pendiente inmediato conocido:

**Hacer editable "Con descuento"** en:

```text
lib/presentation/purchases/purchase_creation_dialog.dart
```

Después:
1. revisar dropdown de distribuidora;
2. verificar Inventario/Compras;
3. `flutter analyze`;
4. tests pertinentes;
5. revisión visual;
6. continuar con la siguiente funcionalidad.

---

# 28. Checklist obligatorio antes de cada cambio

```text
[ ] ¿Estoy en feature/finalization?
[ ] ¿Estoy evitando main y feature/local-storage?
[ ] ¿Leí AGENTS.md?
[ ] ¿Inspeccioné el código real?
[ ] ¿Identifiqué modelos/providers/persistencia relacionados?
[ ] ¿Apliqué las reglas de negocio correspondientes?
[ ] ¿El cambio es mínimo?
[ ] ¿Evité duplicación?
[ ] ¿Consideré compatibilidad?
[ ] ¿Validé con flutter analyze/tests?
[ ] ¿Revisé el diff?
[ ] ¿Evité commit/push sin autorización?
```

---

## Regla final

Si una instrucción explícita nueva del usuario contradice este documento, la instrucción nueva
tiene prioridad.

Si el documento contradice el código actual, inspeccionar primero y explicar la discrepancia
antes de hacer un cambio destructivo.

**Este archivo es contexto del proyecto, no una orden para implementar todas las funcionalidades
descritas de una sola vez.**
