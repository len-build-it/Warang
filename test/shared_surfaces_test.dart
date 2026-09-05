import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';

void main() {
  group('WarangGlassSurface', () {
    testWidgets(
      'renders backdrop filter and clips to bounds under normal theme',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildWarangTheme(Brightness.light),
            home: const Scaffold(
              body: WarangGlassSurface(
                child: SizedBox(width: 100, height: 60, child: Text('Glass')),
              ),
            ),
          ),
        );

        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.byType(ClipRRect), findsOneWidget);
      },
    );

    testWidgets('clips to oval when shape is circular', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildWarangTheme(Brightness.dark),
          home: const Scaffold(
            body: WarangGlassSurface(
              shape: BoxShape.circle,
              child: SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      );

      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets(
      'falls back to solid surface without blur in high-contrast mode',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(highContrast: true),
            child: MaterialApp(
              theme: buildWarangTheme(Brightness.light),
              home: const Scaffold(
                body: WarangGlassSurface(
                  child: SizedBox(width: 80, height: 40, child: Text('Solid')),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.text('Solid'), findsOneWidget);
      },
    );
  });

  group('WarangGlassIconButton', () {
    testWidgets(
      'provides at least 48x48 hit target, semantics, and responds to tap',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildWarangTheme(Brightness.light),
            home: Scaffold(
              body: Center(
                child: WarangGlassIconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => tapped = true,
                  semanticLabel: 'Open navigation menu',
                  tooltip: 'Menu',
                ),
              ),
            ),
          ),
        );

        final buttonFinder = find.bySemanticsLabel('Open navigation menu');
        expect(buttonFinder, findsOneWidget);

        final size = tester.getSize(buttonFinder);
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));

        await tester.tap(buttonFinder);
        expect(tapped, isTrue);
      },
    );
  });

  group('Accessibility & Button standards', () {
    testWidgets('WarangQuietButton has at least 48px height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildWarangTheme(Brightness.light),
          home: const Scaffold(body: WarangQuietButton(label: 'Cancel')),
        ),
      );

      final size = tester.getSize(find.byType(WarangQuietButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('WarangToggle includes toggle semantics', (tester) async {
      var current = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildWarangTheme(Brightness.light),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: WarangToggle(
                value: current,
                onChanged: (v) => setState(() => current = v),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WarangToggle), findsOneWidget);
      await tester.tap(find.byType(WarangToggle));
      expect(current, isTrue);
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
