import 'package:flutter/material.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _service = SupabaseService();
  
  bool _isLogin = true; // Alternar entre Login y Registro
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await _service.loginConPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await _service.registrarse(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuenta creada. Revisa tu correo para confirmar tu cuenta antes de iniciar sesión.')),
          );
          setState(() => _isLogin = true);
        }
      }
      if (mounted && _isLogin) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        // SEGURIDAD #10: No exponer mensajes técnicos del servidor al usuario
        final String mensaje = _traducirError(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Traduce errores técnicos de Supabase a mensajes amigables
  String _traducirError(String error) {
    if (error.contains('Invalid login credentials') || error.contains('invalid_credentials')) {
      return 'Correo o contraseña incorrectos.';
    } else if (error.contains('Email not confirmed')) {
      return 'Tu cuenta aún no ha sido confirmada. Revisa tu correo.';
    } else if (error.contains('User already registered') || error.contains('already registered')) {
      return 'Este correo ya tiene una cuenta registrada.';
    } else if (error.contains('Password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    } else if (error.contains('rate limit') || error.contains('too many')) {
      return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
    } else if (error.contains('network') || error.contains('SocketException')) {
      return 'Sin conexión a internet. Revisa tu red.';
    }
    return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }

  Future<void> _mostrarRecuperarPassword() async {
    final emailActual = _emailController.text.trim();
    final TextEditingController emailCtrl = TextEditingController(text: emailActual);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Te enviaremos un enlace para restablecer tu contraseña.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar enlace', style: TextStyle(color: Color(0xFF2E7D32))),
          ),
        ],
      ),
    );

    if (confirmed == true && emailCtrl.text.trim().isNotEmpty) {
      try {
        await _service.recuperarPassword(emailCtrl.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Listo! Revisa tu correo para el enlace de recuperación 📧'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al enviar el correo. Verifica el email ingresado.'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8), // Fondo suave
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_shipping_rounded, size: 80, color: Color(0xFF2E7D32)),
                  const SizedBox(height: 10),
                  Text(
                    _isLogin ? '¡Bienvenido de nuevo!' : 'Únete a Marketplace Local',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1C)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Ingresa tus credenciales para continuar' : 'Crea una cuenta para guardar tus favoritos',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),
                  
                  // Campo Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa un correo';
                      // MEJORA #9: Validar formato de email en cliente
                      final emailRegex = RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
                      if (!emailRegex.hasMatch(v.trim())) return 'Ingresa un correo válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                    validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                  ),
                  
                  if (_isLogin)
                      Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        // MEJORA #12: Conectar botón olvidaste tu contraseña
                        onPressed: _mostrarRecuperarPassword,
                        child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ),
                    ),
                  
                  const SizedBox(height: 30),

                  // Botón Principal
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(_isLogin ? 'Iniciar Sesión' : 'Crear Cuenta', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Toggle entre Login y Registro
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_isLogin ? '¿No tienes cuenta?' : '¿Ya tienes cuenta?'),
                      TextButton(
                        onPressed: () => setState(() {
                          _isLogin = !_isLogin;
                          _formKey.currentState?.reset();
                        }),
                        child: Text(
                          _isLogin ? 'Regístrate' : 'Inicia Sesión',
                          style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}