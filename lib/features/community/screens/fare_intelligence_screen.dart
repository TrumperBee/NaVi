import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:navi_app/features/community/providers/community_provider.dart';

class FareIntelligenceScreen extends StatelessWidget {
  const FareIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final intelligence = provider.fareIntelligenceService.intelligenceData;
    final rising = provider.fareIntelligenceService.getStagesWithRisingFares();
    final bestValue = provider.fareIntelligenceService.getBestValueStages();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fare Intelligence'),
        backgroundColor: const Color(0xFF008751),
        foregroundColor: Colors.white,
      ),
      body: intelligence.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCards(intelligence, context),
                const SizedBox(height: 24),
                _buildSection('Rising Fares', Icons.trending_up, Colors.red, rising, context),
                const SizedBox(height: 24),
                _buildSection('Best Value Stages', Icons.attach_money, Colors.green, bestValue, context),
                const SizedBox(height: 24),
                _buildHourlyChart(context),
              ],
            ),
    );
  }

  Widget _buildSummaryCards(List<dynamic> data, BuildContext context) {
    final avg = data.isEmpty ? 0.0 : data.fold(0.0, (sum, d) => sum + d.currentAverage) / data.length;
    final min = data.isEmpty ? 0.0 : data.map((d) => d.currentAverage).reduce((a, b) => a < b ? a : b);
    final max = data.isEmpty ? 0.0 : data.map((d) => d.currentAverage).reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        _buildStatCard('Avg Fare', 'KSh ${avg.toStringAsFixed(0)}', Colors.blue, Icons.trending_up),
        const SizedBox(width: 12),
        _buildStatCard('Min Fare', 'KSh ${min.toStringAsFixed(0)}', Colors.green, Icons.arrow_downward),
        const SizedBox(width: 12),
        _buildStatCard('Max Fare', 'KSh ${max.toStringAsFixed(0)}', Colors.red, Icons.arrow_upward),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color,
            )),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<dynamic> items, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(item.stageName),
            subtitle: Text('KSh ${item.currentAverage.toStringAsFixed(0)}'),
            trailing: Text(
              '${item.change > 0 ? '+' : ''}${item.change.toStringAsFixed(1)}%',
              style: TextStyle(
                color: item.change > 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildHourlyChart(BuildContext context) {
    final p = context.read<CommunityProvider>();
    final hourly = p.fareIntelligenceService.getSystemWideHourlyAverage();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Average Fare by Hour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: Size.infinite,
              painter: _HourlyChartPainter(hourly),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('12 AM', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('6 AM', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('12 PM', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('6 PM', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('11 PM', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourlyChartPainter extends CustomPainter {
  final Map<int, double> data;
  _HourlyChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0xFF008751)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF008751).withValues(alpha: 0.3), const Color(0xFF008751).withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final min = data.values.reduce((a, b) => a < b ? a : b);
    final max = data.values.reduce((a, b) => a > b ? a : b);
    final range = max - min;
    if (range == 0) return;

    final path = Path();
    final values = List.generate(24, (i) => data[i] ?? 0);
    for (int i = 0; i < 24; i++) {
      final x = (i / 23) * size.width;
      final y = size.height - ((values[i] - min) / range) * size.height * 0.8 - size.height * 0.1;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
    canvas.drawPath(
      Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close(),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
