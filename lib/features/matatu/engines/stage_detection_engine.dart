import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/data/seed_data.dart';

class StageDetectionEngine {
  StageModel? findNearestStage(LatLng location, {double maxDistance = 500}) {
    final stages = SeedData.getStages();
    StageModel? nearest;
    double minDistance = double.infinity;

    for (final stage in stages) {
      final distance = _calculateDistance(location, stage.location);
      if (distance < minDistance && distance <= maxDistance) {
        minDistance = distance;
        nearest = stage;
      }
    }

    return nearest;
  }

  List<StageModel> findStagesInRadius(LatLng location, {double radius = 1000}) {
    final stages = SeedData.getStages();
    return stages.where((stage) {
      final distance = _calculateDistance(location, stage.location);
      return distance <= radius;
    }).toList()
      ..sort((a, b) {
        final distA = _calculateDistance(location, a.location);
        final distB = _calculateDistance(location, b.location);
        return distA.compareTo(distB);
      });
  }

  List<StageModel> getStagesByCorridor(String corridor) {
    return SeedData.getStagesByCorridor(corridor);
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double R = 6371000;
    final double lat1 = start.latitude * math.pi / 180;
    final double lat2 = end.latitude * math.pi / 180;
    final double deltaLat = (end.latitude - start.latitude) * math.pi / 180;
    final double deltaLng = (end.longitude - start.longitude) * math.pi / 180;

    final double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }
}
