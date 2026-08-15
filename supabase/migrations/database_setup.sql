-- ============================================================================
-- SCRIPT DE BASE DE DATOS OPTIMIZADO Y SEGURO (PROD LOCALES)
-- ============================================================================

-- 0. LIMPIEZA INICIAL
DROP TRIGGER IF EXISTS trigger_auto_aprobar ON public.productos;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.auto_aprobar_productos_verificados();
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.disminuir_stock_producto(UUID, INT);
DROP FUNCTION IF EXISTS public.obtener_mi_config_pago();

DROP VIEW IF EXISTS public.perfiles_publicos;
DROP TABLE IF EXISTS public.interacciones CASCADE;
DROP TABLE IF EXISTS public.favoritos CASCADE;
DROP TABLE IF EXISTS public.pedidos CASCADE;
DROP TABLE IF EXISTS public.productos CASCADE;
DROP TABLE IF EXISTS public.perfiles_proveedores CASCADE;
DROP TABLE IF EXISTS public.categorias CASCADE;

-- 1. TABLA DE CATEGORÍAS
CREATE TABLE public.categorias (
  id SERIAL PRIMARY KEY,
  nombre TEXT UNIQUE NOT NULL,
  campos_dinamicos JSONB DEFAULT '[]'::jsonb
);

INSERT INTO public.categorias (nombre, campos_dinamicos) VALUES 
('Miel', '["Floración", "Textura", "Color"]'),
('Queso', '["Tipo de Leche", "Maduración"]'),
('Carne', '["Corte", "Alimentación"]'),
('Tejidos', '["Material", "Técnica"]'),
('Vegetales', '["Tipo de Cultivo", "Temporada"]'),
('Otros', '["Descripción Adicional"]');

-- 2. TABLA DE PERFILES (DATOS PRIVADOS + CONFIG PAGO)
CREATE TABLE public.perfiles_proveedores (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  nombre_comercial TEXT,
  whatsapp TEXT,
  descripcion TEXT,
  ubicacion TEXT,
  region TEXT,
  verificado BOOLEAN DEFAULT FALSE,
  metodo_pago TEXT DEFAULT 'whatsapp',
  premium_activo BOOLEAN DEFAULT FALSE,
  premium_vencimiento TIMESTAMPTZ,
  config_pago JSONB DEFAULT '{}'::jsonb, -- Datos sensibles de transferencia bancaria
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. TABLA DE PRODUCTOS
CREATE TABLE public.productos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  proveedor_id UUID REFERENCES public.perfiles_proveedores(id) ON DELETE CASCADE NOT NULL,
  nombre TEXT NOT NULL,
  precio_base NUMERIC NOT NULL,
  categoria TEXT,
  detalles JSONB DEFAULT '{}'::jsonb,
  imagen_url TEXT,
  activo BOOLEAN DEFAULT TRUE,
  estado TEXT DEFAULT 'pendiente', -- 'pendiente', 'aprobado', 'rechazado'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. TABLA DE PEDIDOS
CREATE TABLE public.pedidos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  producto_id UUID REFERENCES public.productos(id) ON DELETE SET NULL,
  proveedor_id UUID REFERENCES public.perfiles_proveedores(id) ON DELETE CASCADE NOT NULL,
  comprador_nombre TEXT,
  comprador_whatsapp TEXT,
  monto NUMERIC NOT NULL,
  metodo_pago TEXT NOT NULL,
  cantidad INT DEFAULT 1,
  tipo_entrega TEXT DEFAULT 'retiro',
  direccion_entrega TEXT,
  estado TEXT DEFAULT 'pendiente_pago', -- 'pendiente_pago', 'pagado', 'cancelado', 'completado'
  comprobante_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. TABLA DE INTERACCIONES
CREATE TABLE public.interacciones (
  id BIGSERIAL PRIMARY KEY,
  producto_id UUID REFERENCES public.productos(id) ON DELETE CASCADE,
  proveedor_id UUID REFERENCES public.perfiles_proveedores(id) ON DELETE CASCADE,
  tipo_evento TEXT DEFAULT 'clic_whatsapp',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. TABLA DE FAVORITOS
CREATE TABLE public.favoritos (
  id BIGSERIAL PRIMARY KEY,
  usuario_id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  producto_id UUID REFERENCES public.productos(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(usuario_id, producto_id)
);

-- ============================================================================
-- ÍNDICES PARA ALTO RENDIMIENTO
-- ============================================================================
CREATE INDEX idx_productos_proveedor ON public.productos(proveedor_id);
CREATE INDEX idx_productos_filtro ON public.productos(activo, estado);
CREATE INDEX idx_pedidos_proveedor ON public.pedidos(proveedor_id);
CREATE INDEX idx_interacciones_proveedor ON public.interacciones(proveedor_id);
CREATE INDEX idx_favoritos_usuario ON public.favoritos(usuario_id);
CREATE INDEX idx_perfiles_region ON public.perfiles_proveedores(region);

-- ============================================================================
-- SEGURIDAD DE COLUMNAS (PROTECCIÓN DE DATOS BANCARIOS)
-- ============================================================================
ALTER TABLE public.categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles_proveedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interacciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favoritos ENABLE ROW LEVEL SECURITY;

-- PERFILES
CREATE POLICY "Perfiles visibles para todos" ON public.perfiles_proveedores 
  FOR SELECT USING (true);

CREATE POLICY "Proveedor edita su propio perfil" ON public.perfiles_proveedores 
  FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Restringir lectura de la columna config_pago a nivel de base de datos
REVOKE SELECT ON public.perfiles_proveedores FROM anon, authenticated;
GRANT SELECT (id, nombre_comercial, whatsapp, descripcion, ubicacion, region, verificado, metodo_pago, premium_activo, premium_vencimiento, updated_at) 
  ON public.perfiles_proveedores TO anon, authenticated;
GRANT INSERT, UPDATE ON public.perfiles_proveedores TO authenticated;
GRANT ALL ON public.perfiles_proveedores TO service_role;

-- Función segura para que un proveedor lea SU PROPIA configuración de pago bancario
CREATE OR REPLACE FUNCTION public.obtener_mi_config_pago()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT config_pago 
    FROM public.perfiles_proveedores 
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
-- SET search_path = '' previene ataques de search path hijacking en funciones SECURITY DEFINER.

-- FIX SEGURIDAD: Revocar acceso PUBLIC (anon) y otorgar solo a authenticated.
REVOKE EXECUTE ON FUNCTION public.obtener_mi_config_pago() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.obtener_mi_config_pago() FROM anon;
GRANT EXECUTE ON FUNCTION public.obtener_mi_config_pago() TO authenticated;

-- CATEGORÍAS
CREATE POLICY "Categorias visibles para todos" ON public.categorias FOR SELECT USING (true);

-- PRODUCTOS
-- Clientes solo ven productos activos Y aprobados por administración
CREATE POLICY "Productos visibles para clientes" ON public.productos 
  FOR SELECT USING (activo = true AND estado = 'aprobado');

-- Proveedores ven y gestionan TODOS sus productos (incluso pendientes/inactivos)
CREATE POLICY "Proveedores gestionan sus productos" ON public.productos 
  FOR ALL USING (auth.uid() = proveedor_id) WITH CHECK (auth.uid() = proveedor_id);

-- PEDIDOS
CREATE POLICY "Crear pedido con proveedor real" ON public.pedidos 
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.productos p
      WHERE p.id = producto_id
      AND p.proveedor_id = pedidos.proveedor_id
      AND p.activo = true
    )
  );

CREATE POLICY "Proveedores ven sus propios pedidos" ON public.pedidos 
  FOR SELECT USING (auth.uid() = proveedor_id);

CREATE POLICY "Proveedores actualizan sus pedidos" ON public.pedidos 
  FOR UPDATE USING (auth.uid() = proveedor_id);

-- INTERACCIONES
-- FIX SEGURIDAD: Validar que el producto exista, este activo y aprobado antes de registrar la interaccion.
-- Esto evita la alerta "RLS Policy Always True" del Security Advisor de Supabase.
CREATE POLICY "Registrar interaccion en producto activo" ON public.interacciones
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.productos p
      WHERE p.id = producto_id
        AND p.activo = true
        AND p.estado = 'aprobado'
    )
  );
CREATE POLICY "Proveedores ven sus interacciones" ON public.interacciones FOR SELECT USING (auth.uid() = proveedor_id);

GRANT INSERT ON public.interacciones TO anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE interacciones_id_seq TO anon, authenticated;

-- FAVORITOS
CREATE POLICY "Usuarios gestionan sus favoritos" ON public.favoritos 
  FOR ALL USING (auth.uid() = usuario_id) WITH CHECK (auth.uid() = usuario_id);

-- ============================================================================
-- AUTOMATIZACIÓN Y TRIGGERS
-- ============================================================================

-- Auto-aprobar productos de proveedores verificados
CREATE OR REPLACE FUNCTION public.auto_aprobar_productos_verificados()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.perfiles_proveedores 
    WHERE id = NEW.proveedor_id AND verificado = TRUE
  ) THEN
    NEW.estado = 'aprobado';
  ELSE
    NEW.estado = 'pendiente';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- FIX SEGURIDAD: Esta funcion es un trigger interno, nadie debe ejecutarla directamente.
REVOKE EXECUTE ON FUNCTION public.auto_aprobar_productos_verificados() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.auto_aprobar_productos_verificados() FROM anon;
REVOKE EXECUTE ON FUNCTION public.auto_aprobar_productos_verificados() FROM authenticated;

CREATE TRIGGER trigger_auto_aprobar
BEFORE INSERT ON public.productos
FOR EACH ROW
EXECUTE FUNCTION public.auto_aprobar_productos_verificados();

-- Crear automáticamente fila en perfiles_proveedores al registrarse en Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.perfiles_proveedores (id)
  VALUES (new.id)
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- FIX SEGURIDAD: Esta funcion es un trigger interno, nadie debe ejecutarla directamente.
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Sincronizar usuarios existentes
INSERT INTO public.perfiles_proveedores (id)
SELECT id FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- CONFIGURACIÓN DE STORAGE (BUCKETS Y POLÍTICAS)
-- ============================================================================
INSERT INTO storage.buckets (id, name, public) 
VALUES ('productos', 'productos', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('comprobantes', 'comprobantes', false)
ON CONFLICT (id) DO NOTHING;

-- Políticas de Storage
DROP POLICY IF EXISTS "Acceso público a imágenes" ON storage.objects;
DROP POLICY IF EXISTS "Proveedores ven sus comprobantes" ON storage.objects;
DROP POLICY IF EXISTS "Clientes suben comprobantes" ON storage.objects;
DROP POLICY IF EXISTS "Proveedores pueden subir fotos" ON storage.objects;
DROP POLICY IF EXISTS "Proveedores pueden editar sus fotos" ON storage.objects;
DROP POLICY IF EXISTS "Proveedores pueden borrar sus fotos" ON storage.objects;

CREATE POLICY "Acceso público a imágenes" ON storage.objects 
  FOR SELECT USING (bucket_id = 'productos');

CREATE POLICY "Proveedores ven sus comprobantes" ON storage.objects 
  FOR SELECT TO authenticated
  USING (bucket_id = 'comprobantes' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Clientes suben comprobantes" ON storage.objects 
  FOR INSERT WITH CHECK (bucket_id = 'comprobantes');

CREATE POLICY "Proveedores pueden subir fotos" ON storage.objects 
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'productos');

CREATE POLICY "Proveedores pueden editar sus fotos" ON storage.objects 
  FOR UPDATE TO authenticated USING (bucket_id = 'productos' AND auth.uid() = owner);

CREATE POLICY "Proveedores pueden borrar sus fotos" ON storage.objects 
  FOR DELETE TO authenticated USING (bucket_id = 'productos' AND auth.uid() = owner);

-- ============================================================================
-- FUNCIONES DE LÓGICA DE NEGOCIO (STOCK)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.disminuir_stock_producto(prod_id UUID, cant_a_restar INT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.productos
    SET detalles = jsonb_set(
        detalles, 
        '{stock}', 
        ((COALESCE(detalles->>'stock', '0')::int) - cant_a_restar)::text::jsonb
    )
    WHERE id = prod_id 
    AND (detalles->'stock') IS NOT NULL
    AND (detalles->>'stock')::int >= cant_a_restar;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stock insuficiente o producto no encontrado: %', prod_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- FIX SEGURIDAD: Restringir ejecucion directa - solo service_role puede llamar esta funcion.
REVOKE EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) TO service_role;

-- FIX SEGURIDAD: rls_auto_enable es una funcion interna de Supabase.
-- Revocar acceso publico de forma condicional (puede no existir en todos los entornos).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'rls_auto_enable'
  ) THEN
    REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC;
    REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM anon;
    REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM authenticated;
  END IF;
END;
$$;

-- ============================================================================
-- VISTAS PÚBLICAS SEGURAS
-- ============================================================================

-- Vista de perfiles públicos con SECURITY INVOKER (respeta RLS del usuario que consulta)
-- NO expone config_pago ni otros campos sensibles
CREATE OR REPLACE VIEW public.perfiles_publicos
  WITH (security_invoker = true)
AS
  SELECT
    id,
    nombre_comercial,
    whatsapp,
    descripcion,
    ubicacion,
    region,
    verificado,
    metodo_pago,
    premium_activo,
    premium_vencimiento,
    updated_at
  FROM public.perfiles_proveedores;

GRANT SELECT ON public.perfiles_publicos TO anon, authenticated;