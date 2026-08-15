import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class JoinScreen extends StatelessWidget {
  const JoinScreen({super.key});

  void _contactarExpansion() async {
    const email = 'brunafuentealba@gmail.com';
    const subject = 'Interés en expansión regional - ProdLocales';
    final Uri params = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=$subject',
    );
    
    if (await canLaunchUrl(params)) {
      await launchUrl(params);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Únete a la Red')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.public, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              '¡Lleva Marketplace Local a tu región!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Estamos buscando socios para expandirnos a Argentina, Perú y México. Si eres un líder de comunidad o productor, queremos trabajar contigo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            _buildFeature(Icons.check_circle, 'Soporte para múltiples divisas'),
            _buildFeature(Icons.check_circle, 'Dashboard personalizado por región'),
            _buildFeature(Icons.check_circle, 'Herramientas de carga masiva (Python)'),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _contactarExpansion,
              icon: const Icon(Icons.email),
              label: const Text('Contactar por Alianzas'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}