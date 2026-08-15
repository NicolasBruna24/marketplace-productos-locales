import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  static const Color _green = Color(0xFF2E7D32);
  final _service = SupabaseService();
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await _service.getSalesDashboardData();
    if (mounted) {
      setState(() {
        _data = d;
        _loading = false;
      });
    }
  }

  String _money(double v) => NumberFormat.currency(
        symbol: '\$', decimalDigits: 0, locale: 'es_CL').format(v);

  @override
  Widget build(BuildContext context) {
    final ventas = (_data['ventas_diarias'] as List<dynamic>?) ?? [];
    final top = (_data['top_productos'] as List<dynamic>?) ?? [];
    final ultimos = (_data['ultimos_pedidos'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text('Dashboard de Ventas'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(child: _metricCard('Ingresos', _money((_data['ingresos_totales'] ?? 0) as double), Icons.attach_money)),
                      const SizedBox(width: 12),
                      Expanded(child: _metricCard('Pedidos', '${_data['pedidos_totales'] ?? 0}', Icons.shopping_bag)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _metricCard('Productos vendidos', '${_data['productos_vendidos'] ?? 0}', Icons.trending_up)),
                      const SizedBox(width: 12),
                      Expanded(child: _metricCard('Pendientes', '${_data['pedidos_pendientes'] ?? 0}', Icons.schedule)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _cardChart(ventas),
                  const SizedBox(height: 16),
                  _cardTop(top),
                  const SizedBox(height: 16),
                  _cardUltimos(ultimos),
                ],
              ),
            ),
    );
  }

  Widget _metricCard(String titulo, String valor, IconData icono) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: _green, size: 22),
            const SizedBox(height: 8),
            Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(titulo, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _cardChart(List<dynamic> ventas) {
    double maxY = 0;
    for (final v in ventas) {
      final t = (v['total'] as double? ?? 0);
      if (t > maxY) maxY = t;
    }
    if (maxY <= 0) maxY = 100;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ventas últimos 7 días', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxY * 1.2,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= ventas.length) return const SizedBox.shrink();
                          final d = ventas[idx]['dia'] as DateTime;
                          const dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                          return Text(dias[d.weekday - 1], style: const TextStyle(fontSize: 11, color: Colors.grey));
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(ventas.length, (i) {
                    final total = (ventas[i]['total'] as double? ?? 0);
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: total <= 0 ? 0.01 : total,
                          color: _green,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardTop(List<dynamic> top) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top 3 productos más vendidos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            if (top.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Aún no hay ventas.', style: TextStyle(color: Colors.grey)))
            else
              ...top.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text(e['nombre']),
                    trailing: Text('${e['vendidos']} vendidos', style: const TextStyle(fontWeight: FontWeight.bold, color: _green)),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _cardUltimos(List<dynamic> ultimos) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Últimos pedidos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            if (ultimos.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No hay pedidos todavía.', style: TextStyle(color: Colors.grey)))
            else
              ...ultimos.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      e['estado'] == 'pagado' ? Icons.check_circle : Icons.hourglass_top,
                      color: e['estado'] == 'pagado' ? Colors.green : Colors.orange,
                    ),
                    title: Text(e['nombre'], maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(e['comprador']),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_money((e['monto'] as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(e['estado'] == 'pagado' ? 'Pagado' : 'Pendiente', style: TextStyle(fontSize: 11, color: e['estado'] == 'pagado' ? Colors.green : Colors.orange)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
