// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  // Manejar peticiones CORS (Preflight)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Inicializar el cliente de Supabase con la Service Role Key (permisos de Admin)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 2. Obtener el token de autenticación del usuario que hace la petición
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('No se proporcionó el token de autorización');
    }

    // 3. Verificar quién es el usuario que está llamando a la función
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      throw new Error('Usuario no autenticado o token inválido');
    }

    // 4. Leer el ID del usuario a eliminar del cuerpo de la petición
    const { user_id } = await req.json();

    // SEGURIDAD: Validar que el usuario solo pueda borrarse a sí mismo
    if (user.id !== user_id) {
      return new Response(
        JSON.stringify({ error: 'No tienes permiso para eliminar esta cuenta.' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 5. Eliminar el usuario usando el API de Administración
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user_id);

    if (deleteError) {
      throw deleteError;
    }

    return new Response(
      JSON.stringify({ message: `Cuenta ${user_id} eliminada con éxito` }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
