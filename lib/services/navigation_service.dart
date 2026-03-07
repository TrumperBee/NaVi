import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // ADD THIS METHOD - for distance calculation used by screens
  double calculateDistance(LatLng start, LatLng end) {
    const double R = 6371000; // Earth's radius in meters
    double lat1 = start.latitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double deltaLat = (end.latitude - start.latitude) * pi / 180;
    double deltaLng = (end.longitude - start.longitude) * pi / 180;

    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
               cos(lat1) * cos(lat2) *
               sin(deltaLng / 2) * sin(deltaLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  // ADD THIS METHOD - for walking time estimation used by screens
  int estimateWalkingTime(double distanceMeters) {
    // Average walking speed is 1.4 m/s (5 km/h)
    return (distanceMeters / 1.4).round(); // returns seconds
  }

  // This fetches the actual STREET path, not just a straight line
  Future<Map<String, dynamic>> getRouteData(LatLng start, LatLng end) async {
    final url = 'https://router.project-osrm.org/route/v1/walking/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?steps=true&geometries=polyline&overview=full&annotations=true';

    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => http.Response('Timeout', 408),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          // Decode the polyline to get all points
          List<LatLng> points = _decodePolyline(route['geometry']);
          
          // Extract step-by-step instructions
          List<Map<String, dynamic>> instructions = [];
          if (route['legs'] != null && route['legs'].isNotEmpty) {
            final leg = route['legs'][0];
            if (leg['steps'] != null) {
              for (var step in leg['steps']) {
                instructions.add({
                  'instruction': _formatInstruction(step),
                  'distance': (step['distance'] ?? 0).toDouble(),
                  'duration': (step['duration'] ?? 0).toDouble(),
                  'type': step['maneuver']?['type'] ?? 'unknown',
                  'modifier': step['maneuver']?['modifier'] ?? '',
                  'name': step['name'] ?? '',
                  'bearing': step['maneuver']?['bearing_after'] ?? 0,
                });
              }
            }
          }
          
          return {
            'points': points,
            'instructions': instructions,
            'distance': (route['distance'] ?? 0).toDouble(), // in meters
            'duration': (route['duration'] ?? 0).toDouble(), // in seconds
            'source': 'OSRM',
          };
        }
      }
      
      // Fallback to straight line if routing fails
      return {
        'points': [start, end],
        'instructions': [
          {
            'instruction': 'Walk to destination',
            'distance': calculateDistance(start, end),
            'duration': estimateWalkingTime(calculateDistance(start, end)),
            'type': 'walk',
          }
        ],
        'distance': calculateDistance(start, end),
        'duration': estimateWalkingTime(calculateDistance(start, end)),
        'source': 'Straight Line (Fallback)',
      };
    } catch (e) {
      print('OSRM Error: $e');
      
      // Fallback to straight line if routing fails
      return {
        'points': [start, end],
        'instructions': [
          {
            'instruction': 'Walk to destination',
            'distance': calculateDistance(start, end),
            'duration': estimateWalkingTime(calculateDistance(start, end)),
            'type': 'walk',
          }
        ],
        'distance': calculateDistance(start, end),
        'duration': estimateWalkingTime(calculateDistance(start, end)),
        'source': 'Straight Line (Error Fallback)',
      };
    }
  }

  // Get walking route (simplified interface)
  Future<List<LatLng>> getWalkingRoute(LatLng start, LatLng end) async {
    final data = await getRouteData(start, end);
    return data['points'];
  }

  // Get turn-by-turn instructions
  Future<List<Map<String, dynamic>>> getWalkingInstructions(LatLng start, LatLng end) async {
    final data = await getRouteData(start, end);
    return List<Map<String, dynamic>>.from(data['instructions']);
  }

  // Format instruction nicely
  String _formatInstruction(Map<String, dynamic> step) {
    final type = step['maneuver']?['type'] ?? 'unknown';
    final modifier = step['maneuver']?['modifier'] ?? '';
    final name = step['name'] ?? '';
    
    String action;
    
    switch (type) {
      case 'turn':
        switch (modifier) {
          case 'left':
            action = 'Turn left';
            break;
          case 'right':
            action = 'Turn right';
            break;
          case 'slight left':
            action = 'Turn slight left';
            break;
          case 'slight right':
            action = 'Turn slight right';
            break;
          case 'sharp left':
            action = 'Turn sharp left';
            break;
          case 'sharp right':
            action = 'Turn sharp right';
            break;
          default:
            action = 'Turn';
        }
        break;
      case 'continue':
        action = 'Continue straight';
        break;
      case 'depart':
        action = 'Start walking';
        break;
      case 'arrive':
        action = 'You have arrived';
        break;
      case 'roundabout':
        action = 'Enter the roundabout';
        break;
      case 'exit roundabout':
        action = 'Exit roundabout';
        break;
      case 'merge':
        action = 'Merge';
        break;
      case 'fork':
        action = 'Keep $modifier';
        break;
      case 'end of road':
        action = 'At the end of the road';
        break;
      default:
        action = 'Walk';
    }
    
    if (name.isNotEmpty && type != 'arrive' && type != 'depart') {
      return '$action onto $name';
    } else if (type == 'arrive') {
      return 'You have arrived at your destination';
    } else if (type == 'depart') {
      return 'Start walking to your destination';
    }
    
    return action;
  }

  // Internal helper to turn the API response into a map line
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  // Format distance for display
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  // Format time for display
  String formatTime(int seconds) {
    if (seconds < 60) {
      return '$seconds sec';
    } else if (seconds < 3600) {
      int minutes = (seconds / 60).round();
      return '$minutes min';
    } else {
      int hours = (seconds / 3600).floor();
      int minutes = ((seconds % 3600) / 60).round();
      return '$hours hr $minutes min';
    }
  }
}