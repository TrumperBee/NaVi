import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

// FIXED: Import the correct model file
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/models/wait_report_model.dart';
import 'package:navi_app/data/seed_data.dart';

class PredictionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for reports to reduce Firestore reads
  List<WaitReportModel> _cachedReports = [];
  DateTime _lastFetch = DateTime.now().subtract(const Duration(minutes: 5));

  // Calculate mean of wait times
  double calculateMean(List<WaitReportModel> reports) {
    if (reports.isEmpty) return 0;
    
    double sum = reports.fold(0, (total, report) => total + report.waitTime);
    return sum / reports.length;
  }

  // Calculate standard deviation
  double calculateStdDev(List<WaitReportModel> reports) {
    if (reports.length < 2) return 0;
    
    double mean = calculateMean(reports);
    double sumSquaredDiff = reports.fold(
      0, 
      (total, report) => total + pow(report.waitTime - mean, 2).toDouble()
    );
    
    return sqrt(sumSquaredDiff / (reports.length - 1));
  }

  // Calculate 80% confidence interval (z-score = 1.28)
  Map<String, double> calculateConfidenceInterval(List<WaitReportModel> reports) {
    if (reports.isEmpty) {
      return {
        'mean': 0.0,
        'lower': 0.0,
        'upper': 0.0,
        'margin': 0.0,
        'stdDev': 0.0,
        'count': 0.0,
      };
    }
    
    double mean = calculateMean(reports);
    double stdDev = calculateStdDev(reports);
    double n = reports.length.toDouble();
    
    if (reports.length == 1) {
      return {
        'mean': mean,
        'lower': mean,
        'upper': mean,
        'margin': 0.0,
        'stdDev': stdDev,
        'count': n,
      };
    }
    
    // 80% CI z-score = 1.28
    double margin = 1.28 * (stdDev / sqrt(n));
    
    return {
      'mean': mean,
      'lower': max(0, mean - margin), // Wait time can't be negative
      'upper': mean + margin,
      'margin': margin,
      'stdDev': stdDev,
      'count': n,
    };
  }

  // Fetch reports from Firestore with caching
  Future<List<WaitReportModel>> _fetchReports({bool forceRefresh = false}) async {
    // Use cache if less than 5 minutes old
    if (!forceRefresh && 
        _cachedReports.isNotEmpty && 
        DateTime.now().difference(_lastFetch).inMinutes < 5) {
      return _cachedReports;
    }

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('wait_reports')
          .orderBy('timestamp', descending: true)
          .limit(1000) // Limit for performance
          .get();

      _cachedReports = snapshot.docs.map((doc) {
        return WaitReportModel.fromMap(
          doc.data() as Map<String, dynamic>, 
          doc.id
        );
      }).toList();
      
      _lastFetch = DateTime.now();
      return _cachedReports;
    } catch (e) {
      print('Error fetching reports: $e');
      return _cachedReports.isNotEmpty ? _cachedReports : [];
    }
  }

  // Get current hour with buffer (±1 hour for context)
  List<int> _getRelevantHours() {
    final now = DateTime.now();
    final currentHour = now.hour;
    
    return [
      currentHour - 1,
      currentHour,
      currentHour + 1,
    ].where((hour) => hour >= 0 && hour <= 23).toList();
  }

  // Main prediction function
  Future<Map<String, dynamic>> getPredictedWait({
    required String stageId,
    required String routeId,
    bool useTimeContext = true,
  }) async {
    // Fetch all reports
    List<WaitReportModel> allReports = await _fetchReports();
    
    // Get stage and route info for fallback
    final stage = SeedData.getStages().firstWhere(
      (s) => s.id == stageId,
      orElse: () => StageModel(
        id: stageId,
        name: 'Unknown',
        lat: 0,
        lng: 0,
        corridor: 'Unknown',
        routes: const [], // Empty list for fallback
      ),
    );
    
    // FIXED: RouteModel fallback with all required fields and const for majorStops
    final route = SeedData.getRoutes().firstWhere(
      (r) => r.id == routeId,
      orElse: () => RouteModel(
        id: routeId,
        number: 'Unknown',
        name: 'Unknown Route',
        corridor: 'Unknown',
        majorStops: const [], // FIXED: Added 'const'
        sacco: 'Unknown',
        description: 'Fallback route',
        distance: 0.0,
        baseFare: 0.0,
        estimatedTime: 0,
        trafficLevel: 'medium',
      ),
    );

    // Step 1: Filter by time context if requested
    List<WaitReportModel> timeContextReports = [];
    if (useTimeContext) {
      final relevantHours = _getRelevantHours();
      timeContextReports = allReports.where((report) {
        return report.routeId == routeId && 
               report.stageId == stageId &&
               relevantHours.contains(report.hourOfDay);
      }).toList();
    }

    // Step 2: Try route-specific with time context
    if (timeContextReports.length >= 3) {
      Map<String, double> ci = calculateConfidenceInterval(timeContextReports);
      return {
        'source': 'Route-specific (current time context)',
        'confidence': 'High',
        'data': ci,
        'reportCount': timeContextReports.length,
        'stage': stage.name,
        'route': route.number,
        'recommendation': _getRecommendation(ci['mean'] ?? 0),
      };
    }

    // Step 3: Route-specific all time
    List<WaitReportModel> routeStageReports = allReports.where((report) {
      return report.routeId == routeId && report.stageId == stageId;
    }).toList();

    if (routeStageReports.length >= 5) {
      Map<String, double> ci = calculateConfidenceInterval(routeStageReports);
      return {
        'source': 'Route-specific (all times)',
        'confidence': 'High',
        'data': ci,
        'reportCount': routeStageReports.length,
        'stage': stage.name,
        'route': route.number,
        'recommendation': _getRecommendation(ci['mean'] ?? 0),
      };
    }

    // Step 4: Stage average
    List<WaitReportModel> stageReports = allReports.where((report) {
      return report.stageId == stageId;
    }).toList();

    if (stageReports.length >= 10) {
      Map<String, double> ci = calculateConfidenceInterval(stageReports);
      return {
        'source': 'Stage average',
        'confidence': 'Medium',
        'data': ci,
        'reportCount': stageReports.length,
        'stage': stage.name,
        'route': route.number,
        'recommendation': _getRecommendation(ci['mean'] ?? 0),
      };
    }

    // Step 5: Corridor average
    List<WaitReportModel> corridorReports = allReports.where((report) {
      // This requires joining with stage data to get corridor
      // For now, filter by route corridor
      return report.routeId == routeId;
    }).toList();

    if (corridorReports.length >= 20) {
      Map<String, double> ci = calculateConfidenceInterval(corridorReports);
      return {
        'source': 'Corridor average',
        'confidence': 'Low',
        'data': ci,
        'reportCount': corridorReports.length,
        'stage': stage.name,
        'route': route.number,
        'recommendation': _getRecommendation(ci['mean'] ?? 0),
      };
    }

    // Step 6: City average
    if (allReports.length >= 50) {
      Map<String, double> ci = calculateConfidenceInterval(allReports);
      return {
        'source': 'City average',
        'confidence': 'Very Low',
        'data': ci,
        'reportCount': allReports.length,
        'stage': stage.name,
        'route': route.number,
        'recommendation': _getRecommendation(ci['mean'] ?? 0),
      };
    }

    // Step 7: Default estimate based on Nairobi traffic patterns
    return {
      'source': 'Default estimate',
      'confidence': 'None',
      'data': {
        'mean': _getDefaultEstimate(route.corridor, stage.area ?? ''),
        'lower': 5,
        'upper': 15,
        'margin': 5,
        'stdDev': 3,
        'count': 0,
      },
      'reportCount': 0,
      'stage': stage.name,
      'route': route.number,
      'recommendation': 'Consider checking multiple stages',
    };
  }

  // Get batch predictions for multiple routes at a stage
  Future<List<Map<String, dynamic>>> getBatchPredictions({
    required String stageId,
    List<String>? routeIds,
  }) async {
    final stage = SeedData.getStages().firstWhere(
      (s) => s.id == stageId,
      orElse: () => StageModel(
        id: stageId,
        name: 'Unknown',
        lat: 0,
        lng: 0,
        corridor: 'Unknown',
        routes: const [], // Empty list for fallback
      ),
    );

    // If no routeIds provided, get all routes for this stage
    final routesToCheck = routeIds ?? stage.routes;
    
    List<Future<Map<String, dynamic>>> predictions = [];
    for (String routeId in routesToCheck) {
      // Find actual route ID from route number
      // FIXED: RouteModel fallback with all required fields and const for majorStops
      final route = SeedData.getRoutes().firstWhere(
        (r) => r.number == routeId,
        orElse: () => RouteModel(
          id: 'route_$routeId',
          number: routeId,
          name: 'Route $routeId',
          corridor: stage.corridor,
          majorStops: const [], // FIXED: Added 'const'
          sacco: 'Unknown',
          description: 'Fallback route',
          distance: 0.0,
          baseFare: 0.0,
          estimatedTime: 0,
          trafficLevel: 'medium',
        ),
      );
      
      predictions.add(getPredictedWait(
        stageId: stageId,
        routeId: route.id,
      ));
    }

    return Future.wait(predictions);
  }

  // Get real-time prediction stream
  Stream<Map<String, dynamic>> streamPrediction({
    required String stageId,
    required String routeId,
  }) {
    return _firestore
        .collection('wait_reports')
        .where('stage_id', isEqualTo: stageId)
        .where('route_id', isEqualTo: routeId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final reports = snapshot.docs.map((doc) {
            return WaitReportModel.fromMap(
              doc.data() as Map<String, dynamic>, 
              doc.id
            );
          }).toList();

          Map<String, double> ci = calculateConfidenceInterval(reports);
          
          return {
            'source': 'Real-time',
            'confidence': reports.length >= 5 ? 'High' : 'Low',
            'data': ci,
            'reportCount': reports.length,
            'timestamp': DateTime.now(),
          };
        });
  }

  // Helper: Get recommendation based on wait time
  String _getRecommendation(double waitTime) {
    if (waitTime < 5) {
      return 'Great time to travel! Minimal wait expected.';
    } else if (waitTime < 10) {
      return 'Moderate wait time. Plan accordingly.';
    } else if (waitTime < 15) {
      return 'Long wait expected. Consider alternative routes.';
    } else {
      return 'Very long wait! Definitely check alternatives.';
    }
  }

  // Helper: Default estimate based on corridor and area
  double _getDefaultEstimate(String corridor, String area) {
    // Nairobi traffic patterns by corridor
    final Map<String, double> corridorBaseTimes = {
      'Thika Road': 12,
      'Mombasa Road': 10,
      'Ngong Road': 8,
      'Jogoo Road': 9,
      'Waiyaki Way': 7,
      'CBD': 5,
    };

    final now = DateTime.now();
    final isPeakHour = (now.hour >= 7 && now.hour <= 9) || 
                       (now.hour >= 17 && now.hour <= 19);
    final isWeekend = now.weekday == DateTime.saturday || 
                      now.weekday == DateTime.sunday;

    double baseTime = corridorBaseTimes[corridor] ?? 8;
    
    // Adjust for peak hours
    if (isPeakHour && !isWeekend) {
      baseTime *= 1.5;
    }
    
    // Adjust for weekend
    if (isWeekend) {
      baseTime *= 0.8;
    }

    return baseTime;
  }

  // Get historical trends
  Future<Map<String, dynamic>> getHistoricalTrends({
    required String stageId,
    required String routeId,
    int days = 7,
  }) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    
    final reports = await _fetchReports();
    
    final filteredReports = reports.where((report) {
      return report.routeId == routeId && 
             report.stageId == stageId &&
             report.timestamp.isAfter(cutoffDate);
    }).toList();

    // Group by hour of day
    Map<int, List<WaitReportModel>> byHour = {};
    for (var report in filteredReports) {
      byHour.putIfAbsent(report.hourOfDay, () => []).add(report);
    }

    // Calculate averages by hour
    Map<int, double> hourlyAverages = {};
    byHour.forEach((hour, reports) {
      hourlyAverages[hour] = calculateMean(reports);
    });

    // Group by day of week
    Map<int, List<WaitReportModel>> byDay = {};
    for (var report in filteredReports) {
      byDay.putIfAbsent(report.dayOfWeek, () => []).add(report);
    }

    Map<int, double> dailyAverages = {};
    byDay.forEach((day, reports) {
      dailyAverages[day] = calculateMean(reports);
    });

    return {
      'total_reports': filteredReports.length,
      'date_range': 'Last $days days',
      'hourly_averages': hourlyAverages,
      'daily_averages': dailyAverages,
      'overall_average': calculateMean(filteredReports),
      'trend': _analyzeTrend(filteredReports),
    };
  }

  // Analyze trend (increasing/decreasing/stable)
  String _analyzeTrend(List<WaitReportModel> reports) {
    if (reports.length < 10) return 'Insufficient data';
    
    // Sort by timestamp
    reports.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Split into two halves and compare means
    int midPoint = reports.length ~/ 2;
    var firstHalf = reports.sublist(0, midPoint);
    var secondHalf = reports.sublist(midPoint);
    
    double firstMean = calculateMean(firstHalf);
    double secondMean = calculateMean(secondHalf);
    
    double difference = secondMean - firstMean;
    
    if (difference > 2) return 'Increasing 🔼';
    if (difference < -2) return 'Decreasing 🔽';
    return 'Stable ➡️';
  }
}