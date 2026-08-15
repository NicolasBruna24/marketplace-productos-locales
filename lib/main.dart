import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:cotizador_de_productos_locales/product_list_screen.dart';
import 'package:cotizador_de_productos_locales/thank_you_screen.dart';
import 'package:cotizador_de_productos_locales/pending_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleDeepLink(initialLink.toString());
        });
      }
    } catch (e) {
      debugPrint('Error obteniendo link inicial: $e');
    }

    // En app_links v7, el stream de enlaces es un getter: uriLinkStream
    _appLinks.uriLinkStream
        .listen((Uri link) {
          _handleDeepLink(link.toString());
        })
        .onError((error) {
          debugPrint('Error en linkStream: $error');
        });
  }

  void _handleDeepLink(String link) {
    try {
      final uri = Uri.parse(link);
      final path = uri.path;

      if (path.isEmpty || path == '/') {
        debugPrint('Deep link sin path, ignorado.');
        return;
      }

      if (path.contains('pago-exitoso')) {
        navigatorKey.currentState?.pushReplacementNamed('/thank-you');
      } else if (path.contains('pago-fallido')) {
        final context = navigatorKey.currentState?.context;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El pago no se pudo completar. Inténtalo de nuevo.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (path.contains('pago-pendiente')) {
        navigatorKey.currentState?.pushReplacementNamed('/pending');
      } else {
        debugPrint('Deep link no reconocido: $link');
      }
    } catch (e) {
      debugPrint('Error procesando deep link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marketplace Local',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const ProductListScreen(),
        '/thank-you': (context) => const ThankYouScreen(),
        '/pending': (context) => const PendingScreen(),
      },
    );
  }
}
