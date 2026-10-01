import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:navi_app/features/community/providers/community_provider.dart';

class HealthDashboardScreen extends StatelessWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final health = provider.transportHealthService;
    final metric = health.todayMetric;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Health'),
        backgroundColor: const Color(0xFF008751),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.refreshAll(),
          ),
        ],
      ),
      body: metric == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMetricRow('Today\'s Health Score', _formatPercent(metric.reliabilityScore), _scoreColor(metric.reliabilityScore), Icons.monitor_heart),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Reliability', '${(metric.reliabilityScore * 100).toStringAsFixed(0)}%', Colors.green, Icons.check_circle)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricCard('Congestion', '${(metric.congestionLevel * 100).toStringAsFixed(0)}%', _scoreColor(1 - metric.congestionLevel), Icons.traffic)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Avg Wait', '${metric.averageWaitTime.toStringAsFixed(0)} min', Colors.orange, Icons.timer)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricCard('On-Time', '${(metric.onTimePerformance * 100).toStringAsFixed(0)}%', Colors.blue, Icons.schedule)),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection('Active Reports', Icons.report, Colors.red),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.red.withValues(alpha: 0.1), child: const Icon(Icons.error, color: Colors.red)),
                    title: Text('${metric.activeReports} Active Reports'),
                    subtitle: Text('${metric.resolvedReports} resolved today'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection('Route Performance', Icons.route, Colors.blue),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Best Performing:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        ...metric.bestRoutes.map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(r),
                          ]),
                        )),
                        const SizedBox(height: 12),
                        const Text('Needs Improvement:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        ...metric.worstRoutes.map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            const Icon(Icons.warning, size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(r),
                          ]),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection('Trends', Icons.trending_up, Colors.purple),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildTrendRow('Reliability Trend', health.weeklyReliabilityTrend, Colors.green),
                        const Divider(),
                        _buildTrendRow('Congestion Trend', health.weeklyCongestionTrend, Colors.red),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTrendRow(String label, double trend, Color upColor) {
    final isUp = trend >= 0;
    final arrow = isUp ? Icons.arrow_upward : Icons.arrow_downward;
    final arrowColor = label.contains('Congestion') ? (isUp ? Colors.red : Colors.green) : (isUp ? Colors.green : Colors.red);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            Icon(arrow, color: arrowColor, size: 18),
            Text('${trend.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: arrowColor)),
          ],
        ),
      ],
    );
  }

  String _formatPercent(double v) => '${(v * 100).toStringAsFixed(0)}%';
  Color _scoreColor(double v) => v >= 0.7 ? Colors.green : v >= 0.4 ? Colors.orange : Colors.red;
}
