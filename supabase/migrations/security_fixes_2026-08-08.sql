-- ============================================================================
-- SECURITY FIXES -- Cotizador Productos Locales
-- Ejecutar en: Supabase > SQL Editor
-- Descripcion: Corrige avisos de alta prioridad del Security Advisor.
--   1. RLS Policy Always True en public.interacciones
--   2. Public Can Execute SECURITY DEFINER Function (4 funciones)
-- ADVERTENCIA: Este script NO elimina ni modifica datos existentes.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- FIX 1: RLS Policy Always True -> public.interacciones
-- Problema: WITH CHECK (true) permite insertar cualquier registro sin validacion.
-- Solucion: Validar que el producto_id exista, este activo y aprobado.
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Cualquiera registra interacciones" ON public.interacciones;

CREATE POLICY "Registrar interaccion en producto activo"
  ON public.interacciones
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.productos p
      WHERE p.id = producto_id
        AND p.activo = true
        AND p.estado = 'aprobado'
    )
  );

-- ----------------------------------------------------------------------------
-- FIX 2: Public Can Execute SECURITY DEFINER Function
-- Problema: En PostgreSQL todas las funciones tienen EXECUTE para PUBLIC por defecto.
-- Solucion: REVOKE EXECUTE FROM PUBLIC y GRANT solo a quienes corresponde.
-- ----------------------------------------------------------------------------

-- 2a. auto_aprobar_productos_verificados()
--     Solo debe ejecutarla el motor (es un trigger), nadie mas.
REVOKE EXECUTE ON FUNCTION public.auto_aprobar_productos_verificados() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.auto_aprobar_productos_verificados() FROM anon;
REVOKE EXECUTE ON FUNCTION public.auto_aprobar_productos_verificados() FROM authenticated;

-- 2b. handle_new_user()
--     Solo debe ejecutarla el motor (es un trigger), nadie mas.
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated;

-- 2c. obtener_mi_config_pago()
--     Solo usuarios autenticados deben poder llamarla.
REVOKE EXECUTE ON FUNCTION public.obtener_mi_config_pago() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.obtener_mi_config_pago() FROM anon;
GRANT EXECUTE ON FUNCTION public.obtener_mi_config_pago() TO authenticated;

-- 2d. disminuir_stock_producto(UUID, INT)
--     Solo service_role (ya tenia REVOKE, se refuerza explicitamente).
REVOKE EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) TO service_role;

-- ----------------------------------------------------------------------------
-- VERIFICACION (opcional -- puedes ejecutar esto por separado para confirmar)
-- ----------------------------------------------------------------------------
-- Verifica que las politicas de interacciones son correctas:
-- SELECT policyname, cmd, qual, with_check
-- FROM pg_policies
-- WHERE tablename = 'interacciones';

-- Verifica permisos de ejecucion de funciones:
-- SELECT routine_name, grantee, privilege_type
-- FROM information_schema.routine_privileges
-- WHERE routine_schema = 'public'
--   AND routine_name IN (
--     'auto_aprobar_productos_verificados',
--     'handle_new_user',
--     'obtener_mi_config_pago',
--     'disminuir_stock_producto'
--   )
-- ORDER BY routine_name, grantee;

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================
