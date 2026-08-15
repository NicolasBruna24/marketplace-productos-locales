import 'package:flutter/material.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';

/// Pantalla de Configuración. Por ahora incluye "Eliminar mi Cuenta"
/// (movida desde el drawer) y placeholders de próximas opciones.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = SupabaseService();
  bool _deleting = false;

  Future<void> _eliminarCuenta() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text(
          'Esta acción es irreversible y eliminará todos tus productos y datos asociados. '
          '¿Estás absolutamente seguro de que quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sí, eliminar mi cuenta'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _service.deleteUserAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu cuenta ha sido eliminada con éxito.')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar la cuenta: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.notifications_active_outlined, color: Color(0xFF2E7D32)),
            title: Text('Preferencias de notificaciones'),
            subtitle: Text('Próximamente'),
            enabled: false,
          ),
          const ListTile(
            leading: Icon(Icons.language, color: Color(0xFF2E7D32)),
            title: Text('Idioma y región'),
            subtitle: Text('Próximamente'),
            enabled: false,
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: _deleting ? Colors.grey : Colors.red,
            ),
            title: const Text('Eliminar mi Cuenta', style: TextStyle(color: Colors.red)),
            onTap: _deleting ? null : _eliminarCuenta,
            trailing: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}