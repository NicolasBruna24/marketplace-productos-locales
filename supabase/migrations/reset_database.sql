-- ============================================================================
-- RESET DE LA BASE DE DATOS (SOLO PARA DESARROLLO)
-- ============================================================================
-- ⚠️⚠️⚠️  ¡DESTRUCTIVO!  ⚠️⚠️⚠️
-- Este script ELIMINA todos los objetos y TODOS los datos de la aplicación
-- (tablas, vista, funciones y triggers). NO lo ejecutes en producción sin
-- antes hacer un respaldo (Backups > Download .sql) de tu proyecto.
--
-- Uso recomendado (solo en entornos de DEV/STAGING):
--   1. Ejecuta este reset.
--   2. Ejecuta database_setup_completo.sql para reconstruir el esquema.
-- ============================================================================

-- ── Triggers ────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trigger_auto_aprobar ON public.productos;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- ── Vista ───────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.perfiles_publicos;

-- ── Funciones ───────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.disminuir_stock_producto(UUID, INT);
DROP FUNCTION IF EXISTS public.obtener_mi_config_pago();
DROP FUNCTION IF EXISTS public.auto_aprobar_productos_verificados();
DROP FUNCTION IF EXISTS public.handle_new_user();

-- ── Tablas (CASCADE elimina dependencias) ───────────────────────────────────
DROP TABLE IF EXISTS public.interacciones CASCADE;
DROP TABLE IF EXISTS public.favoritos CASCADE;
DROP TABLE IF EXISTS public.pedidos CASCADE;
DROP TABLE IF EXISTS public.productos CASCADE;
DROP TABLE IF EXISTS public.perfiles_proveedores CASCADE;
DROP TABLE IF EXISTS public.categorias CASCADE;

-- Nota: los buckets de Storage (productos, comprobantes) se conservan. Si
-- también quieres vaciarlos, borra sus objetos manualmente desde el Dashboard.

-- ============================================================================
-- ✅ LISTO: esquema eliminado.
-- ➤ A continuación ejecuta: supabase/migrations/database_setup_completo.sql
-- ============================================================================
