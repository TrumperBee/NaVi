import 'dart:async'; // Add this for StreamSubscription
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

// Rest of your imports
import 'package:navi_app/data/seed_data.dart';
import 'package:navi_app/models/stage_model.dart';
import 'package:navi_app/utils/constants.dart';
import 'package:navi_app/screens/stage_details_sheet.dart';
import 'package:navi_app/providers/app_state_provider.dart';
import 'package:navi_app/services/navigation_service.dart';
import 'package:navi_app/services/location_service.dart';

// ... rest of your home_map_screen.dart code stays exactly the same
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

// Fix imports - use navi_app
import 'package:navi_app/data/seed_data.dart';
import 'package:navi_app/models/stage_model.dart';
import 'package:navi_app/utils/constants.dart';
import 'package:navi_app/screens/stage_details_sheet.dart';
import 'package:navi_app/providers/app_state_provider.dart';
import 'package:navi_app/services/navigation_service.dart';
import 'package:navi_app/services/location_service.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final MapController _mapController = MapController();
  final NavigationService _navigationService = NavigationService();
  final LocationService _locationService = LocationService();
  
  List<StageModel> _stages = [];
  
  Position? _currentPosition;
  String _locationStatus = 'Locating...';
  String _currentStreet = '';
  bool _isLoading = true;
  bool _locationServiceEnabled = false;
  LocationPermission _locationPermission = LocationPermission.denied;
  bool _isUploading = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Navigation state
  bool _isNavigating = false;
  bool _showDirections = false;
  List<LatLng> _navigationPoints = [];
  List<Map<String, dynamic>> _navigationInstructions = [];
  LatLng? _destinationPoint;
  String? _destinationName;
  String? _destinationRoute;
  double _totalDistance = 0;
  double _totalDuration = 0;

  // Map settings - using correct v6 parameter names
  static const LatLng _nairobiCenter = LatLng(-1.2833, 36.8167);
  static const double _initialZoom = 15.0; // Closer zoom for street level
  static const double _navigationZoom = 17.0; // Street-level zoom for navigation
  static const double _minZoom = 11.0;
  static const double _maxZoom = 19.0;

  @override
  void initState() {
    super.initState();
    _stages = SeedData.getStages();
    _initializeLocationService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check if we have navigation arguments from search
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startNavigationFromSearch(args);
      });
    }
  }

  @override
  void dispose() {
    _stopLiveTracking();
    _mapController.dispose();
    super.dispose();
  }

  // Start live tracking with real-time updates
  void _startLiveTracking() {
    _positionStreamSubscription = _locationService.startLiveTracking(
      distanceFilter: 5, // Update every 5 meters
      accuracy: LocationAccuracy.bestForNavigation,
    ).listen((Position position) async {
      // Update current position
      setState(() {
        _currentPosition = position;
      });
      
      // Get street name for this position
      String street = await _locationService.getStreetName(
        position.latitude, 
        position.longitude
      );
      
      setState(() {
        _currentStreet = street;
        _locationStatus = street;
      });
      
      // Automatically pan the map to follow the user during navigation
      if (_isNavigating) {
        _mapController.move(
          LatLng(position.latitude, position.longitude), 
          _navigationZoom,
        );
      }
    });
  }

  // Stop live tracking
  void _stopLiveTracking() {
    _positionStreamSubscription?.cancel();
  }

  // Handle navigation from search results
  void _startNavigationFromSearch(Map<String, dynamic> searchResult) {
    if (searchResult.containsKey('destination')) {
      final dest = searchResult['destination'];
      final destLocation = dest['location'] as LatLng;
      final destName = dest['name'] as String;
      final destStage = dest['stage'] as StageModel?;
      
      // Get available routes
      String routes = '';
      if (destStage != null && destStage.routes != null) {
        routes = destStage.routes!.join(', ');
      }
      
      _navigateToDestination(destName, destLocation, routes);
    }
  }

  // IMPROVED: Location service with high accuracy
  Future<void> _initializeLocationService() async {
    setState(() => _isLoading = true);

    try {
      // Try to get current position with high accuracy
      Position position = await _locationService.getCurrentPosition();
      
      // Get street name for this position
      String street = await _locationService.getStreetName(
        position.latitude, 
        position.longitude
      );

      setState(() {
        _currentPosition = position;
        _currentStreet = street;
        _locationStatus = street;
        _isLoading = false;
      });

      // Center map on current location with street-level zoom
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _initialZoom,
      );
      
      // Start live tracking for real-time updates
      _startLiveTracking();
      
    } catch (e) {
      print('Location error: $e');
      
      // Fallback to default Nairobi CBD position
      setState(() {
        _locationStatus = 'Using default (CBD)';
        _currentStreet = 'Nairobi CBD';
        _isLoading = false;
        _currentPosition = Position(
          longitude: 36.81667,
          latitude: -1.28333,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      });
      
      // Center map on CBD
      _mapController.move(_nairobiCenter, _initialZoom);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await _locationService.getCurrentPosition();
      
      // Get street name
      String street = await _locationService.getStreetName(
        position.latitude, 
        position.longitude
      );
      
      setState(() {
        _currentPosition = position;
        _currentStreet = street;
        _locationStatus = street;
      });

      // Center map on current location with street-level zoom
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _navigationZoom, // Closer zoom for street view
      );
    } catch (e) {
      setState(() {
        _locationStatus = 'Error getting location';
      });
      print('Error getting location: $e');
    }
  }

  Future<void> _centerMapOnUser() async {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        _navigationZoom, // Street-level zoom
      );
    } else {
      await _getCurrentLocation();
    }
  }

  // Navigate to a destination with OSRM street routing
  Future<void> _navigateToDestination(String destinationName, LatLng destination, [String routes = '']) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available')),
      );
      return;
    }

    setState(() {
      _isNavigating = true;
      _showDirections = true;
      _destinationName = destinationName;
      _destinationRoute = routes;
      _destinationPoint = destination;
      _navigationPoints = [];
      _navigationInstructions = [];
    });

    try {
      // Get walking route from current location to destination using OSRM
      LatLng start = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calculating route on Nairobi streets...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Get route data with street-level instructions
      final routeData = await _navigationService.getRouteData(start, destination);
      
      setState(() {
        _navigationPoints = routeData['points'];
        _navigationInstructions = List<Map<String, dynamic>>.from(routeData['instructions']);
        _totalDistance = routeData['distance'];
        _totalDuration = routeData['duration'];
      });
      
      // Zoom to show the entire route
      _fitRouteOnMap(_navigationPoints);
      
    } catch (e) {
      print('Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error calculating route: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isNavigating = false;
        _showDirections = false;
      });
    }
  }

  // Fit the route on map view
  void _fitRouteOnMap(List<LatLng> route) {
    if (route.isEmpty) return;
    
    double minLat = route.map((p) => p.latitude).reduce(min);
    double maxLat = route.map((p) => p.latitude).reduce(max);
    double minLng = route.map((p) => p.longitude).reduce(min);
    double maxLng = route.map((p) => p.longitude).reduce(max);
    
    // Add padding
    double latPadding = (maxLat - minLat) * 0.2;
    double lngPadding = (maxLng - minLng) * 0.2;
    
    LatLng center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );
    
    // Calculate appropriate zoom level
    double latDiff = (maxLat - minLat) + 2 * latPadding;
    double lngDiff = (maxLng - minLng) + 2 * lngPadding;
    double zoom = _initialZoom;
    
    if (latDiff > 0.1 || lngDiff > 0.1) {
      zoom = 13.0;
    } else if (latDiff > 0.05 || lngDiff > 0.05) {
      zoom = 14.0;
    } else if (latDiff > 0.02 || lngDiff > 0.02) {
      zoom = 15.0;
    } else {
      zoom = 16.0;
    }
    
    _mapController.move(center, zoom);
  }

  // Clear current navigation
  void _clearNavigation() {
    setState(() {
      _isNavigating = false;
      _showDirections = false;
      _navigationPoints = [];
      _navigationInstructions = [];
      _destinationPoint = null;
      _destinationName = null;
      _destinationRoute = null;
      _totalDistance = 0;
      _totalDuration = 0;
    });
  }

  // Upload seed data using batch for speed and timeout
  Future<void> _uploadSeedData() async {
    setState(() => _isUploading = true);
    
    try {
      final db = FirebaseFirestore.instance;
      
      // Use a WriteBatch for speed and atomicity
      WriteBatch batch = db.batch();
      int stageCount = 0;
      int routeCount = 0;

      // Add stages to batch
      for (var stage in SeedData.getStages()) {
        DocumentReference docRef = db.collection('stages').doc(stage.id);
        batch.set(docRef, stage.toMap());
        stageCount++;
      }

      // Add routes to batch
      for (var route in SeedData.getRoutes()) {
        DocumentReference docRef = db.collection('routes').doc(route.id);
        batch.set(docRef, route.toMap());
        routeCount++;
      }

      // Commit batch with timeout
      await batch.commit().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Upload timeout - check your internet connection');
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Uploaded $stageCount stages and $routeCount routes to Firestore!'),
            backgroundColor: AppConstants.nairobiGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error uploading data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('Upload error: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showStageDetails(StageModel stage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: StageDetailsSheet(
          stage: stage,
          onNavigate: () {
            // When user taps "Navigate" in the stage details
            Navigator.pop(context); // Close bottom sheet
            if (_currentPosition != null) {
              String routes = stage.routes != null ? stage.routes!.join(', ') : '';
              _navigateToDestination(
                stage.name,
                LatLng(stage.lat, stage.lng),
                routes,
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildLocationStatus() {
    Color statusColor;
    IconData statusIcon;
    
    if (_currentPosition != null) {
      statusColor = Colors.green;
      statusIcon = Icons.location_on;
    } else if (_locationServiceEnabled && _locationPermission == LocationPermission.whileInUse) {
      statusColor = Colors.orange;
      statusIcon = Icons.location_searching;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.location_off;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _currentStreet.isNotEmpty ? _currentStreet : _locationStatus,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      bottom: 20,
      right: 16,
      child: Column(
        children: [
          // My Location button (Blue circle)
          FloatingActionButton(
            heroTag: 'my_location',
            mini: true,
            onPressed: _centerMapOnUser,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.my_location,
              color: _currentPosition != null ? Colors.blue : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          
          // Zoom in button
          FloatingActionButton(
            heroTag: 'zoom_in',
            mini: true,
            onPressed: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom + 1,
              );
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          
          // Zoom out button
          FloatingActionButton(
            heroTag: 'zoom_out',
            mini: true,
            onPressed: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom - 1,
              );
            },
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  // Direction card widget with turn-by-turn instructions
  Widget _buildDirectionCard() {
    if (!_showDirections || _navigationInstructions.isEmpty) return const SizedBox.shrink();
    
    final firstInstruction = _navigationInstructions.isNotEmpty ? _navigationInstructions.first : null;
    final nextInstruction = _navigationInstructions.length > 1 ? _navigationInstructions[1] : null;
    
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with destination
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.nairobiGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_walk,
                    color: AppConstants.nairobiGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To: $_destinationName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_destinationRoute != null && _destinationRoute!.isNotEmpty)
                        Text(
                          'Routes: $_destinationRoute',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _clearNavigation,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Distance and time
            Row(
              children: [
                _buildStatChip(
                  Icons.straighten,
                  _navigationService.formatDistance(_totalDistance),
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  Icons.timer,
                  _navigationService.formatTime(_totalDuration.round()),
                  Colors.orange,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Current instruction
            if (firstInstruction != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getInstructionIcon(firstInstruction['type']),
                      size: 20,
                      color: AppConstants.nairobiGreen,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstInstruction['instruction'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (firstInstruction['distance'] > 0)
                            Text(
                              'in ${_navigationService.formatDistance(firstInstruction['distance'])}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (nextInstruction != null)
                      const Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Colors.grey,
                      ),
                  ],
                ),
              ),
            
            // Next instruction preview
            if (nextInstruction != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getInstructionIcon(nextInstruction['type']),
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Then: ${nextInstruction['instruction']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper for stat chips
  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Get icon for instruction type
  IconData _getInstructionIcon(String type) {
    switch (type) {
      case 'turn':
        return Icons.turn_right;
      case 'continue':
        return Icons.arrow_upward;
      case 'depart':
        return Icons.exit_to_app;
      case 'arrive':
        return Icons.flag;
      case 'roundabout':
        return Icons.rotate_right;
      default:
        return Icons.directions_walk;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(AppConstants.appName),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Know Your Wait',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              // Navigate to search and wait for result
              final result = await Navigator.pushNamed(context, '/search');
              if (result != null && result is Map<String, dynamic>) {
                _startNavigationFromSearch(result);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeLocationService,
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          // Profile button
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map - Using flutter_map v6 syntax
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _nairobiCenter,
              initialZoom: _initialZoom,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              onTap: (tapPosition, point) {
                // Handle map tap if needed
              },
            ),
            children: [
              // OpenStreetMap tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.navi_app',
                maxZoom: 19,
              ),
              
              // Navigation polyline (walking path)
              if (_navigationPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _navigationPoints,
                      strokeWidth: 5.0,
                      color: Colors.blue.withOpacity(0.7),
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.0,
                    ),
                  ],
                ),
              
              // Destination marker (if navigating)
              if (_destinationPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _destinationPoint!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.flag,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              
              // User location marker
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              
              // Stage markers
              MarkerLayer(
                markers: _stages.map((stage) {
                  return Marker(
                    point: LatLng(stage.lat, stage.lng),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showStageDetails(stage),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppConstants.nairobiGreen,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.directions_bus,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          
          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Getting your precise location...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Using high accuracy for street navigation',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          
          // Upload progress indicator
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Uploading Nairobi data...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          
          // Location status with street name
          Positioned(
            top: 16,
            left: 16,
            child: _buildLocationStatus(),
          ),
          
          // Direction card with turn-by-turn instructions
          _buildDirectionCard(),
          
          // Map controls
          _buildMapControls(),
        ],
      ),
      // Floating action button for uploading seed data
      floatingActionButton: !_isNavigating 
          ? FloatingActionButton.extended(
              onPressed: _isUploading ? null : _uploadSeedData,
              backgroundColor: AppConstants.nairobiGreen,
              icon: _isUploading 
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cloud_upload, color: Colors.white),
              label: Text(
                _isUploading ? 'Uploading...' : 'Update 2026 Data',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}