import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/components.dart';
import '../../core/models.dart';

/// The maya's poses (M3, M4). None is sad, lonely, or waiting (M5, REQ-019).
enum MayaPose {
  idle,
  hop,
  dizzy,
  puffed,
  sleepy,
  packedBag,
  postcard,
  binoculars,
  footTap,
  cheer,
  sitting,
}

/// The places the maya may appear (M2). The map, capture, and the moment
/// card are deliberately absent.
enum MayaPlace {
  firstRun,
  shelf,
  emptyShelf,
  search,
  trip,
  news,
  milestone,
  settings,
  about,
}

/// The maya's pose from what is already on the phone (M4); [fallback] when
/// nothing applies.
MayaPose contextPose({
  required DateTime now,
  required Iterable<Trip> trips,
  required Iterable<Moment> moments,
  MayaPose fallback = MayaPose.idle,
}) {
  if (now.hour >= 23 || now.hour < 5) return MayaPose.sleepy;
  final today = DateTime(now.year, now.month, now.day);
  DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);
  for (final trip in trips) {
    final start = trip.startDate;
    if (!trip.isEveryday && start != null && day(start) == today) {
      return MayaPose.packedBag;
    }
  }
  for (final trip in trips) {
    final end = trip.endDate;
    if (!trip.isEveryday &&
        end != null &&
        day(end).isBefore(today) &&
        moments.any((moment) => moment.tripId == trip.id)) {
      return MayaPose.postcard;
    }
  }
  return fallback;
}

/// The bundled lines, by place, from `assets/data/maya_lines.json`.
abstract final class MayaLines {
  static Future<Map<String, List<String>>>? _lines;

  static Future<Map<String, List<String>>> load(AssetBundle bundle) =>
      _lines ??= bundle
          .loadString('assets/data/maya_lines.json')
          .then((raw) {
            final decoded = jsonDecode(raw);
            if (decoded is! Map<String, Object?>) {
              return const <String, List<String>>{};
            }
            return <String, List<String>>{
              for (final entry in decoded.entries)
                if (entry.value case final List<Object?> items)
                  entry.key: [
                    for (final item in items)
                      if (item is String) item,
                  ],
            };
          })
          .catchError((Object error, StackTrace stackTrace) {
            _lines = null;
            Error.throwWithStackTrace(error, stackTrace);
          });

  @visibleForTesting
  static void reset() => _lines = null;
}

/// The maya, a companion that reacts to touch (C14, M3):
///
/// - a tap makes it hop and say a short line for its place;
/// - three taps within two seconds make it dizzy;
/// - a long press puffs its feathers until release;
/// - a drag moves it up to 24 with resistance, then it springs back.
///
/// A reaction repeated more than five times in a minute plays calmer. Under
/// reduced motion every reaction is only a pose change. Every action in the
/// app works without touching it (M5).
class MayaCompanion extends StatefulWidget {
  const MayaCompanion({
    super.key,
    required this.size,
    required this.place,
    this.pose = MayaPose.idle,
    this.float = false,
    this.lookToward = false,
  });

  final double size;
  final MayaPlace place;

  /// The resting pose, before any reaction.
  final MayaPose pose;

  /// A 2 px idle float, for the one idle loop a screen may have (V6).
  final bool float;

  /// Turns the head toward the name field on first run (S1).
  final bool lookToward;

  @override
  State<MayaCompanion> createState() => MayaCompanionState();
}

class MayaCompanionState extends State<MayaCompanion>
    with TickerProviderStateMixin {
  /// The clock that taps and repeats are timed by; tests replace it.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  late final AnimationController _react = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _drag = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  MayaPose? _reaction;
  final _taps = <DateTime>[];
  final _recent = <(MayaPose, DateTime)>[];
  bool _calm = false;
  Offset _offset = Offset.zero;
  String? _line;
  int _lineCount = 0;
  String? _lastLine;
  Timer? _settle;

  /// The pose on show: a reaction while it plays, else the resting pose.
  MayaPose get pose => _reaction ?? widget.pose;

  bool get _reduced => WarangMotion.reduced(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.float && !_reduced) {
      if (!_float.isAnimating) _float.repeat(reverse: true);
    } else {
      _float.stop();
    }
  }

  @override
  void dispose() {
    _settle?.cancel();
    _react.dispose();
    _drag.dispose();
    _float.dispose();
    super.dispose();
  }

  /// Plays [reaction] for a moment, then returns to the resting pose.
  void _play(MayaPose reaction, {Duration hold = Duration.zero}) {
    final now = clock();
    _recent
      ..removeWhere((entry) => now.difference(entry.$2).inSeconds >= 60)
      ..add((reaction, now));
    _calm = _recent.where((entry) => entry.$1 == reaction).length > 5;
    setState(() => _reaction = reaction);
    _settle?.cancel();
    if (_reduced) {
      _react.value = 1;
    } else {
      _react.forward(from: 0);
    }
    _settle = Timer(_react.duration! + hold, () {
      if (mounted && _reaction == reaction) setState(() => _reaction = null);
    });
  }

  Future<void> _onTap() async {
    WarangHaptic.light.play();
    final now = clock();
    _taps
      ..removeWhere((tap) => now.difference(tap).inMilliseconds > 2000)
      ..add(now);
    if (_taps.length >= 3) {
      _taps.clear();
      _play(MayaPose.dizzy, hold: const Duration(milliseconds: 400));
      return;
    }
    _play(MayaPose.hop);
    if (_calm) return;
    final lines = (await MayaLines.load(
      DefaultAssetBundle.of(context),
    ))[widget.place.name];
    if (!mounted || lines == null || lines.isEmpty) return;
    // Never the same line twice in a row.
    final choices = lines.where((line) => line != _lastLine).toList();
    final line =
        (choices.isEmpty ? lines : choices)[math.Random().nextInt(
          choices.isEmpty ? lines.length : choices.length,
        )];
    setState(() {
      _line = line;
      _lastLine = line;
      _lineCount++;
    });
  }

  void _onLongPressStart(LongPressStartDetails _) {
    WarangHaptic.selection.play();
    _settle?.cancel();
    setState(() => _reaction = MayaPose.puffed);
    _react.value = 1;
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    if (_reduced) {
      setState(() => _reaction = null);
      return;
    }
    _react.reverse(from: 1).whenComplete(() {
      if (mounted && _reaction == MayaPose.puffed) {
        setState(() => _reaction = null);
      }
    });
  }

  bool _dragging = false;

  void _onDragStart(DragStartDetails _) {
    _dragging = true;
    _drag.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragging = true;
    if (_drag.isAnimating) _drag.stop();
    // Resistance: the maya follows at half speed and no further than 24.
    final next = _offset + details.delta * .5;
    final length = next.distance;
    setState(() => _offset = length > 24 ? next * (24 / length) : next);
  }

  void _onDragEnd(DragEndDetails _) {
    _dragging = false;
    final from = _offset;
    if (_reduced) {
      setState(() => _offset = Offset.zero);
      return;
    }
    _drag.value = 1;
    void back() => setState(() => _offset = from * _drag.value);
    _drag.addListener(back);
    _drag.animateWith(WarangMotion.release.simulate(1, 0)).whenCompleteOrCancel(
      () {
        _drag.removeListener(back);
        if (mounted && !_dragging) setState(() => _offset = Offset.zero);
      },
    );
  }

  /// Clears line [count] once its bubble fades, but never a newer line
  /// that arrived while it was fading.
  VoidCallback _hideLine(int count) => () {
    if (mounted && _lineCount == count) setState(() => _line = null);
  };

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final reduced = _reduced;
    Widget figure = MayaFigure(pose: pose, size: size);
    if (!reduced) {
      figure = AnimatedBuilder(
        animation: Listenable.merge([_react, _float]),
        child: figure,
        builder: (context, child) {
          final t = _react.value;
          final amplitude = _calm ? .4 : 1.0;
          var dy = -2 * math.sin(_float.value * math.pi);
          var angle = widget.lookToward ? -.08 : 0.0;
          var scale = 1.0;
          switch (_reaction) {
            case MayaPose.hop:
            case MayaPose.cheer:
              dy -= size * .12 * amplitude * math.sin(t * math.pi);
            case MayaPose.dizzy:
              angle += .18 * amplitude * math.sin(t * math.pi * 6) * (1 - t);
            case MayaPose.puffed:
              scale = 1 + .1 * t;
            default:
              break;
          }
          return Transform.translate(
            offset: _offset + Offset(0, dy),
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(scale: scale, child: child),
            ),
          );
        },
      );
    } else if (_offset != Offset.zero) {
      figure = Transform.translate(offset: _offset, child: figure);
    }
    return Semantics(
      label: 'Maya, the Warang mascot',
      image: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        onPanStart: _onDragStart,
        onPanUpdate: _onDragUpdate,
        onPanEnd: _onDragEnd,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              RepaintBoundary(child: figure),
              if (_line != null)
                Positioned(
                  bottom: size + 4,
                  child: SizedBox(
                    width: math.max(size * 1.8, 180),
                    child: Center(
                      child: WarangSpeechBubble(
                        key: ValueKey(_lineCount),
                        text: _line!,
                        onHidden: _hideLine(_lineCount),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The maya drawn in one pose. Until the layered artwork arrives (D-2),
/// it is the whole maya as one image, and a pose's prop is a small clay
/// badge with a glyph.
class MayaFigure extends StatelessWidget {
  const MayaFigure({super.key, required this.pose, required this.size});

  final MayaPose pose;
  final double size;

  static WarangGlyph? propFor(MayaPose pose) => switch (pose) {
    MayaPose.packedBag => WarangGlyphs.trips,
    MayaPose.postcard => WarangGlyphs.news,
    MayaPose.binoculars => WarangGlyphs.explore,
    MayaPose.sleepy => WarangGlyphs.theme,
    MayaPose.cheer => WarangGlyphs.check,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final prop = propFor(pose);
    final badge = size * .34;
    // Sitting and sleepy sit a little lower, eyes half-closed in spirit.
    final settled = pose == MayaPose.sitting || pose == MayaPose.sleepy;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: settled ? size * .06 : 0,
            child: Image.asset(
              'assets/maya/body.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          // A prop below about 56 is too small to read, so it is left off.
          if (prop != null && size >= 56)
            Positioned(
              right: -badge * .1,
              bottom: 0,
              child: ClaySurface(
                depth: ClayDepth.clay1,
                tone: pose == MayaPose.cheer ? WarangKeepsake.amber : null,
                circle: true,
                child: SizedBox.square(
                  dimension: badge,
                  child: Center(child: WarangIcon(prop, size: badge * .58)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
