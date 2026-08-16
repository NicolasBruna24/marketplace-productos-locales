-- ============================================================================
-- PEDIDOS: vincular cada pedido con su COMPRADOR (comprador_id)
-- ============================================================================
-- Objetivo:
--   * Permitir que el comprador consulte sus pedidos (historial de compras).
--   * Que la pantalla "Mis Pedidos" ofrezca el botón "Calificar producto" SOLO al
--     comprador del pedido (comprador_id = auth.uid()), nunca al vendedor.
--   * Mantener coherente la tabla `reseñas` (ya tiene comprador_id y
--     UNIQUE(pedido_id)): un comprador califica una sola vez su pedido pagado.
--
-- Nota: los pedidos creados ANTES de esta migración quedan con comprador_id en
-- NULL, por lo que el botón de calificación no se muestra para ellos hasta que
-- se registre el comprador_id.
-- ============================================================================

-- 1) Columna que enlaza el pedido con el usuario comprador (auth.users).
--    Se permite NULL para no romper pedidos históricos.
ALTER TABLE IF EXISTS public.pedidos
  ADD COLUMN IF NOT EXISTS comprador_id UUID REFERENCES auth.users ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_pedidos_comprador ON public.pedidos(comprador_id);

-- 2) RLS: el COMPRADOR puede leer sus propios pedidos (historial de compras).
--    Las políticas SELECT se combinan con OR: además de "Proveedores ven sus
--    propios pedidos", el comprador también ve los pedidos donde él es el
--    comprador.
DROP POLICY IF EXISTS "Comprador ve sus pedidos" ON public.pedidos;
CREATE POLICY "Comprador ve sus pedidos" ON public.pedidos
  FOR SELECT USING (auth.uid() = comprador_id);
