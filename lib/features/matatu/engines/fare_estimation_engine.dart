class FareEstimationEngine {
  static const double baseFare = 50.0;
  static const double ratePerKm = 10.0;
  static const double peakMultiplier = 1.2;
  static const double nightMultiplier = 1.3;

  double estimateFare(double distanceKm, {
    bool isPeakHour = false,
    bool isNight = false,
  }) {
    double fare = baseFare + (distanceKm * ratePerKm);

    if (isPeakHour) {
      fare *= peakMultiplier;
    }
    if (isNight) {
      fare *= nightMultiplier;
    }

    return fare;
  }

  double estimateFareForRoute({
    required double distanceKm,
    required String corridor,
    required String sacco,
  }) {
    double fare = estimateFare(distanceKm);

    final Map<String, double> corridorAdjustments = {
      'Thika Road': 1.0,
      'Mombasa Road': 1.0,
      'Ngong Road': 0.9,
      'Jogoo Road': 0.85,
      'Waiyaki Way': 1.0,
      'CBD': 0.8,
      'Ngong/Langata Rd': 1.1,
    };

    final Map<String, double> saccoAdjustments = {
      'Super Metro': 1.1,
      'Double M': 1.0,
      'Citi Hoppa': 1.0,
      'KBS': 0.9,
      'East Shuttle': 0.85,
      'Embassava': 0.85,
    };

    fare *= (corridorAdjustments[corridor] ?? 1.0);
    fare *= (saccoAdjustments[sacco] ?? 1.0);

    return fare;
  }

  bool get isPeakHour {
    final hour = DateTime.now().hour;
    return (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19);
  }

  bool get isNight {
    final hour = DateTime.now().hour;
    return hour >= 22 || hour <= 5;
  }
}
