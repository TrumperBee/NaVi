import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/transport_models.dart';
import '../models/app_settings.dart';
import '../utils/distance_formatter.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // OSRM API endpoint
  static const String osrmBaseUrl = 'https://router.project-osrm.org/route/v1';

  DistanceUnit _distanceUnit = DistanceUnit.km;

  void setDistanceUnit(DistanceUnit unit) => _distanceUnit = unit;
  DistanceUnit get distanceUnit => _distanceUnit;
  
  // Format distance for display
  String formatDistance(double meters) =>
      DistanceFormatter.format(meters, unit: _distanceUnit);

  // ADDED: Format time for display
  String formatTime(int seconds) {
    if (seconds < 60) return '$seconds sec';
    int minutes = (seconds / 60).floor();
    if (minutes >= 60) {
      int hours = (minutes / 60).floor();
      int remainingMins = minutes % 60;
      return '${hours}h ${remainingMins}m';
    }
    return '$minutes min';
  }
  
  // Get walking/driving route from OSRM
  Future<Map<String, dynamic>> getOSRMRoute(
    LatLng start,
    LatLng end, {
    String mode = 'walking', // 'walking' or 'driving'
  }) async {
    final url = '$osrmBaseUrl/$mode/'
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
          
          // Decode the polyline
          List<LatLng> points = _decodePolyline(route['geometry']);
          
          // Extract steps
          List<Map<String, dynamic>> steps = [];
          if (route['legs'] != null && route['legs'].isNotEmpty) {
            final leg = route['legs'][0];
            if (leg['steps'] != null) {
              for (var step in leg['steps']) {
                steps.add({
                  'instruction': step['maneuver']?['type'] ?? 'walk',
                  'name': step['name'] ?? '',
                  'distance': (step['distance'] ?? 0).toDouble(),
                  'duration': (step['duration'] ?? 0).toDouble(),
                  'bearing': step['maneuver']?['bearing_after'] ?? 0,
                  'modifier': step['maneuver']?['modifier'] ?? '',
                });
              }
            }
          }
          
          return {
            'points': points,
            'steps': steps,
            'distance': (route['distance'] ?? 0).toDouble(),
            'duration': (route['duration'] ?? 0).toDouble(),
            'source': 'OSRM',
          };
        }
      }
      
      // Fallback
      return _getFallbackRoute(start, end, mode);
      
    } catch (e) {
      print('OSRM Error: $e');
      return _getFallbackRoute(start, end, mode);
    }
  }
  
  // Fallback straight-line route
  Map<String, dynamic> _getFallbackRoute(LatLng start, LatLng end, String mode) {
    final distance = calculateDistance(start, end);
    final duration = mode == 'walking' 
        ? estimateWalkingTime(distance)
        : (distance / 8.33).round(); // driving speed
    
    return {
      'points': [start, end],
      'steps': [
        {
          'instruction': mode == 'walking' ? 'Walk to destination' : 'Drive to destination',
          'name': '',
          'distance': distance,
          'duration': duration,
          'bearing': 0,
          'modifier': '',
        }
      ],
      'distance': distance,
      'duration': duration,
      'source': 'Fallback',
    };
  }
  
  // Get route through multiple waypoints (for road-following polyline)
  Future<Map<String, dynamic>> getMultiSegmentRoute(
    List<LatLng> waypoints, {
    String mode = 'walking',
  }) async {
    if (waypoints.length < 2) {
      return {'points': waypoints, 'source': 'Fallback'};
    }

    final coords = waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
    final url = '$osrmBaseUrl/$mode/$coords'
        '?steps=false&geometries=polyline&overview=full&annotations=true';

    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => http.Response('Timeout', 408),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          List<LatLng> points = _decodePolyline(route['geometry']);
          return {
            'points': points,
            'source': 'OSRM',
          };
        }
      }
    } catch (e) {
      print('OSRM Multi Error: $e');
    }

    // Fallback: return direct waypoints
    return {'points': waypoints, 'source': 'Fallback'};
  }

  // Get dual-mode turn-by-turn instructions for transport mode
  Future<List<InstructionStep>> getTransportInstructions(
    List<Node> path,
    List<Edge> edges,
  ) async {
    List<InstructionStep> instructions = [];
    
    for (int i = 0; i < edges.length; i++) {
      final edge = edges[i];
      
      if (edge.routeNumbers.contains('walk')) {
        // Walking instruction
        instructions.add(InstructionStep(
          instruction: 'Walk ${formatDistance(edge.distance)} to ${edge.to.name}',
          distance: edge.distance,
          duration: edge.averageTime,
          type: 'walk',
          icon: '🚶',
          startNode: edge.from,
          endNode: edge.to,
        ));
      } else {
        // Matatu boarding instruction
        final routeNum = edge.routeNumbers.first;
        
        if (i == 0 || !edges[i-1].routeNumbers.contains(routeNum)) {
          // Boarding
          instructions.add(InstructionStep(
            instruction: 'Board Route $routeNum at ${edge.from.name}',
            distance: edge.distance,
            duration: edge.averageTime,
            type: 'board',
            icon: '🚌',
            startNode: edge.from,
            endNode: edge.to,
            routeNumber: routeNum,
          ));
        } else {
          // Continuing on same route
          if (i == edges.length - 1 || !edges[i+1].routeNumbers.contains(routeNum)) {
            // Alighting
            instructions.add(InstructionStep(
              instruction: 'Alight at ${edge.to.name}',
              distance: edge.distance,
              duration: edge.averageTime,
              type: 'alight',
              icon: '🚏',
              startNode: edge.from,
              endNode: edge.to,
              routeNumber: routeNum,
            ));
          }
          // Middle segments are implied, not shown as separate instructions
        }
        
        // Check for transfer
        if (i < edges.length - 1 && 
            !edges[i+1].routeNumbers.contains(routeNum) &&
            !edges[i+1].routeNumbers.contains('walk')) {
          instructions.add(InstructionStep(
            instruction: 'Transfer to Route ${edges[i+1].routeNumbers.first}',
            distance: 0,
            duration: 300, // 5 minutes transfer time
            type: 'transfer',
            icon: '🔄',
            startNode: edge.to,
            endNode: edges[i+1].to,
            routeNumber: edges[i+1].routeNumbers.first,
          ));
        }
      }
    }
    
    return instructions;
  }
  
  // Get general navigation instructions (street-based)
  Future<List<InstructionStep>> getGeneralInstructions(
    LatLng start,
    LatLng end, {
    String mode = 'walking',
  }) async {
    final route = await getOSRMRoute(start, end, mode: mode);
    final steps = route['steps'] as List;
    
    List<InstructionStep> instructions = [];
    
    for (var step in steps) {
      String instruction = _formatOSRMInstruction(
        step['instruction'],
        step['name'],
        step['modifier'],
      );
      
      instructions.add(InstructionStep(
        instruction: instruction,
        distance: step['distance'],
        duration: step['duration'].round(),
        type: mode == 'walking' ? 'walk' : 'drive',
        icon: _getDirectionIcon(step['modifier']),
      ));
    }
    
    // Add final arrival instruction
    instructions.add(InstructionStep(
      instruction: 'You have arrived at your destination',
      distance: 0,
      duration: 0,
      type: 'arrive',
      icon: '🏁',
    ));
    
    return instructions;
  }
  
  // Format OSRM instruction
  String _formatOSRMInstruction(String type, String name, String modifier) {
    if (type == 'depart') {
      return 'Start $modifier on ${name.isNotEmpty ? name : 'the road'}';
    } else if (type == 'turn') {
      return 'Turn $modifier onto ${name.isNotEmpty ? name : 'the road'}';
    } else if (type == 'continue') {
      return 'Continue straight on ${name.isNotEmpty ? name : 'this road'}';
    } else if (type == 'arrive') {
      return 'You have arrived';
    }
    return 'Walk on ${name.isNotEmpty ? name : 'the path'}';
  }
  
  // Get direction icon
  String _getDirectionIcon(String modifier) {
    switch (modifier) {
      case 'left': return '⬅️';
      case 'right': return '➡️';
      case 'straight': return '⬆️';
      case 'slight left': return '↖️';
      case 'slight right': return '↗️';
      case 'sharp left': return '↙️';
      case 'sharp right': return '↘️';
      default: return '⬆️';
    }
  }
  
  // Helper methods
  double calculateDistance(LatLng start, LatLng end) {
    const double R = 6371000;
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

  int estimateWalkingTime(double distanceMeters) {
    return (distanceMeters / 1.4).round();
  }
  
  // Polyline decoder
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
}