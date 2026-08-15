-- ============================================================================
-- SECURITY FIXES #2 -- Cotizador Productos Locales
-- Ejecutar en: Supabase > SQL Editor
-- Descripcion: Corrige las advertencias restantes del Security Advisor.
--   1. Function Search Path Mutable (4 funciones) -> agregar SET search_path = ''
--   2. Public Can Execute SECURITY DEFINER -> public.rls_auto_enable()
--   3. Signed-in Users Can Execute SECURITY DEFINER -> public.rls_auto_enable()
-- NOTA: La advertencia "Signed-in Users Can Execute -> obtener_mi_config_pago"
--       es INTENCIONAL: los usuarios autenticados necesitan llamar esa funcion
--       para leer su propia config_pago. Se explica al final del script.
-- ADVERTENCIA: Este script NO elimina ni modifica datos existentes.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- FIX 1: Function Search Path Mutable
-- Problema: Las funciones SECURITY DEFINER sin SET search_path son vulnerables
--           a ataques de "search path hijacking" (un atacante podria crear
--           objetos en otro schema con el mismo nombre para interceptar llamadas).
-- Solucion: Agregar SET search_path = '' para fijar el contexto de busqueda.
--           Al hacerlo, todos los objetos deben estar calificados con su schema
--           (public.tabla), lo que ya es el caso en todas nuestras funciones.
-- ----------------------------------------------------------------------------

-- 1a. obtener_mi_config_pago
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

REVOKE EXECUTE ON FUNCTION public.obtener_mi_config_pago() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.obtener_mi_config_pago() FROM anon;
GRANT EXECUTE ON FUNCTION public.obtener_mi_config_pago() TO authenticated;

-- 1b. auto_aprobar_productos_verificados
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

REVOKE EXECUTE ON FUNCTION public.auto_aprobar_productos_verificados() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.auto_aprobar_productos_verificados() FROM anon;
REVOKE EXECUTE ON FUNCTION public.auto_aprobar_productos_verificados() FROM authenticated;

-- 1c. handle_new_user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.perfiles_proveedores (id)
  VALUES (new.id)
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated;

-- 1d. disminuir_stock_producto
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

REVOKE EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.disminuir_stock_producto(UUID, INT) TO service_role;

-- ----------------------------------------------------------------------------
-- FIX 2: Public Can Execute SECURITY DEFINER -> public.rls_auto_enable()
--         Signed-in Users Can Execute SECURITY DEFINER -> public.rls_auto_enable()
--
-- Que es rls_auto_enable()?
--   Es una funcion interna creada automaticamente por Supabase para habilitar
--   RLS en tablas desde su panel de administracion. No es una funcion que tu
--   hayas creado ni que la aplicacion deba llamar directamente. Es seguro
--   revocar el acceso publico y de usuarios autenticados.
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- NOTA SOBRE: "Signed-in Users Can Execute SECURITY DEFINER -> obtener_mi_config_pago"
-- Esta advertencia es INTENCIONAL y NO debe corregirse.
-- Por que: Los proveedores autenticados necesitan llamar esta funcion para
--          leer su propio campo config_pago, que esta restringido a nivel de
--          columna (REVOKE SELECT) para todos los roles.
--          La funcion usa auth.uid() internamente para garantizar que cada
--          usuario solo puede leer SU PROPIA configuracion de pago.
-- Accion: Ignorar esta advertencia. Es un falso positivo para este caso de uso.
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- VERIFICACION OPCIONAL
-- ----------------------------------------------------------------------------
-- Confirma que SET search_path fue aplicado a las funciones:
-- SELECT p.proname, p.proconfig
-- FROM pg_proc p
-- JOIN pg_namespace n ON p.pronamespace = n.oid
-- WHERE n.nspname = 'public'
--   AND p.proname IN (
--     'obtener_mi_config_pago',
--     'auto_aprobar_productos_verificados',
--     'handle_new_user',
--     'disminuir_stock_producto'
--   );
-- Deberias ver 'search_path=' en la columna proconfig de cada funcion.

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================
