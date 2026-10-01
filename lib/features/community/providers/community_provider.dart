import 'package:flutter/foundation.dart';
import 'package:navi_app/features/community/models/community_models.dart';
import 'package:navi_app/features/community/services/community_service.dart';
import 'package:navi_app/features/community/services/trust_score_service.dart';
import 'package:navi_app/features/community/services/anti_spam_service.dart';
import 'package:navi_app/features/community/services/fare_intelligence_service.dart';
import 'package:navi_app/features/community/services/transport_health_service.dart';
import 'package:navi_app/features/community/services/moderation_service.dart';

class CommunityProvider extends ChangeNotifier {
  final CommunityService communityService = CommunityService();
  final TrustScoreService trustScoreService = TrustScoreService();
  final AntiSpamService antiSpamService = AntiSpamService();
  final FareIntelligenceService fareIntelligenceService = FareIntelligenceService();
  final TransportHealthService transportHealthService = TransportHealthService();
  final ModerationService moderationService = ModerationService();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize({required String userId}) async {
    if (_isInitialized) return;
    await Future.wait([
      communityService.loadSuggestions(),
      trustScoreService.loadScore(userId),
      fareIntelligenceService.loadIntelligence(),
      transportHealthService.loadHealthData(),
      moderationService.loadData(),
    ]);
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    await Future.wait([
      communityService.loadSuggestions(),
      trustScoreService.loadLeaderboard(),
      fareIntelligenceService.loadIntelligence(),
      transportHealthService.loadHealthData(),
      moderationService.loadData(),
    ]);
    notifyListeners();
  }
}
