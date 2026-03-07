import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

// Fix imports - use navi_app
import 'package:navi_app/models/stage_model.dart';
import 'package:navi_app/models/route_model.dart';
import 'package:navi_app/services/prediction_service.dart';
import 'package:navi_app/services/database_service.dart';
import 'package:navi_app/services/navigation_service.dart';
import 'package:navi_app/providers/app_state_provider.dart';
import 'package:navi_app/utils/constants.dart';
import 'package:navi_app/screens/submit_wait_screen.dart';

class StageDetailsSheet extends StatefulWidget {
  final StageModel stage;
  final VoidCallback? onNavigate; // Callback for navigation

  const StageDetailsSheet({
    super.key, 
    required this.stage,
    this.onNavigate, // Add this
  });

  @override
  State<StageDetailsSheet> createState() => _StageDetailsSheetState();
}

class _StageDetailsSheetState extends State<StageDetailsSheet> {
  final DatabaseService _databaseService = DatabaseService();
  final PredictionService _predictionService = PredictionService();
  final NavigationService _navigationService = NavigationService();
  
  List<RouteModel> _routes = [];
  RouteModel? _selectedRoute;
  bool _isLoadingRoutes = true;
  bool _isLoadingPrediction = false;
  Map<String, dynamic>? _predictionResult;
  String? _errorMessage;
  
  // Distance from user if available
  double? _distanceFromUser;
  int? _walkingTime;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _calculateDistance();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _isLoadingRoutes = true;
      _errorMessage = null;
    });

    try {
      final routes = await _databaseService.getRoutesByStage(widget.stage.id);
      
      setState(() {
        _routes = routes;
        _isLoadingRoutes = false;
        
        // Select first route by default if available
        if (_routes.isNotEmpty) {
          _selectedRoute = _routes.first;
          _loadPrediction(_routes.first);
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingRoutes = false;
        _errorMessage = 'Failed to load routes: $e';
      });
    }
  }

  Future<void> _loadPrediction(RouteModel route) async {
    setState(() {
      _isLoadingPrediction = true;
      _predictionResult = null;
    });

    try {
      final prediction = await _predictionService.getPredictedWait(
        stageId: widget.stage.id,
        routeId: route.id,
      );
      
      setState(() {
        _predictionResult = prediction;
        _isLoadingPrediction = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPrediction = false;
        _errorMessage = 'Failed to load prediction: $e';
      });
    }
  }

  // Calculate distance from user to this stage
  Future<void> _calculateDistance() async {
    // In a real app, you'd get user location from provider or geolocator
    // For now, we'll use a sample location (CBD)
    try {
      // This would come from your location service
      // For demo, using CBD coordinates
      LatLng userLocation = const LatLng(-1.2833, 36.8167);
      LatLng stageLocation = LatLng(widget.stage.lat, widget.stage.lng);
      
      double distance = _navigationService.calculateDistance(userLocation, stageLocation);
      int time = _navigationService.estimateWalkingTime(distance);
      
      setState(() {
        _distanceFromUser = distance;
        _walkingTime = time;
      });
    } catch (e) {
      print('Error calculating distance: $e');
    }
  }

  void _navigateToSubmit() {
    Navigator.pop(context); // Close bottom sheet
    Navigator.pushNamed(
      context,
      '/submit',
      arguments: widget.stage,
    );
  }

  void _selectRoute(RouteModel route) {
    setState(() {
      _selectedRoute = route;
    });
    _loadPrediction(route);
    
    // Update selected route in provider
    Provider.of<AppStateProvider>(context, listen: false).selectRoute(route);
  }

  void _handleNavigate() {
    Navigator.pop(context); // Close bottom sheet
    if (widget.onNavigate != null) {
      widget.onNavigate!(); // Call the navigation callback
    } else {
      // Default behavior if no callback provided
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Navigation feature coming soon!'),
        ),
      );
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.nairobiGreen,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.stage.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.stage.corridor,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_distanceFromUser != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_walk, size: 16, color: Colors.white.withOpacity(0.9)),
                  const SizedBox(width: 4),
                  Text(
                    '${_navigationService.formatDistance(_distanceFromUser!)} · ${_navigationService.formatTime(_walkingTime!)} walk',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteChips() {
    if (_isLoadingRoutes) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_routes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('No routes available for this stage'),
        ),
      );
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _routes.length,
        itemBuilder: (context, index) {
          final route = _routes[index];
          final isSelected = _selectedRoute?.id == route.id;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                route.number,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => _selectRoute(route),
              backgroundColor: Colors.grey[100],
              selectedColor: AppConstants.nairobiGreen,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPredictionCard() {
    if (_isLoadingPrediction) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_predictionResult == null) {
      return const SizedBox.shrink();
    }

    final data = _predictionResult!['data'] as Map<String, double>;
    final source = _predictionResult!['source'] as String;
    final confidence = _predictionResult!['confidence'] as String;
    final reportCount = _predictionResult!['reportCount'] as int;
    final recommendation = _predictionResult!['recommendation'] as String;

    // Determine confidence color
    Color confidenceColor;
    switch (confidence) {
      case 'High':
        confidenceColor = Colors.green;
        break;
      case 'Medium':
        confidenceColor = Colors.orange;
        break;
      case 'Low':
      case 'Very Low':
        confidenceColor = Colors.red;
        break;
      default:
        confidenceColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Expected Wait Time',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: confidenceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: confidenceColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$confidence Confidence',
                      style: TextStyle(
                        fontSize: 12,
                        color: confidenceColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${data['mean']?.toStringAsFixed(0) ?? '?'}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.nairobiGreen,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'min',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      '80% CI',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${data['lower']?.toStringAsFixed(0)}-${data['upper']?.toStringAsFixed(0)} min',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: AppConstants.nairobiGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendation,
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Source: $source',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '$reportCount reports',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Navigate button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _handleNavigate, // Use the new handler
              icon: const Icon(Icons.directions),
              label: const Text('Navigate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.nairobiGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Report Wait button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _navigateToSubmit,
              icon: const Icon(Icons.timer),
              label: const Text('Report Wait'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.nairobiGreen,
                side: const BorderSide(color: AppConstants.nairobiGreen),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    if (_selectedRoute == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppConstants.nairobiGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedRoute!.number,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.nairobiGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedRoute!.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Sacco info
          Row(
            children: [
              Icon(Icons.business, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _selectedRoute!.sacco,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          
          if (_selectedRoute!.description != null) ...[
            const SizedBox(height: 8),
            Text(
              _selectedRoute!.description!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Major stops
          const Text(
            'Major Stops:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _selectedRoute!.majorStops.map((stop) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  stop,
                  style: const TextStyle(fontSize: 11),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 16),
                    _buildRouteChips(),
                    
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    _buildPredictionCard(),
                    _buildRouteInfo(),
                    _buildActionButtons(),
                    
                    // Extra padding at bottom
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}