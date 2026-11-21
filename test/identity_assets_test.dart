import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled identity fonts are present in the application bundle',
    () async {
      const fontAssets = [
        'assets/fonts/BagelFatOne-Regular.ttf',
        'assets/fonts/AtkinsonHyperlegibleNext-Regular.ttf',
        'assets/fonts/AtkinsonHyperlegibleNext-SemiBold.ttf',
        'assets/fonts/AtkinsonHyperlegibleNext-Bold.ttf',
        'assets/fonts/ShantellSans-Medium.ttf',
      ];

      for (final asset in fontAssets) {
        final bytes = await rootBundle.load(asset);
        expect(bytes.lengthInBytes, greaterThan(1000), reason: asset);
      }
    },
  );

  test('each bundled font family ships its OFL licence', () async {
    for (final family in [
      'BagelFatOne',
      'AtkinsonHyperlegibleNext',
      'ShantellSans',
    ]) {
      final licence = await rootBundle.loadString(
        'assets/fonts/$family-OFL.txt',
      );
      expect(
        licence,
        contains('SIL Open Font License, Version 1.1'),
        reason: family,
      );
    }
  });
}
