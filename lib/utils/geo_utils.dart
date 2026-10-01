import 'dart:math';

double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
      sin(dLon / 2) * sin(dLon / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double bearing(double lat1, double lon1, double lat2, double lon2) {
  final dLon = (lon2 - lon1) * pi / 180;
  final y = sin(dLon) * cos(lat2 * pi / 180);
  final x = cos(lat1 * pi / 180) * sin(lat2 * pi / 180) -
      sin(lat1 * pi / 180) * cos(lat2 * pi / 180) * cos(dLon);
  return atan2(y, x) * 180 / pi;
}
