import 'package:navi_app/models/fare_estimate.dart';

class FareMatrix {
  static const Map<FareTier, Map<TimeOfDay, List<int>>> _baseFareRanges = {
    FareTier.short: {
      TimeOfDay.offPeak: [20, 30],
      TimeOfDay.peak: [30, 50],
    },
    FareTier.medium: {
      TimeOfDay.offPeak: [50, 80],
      TimeOfDay.peak: [80, 100],
    },
    FareTier.long: {
      TimeOfDay.offPeak: [100, 100],
      TimeOfDay.peak: [150, 150],
    },
  };

  static const List<int> _standardDenominations = [20, 30, 50, 80, 100, 150];

  static List<int> getStandardDenominations() => List.unmodifiable(_standardDenominations);

  static List<int> getFareRange(FareTier tier, TimeOfDay timeOfDay) {
    return _baseFareRanges[tier]?[timeOfDay] ?? [20, 30];
  }

  static int roundToStandardDenomination(int amount) {
    for (final denom in _standardDenominations) {
      if (amount <= denom) return denom;
    }
    return _standardDenominations.last;
  }

  static TimeOfDay getTimeOfDay(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final totalMinutes = hour * 60 + minute;

    const peakMorningStart = 6 * 60 + 30;
    const peakMorningEnd = 9 * 60 + 30;
    const peakEveningStart = 16 * 60 + 30;
    const peakEveningEnd = 20 * 60;

    final isPeakMorning = totalMinutes >= peakMorningStart && totalMinutes <= peakMorningEnd;
    final isPeakEvening = totalMinutes >= peakEveningStart && totalMinutes <= peakEveningEnd;

    return (isPeakMorning || isPeakEvening) ? TimeOfDay.peak : TimeOfDay.offPeak;
  }
}