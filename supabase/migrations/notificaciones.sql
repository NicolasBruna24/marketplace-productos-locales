-- ============================================================================
-- NOTIFICACIONES — Marketplace Local (idempotente)
-- ============================================================================
-- Tabla, RLS y triggers del sistema de notificaciones.

-- 1. TABLA ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notificaciones (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  usuario_id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  tipo TEXT NOT NULL DEFAULT 'sistema',
  titulo TEXT NOT NULL,
  mensaje TEXT,
  leida BOOLEAN DEFAULT false,
  fecha_creacion TIMESTAMPTZ DEFAULT NOW(),
  enlace TEXT,
  imagen_url TEXT
);

ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

-- 2. RLS: cada usuario solo ve/actualiza/borra las suyas -------------------
DROP POLICY IF EXISTS "Usuarios ven sus notificaciones" ON public.notificaciones;
CREATE POLICY "Usuarios ven sus notificaciones" ON public.notificaciones
  FOR SELECT USING (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "Usuarios actualizan sus notificaciones" ON public.notificaciones;
CREATE POLICY "Usuarios actualizan sus notificaciones" ON public.notificaciones
  FOR UPDATE USING (auth.uid() = usuario_id) WITH CHECK (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "Usuarios eliminan sus notificaciones" ON public.notificaciones;
CREATE POLICY "Usuarios eliminan sus notificaciones" ON public.notificaciones
  FOR DELETE USING (auth.uid() = usuario_id);

-- 3. TRIGGER: notificar al proveedor cuando un pedido pasa a 'pagado' ------
CREATE OR REPLACE FUNCTION public.notificar_pedido_pagado()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.estado = 'pagado' AND OLD.estado IS DISTINCT FROM 'pagado' THEN
    INSERT INTO public.notificaciones (usuario_id, tipo, titulo, mensaje, enlace)
    VALUES (
      NEW.proveedor_id,
      'pedido_nuevo',
      '¡Nuevo pedido pagado!',
      'Un cliente pagó uno de tus pedidos.',
      '/pedidos'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP TRIGGER IF EXISTS trg_notificar_pedido_pagado ON public.pedidos;
CREATE TRIGGER trg_notificar_pedido_pagado
  AFTER UPDATE OF estado ON public.pedidos
  FOR EACH ROW
  EXECUTE FUNCTION public.notificar_pedido_pagado();

-- 4. FUNCIÓN: notificar promociones a quienes tienen el producto en favoritos
-- Invócala desde un panel admin o una función de negocio, p. ej.:
--   SELECT public.notificar_promocion_producto('<producto_uuid>', '¡En promoción!', '20% de descuento');
CREATE OR REPLACE FUNCTION public.notificar_promocion_producto(
  prod_id UUID, promoTitulo TEXT, promoMensaje TEXT)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.notificaciones (usuario_id, tipo, titulo, mensaje, enlace)
  SELECT f.usuario_id, 'promocion', promoTitulo, promoMensaje, '/detalle/' || $1
  FROM public.favoritos f
  WHERE f.producto_id = prod_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

REVOKE EXECUTE ON FUNCTION public.notificar_promocion_producto(UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notificar_promocion_producto(UUID, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.notificar_promocion_producto(UUID, TEXT, TEXT) TO service_role;

-- ============================================================================
-- FIN
-- ============================================================================
