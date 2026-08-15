-- ============================================================
-- CORRECCIÓN DE MOJIBAKE (SIN DESCRIPCION)
-- ============================================================

-- 1. Corregir "RegiA^n" y similares en la región
UPDATE public.perfiles_proveedores
SET region = 
    REPLACE(
        REPLACE(
            REPLACE(region, 'RegiA^n', 'Región'),
            'RegiÃ³n', 'Región'
        ),
        'RegiÃ³n', 'Región'
    )
WHERE region IS NOT NULL;

-- 2. Corregir "Tienda Prueba A:" (con virgulilla)
UPDATE public.perfiles_proveedores
SET nombre_comercial = 
    REPLACE(
        REPLACE(
            REPLACE(nombre_comercial, 'Tienda Prueba A:', 'Tienda Prueba Á'),
            'Tienda Prueba Ã', 'Tienda Prueba Á'
        ),
        'Tienda Prueba', 'Tienda Prueba'
    )
WHERE nombre_comercial LIKE '%Tienda%Prueba%';

-- 3. Corregir "CÃ³digo" → "Código" (solo en productos, porque perfiles no tiene descripcion)
UPDATE public.productos
SET nombre = REPLACE(nombre, 'CÃ³digo', 'Código')
WHERE nombre LIKE '%CÃ³digo%';

-- 4. Corrección general de tildes (sin descripcion)
UPDATE public.perfiles_proveedores
SET 
    nombre_comercial = 
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(nombre_comercial, 
                            'Ã¡', 'á'),
                        'Ã©', 'é'),
                    'Ã­', 'í'),
                'Ã³', 'ó'),
            'Ãº', 'ú'),
        'Ã±', 'ñ')
    WHERE nombre_comercial IS NOT NULL;

UPDATE public.perfiles_proveedores
SET 
    region = 
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(region, 
                            'Ã¡', 'á'),
                        'Ã©', 'é'),
                    'Ã­', 'í'),
                'Ã³', 'ó'),
            'Ãº', 'ú'),
        'Ã±', 'ñ')
    WHERE region IS NOT NULL;

UPDATE public.productos
SET 
    nombre = 
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(nombre, 
                            'Ã¡', 'á'),
                        'Ã©', 'é'),
                    'Ã­', 'í'),
                'Ã³', 'ó'),
            'Ãº', 'ú'),
        'Ã±', 'ñ')
    WHERE nombre IS NOT NULL;

-- 5. Verifica el resultado
SELECT id, nombre_comercial, region FROM public.perfiles_proveedores;
SELECT id, nombre FROM public.productos;