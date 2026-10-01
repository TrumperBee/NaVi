import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/utils/geo_utils.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  bool _highAccuracy = true;

  void setHighAccuracy(bool enabled) {
    _highAccuracy = enabled;
  }

  LocationAccuracy get _accuracy =>
      _highAccuracy ? LocationAccuracy.bestForNavigation : LocationAccuracy.medium;

  // Get current position with best accuracy for navigation
  Future<Position> getCurrentPosition() async {
    // Check permissions first
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions permanently denied');
    }

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: _accuracy,
    );
  }

  // Convert coordinates to street name (e.g., "Kenyatta Avenue")
  Future<String> getStreetName(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Build a readable address
        List<String> parts = [];
        
        if (place.street != null && place.street!.isNotEmpty) {
          parts.add(place.street!);
        } else if (place.name != null && place.name!.isNotEmpty) {
          parts.add(place.name!);
        }
        
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          parts.add(place.subLocality!);
        } else if (place.locality != null && place.locality!.isNotEmpty) {
          parts.add(place.locality!);
        }
        
        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
        
        // If we have a thoroughfare (road name), use that
        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
          return place.thoroughfare!;
        }
        
        // Returns something like "Kenyatta Ave" instead of just "CBD"
        return place.street ?? place.name ?? "Nairobi CBD";
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return "Nairobi CBD"; // Fallback
  }

  // Get comprehensive address with more details
  Future<String> getFullAddress(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        return [
          place.street,
          place.subLocality,
          place.locality,
          place.postalCode,
          place.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return "Nairobi, Kenya";
  }

  // Get locality/area name (e.g., "Westlands", "CBD")
  Future<String> getAreaName(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Try to get the most specific area name
        return place.subLocality ?? 
               place.locality ?? 
               place.subAdministrativeArea ?? 
               place.administrativeArea ?? 
               "Nairobi";
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return "Nairobi";
  }

  // Start live tracking with real-time updates
  Stream<Position> startLiveTracking({
    double distanceFilter = 5, // Update every 5 meters
    LocationAccuracy? accuracy,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy ?? _accuracy,
        distanceFilter: distanceFilter.toInt(),
      ),
    );
  }

  // Calculate distance between two points (Haversine formula)
  double calculateDistance(LatLng start, LatLng end) {
    return haversineDistance(
      start.latitude, start.longitude,
      end.latitude, end.longitude,
    );
  }

  // Format distance for display
  String formatDistance(double meters, {String unit = 'km'}) {
    if (unit == 'mi') {
      final miles = meters / 1609.344;
      if (miles >= 1) return '${miles.toStringAsFixed(1)} mi';
      return '${(meters / 0.3048).round()} ft';
    }
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // Estimate walking time (5 km/h average walking speed)
  int estimateWalkingTime(double distanceMeters) {
    return (distanceMeters / 1.4).round(); // 1.4 m/s ≈ 5 km/h
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