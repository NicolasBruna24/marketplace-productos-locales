import 'package:flutter/material.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';

class ReviewFormScreen extends StatefulWidget {
  final String pedidoId;
  final String productoId;
  final String proveedorId;
  const ReviewFormScreen({
    super.key,
    required this.pedidoId,
    required this.productoId,
    required this.proveedorId,
  });

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  static const Color _green = Color(0xFF2E7D32);
  final _service = SupabaseService();
  final _comentarioController = TextEditingController();
  int _calificacion = 5;
  bool _saving = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final user = _service.usuarioActual;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para reseñar')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.createReview({
        'pedido_id': widget.pedidoId,
        'producto_id': widget.productoId,
        'proveedor_id': widget.proveedorId,
        'comprador_id': user.id,
        'comprador_nombre': user.email ?? 'Cliente',
        'calificacion': _calificacion,
        'comentario': _comentarioController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Gracias por tu reseña!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text('Califica tu compra'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Cómo calificas este producto?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: _saving ? null : () => setState(() => _calificacion = star),
                  iconSize: 40,
                  icon: Icon(
                    star <= _calificacion ? Icons.star : Icons.star_border,
                    color: star <= _calificacion ? Colors.amber : Colors.grey,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('$_calificacion de 5', style: const TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _comentarioController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                hintText: 'Cuéntale a otros compradores tu experiencia...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: _saving
                  ? const Center(child: CircularProgressIndicator(color: _green))
                  : ElevatedButton(
                      onPressed: _enviar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Enviar reseña',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
