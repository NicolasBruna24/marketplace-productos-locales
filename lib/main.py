import os
import io
import json
from supabase import create_client
from PIL import Image

def handler(req):
    # 1. Obtener el cuerpo de la petición (evento de Supabase Storage)
    try:
        payload = req.get_json()
    except Exception:
        return "Invalid JSON", 400

    # Solo procesamos eventos de inserción en el bucket 'productos'
    record = payload.get('record', {})
    bucket_id = record.get('bucket_id')
    file_path = record.get('name')

    if bucket_id != 'productos' or not file_path:
        return json.dumps({"message": "Not a product image, skipping"}), 200

    # 2. Inicializar cliente Supabase con Service Role (para bypass RLS)
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    supabase = create_client(url, key)

    try:
        # 3. Descargar la imagen original
        file_data = supabase.storage.from_(bucket_id).download(file_path)
        
        # 4. Procesar imagen con Pillow
        img = Image.open(io.BytesIO(file_data))
        original_format = img.format or 'JPEG'

        # Si la imagen ya es pequeña, terminamos para evitar bucles infinitos
        if img.width <= 800 and img.height <= 800:
            return json.dumps({"message": "Image already optimized"}), 200

        # Redimensionar manteniendo aspecto (no deforma la foto)
        img.thumbnail((800, 800), Image.Resampling.LANCZOS)

        # Guardar en un buffer de memoria
        output = io.BytesIO()
        # Optimizamos: 85 de calidad es casi imperceptible pero pesa mucho menos
        img.save(output, format=original_format, quality=85, optimize=True)
        output.seek(0)

        # 5. Volver a subir la imagen (sobrescribir la original)
        # El flag 'upsert': 'true' permite reemplazar el archivo existente
        supabase.storage.from_(bucket_id).upload(
            path=file_path,
            file=output.read(),
            file_options={
                "upsert": "true",
                "contentType": record.get('metadata', {}).get('mimetype', 'image/jpeg')
            }
        )

        return json.dumps({"status": "success", "file": file_path}), 200

    except Exception as e:
        print(f"Error procesando imagen: {str(e)}")
        return json.dumps({"error": str(e)}), 500