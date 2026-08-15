import os
import io
import json
from supabase import create_client
from PIL import Image

def handler(req):
    # El cuerpo de la petición llega como JSON desde el Webhook de Storage
    try:
        payload = req.json()
    except Exception:
        return json.dumps({"error": "Invalid JSON"}), 400

    record = payload.get('record', {})
    bucket_id = record.get('bucket_id')
    file_path = record.get('name')

    # Solo procesamos si es el bucket correcto
    if bucket_id != 'productos' or not file_path:
        return json.dumps({"message": "Not a product image, skipping"}), 200

    # Las credenciales se obtienen automáticamente del entorno de la función
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    supabase = create_client(url, key)

    try:
        # 1. Descargar imagen original
        file_data = supabase.storage.from_(bucket_id).download(file_path)
        
        # 2. Abrir con Pillow y detectar formato
        img = Image.open(io.BytesIO(file_data))
        img_format = img.format if img.format in ['PNG', 'JPEG', 'WEBP'] else 'JPEG'

        # Evitar re-procesar si ya está optimizada
        if img.width <= 800 and img.height <= 800:
            return json.dumps({"message": "Image already optimized"}), 200

        # 3. Redimensionar (máximo 800px manteniendo proporción)
        img.thumbnail((800, 800), Image.Resampling.LANCZOS)

        output = io.BytesIO()
        img.save(output, format=img_format, quality=80, optimize=True, progressive=True)
        output.seek(0)

        # 4. Sobrescribir el archivo original
        supabase.storage.from_(bucket_id).upload(
            path=file_path,
            file=output.read(),
            file_options={"upsert": True, "contentType": f"image/{img_format.lower()}"}
        )

        return json.dumps({"status": "success", "file": file_path}), 200

    except Exception as e:
        return json.dumps({"error": str(e)}), 500