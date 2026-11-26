import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A physical spring from FEAT-003 V6, usable as a simulation or a curve.
@immutable
class WarangSpring {
  const WarangSpring(this.duration, this.bounce);

  final Duration duration;
  final double bounce;

  SpringDescription get description => SpringDescription.withDurationAndBounce(
    duration: duration,
    bounce: bounce,
  );

  /// A simulation from [from] to [to], starting at [velocity].
  SpringSimulation simulate(double from, double to, {double velocity = 0}) =>
      SpringSimulation(description, from, to, velocity);

  /// The spring as a 0 to 1 curve over [duration], for route and sheet
  /// transitions that take a [Curve].
  Curve get curve => _SpringCurve(this, clamp: false);

  /// The spring as a curve that never passes 1, for surfaces such as
  /// bottom sheets whose overshoot would open a gap at the screen edge.
  Curve get settleCurve => _SpringCurve(this, clamp: true);
}

class _SpringCurve extends Curve {
  _SpringCurve(this.spring, {required this.clamp})
    : _seconds = spring.duration.inMicroseconds / 1e6,
      _simulation = spring.simulate(0, 1);

  final WarangSpring spring;
  final bool clamp;
  final double _seconds;
  final SpringSimulation _simulation;

  @override
  double transformInternal(double t) {
    final x = _simulation.x(t * _seconds);
    return clamp ? x.clamp(0.0, 1.0) : x;
  }
}

/// FEAT-003 V6 motion tokens. Under reduced motion every spring becomes
/// [fade], and scale and rotation changes are skipped.
abstract final class WarangMotion {
  static const press = Duration(milliseconds: 90);
  static const pressCurve = Curves.easeOut;
  static const release = WarangSpring(Duration(milliseconds: 300), 0.3);
  static const sheet = WarangSpring(Duration(milliseconds: 380), 0.12);
  static const pop = WarangSpring(Duration(milliseconds: 450), 0.35);
  static const slide = WarangSpring(Duration(milliseconds: 320), 0.15);
  static const count = Duration(milliseconds: 600);
  static const countCurve = Curves.easeOut;
  static const fade = Duration(milliseconds: 150);

  /// True when the platform asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// FEAT-003 V6 haptics, one per kind of event.
enum WarangHaptic {
  none,

  /// Capture pressed, a new pin lands, the maya is tapped.
  light,

  /// A moment saved, a delete confirmed.
  medium,

  /// A dock tab, toggle, chip, or date selected.
  selection;

  Future<void> play() => switch (this) {
    none => Future<void>.value(),
    light => HapticFeedback.lightImpact(),
    medium => HapticFeedback.mediumImpact(),
    selection => HapticFeedback.selectionClick(),
  };
}
