-- ============================================================================
-- DATABASE SETUP MAESTRO (UNIFICADO E IDEMPOTENTE) — Marketplace Local
-- ============================================================================
-- Consolida TODAS las migraciones del proyecto:
--   database_setup.sql + security_fixes_2.sql + security_fixes_2026-08-08.sql
--   + fix_profile_permissions.sql + notificaciones.sql + reseñas.sql
--   + pedidos_comprador_id.sql + fix_encoding.sql
--   + obtener_datos_transferencia (nueva, corrección ALTO 1 de auditoría)
--
-- IDEMPOTENTE: usa CREATE TABLE IF NOT EXISTS / ADD COLUMN IF NOT EXISTS /
-- DROP POLICY IF EXISTS / CREATE OR REPLACE / ON CONFLICT DO NOTHING.
-- Ejecutar en Supabase Dashboard -> SQL Editor.
-- ============================================================================

-- ══════════════════════════════════════════════════════
-- 1. TABLAS
-- ══════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.categorias (
  id SERIAL PRIMARY KEY,
  nombre TEXT UNIQUE NOT NULL,
  campos_dinamicos JSONB DEFAULT '[]'::jsonb
);

CREATE TABLE IF NOT EXISTS public.perfiles_proveedores (
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
  config_pago JSONB DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.perfiles_proveedores
  ADD COLUMN IF NOT EXISTS foto_perfil_url TEXT,
  ADD COLUMN IF NOT EXISTS portada_url TEXT,
  ADD COLUMN IF NOT EXISTS horarios_atencion JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS metodos_pago JSONB DEFAULT '[]'::jsonb;

CREATE TABLE IF NOT EXISTS public.productos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  proveedor_id UUID REFERENCES public.perfiles_proveedores(id) ON DELETE CASCADE NOT NULL,
  nombre TEXT NOT NULL,
  precio_base NUMERIC NOT NULL,
  categoria TEXT,
  detalles JSONB DEFAULT '{}'::jsonb,
  imagen_url TEXT,
  activo BOOLEAN DEFAULT TRUE,
  estado TEXT DEFAULT 'pendiente',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.pedidos (
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
  estado TEXT DEFAULT 'pendiente_pago',
  comprobante_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS comprador_id UUID REFERENCES auth.users ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS public.interacciones (
  id BIGSERIAL PRIMARY KEY,
  producto_id UUID REFERENCES public.productos(id) ON DELETE CASCADE,
  proveedor_id UUID REFERENCES public.perfiles_proveedores(id) ON DELETE CASCADE,
  tipo_evento TEXT DEFAULT 'clic_whatsapp',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.favoritos (
  id BIGSERIAL PRIMARY KEY,
  usuario_id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  producto_id UUID REFERENCES public.productos(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(usuario_id, producto_id)
);

CREATE TABLE IF NOT EXISTS public.notificaciones (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  usuario_id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  tipo TEXT NOT NULL DEFAULT 'sistema',
  titulo TEXT NOT NULL,
  mensaje TEXT,
  leida BOOLEAN DEFAULT FALSE,
  fecha_creacion TIMESTAMPTZ DEFAULT NOW(),
  enlace TEXT,
  imagen_url TEXT
);

CREATE TABLE IF NOT EXISTS public."reseñas" (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  pedido_id UUID REFERENCES public.pedidos(id) ON DELETE CASCADE NOT NULL UNIQUE,
  producto_id UUID REFERENCES public.productos(id) ON DELETE CASCADE NOT NULL,
  proveedor_id UUID REFERENCES public.perfiles_proveedores(id) ON DELETE CASCADE,
  comprador_id UUID REFERENCES auth.users ON DELETE CASCADE,
  comprador_nombre TEXT,
  calificacion INT NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
  comentario TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════
-- 2. DATOS INICIALES
-- ══════════════════════════════════════════════════════
INSERT INTO public.categorias (nombre, campos_dinamicos) VALUES
  ('Miel',      '["Floración", "Textura", "Color"]'),
  ('Queso',     '["Tipo de Leche", "Maduración"]'),
  ('Carne',     '["Corte", "Alimentación"]'),
  ('Tejidos',   '["Material", "Técnica"]'),
  ('Vegetales', '["Tipo de Cultivo", "Temporada"]'),
  ('Otros',     '["Descripción Adicional"]')
ON CONFLICT (nombre) DO NOTHING;

-- ══════════════════════════════════════════════════════
-- 3. ÍNDICES
-- ══════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_productos_proveedor     ON public.productos(proveedor_id);
CREATE INDEX IF NOT EXISTS idx_productos_filtro        ON public.productos(activo, estado);
CREATE INDEX IF NOT EXISTS idx_pedidos_proveedor       ON public.pedidos(proveedor_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_comprador       ON public.pedidos(comprador_id);
CREATE INDEX IF NOT EXISTS idx_interacciones_proveedor ON public.interacciones(proveedor_id);
CREATE INDEX IF NOT EXISTS idx_favoritos_usuario       ON public.favoritos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_perfiles_region         ON public.perfiles_proveedores(region);
CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario  ON public.notificaciones(usuario_id);
CREATE INDEX IF NOT EXISTS "idx_reseñas_producto"      ON public."reseñas"(producto_id);
CREATE INDEX IF NOT EXISTS "idx_reseñas_proveedor"     ON public."reseñas"(proveedor_id);

-- ══════════════════════════════════════════════════════
-- 4. ROW LEVEL SECURITY
-- ══════════════════════════════════════════════════════
ALTER TABLE public.categorias           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles_proveedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productos            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interacciones        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favoritos            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."reseñas"            ENABLE ROW LEVEL SECURITY;

-- Perfiles
DROP POLICY IF EXISTS "Perfiles visibles para todos" ON public.perfiles_proveedores;
CREATE POLICY "Perfiles visibles para todos" ON public.perfiles_proveedores FOR SELECT USING (true);

DROP POLICY IF EXISTS "Proveedor edita su propio perfil" ON public.perfiles_proveedores;
CREATE POLICY "Proveedor edita su propio perfil" ON public.perfiles_proveedores
  FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

REVOKE SELECT ON public.perfiles_proveedores FROM anon, authenticated;
GRANT SELECT (id, nombre_comercial, whatsapp, descripcion, ubicacion, region, verificado,
              metodo_pago, premium_activo, premium_vencimiento, updated_at,
              foto_perfil_url, portada_url, horarios_atencion, metodos_pago)
  ON public.perfiles_proveedores TO anon, authenticated;
GRANT INSERT, UPDATE ON public.perfiles_proveedores TO authenticated;
GRANT ALL ON public.perfiles_proveedores TO service_role;

-- Categorías
DROP POLICY IF EXISTS "Categorias visibles para todos" ON public.categorias;
CREATE POLICY "Categorias visibles para todos" ON public.categorias FOR SELECT USING (true);

-- Productos
DROP POLICY IF EXISTS "Productos visibles para clientes" ON public.productos;
CREATE POLICY "Productos visibles para clientes" ON public.productos
  FOR SELECT USING (activo = true AND estado = 'aprobado');

DROP POLICY IF EXISTS "Proveedores gestionan sus productos" ON public.productos;
CREATE POLICY "Proveedores gestionan sus productos" ON public.productos
  FOR ALL USING (auth.uid() = proveedor_id) WITH CHECK (auth.uid() = proveedor_id);

-- Pedidos
DROP POLICY IF EXISTS "Crear pedido con proveedor real" ON public.pedidos;
CREATE POLICY "Crear pedido con proveedor real" ON public.pedidos
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.productos p
      WHERE p.id = producto_id AND p.proveedor_id = pedidos.proveedor_id AND p.activo = true
    )
  );

DROP POLICY IF EXISTS "Proveedores ven sus propios pedidos" ON public.pedidos;
CREATE POLICY "Proveedores ven sus propios pedidos" ON public.pedidos
  FOR SELECT USING (auth.uid() = proveedor_id);

DROP POLICY IF EXISTS "Comprador ve sus pedidos" ON public.pedidos;
CREATE POLICY "Comprador ve sus pedidos" ON public.pedidos
  FOR SELECT USING (auth.uid() = comprador_id);

DROP POLICY IF EXISTS "Proveedores actualizan sus pedidos" ON public.pedidos;
CREATE POLICY "Proveedores actualizan sus pedidos" ON public.pedidos
  FOR UPDATE USING (auth.uid() = proveedor_id);

-- Interacciones
DROP POLICY IF EXISTS "Cualquiera registra interacciones" ON public.interacciones;
DROP POLICY IF EXISTS "Registrar interaccion en producto activo" ON public.interacciones;
DROP POLICY IF EXISTS "Proveedores ven sus interacciones" ON public.interacciones;

CREATE POLICY "Registrar interaccion en producto activo" ON public.interacciones
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.productos p WHERE p.id = producto_id AND p.activo = true AND p.estado = 'aprobado')
  );
CREATE POLICY "Proveedores ven sus interacciones" ON public.interacciones
  FOR SELECT USING (auth.uid() = proveedor_id);

GRANT INSERT ON public.interacciones TO anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.interacciones_id_seq TO anon, authenticated;

-- Favoritos
DROP POLICY IF EXISTS "Usuarios gestionan sus favoritos" ON public.favoritos;
CREATE POLICY "Usuarios gestionan sus favoritos" ON public.favoritos
  FOR ALL USING (auth.uid() = usuario_id) WITH CHECK (auth.uid() = usuario_id);

-- Notificaciones
DROP POLICY IF EXISTS "Usuarios ven sus notificaciones" ON public.notificaciones;
CREATE POLICY "Usuarios ven sus notificaciones" ON public.notificaciones
  FOR SELECT USING (auth.uid() = usuario_id);
DROP POLICY IF EXISTS "Usuarios actualizan sus notificaciones" ON public.notificaciones;
CREATE POLICY "Usuarios actualizan sus notificaciones" ON public.notificaciones
  FOR UPDATE USING (auth.uid() = usuario_id) WITH CHECK (auth.uid() = usuario_id);
DROP POLICY IF EXISTS "Usuarios eliminan sus notificaciones" ON public.notificaciones;
CREATE POLICY "Usuarios eliminan sus notificaciones" ON public.notificaciones
  FOR DELETE USING (auth.uid() = usuario_id);

-- Reseñas
DROP POLICY IF EXISTS "Ver reseñas de productos activos" ON public."reseñas";
CREATE POLICY "Ver reseñas de productos activos" ON public."reseñas"
  FOR SELECT USING (EXISTS (SELECT 1 FROM public.productos p WHERE p.id = producto_id AND p.activo = true AND p.estado = 'aprobado'));
DROP POLICY IF EXISTS "Comprador crea su reseña" ON public."reseñas";
CREATE POLICY "Comprador crea su reseña" ON public."reseñas"
  FOR INSERT WITH CHECK (comprador_id = auth.uid());

-- ══════════════════════════════════════════════════════
-- 5. STORAGE
-- ══════════════════════════════════════════════════════
INSERT INTO storage.buckets (id, name, public) VALUES ('productos', 'productos', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('comprobantes', 'comprobantes', false) ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Acceso público a imágenes" ON storage.objects;
DROP POLICY IF EXISTS "Proveedores ven sus comprobantes" ON storage.objects;
DROP POLICY IF EXISTS "Clientes suben comprobantes" ON storage.objects;
DROP POLICY IF EXISTS "Proveedores pueden subir fotos" ON storage.objects;
DROP POLICY IF EXISTS "Proveedores pueden editar sus fotos" ON storage.objects;
DROP POLICY IF EXISTS "Proveedores pueden borrar sus fotos" ON storage.objects;

CREATE POLICY "Acceso público a imágenes" ON storage.objects FOR SELECT USING (bucket_id = 'productos');
CREATE POLICY "Proveedores ven sus comprobantes" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'comprobantes' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Clientes suben comprobantes" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'comprobantes');
CREATE POLICY "Proveedores pueden subir fotos" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'productos');
CREATE POLICY "Proveedores pueden editar sus fotos" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'productos' AND auth.uid() = owner);
CREATE POLICY "Proveedores pueden borrar sus fotos" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'productos' AND auth.uid() = owner);

-- ══════════════════════════════════════════════════════
-- 6. FUNCIONES RPC (SECURITY DEFINER, search_path = ')
-- ══════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.disminuir_stock_producto(prod_id UUID, cant_a_restar INT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.productos
    SET detalles = jsonb_set(detalles, '{stock}',
        ((COALESCE(detalles->>'stock', '0')::int) - cant_a_restar)::text::jsonb)
    WHERE id = prod_id
      AND (detalles->'stock') IS NOT NULL
      AND (detalles->>'stock')::int >= cant_a_restar;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stock insuficiente o producto no encontrado: %', prod_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
REVOKE EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) TO service_role;

CREATE OR REPLACE FUNCTION public.obtener_mi_config_pago()
RETURNS JSONB AS $$
BEGIN
  RETURN (SELECT config_pago FROM public.perfiles_proveedores WHERE id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
REVOKE EXECUTE ON FUNCTION public.obtener_mi_config_pago() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.obtener_mi_config_pago() TO authenticated;

CREATE OR REPLACE FUNCTION public.obtener_datos_transferencia(p_proveedor_id UUID)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'titular',       config_pago->>'titular',
      'rut',           config_pago->>'rut',
      'banco',         config_pago->>'banco',
      'tipo_cuenta',   config_pago->>'tipo_cuenta',
      'numero_cuenta', config_pago->>'numero_cuenta',
      'alias',         config_pago->>'alias'
    )
    FROM public.perfiles_proveedores WHERE id = p_proveedor_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
REVOKE EXECUTE ON FUNCTION public.obtener_datos_transferencia(UUID) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.obtener_datos_transferencia(UUID) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.auto_aprobar_productos_verificados()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.perfiles_proveedores WHERE id = NEW.proveedor_id AND verificado = TRUE) THEN
    NEW.estado = 'aprobado';
  ELSE
    NEW.estado = 'pendiente';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
REVOKE EXECUTE ON FUNCTION public.auto_aprobar_productos_verificados() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.perfiles_proveedores (id) VALUES (NEW.id) ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.notificar_pedido_pagado()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.estado = 'pagado' AND OLD.estado IS DISTINCT FROM 'pagado' THEN
    INSERT INTO public.notificaciones (usuario_id, tipo, titulo, mensaje, enlace)
    VALUES (NEW.proveedor_id, 'pedido_nuevo', '¡Nuevo pedido pagado!', 'Un cliente pagó uno de tus pedidos.', '/pedidos');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

CREATE OR REPLACE FUNCTION public.notificar_promocion_producto(prod_id UUID, promoTitulo TEXT, promoMensaje TEXT)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.notificaciones (usuario_id, tipo, titulo, mensaje, enlace)
  SELECT f.usuario_id, 'promocion', promoTitulo, promoMensaje, '/detalle/' || $1
  FROM public.favoritos f WHERE f.producto_id = prod_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
REVOKE EXECUTE ON FUNCTION public.notificar_promocion_producto(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.notificar_promocion_producto(UUID, TEXT, TEXT) TO service_role;

-- ══════════════════════════════════════════════════════
-- 7. TRIGGERS
-- ══════════════════════════════════════════════════════
DROP TRIGGER IF EXISTS trigger_auto_aprobar ON public.productos;
CREATE TRIGGER trigger_auto_aprobar
  BEFORE INSERT ON public.productos FOR EACH ROW
  EXECUTE FUNCTION public.auto_aprobar_productos_verificados();

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user();

DROP TRIGGER IF EXISTS trg_notificar_pedido_pagado ON public.pedidos;
CREATE TRIGGER trg_notificar_pedido_pagado
  AFTER UPDATE OF estado ON public.pedidos FOR EACH ROW
  EXECUTE FUNCTION public.notificar_pedido_pagado();

INSERT INTO public.perfiles_proveedores (id)
SELECT id FROM auth.users ON CONFLICT (id) DO NOTHING;

-- ══════════════════════════════════════════════════════
-- 8. VISTA PÚBLICA SEGURA
-- ══════════════════════════════════════════════════════
CREATE OR REPLACE VIEW public.perfiles_publicos WITH (security_invoker = true) AS
  SELECT id, nombre_comercial, whatsapp, descripcion, ubicacion, region, verificado,
         metodo_pago, premium_activo, premium_vencimiento, updated_at,
         foto_perfil_url, portada_url, horarios_atencion, metodos_pago
  FROM public.perfiles_proveedores;
GRANT SELECT ON public.perfiles_publicos TO anon, authenticated;

-- ══════════════════════════════════════════════════════
-- 9. CORRECCIÓN DE CARACTERES / MOJIBAKE
-- ══════════════════════════════════════════════════════
UPDATE public.perfiles_proveedores SET
  nombre_comercial = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(nombre_comercial,'Ã¡','á'),'Ã©','é'),'Ã­','í'),'Ã³','ó'),'Ãº','ú'),'Ã±','ñ'),
  region = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(region,'RegiA^n','Región'),'RegiÃ³n','Región'),'Ã¡','á'),'Ã©','é'),'Ã­','í'),'Ã³','ó'),'Ãº','ú'),'Ã±','ñ')
WHERE nombre_comercial IS NOT NULL OR region IS NOT NULL;

UPDATE public.productos SET
  nombre = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(nombre,'CÃ³digo','Código'),'Ã¡','á'),'Ã©','é'),'Ã­','í'),'Ã³','ó'),'Ãº','ú'),'Ã±','ñ')
WHERE nombre IS NOT NULL;

-- ============================================================================
-- FIN DEL SCRIPT MAESTRO
-- ============================================================================

