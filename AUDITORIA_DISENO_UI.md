# 🔍 Auditoría de Diseño/UI — Marketplace Local (Flutter)

**Fecha:** 9 de agosto de 2026  
**Alcance:** 13 archivos de pantalla en `lib/`  
**Criterios auditados:**
1. Uso de Row/Column sin Expanded/Flexible que puedan desbordar
2. Tamaños fijos en píxeles (width:, height:, fontSize:) que no se adapten
3. Ausencia de SafeArea, LayoutBuilder, o MediaQuery

---

## 📊 Resumen Ejecutivo

| Criterio | Hallazgos | Severidad |
|----------|-----------|-----------|
| Row/Column sin Expanded/Flexible | **12 casos** en 6 archivos | 🟠 Media |
| Tamaños fijos en píxeles | **+80 casos** en 13 archivos | 🟠 Media |
| Ausencia de SafeArea | **0 usos** en 13 archivos | 🔴 Alta |
| Ausencia de LayoutBuilder | **0 usos** en 13 archivos | 🔴 Alta |
| Ausencia de MediaQuery | **1 uso** en 1 de 13 archivos | 🔴 Alta |

**Veredicto general:** La app tiene una **capacidad de respuesta (responsiveness) deficiente**. No maneja correctamente los notches de dispositivos (SafeArea), no adapta layouts a distintos tamaños de pantalla (LayoutBuilder/MediaQuery), y tiene múltiples puntos de desbordamiento potenciales en pantallas pequeñas o con texto largo.

---

## 1️⃣ Row/Column sin Expanded/Flexible que pueden desbordar

### 🔴 Crítico

| # | Archivo | Línea | Problema |
|---|---------|-------|----------|
| 1 | `product_detail_screen.dart` | 101–137 | `Row` con etiquetas "categoría" y "stock" sin `Expanded`. En pantallas <360dp o con categorías largas, las etiquetas se desbordan horizontalmente. |
| 2 | `product_detail_screen.dart` | 387–407 | `_buildInfoRow`: `Row` con icono + `Column` de texto **sin `Expanded`**. Regiones o nombres de vendedor largos desbordan el ancho disponible. |
| 3 | `product_list_screen.dart` | 1394–1404 | `Row` con precio formateado e icono sin `Expanded`. Precios como `$1.234.567` en pantallas pequeñas desbordan. |
| 4 | `product_list_screen.dart` | 923–944 | `Row` con `ActionChip` (texto "Detectar Región" o región detectada) + `IconButton` sin `Expanded`. Regiones largas (ej: "Región de Aysén del General Carlos Ibáñez del Campo") desbordan. |

### 🟠 Medio

| # | Archivo | Línea | Problema |
|---|---------|-------|----------|
| 5 | `product_list_screen.dart` | 377–391 | `Row` con badge "Paso X de Y" + icono sin `Expanded`. Con `mainAxisAlignment.spaceBetween`, en pantallas muy pequeñas puede comprimir mal. |
| 6 | `product_detail_screen.dart` | 188–211 | `Row` título/precio: el título tiene `Expanded` ✅ pero el precio (fontSize 28) no está protegido. Precios de 7+ dígitos desbordan. |
| 7 | `product_detail_screen.dart` | 259–304 | `Row` selector cantidad + dropdown: el dropdown tiene `Expanded` ✅ pero el contenedor de cantidad (2 IconButtons + texto) tiene ancho intrínseco que puede desbordar en pantallas <320dp. |
| 8 | `login_screen.dart` | 227–242 | `Row` con "¿No tienes cuenta?" + `TextButton` sin `Expanded`. En pantallas pequeñas o con `textScaleFactor` alto, el texto se corta. |
| 9 | `orders_screen.dart` | 156–163 | `Row` con icono + "Entrega: " + tipo de entrega **sin `Expanded`**. Texto "Gestionada por vendedor" puede desbordar en pantallas pequeñas. |
| 10 | `dashboard_screen.dart` | 142–148 | `Row` con 3 leyendas (`_buildLegendItem`) sin `Expanded`/`Flexible`. En pantallas <400dp las leyendas se superponen o desbordan. |
| 11 | `premium_dashboard_screen.dart` | 104–111 | `Row` con icono + label + `Spacer` + valor. El `Spacer` no protege contra desbordamiento si el valor es muy largo. |
| 12 | `reset_password_screen.dart` | 63–90 | `Column` con `mainAxisAlignment: center` dentro de `Padding` sin `SingleChildScrollView`. Con teclado abierto o `textScaleFactor` alto, el contenido se desborda verticalmente. |

### ✅ Correctos (referencia)

- `join_screen.dart` línea 67–74: usa `Expanded` correctamente.
- `orders_screen.dart` línea 128–154: usa `Expanded` correctamente.
- `favorites_screen.dart`: usa `Expanded` en la imagen de la tarjeta.
- `product_list_screen.dart` línea 875–899: usa `Expanded` correctamente.

---

## 2️⃣ Tamaños fijos en píxeles (no adaptativos)

### 🔴 Críticos (alturas/anchuras de layout)

| # | Archivo | Línea | Valor fijo | Impacto |
|---|---------|-------|------------|---------|
| 1 | `product_list_screen.dart` | 869 | `Size.fromHeight(210)` | Altura fija del AppBar. En pantallas pequeñas o con `textScaleFactor` alto, el contenido del header se corta o desborda. |
| 2 | `product_list_screen.dart` | 977 | `height: 180` | Altura fija del header del Drawer. En pantallas pequeñas o con fuente grande, el contenido se corta. |
| 3 | `product_detail_screen.dart` | 80 | `height: 320` | Altura fija de la tarjeta de imagen. No se adapta a pantallas pequeñas. |
| 4 | `product_detail_screen.dart` | 148 | `height: 200` | Altura fija de la imagen del producto. |
| 5 | `upload_product_screen.dart` | 177 | `height: 150` | Altura fija del contenedor de foto. |
| 6 | `login_screen.dart` | 209 | `height: 55` | Altura fija del botón principal. |
| 7 | `orders_screen.dart` | 134–135 | `width: 60, height: 60` | Tamaño fijo de la miniatura del producto. |
| 8 | `reset_password_screen.dart` | 87 | `Size(double.infinity, 50)` | Altura fija del botón. |
| 9 | `product_list_screen.dart` | 746 | `width: 300` | Ancho fijo del diálogo QR. En pantallas <320dp desborda. |
| 10 | `product_list_screen.dart` | 768 | `size: 200.0` | Tamaño fijo del QR. |
| 11 | `premium_dashboard_screen.dart` | 116–123 | `height: 8` | Altura fija de las barras de progreso. |
| 12 | `dashboard_screen.dart` | 276 | `height: 40` | Altura fija del heatmap. |
| 13 | `dashboard_screen.dart` | 316 | `width: 22` | Ancho fijo de las barras del gráfico. |

### 🟠 Medios (tamaños de fuente fijos)

| fontSize | Archivos donde se usa |
|----------|----------------------|
| 32 | `product_detail_screen.dart` (título) |
| 28 | `product_detail_screen.dart` (precio) |
| 24 | `product_list_screen.dart`, `login_screen.dart`, `join_screen.dart` |
| 22 | `premium_dashboard_screen.dart`, `dashboard_screen.dart`, `product_list_screen.dart` |
| 20 | `dashboard_screen.dart`, `product_list_screen.dart` |
| 18 | `product_detail_screen.dart`, `edit_profile_screen.dart`, `premium_dashboard_screen.dart`, `dashboard_screen.dart`, `product_list_screen.dart` |
| 16 | `login_screen.dart`, `join_screen.dart`, `orders_screen.dart`, `favorites_screen.dart`, `edit_profile_screen.dart`, `product_list_screen.dart`, `premium_dashboard_screen.dart`, `product_detail_screen.dart` |
| 14 | `product_list_screen.dart`, `product_detail_screen.dart`, `favorites_screen.dart` |
| 13 | `login_screen.dart`, `orders_screen.dart`, `product_detail_screen.dart`, `product_list_screen.dart`, `dashboard_screen.dart` |
| 12 | `favorites_screen.dart`, `edit_profile_screen.dart`, `premium_dashboard_screen.dart`, `product_detail_screen.dart`, `product_list_screen.dart` |
| 11 | `favorites_screen.dart`, `product_detail_screen.dart`, `dashboard_screen.dart`, `product_list_screen.dart` |
| 10 | `product_detail_screen.dart`, `product_list_screen.dart` |

> **Nota:** Los `fontSize` fijos impiden que la app respete la configuración de accesibilidad `textScaleFactor` del sistema. Se recomienda usar `MediaQuery.textScalerOf(context)` o `Theme.of(context).textTheme` para escalar tipografía.

### 🟠 Medios (tamaños de iconos fijos)

| size | Archivos |
|------|----------|
| 100 | `product_detail_screen.dart` |
| 80 | `login_screen.dart`, `join_screen.dart`, `product_list_screen.dart`, `premium_dashboard_screen.dart` |
| 60 | `product_list_screen.dart` |
| 50 | `product_list_screen.dart` |
| 48 | `product_list_screen.dart` |
| 40 | `upload_product_screen.dart`, `orders_screen.dart` |
| 28 | `product_list_screen.dart` |
| 22 | `product_list_screen.dart` |
| 20 | `edit_profile_screen.dart`, `product_detail_screen.dart`, `product_list_screen.dart` |
| 18 | `product_detail_screen.dart`, `dashboard_screen.dart` |
| 16 | `product_list_screen.dart`, `orders_screen.dart` |
| 14 | `premium_dashboard_screen.dart`, `product_detail_screen.dart` |

---

## 3️⃣ Ausencia de SafeArea, LayoutBuilder, MediaQuery

### 🔴 SafeArea — 0 usos en 13 archivos

**Ningún archivo usa `SafeArea`.** Esto significa que en dispositivos con notch (iPhone X+, Pixel, etc.) o barras de gestos:

- El contenido del `Drawer` en `product_list_screen.dart` (línea 971) puede quedar oculto bajo el notch.
- Los `showModalBottomSheet` en `product_detail_screen.dart` (líneas 412, 465) y `product_list_screen.dart` (línea 807) pueden invadir la barra de gestos inferior.
- El `bottomNavigationBar` en `product_list_screen.dart` (línea 1179) puede superponerse con la barra de navegación del sistema.
- El contenido de `reset_password_screen.dart` (línea 63) puede quedar oculto bajo el notch superior.

### 🔴 LayoutBuilder — 0 usos en 13 archivos

**Ningún archivo usa `LayoutBuilder`.** No hay adaptación de layouts basada en las restricciones reales del padre:

- `product_list_screen.dart` usa `SliverGridDelegateWithMaxCrossAxisExtent` (buena práctica ✅) pero el `childAspectRatio: 0.68` fijo puede causar desbordamiento vertical en pantallas con poca altura.
- `favorites_screen.dart` usa `childAspectRatio: 0.7` fijo — mismo problema.
- `dashboard_screen.dart` usa `MediaQuery` para detectar desktop, pero un `LayoutBuilder` sería más robusto.

### 🔴 MediaQuery — 1 uso en 13 archivos

| # | Archivo | Línea | Uso |
|---|---------|-------|-----|
| 1 | `dashboard_screen.dart` | 57 | `MediaQuery.of(context).size.width` para detectar desktop (>800px) |

**Los 12 archivos restantes no usan `MediaQuery` en absoluto**, lo que significa que:

- No se adapta el padding a `MediaQuery.paddingOf(context)` (insets del sistema).
- No se usa `MediaQuery.sizeOf(context)` para dimensionar elementos.
- No se usa `MediaQuery.textScalerOf(context)` para escalar tipografía.
- No se usa `MediaQuery.orientationOf(context)` para layouts landscape/portrait.
- No se usa `MediaQuery.viewInsetsOf(context)` para manejar el teclado.

---

## 🛠️ Recomendaciones Priorizadas

### Prioridad 1 — Correcciones críticas (previenen bugs visibles)

1. **Envolver todos los Scaffold en `SafeArea`** o usar `SafeArea` en los body de cada pantalla:
   ```dart
   body: SafeArea(
     child: ...
   )
   ```

2. **Agregar `Expanded`/`Flexible` a los Row problemáticos** identificados en la sección 1:
   - `product_detail_screen.dart` líneas 101–137, 387–407
   - `product_list_screen.dart` líneas 1394–1404, 923–944
   - `orders_screen.dart` línea 156–163
   - `login_screen.dart` línea 227–242

3. **Reemplazar alturas fijas por `AspectRatio` o `ConstrainedBox` con `min/max`**:
   - `product_detail_screen.dart` `height: 320` → `AspectRatio(aspectRatio: 1.2)`
   - `upload_product_screen.dart` `height: 150` → `AspectRatio(aspectRatio: 2.5)`
   - `product_list_screen.dart` `Size.fromHeight(210)` → calcular con `MediaQuery`

### Prioridad 2 — Mejoras de adaptabilidad

4. **Usar `LayoutBuilder`** en pantallas principales para decidir layout:
   ```dart
   LayoutBuilder(
     builder: (context, constraints) {
       if (constraints.maxWidth > 800) {
         return _buildDesktopLayout();
       }
       return _buildMobileLayout();
     },
   )
   ```

5. **Usar `MediaQuery.textScalerOf(context)`** para tipografía accesible:
   ```dart
   final textScaler = MediaQuery.textScalerOf(context);
   Text('Hola', style: TextStyle(fontSize: 16 * textScaler.scale(1)));
   ```

6. **Usar `MediaQuery.sizeOf(context)`** para tamaños de iconos e imágenes proporcionales.

### Prioridad 3 — Buenas prácticas

7. **Reemplazar `fontSize` fijos por `Theme.of(context).textTheme`** (bodyMedium, titleLarge, etc.).
8. **Envolver los `showModalBottomSheet` con `SafeArea`** para respetar la barra de gestos.
9. **Usar `FractionallySizedBox` o `Flexible`** en lugar de `width: 300` en el diálogo QR.
10. **Considerar `SingleChildScrollView` + `ConstrainedBox`** en `reset_password_screen.dart` para evitar desbordes verticales con teclado.

---

## 📁 Archivos Auditados

| Archivo | Líneas | Row/Col sin Flex | Tamaños fijos | SafeArea | LayoutBuilder | MediaQuery |
|---------|--------|------------------|---------------|----------|---------------|------------|
| `product_list_screen.dart` | 1416 | 3 | 30+ | ❌ | ❌ | ❌ |
| `product_detail_screen.dart` | 563 | 3 | 25+ | ❌ | ❌ | ❌ |
| `login_screen.dart` | 251 | 1 | 5 | ❌ | ❌ | ❌ |
| `join_screen.dart` | 76 | 0 | 3 | ❌ | ❌ | ❌ |
| `favorites_screen.dart` | 131 | 0 | 5 | ❌ | ❌ | ❌ |
| `orders_screen.dart` | 200 | 1 | 4 | ❌ | ❌ | ❌ |
| `upload_product_screen.dart` | 308 | 0 | 2 | ❌ | ❌ | ❌ |
| `edit_profile_screen.dart` | 311 | 0 | 8 | ❌ | ❌ | ❌ |
| `reset_password_screen.dart` | 95 | 1 | 1 | ❌ | ❌ | ❌ |
| `premium_dashboard_screen.dart` | 144 | 1 | 6 | ❌ | ❌ | ❌ |
| `dashboard_screen.dart` | 319 | 1 | 8 | ❌ | ❌ | ✅ (1 uso) |
| **Total** | **3814** | **12** | **+80** | **0** | **0** | **1** |