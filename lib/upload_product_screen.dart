import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';
import 'package:cotizador_de_productos_locales/edit_profile_screen.dart';
import 'package:cotizador_de_productos_locales/widgets/page_transitions.dart';

class UploadProductScreen extends StatefulWidget {
  const UploadProductScreen({super.key});

  @override
  State<UploadProductScreen> createState() => _UploadProductScreenState();
}

class _UploadProductScreenState extends State<UploadProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SupabaseService();
  
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();
  final _cantidadController = TextEditingController(text: '0');
  String? _categoria;
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _categoriasDB = [];
  List<String> _camposDinamicosActuales = [];
  final Map<String, dynamic> _detallesDinamicos = {};
  bool _isSaving = false;
  bool _loadingCategories = true;
  bool _activo = true;
  bool _gestionInventario = false;

  @override
  void initState() {
    super.initState();
    _verificarPerfil();
    _cargarCategorias();
    
    // Escuchar cambios para validar el botón "Publicar" en tiempo real
    _nombreController.addListener(_rebuild);
    _precioController.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    try {
      final cats = await _service.obtenerCategorias();
      setState(() {
        _categoriasDB = cats;
        _loadingCategories = false;
      });
    } catch (e) {
      setState(() => _loadingCategories = false);
    }
  }

  Future<void> _verificarPerfil() async {
    final perfil = await _service.obtenerMiPerfil();
    if (perfil == null && mounted) {
      // Si no tiene perfil, lo obligamos a configurar su WhatsApp primero
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Perfil incompleto'),
          content: const Text('Antes de vender, necesitamos tu nombre comercial y WhatsApp.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, slideRoute(const EditProfileScreen()));
              },
              child: const Text('Configurar Ahora'),
            )
          ],
        ),
      );
    }
  }

  Future<void> _seleccionarImagen() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,    // Redimensiona físicamente la imagen a un máximo de 800px
      maxHeight: 800,   // Esto ahorra muchísimos datos de subida al proveedor
      imageQuality: 75, // Una calidad de 75 es ideal para visualizar productos
    );
    if (image != null) {
      setState(() => _imageFile = image);
    }
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    try {
      final user = _service.usuarioActual;
      if (user == null) throw 'Debes estar autenticado';

      String? imageUrl;
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await _service.subirImagen(bytes, fileName);
      }

      // Si la gestión de inventario está activa, guardamos el stock en detalles
      final Map<String, dynamic> finalDetalles = Map.from(_detallesDinamicos);
      if (_gestionInventario) {
        finalDetalles['stock'] = int.tryParse(_cantidadController.text) ?? 0;
        // Opcional: Podrías definir que si stock es 0, activo sea false automáticamente
      }

      await _service.crearProducto({
        'proveedor_id': user.id,
        'nombre': _nombreController.text,
        'precio_base': double.parse(_precioController.text.replaceAll('.', '')),
        'categoria': _categoria,
        'imagen_url': imageUrl,
        'detalles': finalDetalles, // Aquí va el mapa JSONB con el stock si aplica
        'activo': _activo,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Producto enviado! Pasará por una breve revisión antes de publicarse. 🚀'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String userMessage = 'No se pudo publicar el producto.';
        
        if (e.toString().contains('42703') || e.toString().contains('estado')) {
          userMessage = 'Error de configuración en el servidor. Contacta a soporte.';
        } else if (e.toString().contains('403')) {
          userMessage = 'No tienes permisos para subir imágenes.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subir Producto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GestureDetector(
              onTap: _seleccionarImagen,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: _imageFile != null
                      ? DecorationImage(
                          image: kIsWeb 
                              ? NetworkImage(_imageFile!.path) 
                              : FileImage(File(_imageFile!.path)) as ImageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _imageFile == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                          Text('Agregar foto del producto'),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre del Producto'),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _precioController,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _CurrencyInputFormatter(),
              ],
              decoration: const InputDecoration(labelText: 'Precio Base', prefixText: '\$ '),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: InputDecoration(
                labelText: 'Categoría',
                hintText: _loadingCategories ? 'Cargando categorías...' : 'Selecciona una',
              ),
              items: _categoriasDB.map((c) => DropdownMenuItem(value: c['nombre'] as String, child: Text(c['nombre']))).toList(),
              onChanged: (val) => setState(() {
                _categoria = val;
                _detallesDinamicos.clear();
                final catData = _categoriasDB.firstWhere((c) => c['nombre'] == val);
                _camposDinamicosActuales = List<String>.from(catData['campos_dinamicos']);
              }),
            ),
            const SizedBox(height: 20),
            const Divider(),
            SwitchListTile(
              title: const Text('Gestión de inventario'),
              subtitle: const Text('Controla la cantidad exacta de productos disponibles'),
              value: _gestionInventario,
              onChanged: (val) => setState(() => _gestionInventario = val),
            ),
            if (!_gestionInventario)
              SwitchListTile(
                title: const Text('Disponible / En Stock'),
                subtitle: Text(_activo ? 'Los clientes pueden pedirlo' : 'Se mostrará como agotado'),
                value: _activo,
                onChanged: (val) => setState(() => _activo = val),
              ),
            if (_gestionInventario)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextFormField(
                  controller: _cantidadController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad en Stock', suffixText: 'unidades'),
                ),
            ),
            if (_categoria != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(),
              ),
              Text('Detalles de $_categoria', style: const TextStyle(fontWeight: FontWeight.bold)),
              ..._camposDinamicosActuales.map((campo) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextFormField(
                  decoration: InputDecoration(labelText: campo),
                  onChanged: (val) => _detallesDinamicos[campo] = val,
                ),
              )),
            ],
            const SizedBox(height: 30),
            _isSaving 
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: (_nombreController.text.isNotEmpty && 
                              _precioController.text.isNotEmpty && 
                              _categoria != null) 
                      ? _guardarProducto 
                      : null,
                  child: const Text('Publicar'),
                ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Convertir el texto a número para formatear eliminando cualquier caracter no numérico previo
    int value = int.parse(newValue.text.replaceAll(RegExp(r'[^0-9]'), ''));
    
    // Formatear usando locale de Chile para obtener los puntos de miles
    final formatter = NumberFormat.currency(locale: 'es_CL', symbol: '', decimalDigits: 0);
    String newText = formatter.format(value).trim();

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}