import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('capture button is amber clay in a surface ring '
        '(${brightness.name})', (tester) async {
      var taps = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildWarangTheme(brightness),
          home: Scaffold(
            body: Center(child: WarangCaptureButton(onPressed: () => taps++)),
          ),
        ),
      );

      final surfaces = tester
          .widgetList<ClaySurface>(find.byType(ClaySurface))
          .toList();
      // The outer ring is surface clay at clay3; the disc is amber clay.
      expect(surfaces.first.depth, ClayDepth.clay3);
      expect(surfaces.first.circle, isTrue);
      expect(surfaces.first.padding, const EdgeInsets.all(4));
      expect(surfaces.last.tone, WarangKeepsake.amber);
      expect(surfaces.last.circle, isTrue);
      expect(
        tester.getSize(find.byType(WarangCaptureButton)),
        const Size(84, 84),
      );
      expect(find.bySemanticsLabel('Capture a moment'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Capture a moment'));
      expect(taps, 1);
      await tester.pumpAndSettle();
      handle.dispose();
    });
  }
}
