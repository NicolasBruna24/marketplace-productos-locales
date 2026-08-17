import 'package:flutter/material.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';
import 'package:cotizador_de_productos_locales/product_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:cotizador_de_productos_locales/widgets/page_transitions.dart';
import 'package:cotizador_de_productos_locales/widgets/empty_state.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final SupabaseService _service = SupabaseService();
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favs = await _service.obtenerMisFavoritosProductos();
    if (mounted) {
      setState(() {
        _favorites = favs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Favoritos')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? const EmptyState(
                  icon: Icons.favorite_border,
                  title: 'Aún no tienes favoritos',
                  subtitle: 'Toca el corazón de un producto para guardarlo aquí.')
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final product = _favorites[index];
                    final price = product['precio_base'] ?? 0;
                    
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          scaleRoute(ProductDetailScreen(productData: product)),
                        ).then((_) => _loadFavorites());
                      },
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: product['imagen_url'] != null
                                        ? CachedNetworkImage(
                                            imageUrl: product['imagen_url'],
                                            fit: BoxFit.cover,
                                            memCacheWidth: 400,
                                            memCacheHeight: 400,
                                          )
                                        : Container(color: Colors.grey[200], child: const Icon(Icons.image)),
                                  ),
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.white.withValues(alpha: 0.8),
                                      child: IconButton(
                                        icon: const Icon(Icons.favorite, color: Colors.red),
                                        onPressed: () async {
                                          await _service.toggleFavorito(product['id'], true);
                                          _loadFavorites();
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(product['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  Flexible(
                                    child: Text(product['perfiles_proveedores']?['nombre_comercial'] ?? 'Productor', style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_CL').format(price), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.push(context, scaleRoute(ProductDetailScreen(productData: product))),
                                      style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                                      child: const Text('Ver Producto', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ],
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
}