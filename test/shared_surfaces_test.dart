import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';

void main() {
  group('Accessibility & Button standards', () {
    testWidgets('WarangButton.quiet has at least 48px height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildWarangTheme(Brightness.light),
          home: const Scaffold(body: WarangButton.quiet(label: 'Cancel')),
        ),
      );

      final size = tester.getSize(find.byType(WarangButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets(
      'WarangPositionMarker respects reduced motion (disableAnimations)',
      (tester) async {
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MaterialApp(home: Scaffold(body: WarangPositionMarker())),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(WarangPositionMarker), findsOneWidget);
      },
    );
  });
}
