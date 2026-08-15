/// Modelo de notificación de la app Marketplace Local.
/// Se llama `AppNotification` para no colisionar con `Notification` de Flutter.
class AppNotification {
  final String id;
  final String usuarioId;
  final String tipo; // 'pedido_nuevo' | 'promocion' | 'mensaje' | 'sistema'
  final String titulo;
  final String mensaje;
  final bool leida;
  final DateTime? fechaCreacion;
  final String? enlace;
  final String? imagenUrl;

  const AppNotification({
    required this.id,
    required this.usuarioId,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.leida,
    this.fechaCreacion,
    this.enlace,
    this.imagenUrl,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'].toString(),
      usuarioId: map['usuario_id'].toString(),
      tipo: map['tipo']?.toString() ?? 'sistema',
      titulo: map['titulo']?.toString() ?? '',
      mensaje: map['mensaje']?.toString() ?? '',
      leida: map['leida'] == true,
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.tryParse(map['fecha_creacion'].toString())
          : null,
      enlace: map['enlace']?.toString(),
      imagenUrl: map['imagen_url']?.toString(),
    );
  }

  AppNotification copyWith({bool? leida}) {
    return AppNotification(
      id: id,
      usuarioId: usuarioId,
      tipo: tipo,
      titulo: titulo,
      mensaje: mensaje,
      leida: leida ?? this.leida,
      fechaCreacion: fechaCreacion,
      enlace: enlace,
      imagenUrl: imagenUrl,
    );
  }
}