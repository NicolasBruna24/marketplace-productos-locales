import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('APP_URL') ?? '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // ── SEGURIDAD #1: Verificar que el llamante esté autenticado ─────────────
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'No autorizado: falta token' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Verificar el JWT con el cliente de Supabase
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Token inválido o expirado' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ── SEGURIDAD #2: Leer parámetros y validar pedido_id ───────────────────
    const { pedido_id, nombre, precio } = await req.json()

    if (!pedido_id || !precio || precio <= 0) {
      return new Response(JSON.stringify({ error: 'Parámetros inválidos' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Si es pedido normal (no premium), validar que el pedido existe y pertenece
    // a un proveedor real para evitar creación de preferencias con montos falsos
    if (!pedido_id.startsWith('PREMIUM_')) {
      const { data: pedido, error: pedidoError } = await supabase
        .from('pedidos').select('monto, proveedor_id').eq('id', pedido_id).single()

      if (pedidoError || !pedido) {
        return new Response(JSON.stringify({ error: 'Pedido no encontrado' }), {
          status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // Validar que el monto del request coincide con el monto real del pedido en la DB
      if (Math.round(pedido.monto) !== Math.round(precio)) {
        return new Response(JSON.stringify({ error: 'Monto no coincide con el pedido' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
    }

    // ── Obtener el Access Token de Mercado Pago ──────────────────────────────
    const MP_ACCESS_TOKEN = Deno.env.get('MP_ACCESS_TOKEN')
    if (!MP_ACCESS_TOKEN) {
      throw new Error("Token de Mercado Pago no configurado")
    }

    const body = {
      items: [
        {
          title: nombre || "Pedido ProdLocales",
          quantity: 1,
          unit_price: Math.round(precio),
          currency_id: 'CLP'
        }
      ],
      external_reference: pedido_id,
      back_urls: {
        success: "io.supabase.prodlocales://pago-exitoso",
        failure: "io.supabase.prodlocales://pago-fallido",
        pending: "io.supabase.prodlocales://pago-pendiente"
      },
      auto_return: "approved",
      notification_url: "https://glxvtiemjzqlmdiytmow.supabase.co/functions/v1/notificacion-mp",
      payment_methods: {
        installments: 12,
      }
    };

    const response = await fetch('https://api.mercadopago.com/checkout/preferences', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${MP_ACCESS_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });

    const result = await response.json();

    return new Response(
      JSON.stringify({ url_pago: result.init_point }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})