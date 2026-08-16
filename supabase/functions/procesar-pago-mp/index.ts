import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('APP_URL') ?? '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Helper para respuestas JSON con error/mensaje claro
function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

serve(async (req) => {
  // Preflight CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // ── 1) Validar que el Content-Type sea JSON ────────────────────────────
  const contentType = req.headers.get('content-type') ?? ''
  console.log('▶ Content-Type recibido:', contentType)
  if (!contentType.toLowerCase().includes('application/json')) {
    return json({ error: 'Content-Type debe ser application/json' }, 400)
  }

  // ── 2) Leer el cuerpo CRUDO y registrarlo ANTES de parsearlo ──────────
  const rawBody = await req.text()
  console.log('▶ rawBody recibido:', JSON.stringify(rawBody))

  if (!rawBody || rawBody.trim() === '') {
    console.error('⛔ Cuerpo vacío detectado (empty body).')
    return json({ error: 'El cuerpo de la solicitud está vacío' }, 400)
  }

  // ── 2b) Parsear con try-catch (evita SyntaxError) ──────────────────────
  let body: { product_id?: unknown; cantidad?: unknown }
  try {
    body = JSON.parse(rawBody)
  } catch (parseError) {
    console.error('⛔ JSON.parse falló con el rawBody:', JSON.stringify(rawBody))
    return json({ error: `Cuerpo de la solicitud no es JSON válido: ${rawBody}` }, 400)
  }

  // ── 3) Validar campos obligatorios ─────────────────────────────────────
  const product_id = body?.product_id
  const cantidad = body?.cantidad
  if (product_id == null || product_id === '') {
    return json({ error: 'El campo product_id es obligatorio' }, 400)
  }
  if (cantidad == null || typeof cantidad !== 'number' || !Number.isInteger(cantidad) || cantidad <= 0) {
    return json({ error: 'El campo cantidad debe ser un entero mayor a 0' }, 400)
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // ── 4) Verificar identidad del llamante (la función tiene verify_jwt) ─
    const authHeader = req.headers.get('Authorization')
    // Fail-closed: sin token válido no se crea el pedido. `user` queda en scope
    // para poder registrar comprador_id del comprador que paga.
    if (!authHeader) {
      return json({ error: 'No autorizado: falta token de autenticación' }, 401)
    }
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) {
      return json({ error: 'Token inválido o expirado' }, 401)
    }

    // ── 5) Consultar el precio real del producto en la DB ─────────────────
    const { data: producto, error: prodError } = await supabase
      .from('productos')
      .select('id, nombre, precio_base, proveedor_id')
      .eq('id', product_id as string)
      .maybeSingle()

    if (prodError || !producto) {
      return json({ error: 'Producto no encontrado' }, 404)
    }

    const precio = Number(producto.precio_base)
    if (!precio || precio <= 0) {
      return json({ error: 'El producto no tiene un precio válido' }, 400)
    }

    // ── 6) Crear el pedido en la BD (estado pendiente_pago) ───────────────
    // Nota de esquema: la tabla `pedidos` usa `producto_id` y `monto` (así lo
    // lee la pantalla 'Mis Pedidos' de la app). El "precio_total" del requisito
    // se guarda en la columna `monto`.
    const precioTotal = Math.round(precio * (cantidad as number))
    const { data: pedido, error: pedidoError } = await supabase
      .from('pedidos')
      .insert({
        producto_id: product_id,
        proveedor_id: producto.proveedor_id,
        comprador_id: user.id,
        comprador_nombre: user.email ?? 'Cliente',
        monto: precioTotal,
        cantidad: cantidad as number,
        metodo_pago: 'mercado_pago',
        estado: 'pendiente_pago',
      })
      .select('id')
      .single()

    if (pedidoError || !pedido) {
      console.error('Error creando pedido:', JSON.stringify(pedidoError))
      return json({ error: 'No se pudo crear el pedido en la base de datos' }, 500)
    }

    // ── 7) Crear la preferencia en Mercado Pago ───────────────────────────
    const MP_ACCESS_TOKEN = Deno.env.get('MP_ACCESS_TOKEN')
    console.log('ℹ MP_ACCESS_TOKEN configurado:', MP_ACCESS_TOKEN ? 'SÍ' : 'NO')
    if (!MP_ACCESS_TOKEN) {
      return json({ error: 'Token de Mercado Pago no configurado' }, 500)
    }

    const mpBody = {
      items: [
        {
          title: producto.nombre || 'Producto',
          quantity: cantidad as number,
          unit_price: Math.round(precio),
          currency_id: 'CLP',
        },
      ],
      external_reference: String(pedido.id),
      back_urls: {
        success: 'io.supabase.prodlocales://pago-exitoso',
        failure: 'io.supabase.prodlocales://pago-fallido',
        pending: 'io.supabase.prodlocales://pago-pendiente',
      },
      auto_return: 'approved',
      notification_url: `${Deno.env.get('SUPABASE_URL')}/functions/v1/notificacion-mp`,
    }

    const mpResponse = await fetch('https://api.mercadopago.com/checkout/preferences', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${MP_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(mpBody),
    })

    const result = await mpResponse.json()

    if (!mpResponse.ok || !result?.init_point) {
      console.error('Mercado Pago respondió:', mpResponse.status, JSON.stringify(result))
      return json({ error: 'Mercado Pago no pudo generar la preferencia de pago' }, 502)
    }

    // ── 8) Devolver el init_point esperado por la app ─────────────────────
    return json({ init_point: result.init_point })
  } catch (error) {
    console.error('Error en procesar-pago-mp:', error)
    return json(
      { error: error instanceof Error ? error.message : 'Error interno del servidor' },
      500
    )
  }
})
