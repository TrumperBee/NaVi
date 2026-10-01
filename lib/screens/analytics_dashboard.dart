import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/firestore_service.dart';
import '../models/transport_models.dart';
import '../utils/constants.dart';
import '../utils/distance_formatter.dart';

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  
  TransportAnalytics? _currentAnalytics;
  bool _isLoading = true;
  
  // Sample data for demonstration (in production, this comes from Firestore)
  final List<double> _monthlySpending = [2450, 3100, 2890, 4200, 3800, 5100];
  final List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
  
  final Map<String, double> _routeUsage = {
    'Route 44': 35,
    'Route 111': 28,
    'Route 24': 22,
    'Route 58': 15,
  };
  
  final Map<String, double> _timeDistribution = {
    'Walking': 25,
    'Waiting': 30,
    'Traveling': 45,
  };

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      final now = DateTime.now();
      final analytics = await _firestoreService.getUserAnalytics(now);
      
      setState(() {
        _currentAnalytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Transport Analytics'),
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  _buildSummaryCards(),
                  
                  const SizedBox(height: 24),
                  
                  // Monthly Spending Chart
                  _buildSectionHeader('Monthly Transport Spending'),
                  const SizedBox(height: 16),
                  _buildSpendingChart(),
                  
                  const SizedBox(height: 24),
                  
                  // Most Used Routes
                  _buildSectionHeader('Most Used Routes'),
                  const SizedBox(height: 16),
                  _buildRoutesChart(),
                  
                  const SizedBox(height: 24),
                  
                  // Travel Time Distribution
                  _buildSectionHeader('Travel Time Distribution'),
                  const SizedBox(height: 16),
                  _buildTimeDistributionChart(),
                  
                  const SizedBox(height: 24),
                  
                  // Detailed Stats
                  _buildSectionHeader('Detailed Statistics'),
                  const SizedBox(height: 16),
                  _buildDetailedStats(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard(
          'Total Spent',
          'KSh ${_currentAnalytics?.totalSpent.toStringAsFixed(0) ?? '4,520'}',
          Icons.attach_money,
          Colors.green,
        ),
        _buildSummaryCard(
          'Avg Fare',
          'KSh ${_currentAnalytics?.averageFare.toStringAsFixed(0) ?? '65'}',
          Icons.trending_up,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Total Trips',
          _currentAnalytics?.totalTrips.toString() ?? '42',
          Icons.directions_bus,
          Colors.orange,
        ),
        _buildSummaryCard(
          'Total KM',
          DistanceFormatter.format(
              ((_currentAnalytics?.totalDistance ?? 156000) / 1)),
          Icons.map,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSpendingChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _monthlySpending.reduce((a, b) => a > b ? a : b) * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.grey[900],
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  'KSh ${rod.toY.round()}',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < _months.length) {
                    return Text(
                      _months[value.toInt()],
                      style: const TextStyle(fontSize: 12),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(_monthlySpending.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: _monthlySpending[index],
                  color: AppConstants.nairobiGreen,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildRoutesChart() {
    final routes = _routeUsage.keys.toList();
    final values = _routeUsage.values.toList();
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: values.reduce((a, b) => a > b ? a : b) * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.grey[900],
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.round()} trips',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < routes.length) {
                    return Text(
                      routes[value.toInt()],
                      style: const TextStyle(fontSize: 12),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(routes.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: values[index],
                  color: Colors.blue,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTimeDistributionChart() {
    final sections = _timeDistribution.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        title: '${entry.value}%',
        color: entry.key == 'Walking' 
            ? Colors.green 
            : (entry.key == 'Waiting' ? Colors.orange : Colors.blue),
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              // Handle touches if needed
            },
            // Tooltips are handled automatically in newer versions
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStatRow('Most Used Route', _currentAnalytics?.mostUsedRoute ?? 'Route 44'),
          _buildStatRow('Average Distance/Trip',
              DistanceFormatter.format(_currentAnalytics?.averageDistance ?? 3700)),
          _buildStatRow('Peak Travel Hour', '7:30 - 8:30 AM'),
          _buildStatRow('Favorite Sacco', 'Super Metro'),
          _buildStatRow('Total Reports Submitted', _currentAnalytics?.totalTrips.toString() ?? '42'),
          _buildStatRow('Data Last Updated', DateTime.now().toString().substring(0, 16)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}