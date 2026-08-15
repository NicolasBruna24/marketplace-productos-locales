#!/bin/bash
# Script de compilación de Flutter Web para Vercel

# 1. Clonar el SDK de Flutter si no está presente en la máquina de Vercel
if [ ! -d "flutter" ]; then
  echo "Clonando Flutter SDK (stable)..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# 2. Agregar Flutter al PATH temporal de la máquina
export PATH="$PATH:$(pwd)/flutter/bin"

# 3. Habilitar soporte Web y construir
echo "Configurando Flutter Web..."
flutter config --enable-web

echo "Compilando Flutter Web en modo Release..."
flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
