import os
import pandas as pd
from supabase import create_client

# Configuración de Supabase (vía variables de entorno)
URL = os.getenv("SUPABASE_URL", "https://TU_PROYECTO.supabase.co")
KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "TU_SERVICE_ROLE_KEY")

supabase = create_client(URL, KEY)

def cargar_desde_csv(file_path, proveedor_id):
    """
    Lee un CSV con columnas: nombre, precio, categoria, origen, detalle
    """
    try:
        df = pd.read_csv(file_path)
        print(f"Cargando {len(df)} productos...")

        for _, row in df.iterrows():
            data = {
                "proveedor_id": proveedor_id,
                "nombre": row['nombre'],
                "precio_base": row['precio'],
                "categoria": row['categoria'],
                "detalles": {
                    "origen": row['origen'],
                    "info_adicional": row['detalle']
                },
                "activo": True
            }
            supabase.table("productos").insert(data).execute()
        
        print("✅ Carga masiva completada con éxito.")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    # Ejemplo de uso: cargar_desde_csv('productos_argentina.csv', 'ID_DEL_PROVEEDOR')
    pass