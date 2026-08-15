import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = SupabaseService();
  bool _isLoading = true;
  Map<String, int> _stats = {'vista': 0, 'click_detalle': 0, 'clic_whatsapp': 0};
  List<int> _hourlyActivity = List.filled(24, 0);

  final Color colorVistas = const Color(0xFF0D6EFD); // Azul Eléctrico
  final Color colorInteres = const Color(0xFFD35400); // Naranja Quemado
  final Color colorWhatsApp = const Color(0xFF27AE60); // Verde Esmeralda
  final Color colorConversion = const Color(0xFF8E44AD); // Púrpura para Tasa

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final data = await _service.obtenerEstadisticas();
      final Map<String, int> newStats = {'vista': 0, 'click_detalle': 0, 'clic_whatsapp': 0};
      final List<int> newHourlyActivity = List.filled(24, 0);
      
      for (var row in data) {
        final tipo = row['tipo_evento'] as String;
        if (newStats.containsKey(tipo)) {
          newStats[tipo] = newStats[tipo]! + 1;
        }

        final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
        newHourlyActivity[createdAt.hour]++;
      }

      setState(() {
        _stats = newStats;
        _hourlyActivity = newHourlyActivity;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    // Cálculo de conversión
    final int vistas = _stats['vista'] ?? 0;
    final int whatsapps = _stats['clic_whatsapp'] ?? 0;
    final double conversion = vistas > 0 ? (whatsapps / vistas) * 100 : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB), // Fondo cálido solicitado
      appBar: AppBar(
        title: const Text(
          'Estadísticas de Negocio',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildResponsiveSummary(isDesktop, conversion),
                      const SizedBox(height: 40),
                      _buildChartCard(),
                      const SizedBox(height: 32),
                      _buildHeatmapCard(),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildResponsiveSummary(bool isDesktop, double conversion) {
    final cards = [
      _buildSummaryCard('Vistas de Productos', _stats['vista'].toString(), Icons.visibility_outlined, colorVistas),
      _buildSummaryCard('Interés de Clientes', _stats['click_detalle'].toString(), Icons.ads_click, colorInteres),
      _buildSummaryCard('Chats WhatsApp', _stats['clic_whatsapp'].toString(), Icons.forum_outlined, colorWhatsApp),
      _buildSummaryCard('Tasa Conversión', '${conversion.toStringAsFixed(1)}%', Icons.analytics_outlined, colorConversion),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((card) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: card))).toList(),
      );
    } else {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: cards,
      );
    }
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rendimiento del Embudo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 4),
          const Text('Efectividad de visualizaciones vs contactos', style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildLegendItem('Vistas', colorVistas),
              _buildLegendItem('Interés', colorInteres),
              _buildLegendItem('WhatsApp', colorWhatsApp),
            ],
          ),
          const SizedBox(height: 32),
          AspectRatio(
            aspectRatio: 2.0,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _stats.values.every((v) => v == 0) ? 10 : (_stats.values.reduce((a, b) => a > b ? a : b) * 1.3).toDouble(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: const Color(0xFF263238),
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String label = group.x == 0 ? 'Vistas' : (group.x == 1 ? 'Interés' : 'WhatsApp');
                      return BarTooltipItem(
                        '$label\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: rod.toY.toInt().toString(),
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w400),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true, 
                  drawVerticalLine: false, 
                  horizontalInterval: 5, 
                  getDrawingHorizontalLine: (v) => FlLine(color: Colors.black.withValues(alpha: 0.05), strokeWidth: 1)
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeGroup(0, _stats['vista']!.toDouble(), colorVistas),
                  _makeGroup(1, _stats['click_detalle']!.toDouble(), colorInteres),
                  _makeGroup(2, _stats['clic_whatsapp']!.toDouble(), colorWhatsApp),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Horas de Mayor Actividad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Mapa de calor basado en interacciones locales.', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 24),
          _buildHeatmap(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500))),
              Icon(icon, color: color.withValues(alpha: 0.6), size: 18),
            ],
          ),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2D3436))),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildHeatmap() {
    int maxActivity = _hourlyActivity.reduce((a, b) => a > b ? a : b);
    if (maxActivity == 0) maxActivity = 1;

    return Column(
      children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.transparent,
          ),
          child: Row(
            children: List.generate(24, (index) {
              double intensity = _hourlyActivity[index] / maxActivity;
              return Expanded(
                child: Tooltip(
                  message: '$index:00 - ${_hourlyActivity[index]} eventos',
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: colorWhatsApp.withValues(alpha: 0.08 + (intensity * 0.92)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Madrugada', style: TextStyle(fontSize: 11, color: Colors.grey)),
            Text('Mediodía', style: TextStyle(fontSize: 11, color: Colors.grey)),
            Text('Noche', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        )
      ],
    );
  }

  BarChartGroupData _makeGroup(int x, double y, Color color) => BarChartGroupData(
    x: x, 
    barRods: [
      BarChartRodData(
        toY: y, color: color, width: 22, 
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))
    ]);
}