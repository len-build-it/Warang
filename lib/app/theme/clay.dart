import 'dart:ui' as ui;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'palette.dart';
import 'tokens.dart';

/// FEAT-003 V4 corner radii.
abstract final class WarangRadius {
  static const chip = 14.0;
  static const control = 20.0;
  static const card = 28.0;
  static const sheet = 32.0;
  static const photo = 6.0;

  /// Fully rounded ends; any value at least half the shorter side works.
  static const pill = 999.0;
}

/// FEAT-003 V5 clay depth levels.
enum ClayDepth { clay1, clay2, clay3, pressed, inset, flat }

/// The numbers behind one depth level, for one theme.
@immutable
class ClayDepthSpec {
  const ClayDepthSpec({
    this.shadowY = 0,
    this.shadowBlur = 0,
    this.shadowAlpha = 0,
    this.highlightAlpha = 0,
    this.highlightDepth = 0,
    this.shadeAlpha = 0,
    this.shadeDepth = 0,
    this.rimAlpha = 0,
    this.inset = false,
  });

  final double shadowY;
  final double shadowBlur;
  final double shadowAlpha;
  final double highlightAlpha;
  final double highlightDepth;
  final double shadeAlpha;
  final double shadeDepth;
  final double rimAlpha;

  /// Inset surfaces (fields, toggle tracks) light from the bottom and shade
  /// from the top, the reverse of raised clay.
  final bool inset;

  /// The spec for [depth]. Amber clay keeps its highlight and shade in
  /// dark theme, where a 1 px white rim cannot show on it; its shadow stays
  /// the dark theme's.
  static ClayDepthSpec of(
    ClayDepth depth,
    Brightness brightness, {
    KeepsakeTone? tone,
  }) {
    final light = _light[depth]!;
    if (brightness == Brightness.light) return light;
    final dark = _dark[depth]!;
    if (dark.inset || tone?.key != WarangKeepsake.amber.key) return dark;
    return ClayDepthSpec(
      shadowY: dark.shadowY,
      shadowBlur: dark.shadowBlur,
      shadowAlpha: dark.shadowAlpha,
      highlightAlpha: light.highlightAlpha,
      highlightDepth: light.highlightDepth,
      shadeAlpha: light.shadeAlpha,
      shadeDepth: light.shadeDepth,
    );
  }

  /// Lit by a 1 px rim instead of a highlight and shade.
  bool get rimmed => rimAlpha > 0;

  static const _light = {
    ClayDepth.clay1: ClayDepthSpec(
      shadowY: 4,
      shadowBlur: 10,
      shadowAlpha: .14,
      highlightAlpha: .70,
      highlightDepth: 6,
      shadeAlpha: .10,
      shadeDepth: 8,
    ),
    ClayDepth.clay2: ClayDepthSpec(
      shadowY: 10,
      shadowBlur: 24,
      shadowAlpha: .18,
      highlightAlpha: .80,
      highlightDepth: 8,
      shadeAlpha: .12,
      shadeDepth: 10,
    ),
    ClayDepth.clay3: ClayDepthSpec(
      shadowY: 14,
      shadowBlur: 30,
      shadowAlpha: .24,
      highlightAlpha: .85,
      highlightDepth: 10,
      shadeAlpha: .16,
      shadeDepth: 12,
    ),
    ClayDepth.pressed: ClayDepthSpec(
      shadowY: 2,
      shadowBlur: 4,
      shadowAlpha: .12,
      highlightAlpha: .40,
      highlightDepth: 4,
      shadeAlpha: .20,
      shadeDepth: 12,
    ),
    ClayDepth.inset: ClayDepthSpec(
      highlightAlpha: .60,
      highlightDepth: 4,
      shadeAlpha: .10,
      shadeDepth: 6,
      inset: true,
    ),
    ClayDepth.flat: ClayDepthSpec(),
  };

  static const _dark = {
    ClayDepth.clay1: ClayDepthSpec(
      shadowY: 4,
      shadowBlur: 12,
      shadowAlpha: .40,
      rimAlpha: .06,
    ),
    ClayDepth.clay2: ClayDepthSpec(
      shadowY: 10,
      shadowBlur: 26,
      shadowAlpha: .50,
      rimAlpha: .07,
    ),
    ClayDepth.clay3: ClayDepthSpec(
      shadowY: 14,
      shadowBlur: 32,
      shadowAlpha: .60,
      rimAlpha: .08,
    ),
    ClayDepth.pressed: ClayDepthSpec(
      shadowY: 2,
      shadowBlur: 6,
      shadowAlpha: .40,
      rimAlpha: .04,
    ),
    ClayDepth.inset: ClayDepthSpec(rimAlpha: .30, inset: true),
    ClayDepth.flat: ClayDepthSpec(),
  };

  static ClayDepthSpec lerp(ClayDepthSpec a, ClayDepthSpec b, double t) {
    double mix(double x, double y) => lerpDouble(x, y, t)!;
    return ClayDepthSpec(
      shadowY: mix(a.shadowY, b.shadowY),
      shadowBlur: mix(a.shadowBlur, b.shadowBlur),
      shadowAlpha: mix(a.shadowAlpha, b.shadowAlpha),
      highlightAlpha: mix(a.highlightAlpha, b.highlightAlpha),
      highlightDepth: mix(a.highlightDepth, b.highlightDepth),
      shadeAlpha: mix(a.shadeAlpha, b.shadeAlpha),
      shadeDepth: mix(a.shadeDepth, b.shadeDepth),
      rimAlpha: mix(a.rimAlpha, b.rimAlpha),
      inset: t < .5 ? a.inset : b.inset,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ClayDepthSpec &&
      other.shadowY == shadowY &&
      other.shadowBlur == shadowBlur &&
      other.shadowAlpha == shadowAlpha &&
      other.highlightAlpha == highlightAlpha &&
      other.highlightDepth == highlightDepth &&
      other.shadeAlpha == shadeAlpha &&
      other.shadeDepth == shadeDepth &&
      other.rimAlpha == rimAlpha &&
      other.inset == inset;

  @override
  int get hashCode => Object.hash(
    shadowY,
    shadowBlur,
    shadowAlpha,
    highlightAlpha,
    highlightDepth,
    shadeAlpha,
    shadeDepth,
    rimAlpha,
    inset,
  );
}

/// The one widget that draws clay (FEAT-003 V5): an outer shadow, the fill,
/// a top-left highlight and a bottom-right shade in light theme, or a 1 px
/// top rim in dark theme (amber keeps its highlight and shade).
///
/// Photos and the map are never clay; they may sit inside a clay frame.
class ClaySurface extends StatelessWidget {
  const ClaySurface({
    super.key,
    this.child,
    this.depth = ClayDepth.clay1,
    this.pressedDepth = ClayDepth.pressed,
    this.press = 0,
    this.color,
    this.tone,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(WarangRadius.control),
    ),
    this.circle = false,
    this.outline,
    this.padding,
    this.clipBehavior = Clip.none,
    this.bottomSheet = false,
  });

  final Widget? child;
  final ClayDepth depth;

  /// The depth reached when [press] is 1.
  final ClayDepth pressedDepth;

  /// How far the surface is pressed, from 0 (resting) to 1 (pressed).
  final double press;

  /// The fill; defaults to the theme's `surface`.
  final Color? color;

  /// Coloured clay: its fill and clay tones replace white and `shadowTint`.
  final KeepsakeTone? tone;
  final BorderRadius borderRadius;
  final bool circle;
  final BorderSide? outline;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  /// A sheet resting on the screen's bottom edge: its shadow falls upward
  /// and only its top edge is lit, so no shade lines the screen edges.
  final bool bottomSheet;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final neutrals = WarangNeutrals.of(context);
    final resting = ClayDepthSpec.of(depth, brightness, tone: tone);
    final spec = press <= 0
        ? resting
        : ClayDepthSpec.lerp(
            resting,
            ClayDepthSpec.of(pressedDepth, brightness, tone: tone),
            press.clamp(0.0, 1.0),
          );
    final dark = brightness == Brightness.dark;
    final fill = color ?? tone?.fill ?? neutrals.surface;
    final colours = _ClayColours.resolve(
      spec: spec,
      fill: fill,
      tone: tone,
      dark: dark,
      neutrals: neutrals,
    );
    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    return CustomPaint(
      painter: _ClayPainter(
        spec: spec,
        colours: colours,
        borderRadius: borderRadius,
        circle: circle,
        outline: outline,
        bottomSheet: bottomSheet,
      ),
      child: clipBehavior == Clip.none || content == null
          ? content
          : ClipRRect(
              borderRadius: circle
                  ? BorderRadius.circular(WarangRadius.pill)
                  : borderRadius,
              clipBehavior: clipBehavior,
              child: content,
            ),
    );
  }
}

@immutable
class _ClayColours {
  const _ClayColours({
    required this.fill,
    required this.shadow,
    required this.highlight,
    required this.shade,
    required this.rimIsDark,
  });

  factory _ClayColours.resolve({
    required ClayDepthSpec spec,
    required Color fill,
    required KeepsakeTone? tone,
    required bool dark,
    required WarangNeutrals neutrals,
  }) => _ClayColours(
    fill: fill,
    shadow: tone != null && !dark
        ? tone.clayShadow.withValues(
            alpha: tone.clayShadow.a * spec.shadowAlpha / .18,
          )
        : (dark ? Colors.black : neutrals.shadowTint).withValues(
            alpha: spec.shadowAlpha,
          ),
    highlight: spec.rimmed
        ? Colors.white.withValues(alpha: spec.rimAlpha)
        : spec.inset
        ? Colors.white.withValues(alpha: spec.highlightAlpha)
        : tone != null
        ? tone.clayHighlight.withValues(
            alpha: tone.clayHighlight.a * spec.highlightAlpha / .80,
          )
        : Colors.white.withValues(alpha: spec.highlightAlpha),
    shade: spec.rimmed
        ? Colors.transparent
        : spec.inset
        ? neutrals.shadowTint.withValues(alpha: spec.shadeAlpha)
        : tone != null
        ? tone.clayShade.withValues(
            alpha: tone.clayShade.a * spec.shadeAlpha / .12,
          )
        : neutrals.shadowTint.withValues(alpha: spec.shadeAlpha),
    rimIsDark: spec.rimmed && spec.inset,
  );

  final Color fill;
  final Color shadow;
  final Color highlight;
  final Color shade;
  final bool rimIsDark;

  @override
  bool operator ==(Object other) =>
      other is _ClayColours &&
      other.fill == fill &&
      other.shadow == shadow &&
      other.highlight == highlight &&
      other.shade == shade &&
      other.rimIsDark == rimIsDark;

  @override
  int get hashCode => Object.hash(fill, shadow, highlight, shade, rimIsDark);
}

/// The paths a clay surface needs for one size, shape, and depth.
class _ClayGeometry {
  _ClayGeometry(RRect rrect, ClayDepthSpec spec, bool bottomSheet) {
    this.rrect = rrect;
    final bounds = rrect.outerRect.inflate(64);
    Path ring(Offset offset) => Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds)
      ..addRRect(rrect.shift(offset));
    if (spec.rimmed) {
      // A 1 px rim along the top edge (dark inset: a dark inner top edge).
      highlight = ring(const Offset(0, 1));
      shade = null;
    } else if (bottomSheet) {
      // Only the top band: the other sides run into the screen's edges.
      highlight = Path.combine(
        PathOperation.difference,
        Path()..addRect(
          Rect.fromLTRB(
            bounds.left,
            bounds.top,
            bounds.right,
            rrect.top + rrect.tlRadiusY,
          ),
        ),
        Path()..addRRect(rrect.shift(Offset(0, spec.highlightDepth / 2))),
      );
      shade = null;
    } else if (spec.inset) {
      // Inset: shade falls from the top, light rises from the bottom.
      shade = ring(Offset(0, spec.shadeDepth / 2));
      highlight = ring(Offset(0, -spec.highlightDepth / 2));
    } else {
      highlight = ring(
        Offset(spec.highlightDepth / 2, spec.highlightDepth / 2),
      );
      shade = ring(Offset(-spec.shadeDepth / 2, -spec.shadeDepth / 2));
    }
  }

  late final RRect rrect;
  late final Path highlight;
  late final Path? shade;

  // Map literals keep insertion order, so the first key is the oldest.
  static final _cache = <Object, _ClayGeometry>{};

  /// Geometry is cached per size, shape, and depth, so repeated frames and
  /// repeated surfaces reuse the same paths.
  static _ClayGeometry of(RRect rrect, ClayDepthSpec spec, bool bottomSheet) {
    final key = (rrect, spec, bottomSheet);
    final cached = _cache.remove(key);
    if (cached != null) return _cache[key] = cached;
    final geometry = _ClayGeometry(rrect, spec, bottomSheet);
    _cache[key] = geometry;
    if (_cache.length > 128) _cache.remove(_cache.keys.first);
    return geometry;
  }
}

class _ClayPainter extends CustomPainter {
  _ClayPainter({
    required this.spec,
    required this.colours,
    required this.borderRadius,
    required this.circle,
    required this.outline,
    required this.bottomSheet,
  });

  final ClayDepthSpec spec;
  final _ClayColours colours;
  final BorderRadius borderRadius;
  final bool circle;
  final BorderSide? outline;
  final bool bottomSheet;

  static double _sigma(double blur) => blur > 0 ? blur * 0.57735 + 0.5 : 0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = circle
        ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2))
        : borderRadius.toRRect(rect);
    final geometry = _ClayGeometry.of(rrect, spec, bottomSheet);

    if (spec.shadowBlur > 0 && colours.shadow.a > 0) {
      canvas.drawRRect(
        rrect.shift(Offset(0, bottomSheet ? -spec.shadowY : spec.shadowY)),
        Paint()
          ..color = colours.shadow
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            _sigma(spec.shadowBlur),
          ),
      );
    }
    canvas.drawRRect(rrect, Paint()..color = colours.fill);

    canvas.save();
    canvas.clipRRect(rrect);
    if (spec.rimmed) {
      final rim = colours.rimIsDark
          ? Colors.black.withValues(alpha: spec.rimAlpha)
          : colours.highlight;
      if (rim.a > 0) {
        canvas.drawPath(
          geometry.highlight,
          Paint()
            ..color = rim
            ..maskFilter = colours.rimIsDark
                ? MaskFilter.blur(BlurStyle.normal, _sigma(3))
                : null,
        );
      }
    } else {
      if (colours.highlight.a > 0 && spec.highlightDepth > 0) {
        canvas.drawPath(
          geometry.highlight,
          Paint()
            ..color = colours.highlight
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              _sigma(spec.highlightDepth / 2),
            ),
        );
      }
      final shade = geometry.shade;
      if (shade != null && colours.shade.a > 0 && spec.shadeDepth > 0) {
        canvas.drawPath(
          shade,
          Paint()
            ..color = colours.shade
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              _sigma(spec.shadeDepth / 2),
            ),
        );
      }
    }
    canvas.restore();

    final side = outline;
    if (side != null && side.style != BorderStyle.none && side.width > 0) {
      canvas.drawRRect(
        rrect.deflate(side.width / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = side.width
          ..color = side.color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClayPainter old) =>
      old.spec != spec ||
      old.colours != colours ||
      old.borderRadius != borderRadius ||
      old.circle != circle ||
      old.outline != outline ||
      old.bottomSheet != bottomSheet;
}

/// Clay discs painted once into images, for map pins (Q-1): the map then
/// draws plain images while it pans, never live blurs.
abstract final class ClayDiscCache {
  static final _images = <Object, ui.Image>{};

  /// Room around the disc for its outer shadow.
  static double margin(ClayDepth depth, Brightness brightness) {
    final spec = ClayDepthSpec.of(depth, brightness);
    return (spec.shadowY + spec.shadowBlur * 1.4).ceilToDouble();
  }

  static ui.Image image({
    required double diameter,
    required Color fill,
    required KeepsakeTone? tone,
    required ClayDepth depth,
    required Brightness brightness,
    required WarangNeutrals neutrals,
    required double pixelRatio,
  }) {
    final key = Object.hash(
      diameter,
      fill,
      tone?.key,
      depth,
      brightness,
      neutrals.shadowTint,
      pixelRatio,
    );
    final cached = _images.remove(key);
    if (cached != null) return _images[key] = cached;

    final dark = brightness == Brightness.dark;
    final spec = ClayDepthSpec.of(depth, brightness, tone: tone);
    final pad = margin(depth, brightness);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(pixelRatio)
      ..translate(pad, pad);
    _ClayPainter(
      spec: spec,
      colours: _ClayColours.resolve(
        spec: spec,
        fill: fill,
        tone: tone,
        dark: dark,
        neutrals: neutrals,
      ),
      borderRadius: BorderRadius.zero,
      circle: true,
      outline: null,
      bottomSheet: false,
    ).paint(canvas, Size.square(diameter));
    final picture = recorder.endRecording();
    final side = ((diameter + 2 * pad) * pixelRatio).ceil();
    final image = picture.toImageSync(side, side);
    picture.dispose();
    _images[key] = image;
    // Old images are dropped, not disposed: a pin on screen may still draw
    // one until it rebuilds.
    if (_images.length > 64) _images.remove(_images.keys.first);
    return image;
  }
}

/// A pre-painted clay disc of [diameter]; its shadow spills outside the box.
class ClayDisc extends StatelessWidget {
  const ClayDisc({
    super.key,
    required this.diameter,
    this.fill,
    this.tone,
    this.depth = ClayDepth.clay1,
  });

  final double diameter;
  final Color? fill;
  final KeepsakeTone? tone;
  final ClayDepth depth;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final neutrals = WarangNeutrals.of(context);
    final pad = ClayDiscCache.margin(depth, brightness);
    final image = ClayDiscCache.image(
      diameter: diameter,
      fill: fill ?? tone?.fill ?? neutrals.surface,
      tone: tone,
      depth: depth,
      brightness: brightness,
      neutrals: neutrals,
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    return SizedBox.square(
      dimension: diameter,
      child: OverflowBox(
        maxWidth: diameter + 2 * pad,
        maxHeight: diameter + 2 * pad,
        child: RawImage(
          image: image,
          width: diameter + 2 * pad,
          height: diameter + 2 * pad,
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}

/// Wraps a clay control with the V6 `press` and `release` motion.
///
/// Pressing scales the control to 0.95 and sinks it toward `pressed` depth
/// in 90 ms; releasing springs it back with one small overshoot. Under
/// reduced motion there is no scale, and depth fades in 150 ms. The action
/// runs on release with no added delay.
class ClayPressable extends StatefulWidget {
  const ClayPressable({
    super.key,
    required this.builder,
    this.onPressed,
    this.onLongPress,
    this.haptic = WarangHaptic.none,
    this.semanticLabel,
    this.tooltip,
    this.selected,
    this.toggled,
  });

  /// Builds the control for a press amount from 0 (resting) to 1 (pressed).
  final Widget Function(BuildContext context, double press) builder;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// Played when the control is pressed down.
  final WarangHaptic haptic;
  final String? semanticLabel;
  final String? tooltip;
  final bool? selected;
  final bool? toggled;

  @override
  State<ClayPressable> createState() => _ClayPressableState();
}

class _ClayPressableState extends State<ClayPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  bool get _enabled => widget.onPressed != null || widget.onLongPress != null;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _down() {
    if (!_enabled) return;
    widget.haptic.play();
    if (WarangMotion.reduced(context)) {
      _press.animateTo(1, duration: WarangMotion.fade, curve: Curves.linear);
    } else {
      _press.animateTo(
        1,
        duration: WarangMotion.press,
        curve: WarangMotion.pressCurve,
      );
    }
  }

  void _up() {
    if (WarangMotion.reduced(context)) {
      _press.animateTo(0, duration: WarangMotion.fade, curve: Curves.linear);
    } else {
      _press.animateWith(WarangMotion.release.simulate(_press.value, 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = WarangMotion.reduced(context);
    Widget result = AnimatedBuilder(
      animation: _press,
      builder: (context, _) {
        final value = _press.value;
        final child = widget.builder(context, value.clamp(0.0, 1.0));
        if (reduced) return child;
        return Transform.scale(scale: 1 - .05 * value, child: child);
      },
    );
    result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _down(),
      onTapUp: (_) => _up(),
      onTapCancel: _up,
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      child: RepaintBoundary(child: result),
    );
    result = FocusableActionDetector(
      enabled: _enabled,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: result,
    );
    result = MergeSemantics(
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: widget.semanticLabel,
        selected: widget.selected,
        toggled: widget.toggled,
        child: result,
      ),
    );
    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }
    return result;
  }
}
