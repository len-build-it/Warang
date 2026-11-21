import 'package:flutter/painting.dart';

/// FEAT-003 V3 type roles. Colours come from the theme, not from here.
///
/// Bagel Fat One is for single lines of 24 and above, and Shantell Sans is
/// only for words the user wrote or words the maya says.
abstract final class WarangType {
  static const displayFamily = 'Bagel Fat One';
  static const textFamily = 'Atkinson Hyperlegible Next';
  static const handFamily = 'Shantell Sans';

  static const _tabular = [FontFeature.tabularFigures()];

  static const wordmark = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w400,
    fontSize: 56,
    height: 1.0,
    letterSpacing: -0.5,
    fontFeatures: _tabular,
  );
  static const displayL = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w400,
    fontSize: 34,
    height: 1.05,
    letterSpacing: -0.3,
    fontFeatures: _tabular,
  );
  static const displayM = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w400,
    fontSize: 26,
    height: 1.1,
    letterSpacing: -0.2,
    fontFeatures: _tabular,
  );
  static const stampNumber = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w400,
    fontSize: 28,
    height: 1.0,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );
  static const titleS = TextStyle(
    fontFamily: textFamily,
    fontWeight: FontWeight.w700,
    fontSize: 19,
    height: 1.25,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );
  static const bodyL = TextStyle(
    fontFamily: textFamily,
    fontWeight: FontWeight.w400,
    fontSize: 17,
    height: 1.45,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );
  static const body = TextStyle(
    fontFamily: textFamily,
    fontWeight: FontWeight.w400,
    fontSize: 15.5,
    height: 1.45,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );
  static const button = TextStyle(
    fontFamily: textFamily,
    fontWeight: FontWeight.w700,
    fontSize: 16.5,
    height: 1.2,
    letterSpacing: 0.1,
    fontFeatures: _tabular,
  );
  static const meta = TextStyle(
    fontFamily: textFamily,
    fontWeight: FontWeight.w600,
    fontSize: 13.5,
    height: 1.35,
    letterSpacing: 0.1,
    fontFeatures: _tabular,
  );
  static const caption = TextStyle(
    fontFamily: textFamily,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    height: 1.3,
    letterSpacing: 0.2,
    fontFeatures: _tabular,
  );
  static const handL = TextStyle(
    fontFamily: handFamily,
    fontWeight: FontWeight.w500,
    fontSize: 19,
    height: 1.35,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );
  static const hand = TextStyle(
    fontFamily: handFamily,
    fontWeight: FontWeight.w500,
    fontSize: 15,
    height: 1.3,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );
}
