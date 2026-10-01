import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;

// Fix imports - use navi_app
import 'package:navi_app/utils/constants.dart';
import 'package:navi_app/data/seed_data.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/services/distance_calculator.dart';
import 'package:navi_app/utils/distance_formatter.dart';

class DestinationSearchScreen extends StatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  State<DestinationSearchScreen> createState() => _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final TextEditingController _destController = TextEditingController();
  
  List<StageModel> _allStages = [];
  List<StageModel> _filteredStages = [];
  
  Position? _currentPosition;
  String _locationStatus = 'Getting your location...';
  bool _isLoadingLocation = true;
  
  // Selected items
  StageModel? _selectedStartStage;
  StageModel? _selectedDestStage;

  @override
  void initState() {
    super.initState();
    _allStages = SeedData.getStages();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'Location disabled';
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = 'Location permissions denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = 'Location permissions permanently denied';
          _isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _currentPosition = position;
        _locationStatus = 'Your current location';
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationStatus = 'Using default location (CBD)';
        _isLoadingLocation = false;
      });
    }
  }

  void _searchDestination(String query) {
    if (query.isEmpty) {
      setState(() => _filteredStages = []);
      return;
    }

    // Logic: User types destination, we find the CBD stage that goes there
    setState(() {
      _filteredStages = _allStages.where((stage) {
        // Check if destination name matches any stage or the routes it serves
        final nameMatch = stage.name.toLowerCase().contains(query.toLowerCase());
        final corridorMatch = stage.corridor.toLowerCase().contains(query.toLowerCase());
        final areaMatch = stage.area?.toLowerCase().contains(query.toLowerCase()) ?? false;
        
        // Also check if any route served by this stage matches the query
        final routeMatch = stage.routes?.any((route) => 
          route.toLowerCase().contains(query.toLowerCase())
        ) ?? false;
        
        return nameMatch || corridorMatch || areaMatch || routeMatch;
      }).toList();
    });
  }

  // FIXED: Added nullable return type (StageModel?) to allow returning null
  StageModel? _findBestStageForDestination(String destination) {
    // Try exact match first
    try {
      return _allStages.firstWhere(
        (stage) => stage.name.toLowerCase() == destination.toLowerCase(),
        orElse: () => _allStages.firstWhere(
          (stage) => stage.corridor.toLowerCase() == destination.toLowerCase(),
          orElse: () => _allStages.firstWhere(
            (stage) => stage.routes?.any((route) => 
              route.toLowerCase() == destination.toLowerCase()
            ) ?? false,
            orElse: () => _allStages.firstWhere(
              (stage) => stage.area?.toLowerCase() == destination.toLowerCase(),
              orElse: () => _allStages.firstWhere(
                (stage) => stage.name.toLowerCase().contains(destination.toLowerCase()),
                orElse: () => _allStages.firstWhere(
                  (stage) => stage.corridor.toLowerCase().contains(destination.toLowerCase()),
                  orElse: () => _allStages.firstWhere(
                    (stage) => stage.area?.toLowerCase().contains(destination.toLowerCase()) ?? false,
                    // FIXED: Instead of returning null, we return a default stage if available
                    orElse: () => _allStages.isNotEmpty ? _allStages.first : 
                        // Create a fallback stage if no stages exist
                        StageModel(
                          id: 'unknown',
                          name: destination,
                          lat: -1.2833,
                          lng: 36.8167,
                          corridor: 'Unknown',
                          routes: [],
                          area: destination,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      // Return a default stage if no match found
      return StageModel(
        id: 'unknown',
        name: destination,
        lat: -1.2833,
        lng: 36.8167,
        corridor: 'Unknown',
        routes: [],
        area: destination,
      );
    }
  }

  // Calculate distance from current location to stage
  double _calculateDistanceToStage(StageModel stage) {
    if (_currentPosition == null) return 0;
    return DistanceCalculator.distanceMeters(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      LatLng(stage.lat, stage.lng),
    );
  }

  // Get estimated walking time to stage
  String _getWalkingTimeToStage(StageModel stage) {
    if (_currentPosition == null) return '';

    double distance = _calculateDistanceToStage(stage);
    int seconds = DistanceCalculator.walkDurationForDistance(distance);
    
    if (seconds < 60) {
      return '$seconds sec walk';
    } else if (seconds < 3600) {
      int minutes = (seconds / 60).round();
      return '$minutes min walk';
    } else {
      int hours = (seconds / 3600).floor();
      int minutes = ((seconds % 3600) / 60).round();
      return '$hours hr $minutes min walk';
    }
  }

  // Handle destination selection
  void _selectDestination(StageModel stage) {
    // Find the best starting point (user's current location)
    if (_currentPosition != null) {
      // Return both start and destination to the map
      Navigator.pop(context, {
        'start': {
          'name': 'Your Location',
          'location': LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          'isCurrentLocation': true,
        },
        'destination': {
          'name': stage.name,
          'location': LatLng(stage.lat, stage.lng),
          'stage': stage,
        },
        'routes': stage.routes,
      });
    } else {
      // Just return the destination
      Navigator.pop(context, {
        'destination': {
          'name': stage.name,
          'location': LatLng(stage.lat, stage.lng),
          'stage': stage,
        },
        'routes': stage.routes,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Plan Your Journey"),
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // THE INPUT BOXES (Google Maps Style)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Starting Point (Your Location)
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            if (_isLoadingLocation)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Expanded(
                                child: Text(
                                  _locationStatus,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Connecting line
                Padding(
                  padding: const EdgeInsets.only(left: 11, top: 4, bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 2,
                        height: 20,
                        color: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
                
                // Destination Point
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: TextField(
                          controller: _destController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: "Where are you going?",
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(12),
                          ),
                          onChanged: _searchDestination,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Quick suggestions
          if (_destController.text.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Popular Destinations',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSuggestionChip('Karen'),
                      _buildSuggestionChip('Westlands'),
                      _buildSuggestionChip('Githurai'),
                      _buildSuggestionChip('Kibera'),
                      _buildSuggestionChip('Airport'),
                      _buildSuggestionChip('Nyeri'),
                      _buildSuggestionChip('Embu'),
                      _buildSuggestionChip('Langata'),
                    ],
                  ),
                ],
              ),
            ),
          
          // RESULTS LIST
          Expanded(
            child: _destController.text.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Search for your destination',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : _filteredStages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No stages found for this destination',
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try a different name or check spelling',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredStages.length,
                      itemBuilder: (context, index) {
                        final stage = _filteredStages[index];
                        final distance = _calculateDistanceToStage(stage);
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppConstants.nairobiGreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.directions_bus,
                                color: AppConstants.nairobiGreen,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              stage.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Corridor: ${stage.corridor}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (stage.routes != null && stage.routes!.isNotEmpty)
                                  Text(
                                    'Routes: ${stage.routes!.take(3).join(', ')}${stage.routes!.length > 3 ? '...' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                if (_currentPosition != null)
                                  Text(
                                    _getWalkingTimeToStage(stage),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (_currentPosition != null)
                                  Text(
                                    DistanceFormatter.format(distance),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                            onTap: () => _selectDestination(stage),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return FilterChip(
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          _destController.text = label;
          _searchDestination(label);
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: AppConstants.nairobiGreen.withValues(alpha: 0.2),
      labelStyle: const TextStyle(fontSize: 13),
    );
  }

  @override
  void dispose() {
    _destController.dispose();
    super.dispose();
  }
}