import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/stamps.dart';

/// Loads and caches the bundled stamp titles from `assets/data/stamps.json`.
abstract final class StampTitles {
  static const assetPath = 'assets/data/stamps.json';

  static Map<String, List<String>>? _cached;
  static Future<Map<String, List<String>>>? _loading;

  static Map<String, List<String>>? get cached => _cached;

  static Future<Map<String, List<String>>> load({AssetBundle? bundle}) {
    if (_cached != null && bundle == null) {
      return Future<Map<String, List<String>>>.value(_cached!);
    }
    if (bundle != null) {
      return bundle.loadString(assetPath).then(parseStampTitles);
    }
    return _loading ??= rootBundle.loadString(assetPath).then((raw) {
      final parsed = parseStampTitles(raw);
      _cached = parsed;
      return parsed;
    });
  }

  @visibleForTesting
  static void reset() {
    _cached = null;
    _loading = null;
  }
}
