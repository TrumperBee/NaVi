import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:navi_app/features/community/models/community_models.dart';
import 'package:navi_app/services/database/database_service.dart';
import 'package:navi_app/services/database/local_storage_service.dart';
import 'package:navi_app/models/transport_models.dart';
import 'dart:math';

class CommunityService extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final LocalStorageService _storage = LocalStorageService();

  List<CommunityStageSuggestion> _stageSuggestions = [];
  List<CommunityRouteSuggestion> _routeSuggestions = [];
  bool _isLoading = false;

  List<CommunityStageSuggestion> get stageSuggestions =>
      List.unmodifiable(_stageSuggestions);
  List<CommunityRouteSuggestion> get routeSuggestions =>
      List.unmodifiable(_routeSuggestions);
  bool get isLoading => _isLoading;

  List<CommunityStageSuggestion> get pendingStageSuggestions =>
      _stageSuggestions.where((s) => s.status == SuggestionStatus.pending).toList();
  List<CommunityRouteSuggestion> get pendingRouteSuggestions =>
      _routeSuggestions.where((s) => s.status == SuggestionStatus.pending).toList();

  Future<void> loadSuggestions() async {
    _isLoading = true;
    notifyListeners();
    try {
      final stageData = await _db.getCollectionData('stage_suggestions');
      _stageSuggestions = stageData.map((entry) =>
          CommunityStageSuggestion.fromMap(entry['data'], entry['id'])).toList();
      final routeData = await _db.getCollectionData('route_suggestions');
      _routeSuggestions = routeData.map((entry) =>
          CommunityRouteSuggestion.fromMap(entry['data'], entry['id'])).toList();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> suggestStage(CommunityStageSuggestion suggestion) async {
    try {
      final id = await _db.addDocument('stage_suggestions', suggestion.toMap());
      _stageSuggestions.add(suggestion);
      notifyListeners();
      return id;
    } catch (_) {
      return null;
    }
  }

  Future<String?> suggestRoute(CommunityRouteSuggestion suggestion) async {
    try {
      final id = await _db.addDocument('route_suggestions', suggestion.toMap());
      _routeSuggestions.add(suggestion);
      notifyListeners();
      return id;
    } catch (_) {
      return null;
    }
  }

  Future<void> voteOnStageSuggestion(String suggestionId, VoteType vote) async {
    final idx = _stageSuggestions.indexWhere((s) => s.id == suggestionId);
    if (idx == -1) return;
    final suggestion = _stageSuggestions[idx];
    final updated = suggestion.copyWith(
      upvotes: vote == VoteType.upvote ? suggestion.upvotes + 1 : suggestion.upvotes,
      downvotes: vote == VoteType.downvote ? suggestion.downvotes + 1 : suggestion.downvotes,
    );
    _stageSuggestions[idx] = updated;
    notifyListeners();
    await _db.updateDocument('stage_suggestions', suggestionId, {
      'upvotes': updated.upvotes,
      'downvotes': updated.downvotes,
    });
  }

  Future<void> voteOnRouteSuggestion(String suggestionId, VoteType vote) async {
    final idx = _routeSuggestions.indexWhere((s) => s.id == suggestionId);
    if (idx == -1) return;
    final suggestion = _routeSuggestions[idx];
    final updated = suggestion.copyWith(
      upvotes: vote == VoteType.upvote ? suggestion.upvotes + 1 : suggestion.upvotes,
      downvotes: vote == VoteType.downvote ? suggestion.downvotes + 1 : suggestion.downvotes,
    );
    _routeSuggestions[idx] = updated;
    notifyListeners();
    await _db.updateDocument('route_suggestions', suggestionId, {
      'upvotes': updated.upvotes,
      'downvotes': updated.downvotes,
    });
  }

  Future<void> approveStageSuggestion(String suggestionId) async {
    final idx = _stageSuggestions.indexWhere((s) => s.id == suggestionId);
    if (idx == -1) return;
    final suggestion = _stageSuggestions[idx];
    _stageSuggestions[idx] = suggestion.copyWith(status: SuggestionStatus.approved);
    notifyListeners();
    await _db.updateDocument('stage_suggestions', suggestionId, {'status': 'approved'});
    final stage = StageModel(
      id: suggestion.id,
      name: suggestion.name,
      lat: suggestion.latitude,
      lng: suggestion.longitude,
      corridor: suggestion.corridor,
      routes: suggestion.routes,
      area: suggestion.area,
    );
    await _db.addDocument('stages', stage.toMap());
  }

  Future<void> approveRouteSuggestion(String suggestionId) async {
    final idx = _routeSuggestions.indexWhere((s) => s.id == suggestionId);
    if (idx == -1) return;
    final suggestion = _routeSuggestions[idx];
    _routeSuggestions[idx] = suggestion.copyWith(status: SuggestionStatus.approved);
    notifyListeners();
    await _db.updateDocument('route_suggestions', suggestionId, {'status': 'approved'});
    final route = RouteModel(
      id: suggestion.id,
      number: suggestion.number,
      name: suggestion.name,
      corridor: suggestion.corridor,
      sacco: suggestion.sacco,
      majorStops: suggestion.stops,
      baseFare: suggestion.baseFare,
    );
    await _db.addDocument('routes', route.toMap());
  }

  Future<void> rejectSuggestion(String collection, String suggestionId) async {
    await _db.updateDocument(collection, suggestionId, {'status': 'rejected'});
    if (collection == 'stage_suggestions') {
      final idx = _stageSuggestions.indexWhere((s) => s.id == suggestionId);
      if (idx >= 0) {
        _stageSuggestions[idx] = _stageSuggestions[idx].copyWith(status: SuggestionStatus.rejected);
      }
    } else {
      final idx = _routeSuggestions.indexWhere((s) => s.id == suggestionId);
      if (idx >= 0) {
        _routeSuggestions[idx] = _routeSuggestions[idx].copyWith(status: SuggestionStatus.rejected);
      }
    }
    notifyListeners();
  }
}
