import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled identity fonts are present in the application bundle', () async {
    const fontAssets = [
      'assets/fonts/BricolageGrotesque-Bold.ttf',
      'assets/fonts/BricolageGrotesque-ExtraBold.ttf',
      'assets/fonts/PublicSans-Regular.ttf',
      'assets/fonts/PublicSans-Medium.ttf',
      'assets/fonts/PublicSans-SemiBold.ttf',
      'assets/fonts/DMMono-Regular.ttf',
      'assets/fonts/DMMono-Medium.ttf',
    ];

    for (final asset in fontAssets) {
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(1000), reason: asset);
    }
  });
}
