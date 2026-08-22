import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';

void main() {
  testWidgets('capture button is a single-shadow amber disc', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildWarangTheme(Brightness.light),
        home: Scaffold(
          body: WarangCaptureButton(onPressed: () => taps++),
        ),
      ),
    );

    final decorations = tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    );
    final disc = decorations
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.color == WarangColors.accent);
    expect(disc.color, WarangColors.accent);
    expect(disc.shape, BoxShape.circle);
    expect(disc.boxShadow, hasLength(1));
    expect(disc.boxShadow!.single.spreadRadius, 0);
    expect(find.bySemanticsLabel('Capture'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Capture'));
    expect(taps, 1);
  });

  testWidgets('capture button keeps the same flat shape in dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildWarangTheme(Brightness.dark),
        home: const Scaffold(body: WarangCaptureButton(onPressed: _noop)),
      ),
    );

    final disc = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.color == WarangColors.accent);
    expect(disc.boxShadow, hasLength(1));
    expect(disc.boxShadow!.single.spreadRadius, 0);
  });
}

void _noop() {}
