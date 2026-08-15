import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';

class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> productData;
  const EditProductScreen({super.key, required this.productData});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  static const Color _green = Color(0xFF2E7D32);
  final _service = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _descCtrl;
  String? _categoria;
  late List<String> _categorias;
  String? _imagenUrl;
  bool _subiendo = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.productData;
    final detalles = (p['detalles'] is Map)
        ? Map<String, dynamic>.from(p['detalles'] as Map)
        : <String, dynamic>{};
    _nombreCtrl = TextEditingController(text: p['nombre']?.toString() ?? '');
    _precioCtrl = TextEditingController(text: p['precio_base']?.toString() ?? '');
    _stockCtrl = TextEditingController(text: (detalles['stock'] ?? '').toString());
    _descCtrl = TextEditingController(text: (detalles['descripcion'] ?? '').toString());
    _categoria = p['categoria']?.toString();
    _imagenUrl = p['imagen_url']?.toString();
    _categorias = [];
    _loadCategorias();
  }

  Future<void> _loadCategorias() async {
    try {
      final cats = await _service.obtenerCategorias();
      if (mounted) {
        setState(() {
          _categorias = cats.map((e) => e['nombre'].toString()).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _cambiarImagen() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _green),
              title: const Text('Desde la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: _green),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _subiendo = true);
    try {
      final bytes = await file.readAsBytes();
      final name = file.name.split('/').last;
      final ext = name.contains('.') ? name.split('.').last : 'jpg';
      final url = await _service.subirImagen(
        bytes,
        '${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      if (mounted) setState(() => _imagenUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      // Preservar los "detalles" existentes y actualizar stock + descripción
      final prev = (widget.productData['detalles'] is Map)
          ? Map<String, dynamic>.from(widget.productData['detalles'] as Map)
          : <String, dynamic>{};
      prev['stock'] = int.tryParse(_stockCtrl.text.trim()) ?? 0;
      prev['descripcion'] = _descCtrl.text.trim();

      await _service.updateProduct({
        'id': widget.productData['id'],
        'nombre': _nombreCtrl.text.trim(),
        'precio_base':
            double.tryParse(_precioCtrl.text.trim().replaceAll(',', '.')) ?? 0,
        'categoria': _categoria,
        'imagen_url': _imagenUrl,
        'detalles': prev,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto actualizado correctamente')),
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
        title: const Text('Editar producto'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Imagen actual + botón para cambiarla
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: _imagenUrl != null
                            ? Image.network(_imagenUrl!, fit: BoxFit.cover)
                            : Container(
                                color: const Color(0xFFE6F2E6),
                                child: const Icon(Icons.image_outlined, size: 56, color: _green),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _subiendo ? null : _cambiarImagen,
                      icon: _subiendo
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _green),
                            )
                          : const Icon(Icons.photo_camera_outlined),
                      label: const Text('Cambiar imagen'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        side: const BorderSide(color: _green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreCtrl,
              decoration: _in('Nombre del producto'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _precioCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: _in('Precio (\$)'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Indica el precio';
                final n = double.tryParse(v.trim().replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Precio inválido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stockCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _in('Stock (unidades)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: _in('Categoría'),
              items: _categorias
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => setState(() => _categoria = val),
              validator: (v) => v == null ? 'Elige una categoría' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: _in('Descripción (opcional)'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: _saving
                  ? const Center(child: CircularProgressIndicator(color: _green))
                  : ElevatedButton(
                      onPressed: _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Guardar Cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _in(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        filled: true,
        fillColor: Colors.white,
      );
}
