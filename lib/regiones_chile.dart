/// Lista oficial de las 16 regiones de Chile.
///
/// Es la fuente única de verdad para el formato de región que usa la app.
/// Se usa en dos lugares que deben coincidir exactamente:
///  - El dropdown de región en [edit_profile_screen.dart] (perfil del proveedor)
///  - La normalización de la región detectada por geolocalización en
///    [product_list_screen.dart]
///
/// Formato: nombres oficiales con prefijo "Región de...".
const List<String> regionesChile = [
  'Región de Arica y Parinacota',
  'Región de Tarapacá',
  'Región de Antofagasta',
  'Región de Atacama',
  'Región de Coquimbo',
  'Región de Valparaíso',
  'Región Metropolitana de Santiago',
  "Región del Libertador General Bernardo O'Higgins",
  'Región del Maule',
  'Región de Ñuble',
  'Región del Biobío',
  'Región de la Araucanía',
  'Región de los Ríos',
  'Región de los Lagos',
  'Región de Aysén del General Carlos Ibáñez del Campo',
  'Región de Magallanes y de la Antártica Chilena',
];

/// Convierte la región cruda que devuelve un geocodificador (administrativeArea
/// en móvil, o `state`/`province`/`region`/`county` de Nominatim en web) a la
/// región oficial canónica de [regionesChile].
///
/// El geocodificador puede devolver variantes como "Valparaíso",
/// "Región de Valparaíso", "Metropolitana", "O'Higgins", "Biobío", etc. Esta
/// función normaliza cualquier variante a la forma oficial para que la
/// detección por geolocalización coincida exactamente con el dropdown del perfil.
///
/// Retorna `null` si no puede identificar la región.
String? normalizarRegion(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final s = _normalizarTexto(raw);
  if (s.isEmpty) return null;

  if (s.contains('arica')) return regionesChile[0];
  if (s.contains('tarapaca')) return regionesChile[1];
  if (s.contains('antofagasta')) return regionesChile[2];
  if (s.contains('atacama')) return regionesChile[3];
  if (s.contains('coquimbo')) return regionesChile[4];
  if (s.contains('valparaiso')) return regionesChile[5];
  if (s.contains('metropolitana') || s.contains('santiago')) return regionesChile[6];
  if (s.contains('ohiggins') || s.contains('libertador')) return regionesChile[7];
  if (s.contains('maule')) return regionesChile[8];
  if (s.contains('nuble')) return regionesChile[9];
  if (s.contains('biobio') || s.contains('bio-bio')) return regionesChile[10];
  if (s.contains('araucania')) return regionesChile[11];
  if (s.contains('rios')) return regionesChile[12];
  if (s.contains('lagos')) return regionesChile[13];
  if (s.contains('aysen') || s.contains('aisen') || s.contains('ibanez')) return regionesChile[14];
  if (s.contains('magallanes')) return regionesChile[15];

  return null;
}

/// Minúsculas y sin tildes/ñ/apóstrofos para comparar subcadenas de forma
/// robusta contra las variantes que entregan los geocodificadores.
String _normalizarTexto(String text) {
  return text
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll("'", '');
}
