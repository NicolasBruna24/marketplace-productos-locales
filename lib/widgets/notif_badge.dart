import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';
import 'package:cotizador_de_productos_locales/notifications_screen.dart';
import 'package:cotizador_de_productos_locales/widgets/page_transitions.dart';

/// Badge (contador) de notificaciones no leídas en el AppBar. Se actualiza en
/// tiempo real con Supabase Realtime y abre el Centro de Notificaciones.
class NotifBadge extends StatefulWidget {
  const NotifBadge({super.key});

  @override
  State<NotifBadge> createState() => _NotifBadgeState();
}

class _NotifBadgeState extends State<NotifBadge> {
  int _count = 0;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
    super.dispose();
  }

  Future<void> _refresh() async {
    final count = await SupabaseService().getUnreadNotificationsCount();
    if (mounted) setState(() => _count = count);

    final user = Supabase.instance.client.auth.currentUser;
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('badge-${user?.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones',
          filter: user == null
              ? null
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'usuario_id',
                  value: user.id,
                ),
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        tooltip: 'Notificaciones',
        onPressed: () async {
          await Navigator.push(context, slideRoute(const NotificationsScreen()));
          _refresh();
        },
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Badge(
          isLabelVisible: _count > 0,
          backgroundColor: Colors.red,
          label: Text('$_count'),
          child: const Icon(Icons.notifications_outlined, color: Colors.black87, size: 22),
        ),
      ),
    );
  }
}