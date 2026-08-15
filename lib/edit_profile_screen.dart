import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';
import 'package:cotizador_de_productos_locales/regiones_chile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color _green = Color(0xFF2E7D32);
  static const List<(String, String)> _dias = [
    ('lunes', 'Lunes'),
    ('martes', 'Martes'),
    ('miercoles', 'Miércoles'),
    ('jueves', 'Jueves'),
    ('viernes', 'Viernes'),
    ('sabado', 'Sábado'),
    ('domingo', 'Domingo'),
  ];

  final _service = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // ---- Datos públicos ----
  final _nombreComercialController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _descripcionController = TextEditingController();
  String? _region;
  String? _fotoPerfilUrl;
  String? _portadaUrl;
  bool _subiendoFoto = false;
  bool _subiendoPortada = false;

  // ---- Métodos de pago (múltiples) ----
  final List<String> _metodosPago = [];

  // ---- Datos bancarios (Transferencia) ----
  final _titularController = TextEditingController();
  final _rutController = TextEditingController();
  final _bancoController = TextEditingController();
  final _tipoCuentaController = TextEditingController();
  final _numeroCuentaController = TextEditingController();

  // ---- Horarios: 'lunes' -> {'apertura': '09:00', 'cierre': '18:00'} ----
  final Map<String, Map<String, String>> _horarios = {};

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombreComercialController.dispose();
    _whatsappController.dispose();
    _descripcionController.dispose();
    _titularController.dispose();
    _rutController.dispose();
    _bancoController.dispose();
    _tipoCuentaController.dispose();
    _numeroCuentaController.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    try {
      final perfil = await _service.obtenerMiPerfil();
      if (perfil != null && mounted) {
        setState(() {
          _nombreComercialController.text = perfil['nombre_comercial'] ?? '';
          _whatsappController.text = perfil['whatsapp'] ?? '';
          _descripcionController.text = perfil['descripcion'] ?? '';
          _region = normalizarRegion(perfil['region']?.toString());
          _fotoPerfilUrl = perfil['foto_perfil_url'] as String?;
          _portadaUrl = perfil['portada_url'] as String?;

          _metodosPago
            ..clear()
            ..addAll(_parseMetodos(perfil['metodos_pago'], perfil['metodo_pago']));

          _horarios.clear();
          final h = perfil['horarios_atencion'];
          if (h is Map) {
            h.forEach((k, v) {
              if (v is Map) {
                _horarios[k.toString()] = {
                  'apertura': v['apertura']?.toString() ?? '09:00',
                  'cierre': v['cierre']?.toString() ?? '18:00',
                };
              }
            });
          }

          final config = perfil['config_pago'] ?? {};
          _titularController.text = config['titular'] ?? '';
          _rutController.text = config['rut'] ?? '';
          _bancoController.text = config['banco'] ?? '';
          _tipoCuentaController.text = config['tipo_cuenta'] ?? '';
          _numeroCuentaController.text = config['numero_cuenta'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar perfil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _parseMetodos(dynamic raw, dynamic legado) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    final list = <String>[];
    if (legado == 'mercado_pago' || legado == 'ambos') list.add('mercado_pago');
    if (legado == 'transferencia' || legado == 'ambos') list.add('transferencia');
    return list;
  }

  // ================== IMÁGENES: foto de perfil y portada ==================
  Future<void> _pedirImagen(bool portada) async {
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
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() {
      if (portada) {
        _subiendoPortada = true;
      } else {
        _subiendoFoto = true;
      }
    });
    try {
      final Uint8List bytes = await file.readAsBytes();
      final name = file.name.split('/').last;
      final ext = name.contains('.') ? name.split('.').last : 'jpg';
      final url = await _service.subirImagenPerfil(
        bytes,
        '${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      if (mounted) {
        setState(() {
          if (portada) {
            _portadaUrl = url;
          } else {
            _fotoPerfilUrl = url;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (portada) {
            _subiendoPortada = false;
          } else {
            _subiendoFoto = false;
          }
        });
      }
    }
  }

  Widget _botonImagen({required bool portada}) {
    final uploading = portada ? _subiendoPortada : _subiendoFoto;
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: uploading ? null : () => _pedirImagen(portada),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: uploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                )
              : Icon(portada ? Icons.photo_camera : Icons.camera_alt, color: _green),
        ),
      ),
    );
  }

  // ================== VALIDACIÓN DE RUT (dígito verificador) ==================
  bool _validarRut(String rut) {
    if (rut.isEmpty) return false;
    String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').toUpperCase();
    if (cleanRut.length < 2) return false;
    String dv = cleanRut.substring(cleanRut.length - 1);
    String numberStr = cleanRut.substring(0, cleanRut.length - 1);
    int? number = int.tryParse(numberStr);
    if (number == null) return false;
    int sum = 0;
    int multiplier = 2;
    for (int i = numberStr.length - 1; i >= 0; i--) {
      sum += int.parse(numberStr[i]) * multiplier;
      multiplier = multiplier == 7 ? 2 : multiplier + 1;
    }
    int expectedRes = 11 - (sum % 11);
    String expectedDv;
    if (expectedRes == 11) {
      expectedDv = '0';
    } else if (expectedRes == 10) {
      expectedDv = 'K';
    } else {
      expectedDv = expectedRes.toString();
    }
    return dv == expectedDv;
  }

  // ================== HORARIOS DE ATENCIÓN ==================
  String _fmtHora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseHora(String h) {
    final parts = h.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  void _toggleDia(String dia, bool activo) {
    setState(() {
      if (activo) {
        _horarios[dia] ??= {'apertura': '09:00', 'cierre': '18:00'};
      } else {
        _horarios.remove(dia);
      }
    });
  }

  Future<void> _elegirHora(String dia, bool apertura) async {
    final prev = _horarios[dia];
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseHora(prev?[apertura ? 'apertura' : 'cierre'] ?? '09:00'),
      helpText: apertura ? 'Hora de apertura' : 'Hora de cierre',
    );
    if (picked == null) return;
    setState(() {
      _horarios[dia] ??= {'apertura': '09:00', 'cierre': '18:00'};
      _horarios[dia]![apertura ? 'apertura' : 'cierre'] = _fmtHora(picked);
    });
  }

  // ================== MÉTODOS DE PAGO ==================
  void _toggleMetodo(String metodo) {
    setState(() {
      if (_metodosPago.contains(metodo)) {
        _metodosPago.remove(metodo);
      } else {
        _metodosPago.add(metodo);
      }
    });
  }

  // Compatibilidad con la columna 'metodo_pago' (un solo valor) que usa la app
  String _deriveMetodoPago() {
    final mp = _metodosPago.contains('mercado_pago');
    final tr = _metodosPago.contains('transferencia');
    if (mp && tr) return 'ambos';
    if (mp) return 'mercado_pago';
    if (tr) return 'transferencia';
    return 'whatsapp';
  }

  // ================== GUARDAR ==================
  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = _service.usuarioActual;
      if (user == null) return;

      final perfil = <String, dynamic>{
        'id': user.id,
        'nombre_comercial': _nombreComercialController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'region': _region,
        'foto_perfil_url': _fotoPerfilUrl,
        'portada_url': _portadaUrl,
        'metodos_pago': _metodosPago,
        'horarios_atencion': _horarios,
        'metodo_pago': _deriveMetodoPago(),
        'config_pago': _metodosPago.contains('transferencia')
            ? {
                'titular': _titularController.text.trim(),
                'rut': _rutController.text.trim(),
                'banco': _bancoController.text.trim(),
                'tipo_cuenta': _tipoCuentaController.text.trim(),
                'numero_cuenta': _numeroCuentaController.text.trim(),
              }
            : {},
      };

      await _service.actualizarPerfil(perfil);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ================== UI ==================
  InputDecoration _in(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: _green) : null,
        border:
            const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        filled: true,
        fillColor: Colors.white,
      );

  Widget _tituloSeccion(String texto, IconData icono) {
    return Row(
      children: [
        Icon(icono, color: _green, size: 22),
        const SizedBox(width: 8),
        Text(texto, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _green)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text('Mi Perfil Comercial'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _cardImagenes(),
                  const SizedBox(height: 16),
                  _cardDatos(),
                  const SizedBox(height: 16),
                  _cardHorarios(),
                  const SizedBox(height: 16),
                  _cardMetodos(),
                  if (_metodosPago.contains('transferencia')) ...[
                    const SizedBox(height: 16),
                    _cardTransferencia(),
                  ],
                  const SizedBox(height: 24),
                  _botonGuardar(),
                  const SizedBox(height: 16),
                  _cardResenas(),
                ],
              ),
            ),
    );
  }

  Widget _cardImagenes() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 120,
                width: double.infinity,
                color: const Color(0xFFE6F2E6),
                child: _portadaUrl != null
                    ? Image.network(
                        _portadaUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.image_outlined, size: 52, color: Colors.green),
                      )
                    : const Icon(Icons.storefront_outlined, size: 52, color: Colors.green),
              ),
              Positioned(right: 10, bottom: 10, child: _botonImagen(portada: true)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFFE6F2E6),
                      backgroundImage: _fotoPerfilUrl != null
                          ? NetworkImage(_fotoPerfilUrl!)
                          : null,
                      child: _fotoPerfilUrl == null
                          ? const Icon(Icons.person, size: 42, color: Colors.green)
                          : null,
                    ),
                    Positioned(right: -2, bottom: -2, child: _botonImagen(portada: false)),
                  ],
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Toca las cámaras para cambiar tu foto de perfil y portada. Se mostrarán en tus productos.',
                    style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardDatos() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Datos de tu negocio', Icons.storefront),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreComercialController,
              decoration: _in('Nombre Comercial / Tienda', icon: Icons.badge_outlined),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ingresa el nombre de tu negocio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _whatsappController,
              keyboardType: TextInputType.phone,
              decoration: _in('WhatsApp (Ej: 56912345678)', icon: Icons.phone_iphone),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido para contacto' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _region,
              isExpanded: true,
              decoration: _in('Región de origen', icon: Icons.location_on_outlined),
              items: regionesChile
                  .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r, overflow: TextOverflow.ellipsis, maxLines: 1)))
                  .toList(),
              onChanged: (val) => setState(() => _region = val),
              validator: (v) => v == null ? 'Indica tu región' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcionController,
              maxLines: 3,
              decoration: _in('Sobre tus productos...', icon: Icons.notes),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardHorarios() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Horarios de atención', Icons.schedule),
            const SizedBox(height: 12),
            ..._dias.map(_filaDia),
          ],
        ),
      ),
    );
  }

  Widget _filaDia((String, String) dia) {
    final activo = _horarios.containsKey(dia.$1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(dia.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Switch(value: activo, onChanged: (v) => _toggleDia(dia.$1, v)),
            ],
          ),
          if (activo)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Row(
                children: [
                  _chipHora(dia.$1, true),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('a'),
                  ),
                  _chipHora(dia.$1, false),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chipHora(String dia, bool apertura) {
    final hora = _horarios[dia]?[apertura ? 'apertura' : 'cierre'] ?? '09:00';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _elegirHora(dia, apertura),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F2E6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(apertura ? Icons.wb_twilight : Icons.dark_mode, size: 14, color: _green),
            const SizedBox(width: 4),
            Text(hora, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _cardMetodos() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: _tituloSeccion('Métodos de pago', Icons.payment),
            ),
            CheckboxListTile(
              value: _metodosPago.contains('mercado_pago'),
              onChanged: (_) => _toggleMetodo('mercado_pago'),
              title: const Text('Mercado Pago'),
              subtitle: const Text('Pago online con tarjeta o débito'),
              secondary: const Icon(Icons.qr_code_2, color: _green),
            ),
            CheckboxListTile(
              value: _metodosPago.contains('transferencia'),
              onChanged: (_) => _toggleMetodo('transferencia'),
              title: const Text('Transferencia bancaria'),
              subtitle: const Text('El cliente envía el comprobante por WhatsApp'),
              secondary: const Icon(Icons.account_balance_outlined, color: _green),
            ),
            CheckboxListTile(
              value: _metodosPago.contains('efectivo'),
              onChanged: (_) => _toggleMetodo('efectivo'),
              title: const Text('Efectivo (Retiro)'),
              subtitle: const Text('Pago en mano al retirar el producto'),
              secondary: const Icon(Icons.payments_outlined, color: _green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardTransferencia() {
    return Card(
      elevation: 1,
      color: const Color(0xFFFFF8F1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Datos de transferencia', Icons.account_balance_wallet_outlined),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titularController,
              decoration: _in('Titular de la cuenta'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el titular' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rutController,
              decoration: _in('RUT (Ej: 12.345.678-9)', icon: Icons.badge_outlined),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9kK.\-]')),
                LengthLimitingTextInputFormatter(12),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El RUT es necesario para transferencias';
                if (!_validarRut(v.trim())) return 'RUT inválido (verifica el dígito verificador)';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bancoController,
              decoration: _in('Banco (Ej: BancoEstado, BCI)'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Indica el banco' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tipoCuentaController,
              decoration: _in('Tipo de cuenta (Ej: Corriente, RUT)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _numeroCuentaController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _in('Número de cuenta'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El número de cuenta es obligatorio';
                if (v.trim().length < 5) return 'Número de cuenta demasiado corto';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tip: En una Cuenta RUT, el número suele ser tu RUT sin el dígito verificador.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardResenas() {
    final userId = _service.usuarioActual?.id.toString();
    if (userId == null) return const SizedBox.shrink();
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Reseñas de mis clientes', Icons.rate_review_outlined),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _service.getSellerReviews(userId),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Aún no tienes reseñas de tus clientes.', style: TextStyle(color: Colors.grey[600])),
                  );
                }
                final prom =
                    list.fold<int>(0, (acc, r) => acc + ((r['calificacion'] ?? 0) as int)) / list.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < prom.round() ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(prom.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(' (${list.length})', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...list.take(5).map((r) => _reviewCliente(r)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewCliente(Map<String, dynamic> r) {
    final cal = (r['calificacion'] ?? 0) as int;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r['comprador_nombre']?.toString() ?? 'Cliente',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              ...List.generate(
                5,
                (i) => Icon(
                  i < cal ? Icons.star : Icons.star_border,
                  size: 12,
                  color: i < cal ? Colors.amber : Colors.grey,
                ),
              ),
            ],
          ),
          if (((r['comentario']?.toString() ?? '').trim()).isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(r['comentario'].toString(), style: const TextStyle(fontSize: 13)),
          ],
          const Divider(height: 16),
        ],
      ),
    );
  }

  Widget _botonGuardar() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: _isSaving
          ? const Center(child: CircularProgressIndicator(color: _green))
          : ElevatedButton(
              onPressed: _guardarPerfil,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Guardar Cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
    );
  }
}

