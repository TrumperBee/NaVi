import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/stage_model.dart';
import '../models/route_model.dart';
import '../models/wait_report_model.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference get _stagesCollection => _firestore.collection('stages');
  CollectionReference get _routesCollection => _firestore.collection('routes');
  CollectionReference get _waitReportsCollection => _firestore.collection('wait_reports');

  // Error handling helper
  dynamic _handleError(dynamic error) {
    print('DatabaseService Error: $error');
    throw error;
  }

  // ==================== STAGES ====================

  /// Get all stages as a stream (real-time updates)
  Stream<List<StageModel>> getStages() {
    try {
      return _stagesCollection.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return StageModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
    } catch (e) {
      _handleError(e);
      return Stream.error(e);
    }
  }

  /// Get stages by corridor
  Future<List<StageModel>> getStagesByCorridor(String corridor) async {
    try {
      QuerySnapshot snapshot = await _stagesCollection
          .where('corridor', isEqualTo: corridor)
          .get();
      
      return snapshot.docs.map((doc) {
        return StageModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Get a single stage by ID
  Future<StageModel?> getStageById(String stageId) async {
    try {
      DocumentSnapshot doc = await _stagesCollection.doc(stageId).get();
      if (doc.exists) {
        return StageModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      return _handleError(e);
    }
  }

  // ==================== ROUTES ====================

  /// Get all routes as a stream
  Stream<List<RouteModel>> getRoutes() {
    try {
      return _routesCollection.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return RouteModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
    } catch (e) {
      _handleError(e);
      return Stream.error(e);
    }
  }

  /// Get routes associated with a specific stage
  Future<List<RouteModel>> getRoutesByStage(String stageId) async {
    try {
      // First get the stage to know which route numbers serve it
      StageModel? stage = await getStageById(stageId);
      if (stage == null || stage.routes == null || stage.routes!.isEmpty) {
        return [];
      }

      // Get all routes that match the route numbers serving this stage
      QuerySnapshot snapshot = await _routesCollection
          .where('number', whereIn: stage.routes!)
          .get();
      
      return snapshot.docs.map((doc) {
        return RouteModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Get routes by corridor
  Future<List<RouteModel>> getRoutesByCorridor(String corridor) async {
    try {
      QuerySnapshot snapshot = await _routesCollection
          .where('corridor', isEqualTo: corridor)
          .get();
      
      return snapshot.docs.map((doc) {
        return RouteModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Get a single route by ID
  Future<RouteModel?> getRouteById(String routeId) async {
    try {
      DocumentSnapshot doc = await _routesCollection.doc(routeId).get();
      if (doc.exists) {
        return RouteModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      return _handleError(e);
    }
  }

  // ==================== WAIT REPORTS ====================

  /// Submit a new wait time report
  Future<String?> submitReport(WaitReportModel report) async {
    try {
      DocumentReference docRef = await _waitReportsCollection.add(report.toMap());
      
      // Update route's last updated timestamp
      await _routesCollection.doc(report.routeId).update({
        'last_report_at': FieldValue.serverTimestamp(),
      });
      
      return docRef.id;
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Get recent reports for a specific route at a specific stage
  /// Optionally filter by current hour for time-context analysis
  Future<List<WaitReportModel>> getRecentReports({
    required String stageId,
    required String routeId,
    int limit = 50,
    bool filterByCurrentHour = true,
  }) async {
    try {
      Query query = _waitReportsCollection
          .where('stage_id', isEqualTo: stageId)
          .where('route_id', isEqualTo: routeId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      // Filter by current hour if requested
      if (filterByCurrentHour) {
        final now = DateTime.now();
        final currentHour = now.hour;
        
        query = query
            .where('hour_of_day', isEqualTo: currentHour);
      }

      QuerySnapshot snapshot = await query.get();
      
      return snapshot.docs.map((doc) {
        return WaitReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Stream recent reports (real-time updates for predictions)
  Stream<List<WaitReportModel>> streamRecentReports({
    required String stageId,
    required String routeId,
    int limit = 50,
  }) {
    try {
      return _waitReportsCollection
          .where('stage_id', isEqualTo: stageId)
          .where('route_id', isEqualTo: routeId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return WaitReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            }).toList();
          });
    } catch (e) {
      _handleError(e);
      return Stream.error(e);
    }
  }

  /// Get reports for time-context analysis (current hour ± buffer)
  Future<List<WaitReportModel>> getTimeContextReports({
    required String stageId,
    required String routeId,
    int hourBuffer = 1,
  }) async {
    try {
      final now = DateTime.now();
      final currentHour = now.hour;
      
      // Create list of relevant hours
      List<int> relevantHours = [];
      for (int i = -hourBuffer; i <= hourBuffer; i++) {
        int hour = currentHour + i;
        if (hour >= 0 && hour <= 23) {
          relevantHours.add(hour);
        }
      }

      // Firestore doesn't support 'whereIn' with multiple fields easily,
      // so we'll fetch and filter in memory for now
      QuerySnapshot snapshot = await _waitReportsCollection
          .where('stage_id', isEqualTo: stageId)
          .where('route_id', isEqualTo: routeId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      List<WaitReportModel> reports = snapshot.docs.map((doc) {
        return WaitReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // Filter by relevant hours
      return reports.where((report) => 
        relevantHours.contains(report.hourOfDay)
      ).toList();
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Get aggregated statistics for a route at a stage
  Future<Map<String, dynamic>> getReportStatistics({
    required String stageId,
    required String routeId,
    int days = 7,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      
      QuerySnapshot snapshot = await _waitReportsCollection
          .where('stage_id', isEqualTo: stageId)
          .where('route_id', isEqualTo: routeId)
          .where('timestamp', isGreaterThanOrEqualTo: cutoffDate)
          .orderBy('timestamp', descending: false)
          .get();

      List<WaitReportModel> reports = snapshot.docs.map((doc) {
        return WaitReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      if (reports.isEmpty) {
        return {
          'total_reports': 0,
          'average_wait': 0,
          'peak_hour': null,
          'reports_by_hour': {},
        };
      }

      // Calculate average wait time
      double totalWait = reports.fold(0, (sum, report) => sum + report.waitTime);
      double averageWait = totalWait / reports.length;

      // Group by hour to find peak times
      Map<int, List<WaitReportModel>> byHour = {};
      for (var report in reports) {
        byHour.putIfAbsent(report.hourOfDay, () => []).add(report);
      }

      Map<int, double> hourlyAverages = {};
      int? peakHour;
      double peakAverage = 0;

      byHour.forEach((hour, hourReports) {
        double hourTotal = hourReports.fold(0, (sum, r) => sum + r.waitTime);
        double hourAvg = hourTotal / hourReports.length;
        hourlyAverages[hour] = hourAvg;
        
        if (hourAvg > peakAverage) {
          peakAverage = hourAvg;
          peakHour = hour;
        }
      });

      return {
        'total_reports': reports.length,
        'average_wait': averageWait,
        'peak_hour': peakHour,
        'peak_wait': peakAverage,
        'reports_by_hour': hourlyAverages,
        'date_range': 'Last $days days',
      };
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Get user's report history
  Future<List<WaitReportModel>> getUserReports({int limit = 20}) async {
    try {
      String? userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      QuerySnapshot snapshot = await _waitReportsCollection
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return WaitReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Get all wait reports (for prediction service)
  Future<List<WaitReportModel>> getAllReports({int limit = 1000}) async {
    try {
      QuerySnapshot snapshot = await _waitReportsCollection
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return WaitReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      return _handleError(e);
    }
  }

  // ==================== BATCH OPERATIONS ====================

  /// Seed initial data (useful for development)
  Future<void> seedInitialData({
    required List<StageModel> stages,
    required List<RouteModel> routes,
  }) async {
    try {
      WriteBatch batch = _firestore.batch();

      // Add stages
      for (var stage in stages) {
        DocumentReference docRef = _stagesCollection.doc(stage.id);
        batch.set(docRef, stage.toMap());
      }

      // Add routes
      for (var route in routes) {
        DocumentReference docRef = _routesCollection.doc(route.id);
        batch.set(docRef, route.toMap());
      }

      await batch.commit();
      print('Initial data seeded successfully');
    } catch (e) {
      _handleError(e);
    }
  }

  /// Delete old reports (maintenance)
  Future<int> deleteOldReports({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      QuerySnapshot snapshot = await _waitReportsCollection
          .where('timestamp', isLessThanOrEqualTo: cutoffDate)
          .limit(500) // Firestore batch limit
          .get();

      if (snapshot.docs.isEmpty) return 0;

      WriteBatch batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return snapshot.docs.length;
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Get report count for a specific route and stage
  Future<int> getReportCount({
    required String stageId,
    required String routeId,
  }) async {
    try {
      QuerySnapshot snapshot = await _waitReportsCollection
          .where('stage_id', isEqualTo: stageId)
          .where('route_id', isEqualTo: routeId)
          .limit(1)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Delete a specific report (admin function)
  Future<void> deleteReport(String reportId) async {
    try {
      await _waitReportsCollection.doc(reportId).delete();
    } catch (e) {
      _handleError(e);
    }
  }
}