import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/services/mapbox_config.dart';
import 'package:navi_app/widgets/mapbox_token_debug_banner.dart';

void main() {
  testWidgets('debug warning is non-blocking and only shown without a token',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MapboxTokenDebugBanner(
        child: SizedBox.expand(
          child: Center(
            child: TextButton(
              onPressed: () => taps++,
              child: const Text('Underlay'),
            ),
          ),
        ),
      ),
    );

    final warning = find.text(MapboxConfig.missingTokenMessage);
    if (MapboxConfig.isConfigured) {
      expect(warning, findsNothing);
    } else {
      expect(warning, findsOneWidget);
    }

    await tester.tap(find.text('Underlay'));
    expect(taps, 1);
  });
}
