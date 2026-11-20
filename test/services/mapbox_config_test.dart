import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/services/mapbox_config.dart';

void main() {
  test('missing-token warning has the required exact text', () {
    expect(
      MapboxConfig.missingTokenMessage,
      'MAPBOX_TOKEN missing: set it with --dart-define',
    );
  });

  test('startup check logs the exact message only when token is missing',
      () async {
    final printed = <String>[];

    await runZoned(
      () async {
        MapboxConfig.logMissingTokenIfNeeded();
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          printed.add(line);
        },
      ),
    );

    if (MapboxConfig.isConfigured) {
      expect(printed, isEmpty);
    } else {
      expect(printed, <String>[
        'MAPBOX_TOKEN missing: set it with --dart-define',
      ]);
    }
  });
}
