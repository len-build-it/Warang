import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android platform backup and device transfer are disabled', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final rules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(rules, contains('<cloud-backup>'));
    expect(rules, contains('<device-transfer>'));
    for (final domain in ['file', 'database', 'sharedpref', 'external']) {
      expect(
        RegExp('domain="$domain" path="\\."').allMatches(rules),
        hasLength(2),
      );
    }
  });

  test('Android cleartext traffic is disabled', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final networkSecurity = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsStringSync();
    final map = File('lib/features/map/warang_map.dart').readAsStringSync();

    expect(
      manifest,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
    expect(networkSecurity, contains('cleartextTrafficPermitted="false"'));
    expect(map, contains('https://tile.openstreetmap.org/'));
    expect(map, isNot(contains('http://tile.openstreetmap.org/')));
  });
}
