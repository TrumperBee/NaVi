import 'dart:math';
import 'package:flutter/foundation.dart';

enum MovementState { stationary, walking, running, inVehicle, unknown }

class BoardingDetectionResult {
  final MovementState previousState;
  final MovementState currentState;
  final double confidence;
  final double averageSpeed;
  final double maxSpeed;
  final bool didBoard;
  final bool didAlight;

  const BoardingDetectionResult({
    required this.previousState,
    required this.currentState,
    this.confidence = 0.0,
    this.averageSpeed = 0.0,
    this.maxSpeed = 0.0,
    this.didBoard = false,
    this.didAlight = false,
  });
}

class BoardingDetectionEngine extends ChangeNotifier {
  final List<double> _speedHistory = [];
  static const int _historySize = 20;
  static const double _walkingThreshold = 1.67;
  static const double _vehicleThreshold = 3.33;
  static const double _stationaryThreshold = 0.5;

  MovementState _currentState = MovementState.unknown;
  MovementState _previousState = MovementState.unknown;
  double _confidence = 0.0;
  int _vehicleCount = 0;
  int _walkCount = 0;
  bool _hasBoarded = false;
  int _rideTicks = 0;
  int _alightWalkTicks = 0;

  MovementState get currentState => _currentState;
  MovementState get previousState => _previousState;
  double get confidence => _confidence;
  double get averageSpeed {
    if (_speedHistory.isEmpty) return 0;
    return _speedHistory.fold(0.0, (s, v) => s + v) / _speedHistory.length;
  }
  double get maxSpeed => _speedHistory.isEmpty ? 0 : _speedHistory.reduce(max);
  bool get hasBoarded => _hasBoarded;

  BoardingDetectionResult analyze(double speed) {
    _previousState = _currentState;
    _speedHistory.add(speed);
    if (_speedHistory.length > _historySize) {
      _speedHistory.removeAt(0);
    }

    final avg = averageSpeed;
    final maxSp = maxSpeed;

    final newState = _classifyMovement(avg);
    _currentState = newState;

    _vehicleCount = _currentState == MovementState.inVehicle
        ? _vehicleCount + 1
        : max(0, _vehicleCount - 1);
    _walkCount = _currentState == MovementState.walking
        ? _walkCount + 1
        : max(0, _walkCount - 1);

    _confidence = _calculateConfidence();

    final didBoard = _detectBoarding();
    final didAlight = _detectAlighting();

    notifyListeners();

    return BoardingDetectionResult(
      previousState: _previousState,
      currentState: _currentState,
      confidence: _confidence,
      averageSpeed: avg,
      maxSpeed: maxSp,
      didBoard: didBoard,
      didAlight: didAlight,
    );
  }

  MovementState _classifyMovement(double avgSpeed) {
    if (avgSpeed < _stationaryThreshold) return MovementState.stationary;
    if (avgSpeed < _walkingThreshold) return MovementState.walking;
    if (avgSpeed < _vehicleThreshold) return MovementState.running;
    return MovementState.inVehicle;
  }

  bool _detectBoarding() {
    if (_hasBoarded) return false;

    _rideTicks = _currentState == MovementState.inVehicle
        ? _rideTicks + 1
        : 0;

    if (_rideTicks >= 3) {
      _hasBoarded = true;
      return true;
    }
    return false;
  }

  bool _detectAlighting() {
    if (!_hasBoarded) return false;

    _alightWalkTicks = _currentState == MovementState.walking
        ? _alightWalkTicks + 1
        : 0;

    if (_alightWalkTicks >= 2) {
      _hasBoarded = false;
      return true;
    }
    return false;
  }

  double _calculateConfidence() {
    if (_speedHistory.length < 5) return 0.0;

    if (_currentState == MovementState.inVehicle) {
      return min(1.0, _vehicleCount / 5.0);
    }
    if (_currentState == MovementState.walking) {
      return min(1.0, _walkCount / 5.0);
    }
    return 0.3;
  }

  void reset() {
    _speedHistory.clear();
    _currentState = MovementState.unknown;
    _previousState = MovementState.unknown;
    _confidence = 0.0;
    _vehicleCount = 0;
    _walkCount = 0;
    _hasBoarded = false;
    _rideTicks = 0;
    _alightWalkTicks = 0;
    notifyListeners();
  }
}
