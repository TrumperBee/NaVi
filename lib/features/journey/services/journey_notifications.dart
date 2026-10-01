import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';

class JourneyNotificationService {
  bool _initialized = false;

  Future<void> init() async {
    _initialized = true;
  }

  Future<void> showNotification(JourneyNotification notification) async {
    if (!_initialized) return;
    debugPrint('[JourneyNotification] ${notification.title}: ${notification.body}');
  }

  Future<void> showAlert(String title, String body) async {
    if (!_initialized) return;
    debugPrint('[JourneyAlert] $title: $body');
  }

  Future<void> cancelAll() async {}
}
