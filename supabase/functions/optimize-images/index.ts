import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";
import { Image } from "https://deno.land/x/imagescript@1.2.15/mod.ts";

Deno.serve(async (req: Request) => {
  try {
    // 1. Obtener el evento del Webhook de Storage
    const payload = await req.json();
    const record = payload.record;
    const bucket_id = record.bucket_id;
    const file_path = record.name;

    // Solo procesar si es el bucket de productos
    if (bucket_id !== 'productos') {
      return new Response(JSON.stringify({ message: "Ignorado: No es el bucket 'productos'" }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }

    // 2. Inicializar cliente de Supabase
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 3. Descargar la imagen original
    const { data: fileData, error: downloadError } = await supabase.storage
      .from(bucket_id)
      .download(file_path);

    if (downloadError) throw downloadError;

    // 4. Procesar y Redimensionar
    const buffer = await fileData.arrayBuffer();
    const img = await Image.decode(buffer);

    // Si ya es pequeña, no hacemos nada para evitar bucles
    if (img.width <= 800 && img.height <= 800) {
      return new Response(JSON.stringify({ message: "Imagen ya optimizada" }), { status: 200 });
    }

    // Redimensionar a un máximo de 800px manteniendo el aspecto
    img.thumbnail(800, 800);
    const resizedBuffer = await img.encode(80); // Calidad al 80% para ahorrar espacio

    // 5. Volver a subir (sobrescribir)
    const { error: uploadError } = await supabase.storage
      .from(bucket_id)
      .upload(file_path, resizedBuffer, {
        contentType: 'image/jpeg',
        upsert: true
      });

    if (uploadError) throw uploadError;

    return new Response(JSON.stringify({ status: "success", path: file_path }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }), { status: 500 });
  }
});