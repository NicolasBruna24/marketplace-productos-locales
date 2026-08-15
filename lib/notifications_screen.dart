import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';
import 'package:cotizador_de_productos_locales/models/notification.dart';

/// Centro de Notificaciones real. Lista desde Supabase, con Realtime,
/// marcado de leídas y eliminación individual/total.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = SupabaseService();
  List<AppNotification> _notifs = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _initRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
    super.dispose();
  }

  Future<void> _initRealtime() async {
    final user = _service.usuarioActual;
    if (user == null) return;
    _channel = Supabase.instance.client
        .channel('notif-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: user.id,
          ),
          callback: (_) {
            if (mounted) _load();
          },
        )
        .subscribe();
  }

  Future<void> _load() async {
    final notifs = await _service.getNotifications();
    if (!mounted) return;
    setState(() {
      _notifs = notifs;
      _loading = false;
    });
  }

  // Al tocar: marcar como leída y (si hay enlace) navegar
  Future<void> _onTap(AppNotification n) async {
    if (!n.leida) {
      await _service.markNotificationAsRead(n.id);
      if (mounted) _load();
    }
    final enlace = n.enlace;
    if (enlace == null || enlace.isEmpty) return;
    // Determinar ruta según el enlace (patrón de tu app)
    if (enlace == '/pedidos' && mounted) {
      Navigator.pop(context); // vuelve al catálogo con tus pedidos
    }
  }

  Future<void> _eliminarTodas() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar todas'),
        content: const Text('¿Eliminar todas las notificaciones? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteAllNotifications();
      if (mounted) _load();
    }
  }

  String _relative(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _icono(String tipo) {
    switch (tipo) {
      case 'pedido_nuevo':
        return Icons.receipt_long;
      case 'promocion':
        return Icons.local_offer;
      case 'mensaje':
        return Icons.chat;
      case 'sistema':
        return Icons.info_outline;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Notificaciones'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Eliminar todas',
            onPressed: _notifs.isEmpty ? null : _eliminarTodas,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : _notifs.isEmpty
              ? const _EmptyNotif()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _notifs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = _notifs[index];
                      return Dismissible(
                        key: ValueKey(n.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red.shade400,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          await _service.deleteNotification(n.id);
                          if (mounted) _load();
                        },
                        child: ListTile(
                          // Gris si NO leída; blanco si leída
                          tileColor: n.leida ? Colors.white : Colors.grey.shade100,
                          leading: Icon(_icono(n.tipo), color: const Color(0xFF2E7D32)),
                          title: Text(
                            n.titulo,
                            style: TextStyle(
                              fontWeight: n.leida ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            n.mensaje,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _relative(n.fechaCreacion),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              if (!n.leida) ...[
                                const SizedBox(height: 4),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2E7D32),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: () => _onTap(n),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyNotif extends StatelessWidget {
  const _EmptyNotif();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Color(0xFF2E7D32)),
          SizedBox(height: 16),
          Text(
            '¡Todo al día!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          SizedBox(height: 8),
          Text('No tienes notificaciones por ahora.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
