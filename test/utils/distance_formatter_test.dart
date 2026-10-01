import 'package:test/test.dart';
import 'package:navi_app/models/app_settings.dart';
import 'package:navi_app/utils/distance_formatter.dart';

void main() {
  group('DistanceFormatter', () {
    test('formats metric meters under 1000 m', () {
      expect(DistanceFormatter.format(850, unit: DistanceUnit.km), '850 m');
    });

    test('formats metric meters over 1000 m as km', () {
      expect(DistanceFormatter.format(1500, unit: DistanceUnit.km), '1.5 km');
    });

    test('uses currentUnit when no unit provided', () {
      DistanceFormatter.currentUnit = DistanceUnit.km;
      expect(DistanceFormatter.format(2500), '2.5 km');
    });

    test('formats imperial miles over 0.1 mi', () {
      expect(DistanceFormatter.format(1609.344, unit: DistanceUnit.mi),
          '1.0 mi');
    });

    test('formats imperial sub-0.1 mi as feet', () {
      expect(DistanceFormatter.format(50, unit: DistanceUnit.mi), '164 ft');
    });

    test('switches to miles when currentUnit changes', () {
      DistanceFormatter.currentUnit = DistanceUnit.mi;
      expect(DistanceFormatter.format(2000), '1.2 mi');
      DistanceFormatter.currentUnit = DistanceUnit.km;
    });
  });
}