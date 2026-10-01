import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/models/wait_report_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int _maxRetries = 3;
  static const Duration _initialDelay = Duration(seconds: 1);
  static const Duration _timeoutDuration = Duration(seconds: 10);

  CollectionReference get _stagesCollection => _firestore.collection('stages');
  CollectionReference get _placesCollection => _firestore.collection('places');
  CollectionReference get _routesCollection => _firestore.collection('routes');
  CollectionReference get _waitReportsCollection => _firestore.collection('wait_reports');
  CollectionReference get _fareReportsCollection => _firestore.collection('fare_reports');
  CollectionReference get _trafficReportsCollection => _firestore.collection('traffic_reports');
  CollectionReference get _analyticsCollection => _firestore.collection('user_analytics');

  Future<T> _withTimeout<T>(Future<T> Function() fn) async {
    try {
      return await fn().timeout(_timeoutDuration);
    } on TimeoutException {
      print('Firestore operation timed out');
      rethrow;
    }
  }

  Future<T> _retry<T>(Future<T> Function() fn) async {
    int attempt = 0;
    while (true) {
      try {
        return await _withTimeout(fn);
      } catch (e) {
        attempt++;
        if (attempt >= _maxRetries) rethrow;
        final delay = _initialDelay * pow(2, attempt - 1) * (0.5 + Random().nextDouble());
        print('Retry attempt $attempt after ${delay.inSeconds}s delay');
        await Future.delayed(delay);
      }
    }
  }

  dynamic _handleError(dynamic error) {
    print('DatabaseService Error: $error');
    throw error;
  }

  // ==================== STAGES ====================

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

  Future<List<StageModel>> getStagesWithRetry() async {
    return _retry(() async {
      final snapshot = await _stagesCollection.get();
      return snapshot.docs.map((doc) {
        return StageModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

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

  // ==================== PLACES ====================

  Stream<List<PlaceModel>> getPlaces() {
    try {
      return _placesCollection.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return PlaceModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
    } catch (e) {
      print('Error getting places stream: $e');
      return Stream.error(e);
    }
  }

  Future<List<PlaceModel>> searchPlaces(String query) async {
    return _retry(() async {
      final snapshot = await _placesCollection
          .orderBy('name')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(20)
          .get();
      return snapshot.docs.map((doc) {
        return PlaceModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // ==================== ROUTES ====================

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

  Future<List<RouteModel>> getRoutesByStage(String stageId) async {
    try {
      StageModel? stage = await getStageById(stageId);
      if (stage == null || stage.routes.isEmpty) {
        return [];
      }
      QuerySnapshot snapshot = await _routesCollection
          .where('number', whereIn: stage.routes)
          .get();
      return snapshot.docs.map((doc) {
        return RouteModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      return _handleError(e);
    }
  }

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

  Future<String?> submitReport(WaitReportModel report) async {
    try {
      DocumentReference docRef = await _waitReportsCollection.add(report.toMap());
      await _routesCollection.doc(report.routeId).update({
        'last_report_at': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      return _handleError(e);
    }
  }

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

      if (filterByCurrentHour) {
        final now = DateTime.now();
        query = query.where('hour_of_day', isEqualTo: now.hour);
      }

      QuerySnapshot snapshot = await query.get();
      return snapshot.docs.map((doc) {
        return WaitReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      return _handleError(e);
    }
  }

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

  Future<List<WaitReportModel>> getTimeContextReports({
    required String stageId,
    required String routeId,
    int hourBuffer = 1,
  }) async {
    try {
      final now = DateTime.now();
      final currentHour = now.hour;
      List<int> relevantHours = [];
      for (int i = -hourBuffer; i <= hourBuffer; i++) {
        int hour = currentHour + i;
        if (hour >= 0 && hour <= 23) {
          relevantHours.add(hour);
        }
      }

      QuerySnapshot snapshot = await _waitReportsCollection
          .where('stage_id', isEqualTo: stageId)
          .where('route_id', isEqualTo: routeId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      List<WaitReportModel> reports = snapshot.docs.map((doc) {
        return WaitReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      return reports.where((report) =>
      relevantHours.contains(report.hourOfDay)
      ).toList();
    } catch (e) {
      return _handleError(e);
    }
  }

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

      double totalWait = reports.fold(0, (sum, r) => sum + r.waitTime);
      double averageWait = totalWait / reports.length;

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

  // ==================== FARE REPORTS ====================

  Future<void> submitFareReport(String stageId, double fare) async {
    await _retry(() async {
      final userId = _auth.currentUser?.uid ?? 'anonymous';
      final now = DateTime.now();
      await _fareReportsCollection.add({
        'stage_id': stageId,
        'fare': fare,
        'user_id': userId,
        'timestamp': now,
        'day_of_week': now.weekday,
        'hour_of_day': now.hour,
      });
      await _updateAverageFare(stageId, fare);
    });
  }

  Future<Map<String, double>> getAverageFare(String stageId) async {
    return _retry(() async {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final snapshot = await _fareReportsCollection
          .where('stage_id', isEqualTo: stageId)
          .where('timestamp', isGreaterThanOrEqualTo: weekAgo)
          .get();

      if (snapshot.docs.isEmpty) {
        return {'mean': 50.0, 'min': 50.0, 'max': 50.0, 'count': 0.0};
      }

      final fares = snapshot.docs.map((doc) {
        return (doc.data() as Map<String, dynamic>)['fare'] as num;
      }).map((e) => e.toDouble()).toList();

      fares.sort();
      final mean = fares.reduce((a, b) => a + b) / fares.length;
      return {'mean': mean, 'min': fares.first, 'max': fares.last, 'count': fares.length.toDouble()};
    });
  }

  Future<void> _updateAverageFare(String stageId, double newFare) async {
    try {
      final stats = await getAverageFare(stageId);
      final currentAvg = stats['mean'] ?? 50.0;
      final count = (stats['count'] ?? 0).toInt();
      final newAvg = ((currentAvg * count) + newFare) / (count + 1);
      await _stagesCollection.doc(stageId).update({
        'average_fare': newAvg,
        'total_reports': FieldValue.increment(1),
        'fare_history.${DateTime.now().toIso8601String()}': newFare,
      });
    } catch (e) {
      print('Error updating average fare: $e');
    }
  }

  // ==================== TRAFFIC REPORTS ====================

  Future<void> submitTrafficReport(String routeId, String trafficLevel) async {
    try {
      final userId = _auth.currentUser?.uid ?? 'anonymous';
      final now = DateTime.now();
      await _trafficReportsCollection.add({
        'route_id': routeId,
        'traffic_level': trafficLevel,
        'user_id': userId,
        'timestamp': now,
      });
      await _routesCollection.doc(routeId).update({
        'traffic_level': trafficLevel,
        'last_updated': now,
      });
    } catch (e) {
      print('Error submitting traffic report: $e');
    }
  }

  Stream<String> getTrafficLevel(String routeId) {
    return _routesCollection.doc(routeId).snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['traffic_level'] ?? 'medium';
      }
      return 'medium';
    });
  }

  // ==================== USER ANALYTICS ====================

  Future<void> updateUserAnalytics(TransportAnalytics analytics) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      final monthStr = analytics.month.toIso8601String().substring(0, 7);
      await _analyticsCollection.doc('${userId}_$monthStr').set(analytics.toMap());
    } catch (e) {
      print('Error updating user analytics: $e');
    }
  }

  Future<TransportAnalytics?> getUserAnalytics(DateTime month) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;
      final monthStr = month.toIso8601String().substring(0, 7);
      final doc = await _analyticsCollection.doc('${userId}_$monthStr').get();
      if (doc.exists) {
        return TransportAnalytics.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting user analytics: $e');
      return null;
    }
  }

  // ==================== USER ANALYTICS BATCH ====================

  Future<void> saveAnalyticsBatch(List<Map<String, dynamic>> events) async {
    try {
      final userId = _auth.currentUser?.uid ?? 'anonymous';
      final batch = _firestore.batch();
      for (final event in events) {
        final docRef = _analyticsCollection.doc();
        event['user_id'] = userId;
        batch.set(docRef, event);
      }
      await batch.commit();
    } catch (e) {
      print('Error saving analytics batch: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRecentAnalytics({
    String? type,
    int limit = 100,
  }) async {
    try {
      Query query = _analyticsCollection
          .orderBy('timestamp', descending: true)
          .limit(limit);
      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }
      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting recent analytics: $e');
      return [];
    }
  }

  // ==================== REPORTS (new multi-type) ====================

  Future<void> saveReport(Map<String, dynamic> reportData) async {
    try {
      await _waitReportsCollection.add(reportData);
    } catch (e) {
      print('Error saving report: $e');
    }
  }

  Future<void> updateReport(String reportId, Map<String, dynamic> data) async {
    try {
      await _waitReportsCollection.doc(reportId).update(data);
    } catch (e) {
      print('Error updating report: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getActiveReports() async {
    try {
      final snapshot = await _waitReportsCollection
          .where('status', isEqualTo: 'active')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'data': data, 'id': doc.id};
      }).toList();
    } catch (e) {
      print('Error getting active reports: $e');
      return [];
    }
  }

  // ==================== GENERIC COLLECTION OPERATIONS ====================

  Future<List<Map<String, dynamic>>> getCollectionData(String collection) async {
    try {
      final snapshot = await _firestore.collection(collection)
          .orderBy('created_at', descending: true)
          .limit(100)
          .get();
      return snapshot.docs.map((doc) {
        return {'data': doc.data() as Map<String, dynamic>, 'id': doc.id};
      }).toList();
    } catch (e) {
      print('Error getting collection $collection: $e');
      return [];
    }
  }

  Future<String?> addDocument(String collection, Map<String, dynamic> data) async {
    try {
      final docRef = await _firestore.collection(collection).add(data);
      return docRef.id;
    } catch (e) {
      print('Error adding document to $collection: $e');
      return null;
    }
  }

  Future<void> updateDocument(String collection, String docId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(docId).update(data);
    } catch (e) {
      print('Error updating document in $collection: $e');
    }
  }

  // ==================== BATCH OPERATIONS ====================

  Future<void> seedInitialData({
    required List<StageModel> stages,
    required List<RouteModel> routes,
  }) async {
    try {
      WriteBatch batch = _firestore.batch();
      for (var stage in stages) {
        batch.set(_stagesCollection.doc(stage.id), stage.toMap());
      }
      for (var route in routes) {
        batch.set(_routesCollection.doc(route.id), route.toMap());
      }
      await batch.commit();
      print('Initial data seeded successfully');
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> seedPlaces(List<PlaceModel> places) async {
    try {
      final batch = _firestore.batch();
      for (var place in places) {
        batch.set(_placesCollection.doc(place.id), place.toMap());
      }
      await batch.commit();
      print('Seeded ${places.length} places');
    } catch (e) {
      print('Error seeding places: $e');
    }
  }

  Future<int> deleteOldReports({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      QuerySnapshot snapshot = await _waitReportsCollection
          .where('timestamp', isLessThanOrEqualTo: cutoffDate)
          .limit(500)
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

  Future<void> deleteReport(String reportId) async {
    try {
      await _waitReportsCollection.doc(reportId).delete();
    } catch (e) {
      _handleError(e);
    }
  }
}
