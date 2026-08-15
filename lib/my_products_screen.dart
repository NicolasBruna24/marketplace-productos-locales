import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';
import 'package:cotizador_de_productos_locales/upload_product_screen.dart';
import 'package:cotizador_de_productos_locales/edit_product_screen.dart';
import 'package:cotizador_de_productos_locales/widgets/page_transitions.dart';

/// Lista de productos del proveedor autenticado, con agregar/editar/eliminar.
class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  final _service = SupabaseService();
  List<Map<String, dynamic>> _productos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _service.getMyProducts();
    if (!mounted) return;
    setState(() {
      _productos = data;
      _loading = false;
    });
  }

  String _estado(String? e) {
    switch (e) {
      case 'aprobado':
        return 'Aprobado';
      case 'rechazado':
        return 'Rechazado';
      default:
        return 'Pendiente';
    }
  }

  Color _estadoColor(String? e) {
    switch (e) {
      case 'aprobado':
        return Colors.green;
      case 'rechazado':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Future<void> _crear() async {
    await Navigator.push(context, slideRoute(const UploadProductScreen()));
    _load();
  }

  Future<void> _editar(Map<String, dynamic> p) async {
    await Navigator.push(context, slideRoute(EditProductScreen(productData: p)));
    _load();
  }

  Future<void> _eliminar(Map<String, dynamic> p) async {
    final accion = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opciones del producto'),
        content: Text('¿Qué quieres hacer con "${p['nombre']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'desactivar'),
            child: const Text('Desactivar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'eliminar'),
            child: const Text('Eliminar definitivamente', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (accion == null || !mounted) return;

    if (accion == 'eliminar') {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Eliminar definitivamente?'),
          content: const Text('Esta acción no se puede deshacer.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sí, eliminar'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
      await _service.borrarProducto(p['id'].toString());
    } else {
      await _service.actualizarEstadoStock(p['id'].toString(), false);
    }
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text('Mis Productos'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Agregar producto',
            icon: const Icon(Icons.add),
            onPressed: _crear,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : _productos.isEmpty
              ? _EmptyProducts(onCrear: _crear)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _productos.length,
                    itemBuilder: (context, index) {
                      final p = _productos[index];
                      final precio = (p['precio_base'] is num)
                          ? (p['precio_base'] as num).toDouble()
                          : 0;
                      final activo = p['activo'] == true;
                      final estado = p['estado']?.toString();
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: p['imagen_url'] != null
                                  ? CachedNetworkImage(
                                      imageUrl: p['imagen_url'],
                                      fit: BoxFit.cover,
                                      placeholder: (_, _) => Container(color: Colors.grey[200]),
                                      errorWidget: (_, _, _) => const Icon(Icons.image, color: Colors.grey),
                                    )
                                  : Container(
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image_outlined, color: Colors.grey),
                                    ),
                            ),
                          ),
                          title: Text(
                            p['nombre']?.toString() ?? 'Producto',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_CL')
                                    .format(precio),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _estadoColor(estado).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _estado(estado),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _estadoColor(estado),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (!activo) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Inactivo',
                                        style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit_outlined, color: Color(0xFF2E7D32)),
                                onPressed: () => _editar(p),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _eliminar(p),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  final VoidCallback onCrear;
  const _EmptyProducts({required this.onCrear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 80, color: Color(0xFF2E7D32)),
          const SizedBox(height: 16),
          const Text('Aún no tienes productos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Publica tu primer producto y comienza a vender.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onCrear,
            icon: const Icon(Icons.add),
            label: const Text('Crear mi primer producto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
