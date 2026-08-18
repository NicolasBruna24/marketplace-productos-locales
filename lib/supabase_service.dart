import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cotizador_de_productos_locales/models/notification.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // Obtener las categorías dinámicas desde la DB
  Future<List<Map<String, dynamic>>> obtenerCategorias() async {
    final response = await _supabase.from('categorias').select().order('nombre');
    return List<Map<String, dynamic>>.from(response);
  }

  // Obtener todos los productos activos con la info del proveedor
  Future<List<Map<String, dynamic>>> obtenerProductos({String? region}) async {
    var query = _supabase
        .from('productos')
        .select('*, perfiles_proveedores!inner(nombre_comercial, whatsapp, region, metodo_pago)')
        .eq('activo', true);

    if (region != null && region.isNotEmpty) {
      query = query.ilike('perfiles_proveedores.region', '%$region%');
    }

    final response = await query.order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Registrar una interacción (Vista, Detalle o WhatsApp)
  Future<void> registrarInteraccion(String productoId, String proveedorId, String tipoEvento) async {
    final interactionData = {
      'producto_id': productoId,
      'proveedor_id': proveedorId,
      'tipo_evento': tipoEvento,
    };
    debugPrint('SupabaseService: Intentando registrar interacción: $interactionData');
    await _supabase.from('interacciones').insert(interactionData);
    debugPrint('SupabaseService: Interacción registrada con éxito.');
  }

  // Obtener interacciones del proveedor actual para las estadísticas del Dashboard
  Future<List<Map<String, dynamic>>> obtenerEstadisticas() async {
    final user = usuarioActual;
    if (user == null) return [];
    final response = await _supabase
        .from('interacciones')
        .select('tipo_evento, created_at')
        .eq('proveedor_id', user.id);
    return List<Map<String, dynamic>>.from(response);
  }

  // --- Autenticación ---

  // Registrar un nuevo proveedor
  Future<void> registrarse(String email, String password) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    // Supabase NO lanza una excepción cuando el correo ya está registrado y
    // confirmado: para evitar filtrar información, "finge" éxito. El indicador
    // correcto es `identities`: un usuario nuevo trae al menos una identidad,
    // mientras que un correo ya existente devuelve el array `identities` vacío.
    // (No se usa `session == null` porque, con la confirmación de email
    // activada, un correo nuevo también devuelve session nulo.)
    final user = response.user;
    if (user != null && (user.identities?.isEmpty ?? true)) {
      throw AuthException('User already registered');
    }
  }

  // Enviar Magic Link al correo
  Future<void> loginConMagicLink(String email) async {
    // Si estamos en web, detectamos la URL actual para el redireccionamiento
    final String redirectUrl = _getRedirectUrl();

    await _supabase.auth.signInWithOtp(
      email: email,
      emailRedirectTo: redirectUrl,
    );
  }

  // Login con Email y Contraseña
  Future<void> loginConPassword(String email, String password) async {
    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Recuperar contraseña
  Future<void> recuperarPassword(String email) async {
    final String redirectUrl = _getRedirectUrl();
    debugPrint('Solicitando recuperación para $email con redirección a: $redirectUrl');

    await _supabase.auth.resetPasswordForEmail(email, redirectTo: redirectUrl);
  }

  // Helper para obtener la URL de redirección según plataforma
  String _getRedirectUrl() {
    if (kIsWeb) {
      // Obtenemos la URL base y nos aseguramos de que no tenga parámetros extra
      final url = Uri.base.origin;
      // Si termina en /, se la quitamos para que coincida con la config de Supabase
      // o viceversa, lo importante es que coincida EXACTAMENTE con el dashboard
      return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    }
    // En móvil, usamos el esquema de Deep Link configurado en AndroidManifest.xml
    return 'io.supabase.prodlocales://login-callback';
  }

  // Actualizar la contraseña del usuario actual
  Future<void> actualizarPassword(String nuevoPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: nuevoPassword),
    );
  }

  // Cerrar sesión
  Future<void> cerrarSesion() async => await _supabase.auth.signOut();

  // Eliminar cuenta del usuario actual (requiere una Edge Function por seguridad)
  Future<void> deleteUserAccount() async {
    final user = usuarioActual;
    if (user == null) throw 'No hay usuario autenticado para eliminar.';

    try {
      // **IMPORTANTE:** Esta es una llamada a una Edge Function (o Cloud Function)
      // que DEBE manejar la lógica de eliminación de forma segura en el servidor.
      // NO se debe llamar directamente a `_supabase.auth.admin.deleteUser()` desde el cliente.
      //
      // La Edge Function (que deberás crear en Supabase) hará lo siguiente:
      // 1. Verificar la autenticación del usuario que hace la solicitud.
      // 2. Usar la clave de servicio (Service Role Key) para llamar a `supabase.auth.admin.deleteUser(user_id)`.
      // 3. Opcionalmente, eliminar datos asociados al usuario en otras tablas (productos, pedidos, etc.).
      final response = await _supabase.functions.invoke(
        'delete-user-account', // <-- Nombre de tu Edge Function en Supabase
        body: {
          'user_id': user.id,
        },
      );

      if (response.status != 200) {
        throw 'Error al eliminar la cuenta: ${response.data}';
      }
      await cerrarSesion(); // Si la eliminación fue exitosa en el backend, cerramos la sesión localmente
    } catch (e) {
      debugPrint('Error al intentar eliminar la cuenta: $e');
      rethrow; // Re-lanzar para que la UI pueda manejar el error
    }
  }

  // Obtener sesión actual
  Session? get sesionActual => _supabase.auth.currentSession;
  User? get usuarioActual => _supabase.auth.currentUser;

  // Verificar si el usuario actual tiene perfil de proveedor completo
  Future<bool> esUsuarioProveedor() async {
    final perfil = await obtenerMiPerfil();
    // Es proveedor si configuró su nombre comercial O si el admin lo verificó manualmente
    return perfil != null && (perfil['nombre_comercial'] != null || perfil['verificado'] == true);
  }

  // Verificar si el proveedor ya fue aprobado por el admin
  Future<bool> esProveedorVerificado() async {
    final perfil = await obtenerMiPerfil();
    return perfil != null && perfil['verificado'] == true;
  }

  // Verificar si el usuario tiene suscripción premium activa
  Future<bool> esPremium() async {
    final perfil = await obtenerMiPerfil();
    return perfil != null && perfil['premium_activo'] == true;
  }

  // Generar link de pago para la suscripción Premium
  Future<String> obtenerLinkSuscripcionPremium(String planNombre, double precio) async {
    final user = usuarioActual;
    if (user == null) throw 'Debes iniciar sesión para ser Premium';

    // Usamos un ID especial 'PREMIUM_USER_ID' para que el webhook identifique la transacción
    return obtenerLinkMercadoPago(
      'PREMIUM_${user.id}',
      'Plan Premium $planNombre - ProdLocales',
      precio,
    );
  }

  // --- Gestión de Favoritos ---
  Future<List<String>> obtenerMisFavoritosIds() async {
    final user = usuarioActual;
    if (user == null) return [];
    final res = await _supabase.from('favoritos').select('producto_id').eq('usuario_id', user.id);
    return List<String>.from(res.map((e) => e['producto_id'].toString()));
  }

  Future<List<Map<String, dynamic>>> obtenerMisFavoritosProductos() async {
    final user = usuarioActual;
    if (user == null) return [];
    
    final res = await _supabase
        .from('favoritos')
        .select('productos(*, perfiles_proveedores(nombre_comercial, region))')
        .eq('usuario_id', user.id);

    return res
        .map((e) => e['productos'])
        .where((p) => p != null && p is Map<String, dynamic>)
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
  }

  Future<void> toggleFavorito(String productoId, bool esFavoritoActualmente) async {
    final user = usuarioActual;
    if (user == null) return;

    if (esFavoritoActualmente) {
      await _supabase.from('favoritos').delete().eq('usuario_id', user.id).eq('producto_id', productoId);
    } else {
      await _supabase.from('favoritos').insert({'usuario_id': user.id, 'producto_id': productoId});
    }
  }

  // --- Gestión de Productos ---

  // Insertar un nuevo producto
  Future<void> crearProducto(Map<String, dynamic> productoData) async {
    // El RLS se encarga de que el proveedor_id coincida con el usuario autenticado
    await _supabase.from('productos').insert(productoData);
  }

  // Eliminar un producto
  Future<void> borrarProducto(String productoId) async {
    await _supabase.from('productos').delete().eq('id', productoId);
  }

  // Disminuir stock de forma segura
  Future<void> disminuirStock(String productoId, int cantidad) async {
    try {
      await _supabase.rpc('disminuir_stock_producto', params: {
        'prod_id': productoId,
        'cant_a_restar': cantidad,
      });
    } catch (e) {
      debugPrint('Error al disminuir stock: $e');
    }
  }

  // Actualizar stock (activo/inactivo) con soporte offline
  Future<void> actualizarEstadoStock(String productoId, bool nuevoEstado) async {
    try {
      await _supabase
          .from('productos')
          .update({'activo': nuevoEstado})
          .eq('id', productoId);
      debugPrint('Sincronización inmediata exitosa para $productoId');
    } catch (e) {
      debugPrint('Sin conexión o error: Guardando cambio de stock localmente');
      await _guardarCambioOffline(productoId, nuevoEstado);
      rethrow; // Re-lanzamos para que la UI sepa que se guardó "en espera"
    }
  }

  Future<void> _guardarCambioOffline(String id, bool estado) async {
    final prefs = await SharedPreferences.getInstance();
    final String? colaJson = prefs.getString('offline_stock_queue');
    Map<String, dynamic> cola = colaJson != null ? json.decode(colaJson) : {};
    
    cola[id] = estado;
    await prefs.setString('offline_stock_queue', json.encode(cola));
  }

  // Intentar sincronizar cambios pendientes al recuperar señal
  Future<void> sincronizarCambiosOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final String? colaJson = prefs.getString('offline_stock_queue');
    if (colaJson == null) return;

    Map<String, dynamic> cola = json.decode(colaJson);
    List<String> sincronizados = [];

    for (var entry in cola.entries) {
      try {
        await _supabase.from('productos').update({'activo': entry.value}).eq('id', entry.key);
        sincronizados.add(entry.key);
      } catch (_) { /* Seguir intentando el resto */ }
    }

    // Limpiar los que ya se subieron
    for (var id in sincronizados) { cola.remove(id); }
    await prefs.setString('offline_stock_queue', json.encode(cola));
  }

  // Stream para escuchar cambios en la sesión (útil para la UI)
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  // Obtener resumen estadístico para el Dashboard Premium
  Future<Map<String, Map<String, int>>> obtenerResumenEstadistico() async {
    final user = usuarioActual;
    if (user == null) return {};

    // Obtener vistas y clics
    final interacciones = await _supabase
        .from('interacciones')
        .select('tipo_evento, productos(nombre)')
        .eq('proveedor_id', user.id);

    // Obtener ventas reales (pedidos pagados)
    final pedidos = await _supabase
        .from('pedidos')
        .select('productos(nombre)')
        .eq('proveedor_id', user.id)
        .eq('estado', 'pagado');

    Map<String, Map<String, int>> stats = {};

    for (var i in interacciones) {
      String nombre = i['productos']?['nombre'] ?? 'Desconocido';
      stats.putIfAbsent(nombre, () => {'vistas': 0, 'ventas': 0});
      stats[nombre]!['vistas'] = stats[nombre]!['vistas']! + 1;
    }

    for (var p in pedidos) {
      String nombre = p['productos']?['nombre'] ?? 'Desconocido';
      stats.putIfAbsent(nombre, () => {'vistas': 0, 'ventas': 0});
      stats[nombre]!['ventas'] = stats[nombre]!['ventas']! + 1;
    }

    return stats;
  }

  // Obtener el perfil del proveedor actual
  Future<Map<String, dynamic>?> obtenerMiPerfil() async {
    final user = usuarioActual;
    if (user == null) return null;
    final perfil = await _supabase
        .from('perfiles_proveedores')
        .select('id, nombre_comercial, whatsapp, descripcion, ubicacion, region, verificado, metodo_pago, premium_activo, premium_vencimiento, updated_at, foto_perfil_url, portada_url, horarios_atencion, metodos_pago')
        .eq('id', user.id)
        .maybeSingle();

    if (perfil != null) {
      try {
        final configPago = await _supabase.rpc('obtener_mi_config_pago');
        if (configPago != null) {
          perfil['config_pago'] = configPago;
        }
      } catch (e) {
        debugPrint('Error al obtener config_pago: $e');
      }
    }
    return perfil;
  }

  // Obtener datos bancarios de transferencia de un proveedor (vía RPC segura)
  Future<Map<String, dynamic>> obtenerDatosTransferencia(String proveedorId) async {
    try {
      final response = await _supabase.rpc('obtener_datos_transferencia', params: {
        'p_proveedor_id': proveedorId,
      });
      if (response != null && response is Map) {
        return Map<String, dynamic>.from(response);
      }
    } catch (e) {
      debugPrint('Error al obtener datos de transferencia: $e');
    }
    return {};
  }

  // Guardar o actualizar perfil
  Future<void> actualizarPerfil(Map<String, dynamic> perfil) async {
    final user = usuarioActual;
    if (user == null) throw 'No hay sesión activa.';
    
    perfil['id'] = user.id;
    try {
      await _supabase.from('perfiles_proveedores').update(perfil).eq('id', user.id);
    } catch (_) {
      await _supabase.from('perfiles_proveedores').upsert(perfil);
    }
  }

  // Subir imagen al Storage y obtener URL pública
  Future<String> subirImagen(Uint8List bytes, String fileName) async {
    await _supabase.storage.from('productos').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _supabase.storage.from('productos').getPublicUrl(fileName);
  }

  // Subir imagen de perfil/portada al Storage (bucket 'productos', carpeta del usuario)
  Future<String> subirImagenPerfil(Uint8List bytes, String fileName) async {
    final user = usuarioActual;
    if (user == null) throw 'No hay sesión activa para subir la imagen.';
    final path = 'perfiles/${user.id}/$fileName';
    await _supabase.storage.from('productos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _supabase.storage.from('productos').getPublicUrl(path);
  }

  // Generar link de pago llamando a la Edge Function de Python
  Future<String> obtenerLinkMercadoPago(String pedidoId, String nombre, double precio) async {
    try {
      final response = await _supabase.functions.invoke(
        'crear-preferencia-mp', // Asegúrate de desplegar la función con este nombre
        body: {
          'pedido_id': pedidoId,
          'nombre': nombre,
          'precio': precio,
        },
      );
      if (response.data != null && response.data.containsKey('url_pago')) {
        return response.data['url_pago'];
      } else {
        throw 'La respuesta del servidor no contiene la URL de pago';
      }
    } catch (e) {
      debugPrint('Error en obtenerLinkMercadoPago: $e');
      rethrow;
    }
  }

  // Crear la preferencia de pago en Mercado Pago llamando a la Edge Function
  // 'procesar-pago-mp' (ya desplegada en Supabase). Devuelve el init_point
  // (link de pago) que la función genera.
  Future<String> crearPreferenciaPago(String productId, int cantidad) async {
    try {
      final Map<String, dynamic> payload = {
        'product_id': productId,
        'cantidad': cantidad,
      };
      debugPrint('▶ crearPreferenciaPago: body enviado a procesar-pago-mp: $payload');
      final response = await _supabase.functions.invoke(
        'procesar-pago-mp',
        body: payload,
      );

      final data = response.data;
      if (data is Map && data.containsKey('init_point')) {
        return data['init_point'] as String;
      } else {
        throw 'La respuesta del servidor no contiene el link de pago (init_point).';
      }
    } catch (e) {
      debugPrint('Error en crearPreferenciaPago: $e');
      throw Exception('No se pudo generar el link de pago. Inténtalo nuevamente.');
    }
  }

  // --- Gestión de Pedidos ---
  Future<Map<String, dynamic>> crearPedido(Map<String, dynamic> pedidoData) async {
    return await _supabase.from('pedidos').insert(pedidoData).select().single();
  }

  // Obtener los pedidos del usuario actual: como VENDEDOR (pedidos recibidos) y
  // como COMPRADOR (compras propias). El filtrado de filas lo realiza RLS:
  //   - "Proveedores ven sus propios pedidos"  (auth.uid() = proveedor_id)
  //   - "Comprador ve sus pedidos"             (auth.uid() = comprador_id)
  // Se incluye el join a `reseñas` (0 o 1 fila por pedido, por UNIQUE(pedido_id))
  // para poder ocultar el botón de "Calificar producto" cuando el comprador ya
  // calificó ese pedido.
  Future<List<Map<String, dynamic>>> obtenerMisPedidos() async {
    final user = usuarioActual;
    if (user == null) return [];

    final response = await _supabase
        .from('pedidos')
        .select('*, productos(nombre, imagen_url, detalles), reseñas(id)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Flujo para transferencias: El vendedor confirma que recibió el dinero
  Future<void> confirmarPedidoYRestarStock(String pedidoId, String productoId, int cantidad) async {
    // 1. Cambiamos el estado del pedido
    await actualizarEstadoPedido(pedidoId, 'completado');
    // 2. Llamamos a la función SQL que creaste para bajar el stock
    await disminuirStock(productoId, cantidad);
  }

  Future<void> actualizarEstadoPedido(String pedidoId, String nuevoEstado) async {
    await _supabase.from('pedidos').update({'estado': nuevoEstado}).eq('id', pedidoId);
  }

  Future<String> subirComprobante(Uint8List bytes, String fileName) async {
    await _supabase.storage.from('comprobantes').uploadBinary(fileName, bytes, 
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
    return _supabase.storage.from('comprobantes').getPublicUrl(fileName);
  }

  // Obtener los productos del proveedor actual (pantalla "Mis Productos")
  Future<List<Map<String, dynamic>>> getMyProducts() async {
    final user = usuarioActual;
    if (user == null) return [];
    final response = await _supabase
        .from('productos')
        .select('*')
        .eq('proveedor_id', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ════════════════════════ NOTIFICACIONES ════════════════════════

  // Obtener notificaciones del usuario actual (más recientes primero)
  Future<List<AppNotification>> getNotifications() async {
    final user = usuarioActual;
    if (user == null) return [];
    final response = await _supabase
        .from('notificaciones')
        .select('*')
        .eq('usuario_id', user.id)
        .order('fecha_creacion', ascending: false);
    return (response as List)
        .map((e) => AppNotification.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  // Marcar una notificación como leída
  Future<void> markNotificationAsRead(String id) async {
    final user = usuarioActual;
    if (user == null) return;
    await _supabase
        .from('notificaciones')
        .update({'leida': true})
        .eq('id', id)
        .eq('usuario_id', user.id);
  }

  // Eliminar una notificación individual
  Future<void> deleteNotification(String id) async {
    final user = usuarioActual;
    if (user == null) return;
    await _supabase
        .from('notificaciones')
        .delete()
        .eq('id', id)
        .eq('usuario_id', user.id);
  }

  // Eliminar todas las notificaciones del usuario
  Future<void> deleteAllNotifications() async {
    final user = usuarioActual;
    if (user == null) return;
    await _supabase
        .from('notificaciones')
        .delete()
        .eq('usuario_id', user.id);
  }

  // Contador de notificaciones no leídas (para el badge)
  Future<int> getUnreadNotificationsCount() async {
    final user = usuarioActual;
    if (user == null) return 0;
    final response = await _supabase
        .from('notificaciones')
        .select('id')
        .eq('usuario_id', user.id)
        .eq('leida', false);
    return response.length;
  }

  // ════════════════════════ PRODUCTOS ════════════════════════

  // Actualizar un producto (RLS permite UPDATE solo al proveedor dueño)
  Future<void> updateProduct(Map<String, dynamic> product) async {
    final id = product['id'];
    if (id == null) throw 'El producto no tiene id';
    final data = Map<String, dynamic>.from(product)..remove('id');
    await _supabase.from('productos').update(data).eq('id', id);
  }

  // ════════════════════════ DASHBOARD DE VENTAS ════════════════════════
  // Calcula métricas de ventas del proveedor actual a partir de sus pedidos.
  Future<Map<String, dynamic>> getSalesDashboardData() async {
    final user = usuarioActual;
    if (user == null) return {};
    final pedidos = await _supabase
        .from('pedidos')
        .select('*, productos(nombre)')
        .eq('proveedor_id', user.id)
        .order('created_at', ascending: false);

    double ingresos = 0;
    int pagados = 0, pendientes = 0, productosVendidos = 0;
    final Map<String, int> porProducto = {};
    final ultimos = <Map<String, dynamic>>[];

    for (final p in pedidos) {
      final estado = p['estado']?.toString() ?? 'pendiente';
      final monto = (p['monto'] is num) ? (p['monto'] as num).toDouble() : 0.0;
      final cant = (p['cantidad'] ?? 0) as int;
      if (estado == 'pagado') {
        ingresos += monto;
        productosVendidos += cant;
        pagados++;
      } else if (estado == 'pendiente_pago' || estado == 'pendiente') {
        pendientes++;
      }
      final nombre = p['productos']?['nombre']?.toString() ?? 'Producto';
      porProducto[nombre] = (porProducto[nombre] ?? 0) + cant;
      ultimos.add({
        'nombre': nombre,
        'comprador': p['comprador_nombre']?.toString() ??
            p['comprador_whatsapp']?.toString() ??
            'Cliente',
        'monto': monto,
        'estado': estado,
      });
    }

    // Ventas diarias (últimos 7 días, solo pedidos pagados)
    final ventasDiarias = <Map<String, dynamic>>[];
    for (int d = 6; d >= 0; d--) {
      final day = DateTime.now().subtract(Duration(days: d));
      ventasDiarias.add({'dia': DateTime(day.year, day.month, day.day), 'total': 0.0});
    }
    for (final p in pedidos) {
      final estado = p['estado']?.toString();
      if (estado != 'pagado') continue;
      final fecha = DateTime.tryParse(p['created_at']?.toString() ?? '');
      if (fecha == null) continue;
      for (final v in ventasDiarias) {
        final d = v['dia'] as DateTime;
        if (d.year == fecha.year && d.month == fecha.month && d.day == fecha.day) {
          final monto = (p['monto'] is num) ? (p['monto'] as num).toDouble() : 0.0;
          v['total'] = (v['total'] as double) + monto;
        }
      }
    }

    final topList = porProducto.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = topList.take(3).map((e) => {'nombre': e.key, 'vendidos': e.value}).toList();

    return {
      'ingresos_totales': ingresos,
      'pedidos_pagados': pagados,
      'pedidos_pendientes': pendientes,
      'pedidos_totales': pagados + pendientes,
      'productos_vendidos': productosVendidos,
      'ventas_diarias': ventasDiarias,
      'top_productos': top3,
      'ultimos_pedidos': ultimos.take(5).toList(),
    };
  }

  // ════════════════════════ RESEÑAS ════════════════════════
  // Crear una reseña (solo permitida por RLS/UNIQUE, una por pedido)
  Future<void> createReview(Map<String, dynamic> reviewData) async {
    await _supabase.from('reseñas').insert({
      'pedido_id': reviewData['pedido_id'],
      'producto_id': reviewData['producto_id'],
      'proveedor_id': reviewData['proveedor_id'],
      'comprador_id': reviewData['comprador_id'],
      'comprador_nombre': reviewData['comprador_nombre'],
      'calificacion': reviewData['calificacion'],
      'comentario': reviewData['comentario'],
    });
  }

  // Reseñas de un producto (más recientes primero)
  Future<List<Map<String, dynamic>>> getProductReviews(String productId) async {
    final r = await _supabase
        .from('reseñas')
        .select('*')
        .eq('producto_id', productId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  // Promedio y total de calificaciones de un producto
  Future<Map<String, dynamic>> getAverageRating(String productId) async {
    final r = await _supabase
        .from('reseñas')
        .select('calificacion')
        .eq('producto_id', productId);
    if (r.isEmpty) return {'promedio': 0.0, 'total': 0};
    final suma = r.fold<int>(0, (acc, e) => acc + ((e['calificacion'] ?? 0) as int));
    return {'promedio': suma / r.length, 'total': r.length};
  }

  // Reseñas de un vendedor (todos los productos que vende)
  Future<List<Map<String, dynamic>>> getSellerReviews(String sellerId) async {
    final r = await _supabase
        .from('reseñas')
        .select('*')
        .eq('proveedor_id', sellerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }
}
