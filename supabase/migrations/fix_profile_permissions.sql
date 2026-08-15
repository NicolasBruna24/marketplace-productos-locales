-- ============================================================================
-- FIX PERMISOS PERFIL PROVEEDOR -- Marketplace Local
-- Ejecutar en: Supabase > SQL Editor
-- Descripcion: Otorga permisos de INSERT y UPDATE a usuarios autenticados
--   en la tabla perfiles_proveedores para resolver "permission denied".
-- ADVERTENCIA: Este script NO elimina ni modifica datos existentes.
-- ============================================================================

-- Otorgar permisos explícitos de INSERT y UPDATE para usuarios autenticados
GRANT INSERT, UPDATE ON public.perfiles_proveedores TO authenticated;

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================
