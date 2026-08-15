import 'package:flutter/material.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';
import 'package:cotizador_de_productos_locales/widgets/empty_state.dart';

class PremiumDashboardScreen extends StatefulWidget {
  const PremiumDashboardScreen({super.key});

  @override
  State<PremiumDashboardScreen> createState() => _PremiumDashboardScreenState();
}

class _PremiumDashboardScreenState extends State<PremiumDashboardScreen> {
  final _service = SupabaseService();
  bool _isLoading = true;
  Map<String, Map<String, int>> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final data = await _service.obtenerResumenEstadistico();
    if (mounted) {
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text('Métricas Premium', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats.isEmpty
              ? const EmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'Aún no hay datos suficientes',
                  subtitle: 'Tus métricas aparecerán aquí conforme recibas visitas.')
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rendimiento de Productos', 
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const Text('Comparativa entre visualizaciones y ventas concretadas.', 
                        style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 30),
                      ..._stats.entries.map((entry) => _buildStatCard(entry.key, entry.value)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(String nombre, Map<String, int> data) {
    int vistas = data['vistas'] ?? 0;
    int ventas = data['ventas'] ?? 0;
    double conversion = vistas > 0 ? (ventas / vistas) * 100 : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                child: Text('${conversion.toStringAsFixed(1)}% conv.', 
                  style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildBar("Vistas", vistas, Colors.blueGrey[200]!, Icons.visibility_outlined),
          const SizedBox(height: 12),
          _buildBar("Ventas", ventas, const Color(0xFF1B5E20), Icons.shopping_bag_outlined),
        ],
      ),
    );
  }

  Widget _buildBar(String label, int value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Spacer(),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(height: 8, width: double.infinity, 
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              height: 8,
              // Escalado simple para la barra (máximo 200 para el ejemplo)
              width: (value * 10.0).clamp(0, 300), 
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            ),
          ],
        ),
      ],
    );
  }
}