import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';
import 'package:cotizador_de_productos_locales/widgets/page_transitions.dart';
import 'package:cotizador_de_productos_locales/review_form_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cotizador_de_productos_locales/widgets/empty_state.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final SupabaseService _service = SupabaseService();
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _service.obtenerMisPedidos();
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _ordersFuture = _service.obtenerMisPedidos();
    });
  }

  Future<void> _confirmOrder(
    String pedidoId,
    String productoId,
    int cantidad,
    String compradorWhatsapp,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Pedido'),
        content: const Text(
          '¿Estás seguro de que deseas confirmar este pedido y descontar el stock del producto?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.confirmarPedidoYRestarStock(
          pedidoId,
          productoId,
          cantidad,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pedido confirmado y stock actualizado.'),
            ),
          );
          _refreshOrders(); // Recargar la lista de pedidos
          _contactarComprador(
            compradorWhatsapp,
            'Tu pedido ha sido confirmado y está en preparación. ¡Gracias por tu compra!',
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al confirmar pedido: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _contactarComprador(String whatsapp, String message) async {
    final String phone = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) return;

    final url = Uri.https('wa.me', '/$phone', {'text': message});
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pedidos'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar pedidos: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Aún no tienes pedidos',
              subtitle: 'Aquí verás los pedidos que realices y los que recibas.',
            );
          } else {
            final orders = snapshot.data!;
            final String? userId = _service.usuarioActual?.id;
            return RefreshIndicator(
              onRefresh: _refreshOrders,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final product = order['productos'];
                  final String productName =
                      product?['nombre'] ?? 'Producto Desconocido';
                  final String imageUrl = product?['imagen_url'] ?? '';
                  final double amount = (order['monto'] as num).toDouble();
                  final String paymentMethod = order['metodo_pago'] ?? 'N/A';
                  final String status = order['estado'] ?? 'desconocido';
                  final String buyerName =
                      order['comprador_nombre'] ?? 'Anónimo';
                  final String buyerWhatsapp =
                      order['comprador_whatsapp'] ?? '';
                  final String orderId = order['id'];
                  final String? productId = order['producto_id'];
                  final int quantity = order['cantidad'] ?? 1;
                  final String deliveryType = order['tipo_entrega'] ?? 'retiro';
                  final String? deliveryAddress = order['direccion_entrega'];
                  final String? buyerId = order['comprador_id']?.toString();
                  final String? sellerId = order['proveedor_id']?.toString();
                  final bool isBuyer = userId != null && buyerId == userId;
                  final bool isSeller = userId != null && sellerId == userId;
                  final bool alreadyRated;
                  {
                    // `reseñas.pedido_id` tiene UNIQUE, por lo que PostgREST trata
                    // la relación pedido→reseña como "to-one" y la devuelve como un
                    // OBJETO (Map) cuando existe, en lugar de un array. Por eso NO
                    // se debe castear con `as List` (tira "_Map is not a subtype of
                    // List"). Aquí se normaliza para aceptar Map, List o null.
                    final reviewValue = order['reseñas'];
                    alreadyRated = reviewValue is List
                        ? reviewValue.isNotEmpty
                        : reviewValue != null;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: Colors.grey[200]),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        Icons.broken_image,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Comprador: $buyerName',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      'Cantidad: $quantity un.',
                                      style: const TextStyle(
                                        color: Colors.blueGrey,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Monto: ${NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(amount)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              const Icon(
                                Icons.local_shipping_outlined,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Entrega: ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                deliveryType == 'retiro'
                                    ? 'Retiro en sede'
                                    : deliveryType == 'vendedor'
                                    ? 'Gestionada por vendedor'
                                    : 'Empresa especializada',
                              ),
                            ],
                          ),
                          if (deliveryType != 'retiro' &&
                              deliveryAddress != null &&
                              deliveryAddress.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Dirección: $deliveryAddress',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Método de Pago: ${paymentMethod == 'mercado_pago' ? 'Mercado Pago' : 'Transferencia'}',
                          ),
                          Text(
                            'Estado: ${status == 'pendiente_pago'
                                ? 'Pendiente de Pago'
                                : status == 'pagado'
                                ? 'Pagado'
                                : 'Completado'}',
                          ),
                          if (status == 'pendiente_pago' &&
                              paymentMethod == 'transferencia' &&
                              productId != null && isSeller)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: ElevatedButton.icon(
                                onPressed: () => _confirmOrder(
                                  orderId,
                                  productId,
                                  quantity,
                                  buyerWhatsapp,
                                ),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text(
                                  'Confirmar Pago y Descontar Stock',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          // El botón "Calificar producto" debe aparecer SOLO para el
                          // comprador del pedido (comprador_id == auth.uid()), nunca
                          // para el vendedor. isBuyer ya equivale a
                          // `buyerId == userId`, donde buyerId = comprador_id y
                          // userId = usuario actual (auth.uid()).
                          if ((status == 'pagado' || status == 'completado') &&
                              isBuyer &&
                              !alreadyRated)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final pid = order['producto_id'];
                                  if (pid == null) return;
                                  Navigator.push(
                                    context,
                                    slideRoute(
                                      ReviewFormScreen(
                                        pedidoId: orderId,
                                        productoId: pid.toString(),
                                        proveedorId:
                                            (order['proveedor_id'] ?? '')
                                                .toString(),
                                      ),
                                    ),
                                  ).then((_) => _refreshOrders());
                                },
                                icon: const Icon(Icons.star_border),
                                label: const Text('Calificar producto'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2E7D32),
                                  side: const BorderSide(
                                    color: Color(0xFF2E7D32),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }
        },
      ),
    );
  }
}
