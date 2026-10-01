import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/services/navigation_service.dart';
import 'package:navi_app/utils/distance_formatter.dart';

class AlightNotificationEngine {
  final NavigationService _navigationService = NavigationService();

  LatLng? _alightLocation;
  bool _hasNotified = false;
  bool _isApproaching = false;

  bool get hasNotified => _hasNotified;
  bool get isApproaching => _isApproaching;

  void setAlightPoint(StageModel stage) {
    _alightLocation = stage.location;
    _hasNotified = false;
    _isApproaching = false;
  }

  void setAlightPointCustom(LatLng location) {
    _alightLocation = location;
    _hasNotified = false;
    _isApproaching = false;
  }

  CheckResult checkProximity(LatLng currentLocation) {
    if (_alightLocation == null) {
      return CheckResult(shouldNotify: false, isApproaching: false, distance: double.infinity);
    }

    final distance = _navigationService.calculateDistance(
      currentLocation,
      _alightLocation!,
    );

    _isApproaching = distance < 300;
    _hasNotified = distance < 100;

    return CheckResult(
      shouldNotify: _hasNotified,
      isApproaching: _isApproaching,
      distance: distance,
    );
  }

  void reset() {
    _alightLocation = null;
    _hasNotified = false;
    _isApproaching = false;
  }
}

class CheckResult {
  final bool shouldNotify;
  final bool isApproaching;
  final double distance;

  const CheckResult({
    required this.shouldNotify,
    required this.isApproaching,
    required this.distance,
  });

  String get formattedDistance => DistanceFormatter.format(distance);
}
