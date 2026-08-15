import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ── Verificar firma HMAC-SHA256 de Mercado Pago ──────────────────────────────
async function verificarFirmaMP(req: Request): Promise<boolean> {
  const xSignature = req.headers.get('x-signature')
  const xRequestId = req.headers.get('x-request-id')
  const url = new URL(req.url)
  const dataId = url.searchParams.get('data.id') ?? url.searchParams.get('id')

  const secret = Deno.env.get('MP_WEBHOOK_SECRET')
  if (!secret) {
    console.error('❌ MP_WEBHOOK_SECRET no está configurado en el servidor — verificación rechazada por seguridad')
    return false
  }

  if (!xSignature || !xRequestId) {
    console.error('❌ Falta x-signature o x-request-id')
    return false
  }

  // Extraer ts y v1 de la cabecera x-signature
  const parts: Record<string, string> = {}
  xSignature.split(',').forEach(part => {
    const [key, val] = part.trim().split('=')
    if (key && val) parts[key] = val
  })
  const ts = parts['ts']
  const v1 = parts['v1']
  if (!ts || !v1) { console.error('❌ Formato de x-signature inválido'); return false }

  // Construir el mensaje que firmó MP y calcular HMAC-SHA256
  const manifest = `id:${dataId};request-id:${xRequestId};ts:${ts};`
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  )
  const signatureBuffer = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(manifest))
  const hashHex = Array.from(new Uint8Array(signatureBuffer))
    .map(b => b.toString(16).padStart(2, '0')).join('')

  if (hashHex !== v1) { console.error(`❌ Firma inválida`); return false }
  console.log('✅ Firma de MP verificada.')
  return true
}

Deno.serve(async (req) => {
  try {
    // ── SEGURIDAD #1: Verificar firma antes de cualquier procesamiento ────────
    const firmaValida = await verificarFirmaMP(req)
    if (!firmaValida) {
      return new Response(JSON.stringify({ error: 'Firma inválida' }), {
        status: 401, headers: { 'Content-Type': 'application/json' }
      })
    }

    const body = await req.json()
    const { type, data } = body

    if (type === 'payment') {
      const MP_ACCESS_TOKEN = Deno.env.get('MP_ACCESS_TOKEN')
      const paymentId = data.id

      if (paymentId === "123456") {
        console.log("✅ Notificación de prueba recibida (ID 123456).")
        return new Response(JSON.stringify({ status: 'test_received' }), {
          status: 200, headers: { 'Content-Type': 'application/json' }
        })
      }

      // ── SEGURIDAD #2: Re-consultar el estado real del pago en MP ──────────
      const response = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
        headers: { 'Authorization': `Bearer ${MP_ACCESS_TOKEN}` }
      })
      if (!response.ok) {
        console.error(`❌ Error al consultar MP: ${response.status}`)
        return new Response(JSON.stringify({ error: 'Fallo al verificar pago' }), { status: 502 })
      }

      const paymentData = await response.json()

      if (paymentData.status === 'approved') {
        const supabase = createClient(
          Deno.env.get('SUPABASE_URL') ?? '',
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )
        const reference = paymentData.external_reference

        if (reference && reference.startsWith('PREMIUM_')) {
          const userId = reference.replace('PREMIUM_', '')
          const vencimiento = new Date()
          const esMensual = paymentData.additional_info?.items?.[0]?.title?.includes('Mensual')
          if (esMensual) vencimiento.setMonth(vencimiento.getMonth() + 1)
          else vencimiento.setFullYear(vencimiento.getFullYear() + 1)

          const { error } = await supabase
            .from('perfiles_proveedores')
            .update({ premium_activo: true, premium_vencimiento: vencimiento.toISOString() })
            .eq('id', userId)
          if (error) throw error
          console.log(`¡Usuario ${userId} ahora es PREMIUM!`)

        } else {
          const { data: pedido } = await supabase
            .from('pedidos').select('producto_id, cantidad')
            .eq('id', reference).single()

          if (pedido) {
            const { error: errorUpdate } = await supabase
              .from('pedidos').update({ estado: 'pagado' }).eq('id', reference)
            if (errorUpdate) throw errorUpdate

            const { error: errorStock } = await supabase.rpc('disminuir_stock_producto', {
              prod_id: pedido.producto_id, cant_a_restar: pedido.cantidad || 1
            })
            if (errorStock) console.error('Error al restar stock:', errorStock)
            console.log(`✅ Pedido ${reference} pagado y stock actualizado.`)
          }
        }
      }
    }

    return new Response(JSON.stringify({ status: 'success' }), {
      status: 200, headers: { 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('Error en Webhook:', error.message)
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
})
