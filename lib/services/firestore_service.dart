import 'dart:async';
import 'package:navi_app/services/database/database_service.dart';
import 'package:navi_app/models/transport_models.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final DatabaseService _db = DatabaseService();

  Stream<List<StageModel>> getStages() => _db.getStages();

  Future<List<StageModel>> getStagesWithRetry() => _db.getStagesWithRetry();

  Stream<List<PlaceModel>> getPlaces() => _db.getPlaces();

  Future<List<PlaceModel>> searchPlaces(String query) => _db.searchPlaces(query);

  Future<void> submitFareReport(String stageId, double fare) => _db.submitFareReport(stageId, fare);

  Future<Map<String, double>> getAverageFare(String stageId) => _db.getAverageFare(stageId);

  Future<void> submitTrafficReport(String routeId, String trafficLevel) => _db.submitTrafficReport(routeId, trafficLevel);

  Stream<String> getTrafficLevel(String routeId) => _db.getTrafficLevel(routeId);

  Future<void> updateUserAnalytics(TransportAnalytics analytics) => _db.updateUserAnalytics(analytics);

  Future<TransportAnalytics?> getUserAnalytics(DateTime month) => _db.getUserAnalytics(month);

  Future<void> seedPlaces(List<PlaceModel> places) => _db.seedPlaces(places);
}
