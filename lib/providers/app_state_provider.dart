
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:navi_app/models/transport_models.dart';
import '../utils/constants.dart';

class AppStateProvider extends ChangeNotifier {
  // Selected items
  StageModel? _selectedStage;
  RouteModel? _selectedRoute;
  
  // Theme preference
  bool _isDarkTheme = false;
  
  // App statistics
  int _reportsSubmitted = 0;
  String _currentCorridor = 'All';
  
  // User preferences
  bool _notificationsEnabled = true;
  bool _locationSharingEnabled = true;
  
  // Getters
  StageModel? get selectedStage => _selectedStage;
  RouteModel? get selectedRoute => _selectedRoute;
  bool get isDarkTheme => _isDarkTheme;
  int get reportsSubmitted => _reportsSubmitted;
  String get currentCorridor => _currentCorridor;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get locationSharingEnabled => _locationSharingEnabled;

  // Theme data getter
  ThemeData get themeData {
    return _isDarkTheme ? _darkTheme : _lightTheme;
  }

  // Light theme (Nairobi Day)
  ThemeData get _lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppConstants.nairobiGreen,
      colorScheme: const ColorScheme.light(
        primary: AppConstants.nairobiGreen,
        secondary: AppConstants.nairobiGreen,
        surface: Colors.white,
        background: Color(0xFFF5F5F5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.nairobiGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      // Fixed: Removed 'const' from cardTheme because BorderRadius.circular() is not const
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // This can't be const
        ),
      ),
    );
  }

  // Dark theme (Nairobi Night)
  ThemeData get _darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppConstants.nairobiGreen,
      colorScheme: const ColorScheme.dark(
        primary: AppConstants.nairobiGreen,
        secondary: AppConstants.nairobiGreen,
        surface: Color(0xFF1E1E1E),
        background: Color(0xFF121212),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.nairobiGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      // Fixed: Removed 'const' from cardTheme
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // This can't be const
        ),
        color: const Color(0xFF1E1E1E),
      ),
    );
  }

  // Stage selection methods
  void selectStage(StageModel stage) {
    if (_selectedStage?.id != stage.id) {
      _selectedStage = stage;
      // Clear selected route when stage changes
      _selectedRoute = null;
      notifyListeners();
    }
  }

  void clearSelectedStage() {
    _selectedStage = null;
    _selectedRoute = null;
    notifyListeners();
  }

  // Route selection methods
  void selectRoute(RouteModel route) {
    if (_selectedRoute?.id != route.id) {
      _selectedRoute = route;
      notifyListeners();
    }
  }

  void clearSelectedRoute() {
    _selectedRoute = null;
    notifyListeners();
  }

  // Theme toggle
  void toggleTheme() {
    _isDarkTheme = !_isDarkTheme;
    notifyListeners();
  }

  void setTheme(bool isDark) {
    if (_isDarkTheme != isDark) {
      _isDarkTheme = isDark;
      notifyListeners();
    }
  }

  // Reports counter
  void incrementReportsSubmitted() {
    _reportsSubmitted++;
    notifyListeners();
  }

  void resetReportsCounter() {
    _reportsSubmitted = 0;
    notifyListeners();
  }

  // Corridor filter
  void setCurrentCorridor(String corridor) {
    if (_currentCorridor != corridor) {
      _currentCorridor = corridor;
      notifyListeners();
    }
  }

  void resetCorridor() {
    _currentCorridor = 'All';
    notifyListeners();
  }

  // Notification preferences
  void toggleNotifications() {
    _notificationsEnabled = !_notificationsEnabled;
    notifyListeners();
  }

  void setNotificationsEnabled(bool enabled) {
    if (_notificationsEnabled != enabled) {
      _notificationsEnabled = enabled;
      notifyListeners();
    }
  }

  // Location sharing preferences
  void toggleLocationSharing() {
    _locationSharingEnabled = !_locationSharingEnabled;
    notifyListeners();
  }

  void setLocationSharingEnabled(bool enabled) {
    if (_locationSharingEnabled != enabled) {
      _locationSharingEnabled = enabled;
      notifyListeners();
    }
  }

  // Combined selection (useful when navigating from search)
  void selectStageAndRoute(StageModel stage, RouteModel route) {
    _selectedStage = stage;
    _selectedRoute = route;
    notifyListeners();
  }

  // Reset all state (useful for logout)
  void resetAll() {
    _selectedStage = null;
    _selectedRoute = null;
    _reportsSubmitted = 0;
    _currentCorridor = 'All';
    // Don't reset theme preference as it's user-specific
    notifyListeners();
  }

  // Get current context info for analytics
  Map<String, dynamic> getCurrentContext() {
    return {
      'selected_stage_id': _selectedStage?.id,
      'selected_stage_name': _selectedStage?.name,
      'selected_route_id': _selectedRoute?.id,
      'selected_route_number': _selectedRoute?.number,
      'current_corridor': _currentCorridor,
      'theme_mode': _isDarkTheme ? 'dark' : 'light',
      'reports_submitted': _reportsSubmitted,
    };
  }

  // Check if a specific route is available at current stage
  bool isRouteAvailableAtCurrentStage(String routeNumber) {
    if (_selectedStage == null || _selectedStage!.routes == null) {
      return false;
    }
    return _selectedStage!.routes!.contains(routeNumber);
  }

  // Get all available routes at current stage
  List<String> getAvailableRoutesAtCurrentStage() {
    if (_selectedStage == null || _selectedStage!.routes == null) {
      return [];
    }
    return _selectedStage!.routes!;
  }
}

// Extension for easy provider access
extension AppStateContext on BuildContext {
  AppStateProvider get appState => Provider.of<AppStateProvider>(this, listen: false);
  AppStateProvider watchAppState() => Provider.of<AppStateProvider>(this, listen: true);
}