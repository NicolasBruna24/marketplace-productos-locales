-- ============================================================================
-- RESEÑAS — Marketplace Local (idempotente)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.reseñas (
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

-- Índice para agilizar listados por producto y vendedor
CREATE INDEX IF NOT EXISTS idx_reseñas_producto ON public.reseñas(producto_id);
CREATE INDEX IF NOT EXISTS idx_reseñas_proveedor ON public.reseñas(proveedor_id);

ALTER TABLE public.reseñas ENABLE ROW LEVEL SECURITY;

-- Solo se ven reseñas de productos activos (y aprobados)
DROP POLICY IF EXISTS "Ver reseñas de productos activos" ON public.reseñas;
CREATE POLICY "Ver reseñas de productos activos" ON public.reseñas
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.productos p
      WHERE p.id = producto_id AND p.activo = true AND p.estado = 'aprobado'
    )
  );

-- Solo el propio comprador crea su reseña; UNIQUE(pedido_id) evita duplicados.
-- (La validación de "pedido pagado" se hace en la app: el formulario solo se
--  ofrece tras un pedido pagado.)
DROP POLICY IF EXISTS "Comprador crea su reseña" ON public.reseñas;
CREATE POLICY "Comprador crea su reseña" ON public.reseñas
  FOR INSERT WITH CHECK (comprador_id = auth.uid());

-- ============================================================================
-- FIN
-- ============================================================================
