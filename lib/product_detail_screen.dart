import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';
import 'package:cotizador_de_productos_locales/login_screen.dart';
import 'package:cotizador_de_productos_locales/edit_product_screen.dart';
import 'package:cotizador_de_productos_locales/widgets/page_transitions.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> productData;

  const ProductDetailScreen({super.key, required this.productData});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final SupabaseService _service = SupabaseService();
  int _cantidad = 1;
  String _tipoEntrega = 'retiro'; // 'retiro', 'vendedor', 'courier'
  final TextEditingController _direccionController = TextEditingController();
  bool _isProcessing = false;
  late Future<Map<String, dynamic>> _ratingFuture;
  late Future<List<Map<String, dynamic>>> _reviewsFuture;

  // Acceso abreviado a los datos
  Map<String, dynamic> get productData => widget.productData;

  // Getters para facilitar el acceso a los datos anidados de Supabase
  String get title => productData['nombre']?.toString() ?? 'Producto';
  double get price {
    final raw = productData['precio_base'];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }
  String get region => productData['perfiles_proveedores']?['region']?.toString() ?? 'Ubicación no disponible';
  String get sellerName => productData['perfiles_proveedores']?['nombre_comercial']?.toString() ?? 'Productor Anónimo';
  String? get imageUrl => productData['imagen_url']?.toString();
  int get maxStock {
    final stockRaw = productData['detalles']?['stock'];
    if (stockRaw is int) return stockRaw;
    if (stockRaw is String) return int.tryParse(stockRaw) ?? 999;
    return 999;
  }

  @override
  void initState() {
    super.initState();
    final prodId = productData['id']?.toString() ?? '';
    _ratingFuture = _service.getAverageRating(prodId);
    _reviewsFuture = _service.getProductReviews(prodId);
  }

  @override
  void dispose() {
    _direccionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAF8), // Fondo blanco-verdoso muy sutil
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.contact_support_outlined, color: Colors.black),
            onPressed: () => _mostrarModalContacto(context),
          ),
          const SizedBox(width: 10),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAF8), 
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450), // Simula ancho de móvil
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageSection(),
                  const SizedBox(height: 24),
                  _buildSellerRow(),
                  const SizedBox(height: 6),
                  _buildRegionRow(),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: -0.4,
                      color: Color(0xFF1C1C1C),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(price),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -0.5,
                      color: Color(0xFF111318),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildQuantitySelector(),
                  const SizedBox(height: 14),
                  _buildDeliverySelector(),
                  if (_tipoEntrega != 'retiro') ...[
                    const SizedBox(height: 12),
                    _buildAddressField(),
                  ],
                  const SizedBox(height: 30),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  _buildReviewsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reseñas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, dynamic>>(
          future: _ratingFuture,
          builder: (context, snap) {
            final total = (snap.data?['total'] ?? 0) as int;
            final prom = ((snap.data?['promedio'] ?? 0.0) as num).toDouble();
            return Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 22),
                const SizedBox(width: 4),
                Text(prom.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 6),
                Text('($total reseñas)', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _reviewsFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Aún no hay reseñas de este producto.', style: TextStyle(color: Colors.grey[600])),
              );
            }
            return Column(children: list.map((r) => _reviewItem(r)).toList());
          },
        ),
      ],
    );
  }

  Widget _reviewItem(Map<String, dynamic> r) {
    final cal = (r['calificacion'] ?? 0) as int;
    return Card(
      elevation: 0,
      color: const Color(0xFFF7F9F7),
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(r['comprador_nombre']?.toString() ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                Row(
                  children: List.generate(5, (i) => Icon(
                    i < cal ? Icons.star : Icons.star_border,
                    size: 14,
                    color: i < cal ? Colors.amber : Colors.grey,
                  )),
                ),
              ],
            ),
            if (((r['comentario']?.toString() ?? '').trim()).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(r['comentario'].toString(), style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F4), // Fondo gris claro
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.5, // Imagen cuadrada ~50% del ancho
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ColoredBox(
                color: const Color(0xFFE9EBEE),
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.contain,
                        memCacheWidth: 600,
                        memCacheHeight: 600,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.broken_image_outlined, size: 52, color: Colors.grey),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.eco_outlined, size: 56, color: Color(0xFF2E7D32)),
                          SizedBox(height: 8),
                          Text(
                            'Imagen del producto',
                            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSellerRow() {
    return InkWell(
      onTap: () => _mostrarModalContacto(context),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.storefront_outlined, size: 15, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              sellerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.verified, size: 15, color: Color(0xFF2E7D32)),
        ],
      ),
    );
  }

  Widget _buildRegionRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            region,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      children: [
        const Text('Cantidad', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1C))),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18, color: Colors.black87),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                onPressed: _cantidad > 1
                    ? () => setState(() => _cantidad = _cantidad - 1)
                    : null,
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$_cantidad',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1C)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18, color: Colors.black87),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                onPressed: _cantidad < maxStock
                    ? () => setState(() => _cantidad = _cantidad + 1)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliverySelector() {
    return Row(
      children: [
        const Text('Entrega', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1C))),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _tipoEntrega,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black54),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1C), fontWeight: FontWeight.w600),
              items: const [
                DropdownMenuItem(value: 'retiro', child: Text('Retiro en sede', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'vendedor', child: Text('Entrega Productor', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'courier', child: Text('Envío Empresa', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (val) => setState(() => _tipoEntrega = val!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressField() {
    return TextField(
      controller: _direccionController,
      decoration: InputDecoration(
        labelText: 'Dirección de envío',
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
        hintText: 'Calle, número, ciudad...',
        hintStyle: const TextStyle(fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _irAlLogin() {
    // Sin sesión: llevar al Login y, al volver, reconstruir el botón con la
    // sesión recién creada (cambiará a "Comprar ahora").
    Navigator.push(
      context,
      slideRoute(const LoginScreen()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _buildActionButtons() {
    // Verificar sesión al construir el botón (vía supabase.auth.currentUser)
    final bool estaLogueado = _service.usuarioActual != null;

    final bool esDuenio = _service.usuarioActual?.id == productData['proveedor_id'];

    return Column(
      children: [
        if (esDuenio)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    slideRoute(EditProductScreen(productData: productData)),
                  ).then((_) {
                    if (mounted) setState(() {});
                  });
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar producto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isProcessing
                ? null
                : estaLogueado
                    ? () => _iniciarPagoOnline(context)
                    : _irAlLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32), // Verde de marca
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(estaLogueado ? Icons.flash_on : Icons.lock_outline, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          estaLogueado ? 'Comprar ahora' : 'Inicia sesión para comprar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () {
              final proveedor = productData['perfiles_proveedores'];
              final String? phone = proveedor?['whatsapp'];
              if (phone == null || phone.replaceAll(RegExp(r'[^0-9]'), '').isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Este productor aún no tiene WhatsApp configurado')),
                );
                return;
              }
              _contactarVendedor(context, '');
            },
            icon: const Icon(Icons.chat_outlined, size: 20),
            label: const Text('Contactar por WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C1C1C), // Negro / gris oscuro
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _iniciarPagoOnline(BuildContext context) async {
    if (_isProcessing) return;
    
    try {
      // Validación previa de stock
      final int stockActual = productData['detalles']?['stock'] ?? 1;
      if (stockActual <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lo sentimos, este producto se acaba de agotar.')),
        );
        return;
      }

      if (_tipoEntrega != 'retiro' && _direccionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, ingresa una dirección para el envío.')),
        );
        return;
      }

      setState(() => _isProcessing = true);

      // Obtener el link de pago desde la Edge Function 'procesar-pago-mp'.
      // La función recibe el producto y la cantidad, y devuelve el init_point.
      debugPrint(
        '▶ Procesando pago: productId=${productData['id']} | cantidad=$_cantidad',
      );
      final urlPago = await _service.crearPreferenciaPago(
        productData['id'].toString(),
        _cantidad,
      );

      // Abrir la pasarela de pago en el navegador
      final uri = Uri.parse(urlPago);
      final canLaunch = await canLaunchUrl(uri);
      if (!context.mounted) return;
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar el pago: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _mostrarModalTransferencia(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: _service.obtenerDatosTransferencia(productData['proveedor_id'].toString()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
            );
          }

          final config = snapshot.data ?? {};

          return StatefulBuilder(
            builder: (context, setModalState) {
              bool procesando = false;

              Future<void> confirmar() async {
                if (procesando) return; // 🔒 Guardia anti doble-clic

                if (_tipoEntrega != 'retiro' && _direccionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor, ingresa una dirección de envío.')),
                  );
                  return;
                }

                setModalState(() => procesando = true);
                try {
                  // Registramos el pedido para que el vendedor lo vea en su lista
                  await _service.crearPedido({
                    'producto_id': productData['id'],
                    'proveedor_id': productData['proveedor_id'],
                    'comprador_id': _service.usuarioActual?.id,
                    'comprador_nombre': _service.usuarioActual?.email ?? 'Cliente',
                    'monto': price * _cantidad,
                    'metodo_pago': 'transferencia',
                    'estado': 'pendiente_pago',
                    'cantidad': _cantidad,
                    'tipo_entrega': _tipoEntrega,
                    'direccion_entrega': _tipoEntrega != 'retiro' ? _direccionController.text.trim() : null,
                  });
                  if (!context.mounted) return;
                  _contactarVendedor(context, 'Ya realicé la transferencia.');
                } finally {
                  if (mounted) setModalState(() => procesando = false);
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Transferencia Bancaria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _buildCopiaField(context, 'Titular', config['titular']?.toString().isNotEmpty == true ? config['titular'].toString() : sellerName),
                    if (config['rut'] != null && config['rut'].toString().isNotEmpty) _buildCopiaField(context, 'RUT', config['rut'].toString()),
                    if (config['banco'] != null && config['banco'].toString().isNotEmpty) _buildCopiaField(context, 'Banco', config['banco'].toString()),
                    if (config['tipo_cuenta'] != null && config['tipo_cuenta'].toString().isNotEmpty) _buildCopiaField(context, 'Tipo de Cuenta', config['tipo_cuenta'].toString()),
                    if (config['numero_cuenta'] != null && config['numero_cuenta'].toString().isNotEmpty) _buildCopiaField(context, 'Número de Cuenta', config['numero_cuenta'].toString()),
                    if (config['alias'] != null && config['alias'].toString().isNotEmpty) _buildCopiaField(context, 'Alias / Mensaje', config['alias'].toString()),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: procesando ? null : confirmar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        disabledBackgroundColor: Colors.green.withValues(alpha: 0.6),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: procesando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Enviar Comprobante por WhatsApp'),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _mostrarModalContacto(BuildContext context) {
    final String? phone = productData['perfiles_proveedores']?['whatsapp'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Información del Productor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.store, color: Color(0xFF2E7D32)),
              title: const Text('Nombre del Productor'),
              subtitle: Text(sellerName),
            ),
            if (phone != null && phone.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.phone_android, color: Color(0xFF2E7D32)),
                title: const Text('WhatsApp / Contacto'),
                subtitle: Text(phone),
                trailing: const Icon(Icons.copy, size: 20),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: phone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Número copiado al portapapeles'), duration: Duration(seconds: 1)),
                  );
                },
              ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF2E7D32)),
              title: const Text('Pagar por Transferencia'),
              subtitle: const Text('Copia los datos bancarios del productor'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.pop(context);
                _mostrarModalTransferencia(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopiaField(BuildContext context, String label, String value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
      trailing: const Icon(Icons.copy, size: 20),
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copiado al portapapeles'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }

  Future<void> _contactarVendedor(BuildContext context, String mensajeExtra) async {
    final proveedor = productData['perfiles_proveedores'];
    final String? phone = proveedor?['whatsapp']?.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (phone == null || phone.isEmpty) return;

    final message = 'Hola $sellerName, me interesa tu producto "$title". $mensajeExtra';
    final url = Uri.https('wa.me', '/$phone', {'text': message});

    // Registrar la interacción
    await _service.registrarInteraccion(productData['id'], productData['proveedor_id'], 'clic_whatsapp');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
