// FEAT-003 shared clay components: C4 buttons, C5 fields, C6 stamps,
// C7 chips, C8 polaroids, C9 sheets, C11 toggles, C12 toasts, and C13
// speech bubbles. Every one honours reduced motion (V6 rule 2).
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'clay.dart';
import 'components.dart' show WarangIcon;
import 'motion.dart';
import 'palette.dart';
import 'tokens.dart';
import 'warang_icons.dart';

// ------------------------------------------------------------------ C4

enum WarangButtonVariant { primary, secondary, quiet, danger }

/// C4 buttons. There is at most one primary button per screen or sheet,
/// and no button ever uses white text.
class WarangButton extends StatelessWidget {
  const WarangButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = WarangButtonVariant.primary,
    this.icon,
    this.expand = true,
  }) : besidePrimary = false;

  const WarangButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  }) : variant = WarangButtonVariant.primary,
       besidePrimary = false;

  const WarangButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
    this.besidePrimary = false,
  }) : variant = WarangButtonVariant.secondary;

  const WarangButton.quiet({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  }) : variant = WarangButtonVariant.quiet,
       besidePrimary = false;

  const WarangButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  }) : variant = WarangButtonVariant.danger,
       besidePrimary = false;

  final String label;
  final VoidCallback? onPressed;
  final WarangButtonVariant variant;
  final WarangGlyph? icon;

  /// Fills the available width when true.
  final bool expand;

  /// A secondary button sharing a row with a primary takes its height, so
  /// the two edges and labels line up.
  final bool besidePrimary;

  double get height => switch (variant) {
    WarangButtonVariant.primary => 56,
    WarangButtonVariant.secondary => besidePrimary ? 56 : 48,
    WarangButtonVariant.quiet => 48,
    WarangButtonVariant.danger => 48,
  };

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final neutrals = WarangNeutrals.of(context);
    final (depth, fill, tone, labelColor, outline) = switch (variant) {
      WarangButtonVariant.primary => (
        ClayDepth.clay2,
        WarangKeepsake.amber.fill,
        WarangKeepsake.amber,
        // Labels on a keepsake fill are light-theme ink in both themes.
        WarangColors.lightInk,
        null,
      ),
      WarangButtonVariant.secondary => (
        ClayDepth.clay1,
        neutrals.surface,
        null,
        neutrals.ink,
        null,
      ),
      WarangButtonVariant.quiet => (
        ClayDepth.flat,
        Colors.transparent,
        null,
        neutrals.inkSoft,
        BorderSide(color: neutrals.boundary),
      ),
      WarangButtonVariant.danger => (
        ClayDepth.clay1,
        WarangKeepsake.gumamela.tint(brightness),
        null,
        WarangKeepsake.gumamela.text(brightness),
        null,
      ),
    };
    return ClayPressable(
      onPressed: onPressed,
      builder: (context, press) => ClaySurface(
        depth: depth,
        pressedDepth: variant == WarangButtonVariant.quiet
            ? ClayDepth.flat
            : ClayDepth.pressed,
        press: press,
        color: fill,
        tone: tone,
        outline: outline,
        borderRadius: BorderRadius.circular(WarangRadius.control),
        child: SizedBox(
          height: math.max(height, 48),
          width: expand ? double.infinity : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  WarangIcon(icon!, size: 20, color: labelColor),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WarangType.button.copyWith(color: labelColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ C5

/// C5 fields: an inset clay well with the label above it, never inside it.
///
/// Focus draws a 2 px amber outline and lifts the well flat; an error draws
/// a 2 px gumamela outline and an error line, so colour is not the only cue.
class WarangField extends StatefulWidget {
  const WarangField({
    super.key,
    this.label,
    this.controller,
    this.focusNode,
    this.hintText,
    this.hintStyle,
    this.style,
    this.errorText,
    this.helperText,
    this.multiline = false,
    this.minLines,
    this.maxLines,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.pill = false,
    this.leading,
    this.trailing,
  });

  final String? label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextStyle? hintStyle;
  final TextStyle? style;
  final String? errorText;

  /// A short note under the field, in `meta` `inkFaint`.
  final String? helperText;

  /// 104 tall instead of 56.
  final bool multiline;
  final int? minLines;
  final int? maxLines;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// A pill-shaped well, as on the Search tab.
  final bool pill;
  final Widget? leading;
  final Widget? trailing;

  @override
  State<WarangField> createState() => _WarangFieldState();
}

class _WarangFieldState extends State<WarangField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant WarangField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  void _onFocus() {
    if (mounted && _focused != _focus.hasFocus) {
      setState(() => _focused = _focus.hasFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final neutrals = WarangNeutrals.of(context);
    final reduced = WarangMotion.reduced(context);
    final error = widget.errorText;
    final outline = error != null
        ? BorderSide(color: WarangKeepsake.gumamela.fill, width: 2)
        : _focused
        ? BorderSide(color: WarangKeepsake.amber.fill, width: 2)
        : BorderSide(color: neutrals.boundary);
    final radius = BorderRadius.circular(
      widget.pill ? WarangRadius.pill : WarangRadius.control,
    );
    final field = TextField(
      controller: widget.controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      minLines: widget.multiline ? (widget.minLines ?? 3) : 1,
      maxLines: widget.multiline ? (widget.maxLines ?? 5) : 1,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.textInputAction,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: widget.style ?? WarangType.bodyL.copyWith(color: neutrals.ink),
      decoration: InputDecoration(
        isCollapsed: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        hintText: widget.hintText,
        // A long hint wraps at large text sizes instead of being cut.
        hintMaxLines: widget.multiline ? null : 3,
        hintStyle:
            widget.hintStyle ??
            WarangType.bodyL.copyWith(color: neutrals.inkFaint),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: WarangType.meta.copyWith(color: neutrals.inkSoft),
          ),
          const SizedBox(height: 8),
        ],
        TweenAnimationBuilder<double>(
          tween: Tween(end: _focused ? 1 : 0),
          duration: reduced ? WarangMotion.fade : WarangMotion.release.duration,
          curve: reduced ? Curves.linear : WarangMotion.release.curve,
          builder: (context, lift, child) => ClaySurface(
            depth: ClayDepth.inset,
            pressedDepth: ClayDepth.flat,
            press: lift,
            outline: outline,
            borderRadius: radius,
            child: child,
          ),
          // Taps anywhere in the well focus the field; the text field itself
          // carries the semantics, so this detector adds none.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: _focus.requestFocus,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: widget.multiline ? 104 : 56,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.pill ? 20 : 16,
                  vertical: widget.multiline ? 16 : 0,
                ),
                child: Row(
                  crossAxisAlignment: widget.multiline
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    if (widget.leading != null) ...[
                      widget.leading!,
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: field),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 10),
                      widget.trailing!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: WarangType.meta.copyWith(
              color: WarangKeepsake.gumamela.text(brightness),
            ),
          ),
        ] else if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.helperText!,
            style: WarangType.meta.copyWith(color: neutrals.inkFaint),
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ C6

/// Stamp ids shown this session, so each pops in only the first time.
final Set<String> _stampsShown = {};

/// C6 stamp: a scalloped circle (84) or rounded rectangle (120 by 64, or 80
/// tall for three lines) in a keepsake tint, with a dashed inner ring in the
/// matching text colour.
///
/// It tilts between -8 and +8 degrees, fixed by [id] so it never changes
/// between visits, and pops in the first time it is shown in a session.
class WarangStamp extends StatefulWidget {
  const WarangStamp.count({
    super.key,
    required this.id,
    required int this.number,
    required String this.word,
    required this.tone,
    this.countUp = false,
  }) : lines = const [],
       glyph = null,
       place = false;

  const WarangStamp.place({
    super.key,
    required this.id,
    required this.lines,
    required this.tone,
  }) : number = null,
       word = null,
       countUp = false,
       glyph = null,
       place = true;

  /// A small postage stamp, 52 by 60, with [glyph] at its centre, for the
  /// corner of a postcard.
  const WarangStamp.postage({
    super.key,
    required this.id,
    required WarangGlyph this.glyph,
    required this.tone,
  }) : number = null,
       word = null,
       lines = const [],
       countUp = false,
       place = true;

  final String id;
  final int? number;
  final String? word;
  final List<String> lines;
  final KeepsakeTone tone;
  final bool place;

  /// The postage stamp's picture.
  final WarangGlyph? glyph;

  /// The number counts up from zero (`count`) the first time the stamp is
  /// shown in a session, as the Trips shelf's stamps do.
  final bool countUp;

  Size get size => glyph != null
      ? const Size(52, 60)
      : place
      ? Size(120, lines.length > 2 ? 80 : 64)
      : const Size.square(84);

  /// The tilt in degrees, from -8 to +8, decided once from [id].
  double get tiltDegrees {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return (hash % 17) - 8.0;
  }

  @visibleForTesting
  static void resetSession() => _stampsShown.clear();

  @override
  State<WarangStamp> createState() => _WarangStampState();
}

class _WarangStampState extends State<WarangStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  bool _counting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stampsShown.add(widget.id) && !WarangMotion.reduced(context)) {
      _pop.value = 0;
      _pop.animateWith(WarangMotion.pop.simulate(0, 1));
      _counting = widget.countUp;
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ink = widget.tone.text(brightness);
    final glyph = widget.glyph;
    final content = glyph != null
        ? Center(
            child: WarangIcon(glyph, size: 24, color: ink, fillColor: ink),
          )
        : widget.place
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            // Up to three short lines; longer ones scale down to stay
            // inside the dashed ring.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final line in widget.lines)
                    Text(
                      line,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: WarangType.meta.copyWith(color: ink, height: 1.15),
                    ),
                ],
              ),
            ),
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(
                  begin: _counting ? 0 : widget.number,
                  end: widget.number,
                ),
                duration: WarangMotion.count,
                curve: WarangMotion.countCurve,
                builder: (context, value, _) => Text(
                  '$value',
                  style: WarangType.stampNumber.copyWith(color: ink),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 48,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.word!,
                    maxLines: 1,
                    style: WarangType.caption.copyWith(color: ink),
                  ),
                ),
              ),
            ],
          );
    return Semantics(
      container: true,
      label: widget.glyph != null
          ? null
          : widget.place
          ? widget.lines.join(', ')
          : '${widget.number} ${widget.word}',
      excludeSemantics: true,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _pop,
          builder: (context, child) =>
              Transform.scale(scale: _pop.value.clamp(0.0, 1.2), child: child),
          child: Transform.rotate(
            angle: widget.tiltDegrees * math.pi / 180,
            child: CustomPaint(
              size: widget.size,
              painter: _StampPainter(
                fill: widget.tone.tint(brightness),
                ring: ink,
                place: widget.place,
              ),
              child: SizedBox.fromSize(
                size: widget.size,
                child: MediaQuery.withNoTextScaling(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter({required this.fill, required this.ring, required this.place});

  final Color fill;
  final Color ring;
  final bool place;

  /// How far each bump stands out from the base outline.
  static const _bump = 2.8;

  /// From the base outline in to the dashed ring.
  static const _ringGap = 5.0;

  /// A stamp's inner panel is `rChip`; the outline runs concentric with it.
  static const _radius = WarangRadius.chip + _ringGap;

  /// The base outline, clockwise. A rectangle starts at the middle of its
  /// top-left corner, so bumps can be centred on each corner.
  Path _base(Rect rect, double radius) {
    if (!place) return Path()..addOval(rect);
    final r = Radius.circular(radius);
    final inset = radius * (1 - math.sqrt1_2);
    final start = rect.topLeft + Offset(inset, inset);
    return Path()
      ..moveTo(start.dx, start.dy)
      ..arcToPoint(Offset(rect.left + radius, rect.top), radius: r)
      ..lineTo(rect.right - radius, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + radius), radius: r)
      ..lineTo(rect.right, rect.bottom - radius)
      ..arcToPoint(Offset(rect.right - radius, rect.bottom), radius: r)
      ..lineTo(rect.left + radius, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - radius), radius: r)
      ..lineTo(rect.left, rect.top + radius)
      ..arcToPoint(start, radius: r)
      ..close();
  }

  /// Where bumps are centred, as fractions of the outline: evenly along
  /// each run between corners, with one on every corner, 18 to 24 in all
  /// (V4).
  List<double> _bumpCentres(Rect rect) {
    if (!place) return [for (var i = 0; i < 20; i++) i / 20];
    const corner = math.pi * _radius / 2;
    final across = rect.width - 2 * _radius + corner;
    final down = rect.height - 2 * _radius + corner;
    final spacing = 2 * (across + down) / 23;
    final centres = <double>[];
    var from = 0.0;
    for (final run in [across, down, across, down]) {
      final count = math.max(1, (run / spacing).round());
      for (var i = 0; i < count; i++) {
        centres.add((from + run * i / count) / (2 * (across + down)));
      }
      from += run;
    }
    return centres;
  }

  /// Round bumps, each an arc between two valleys on the base outline.
  Path _scalloped(Rect rect) {
    final metric = _base(rect, _radius).computeMetrics().first;
    final centres = _bumpCentres(rect);
    Offset at(double fraction) =>
        metric.getTangentForOffset(metric.length * (fraction % 1))!.position;

    var valley = (centres.last + 1) / 2;
    final path = Path()..moveTo(at(valley).dx, at(valley).dy);
    var from = at(valley);
    for (var index = 0; index < centres.length; index++) {
      final following = index + 1 < centres.length ? centres[index + 1] : 1.0;
      valley = (centres[index] + following) / 2;
      final to = at(valley);
      final half = (to - from).distance / 2;
      // Measured from the chord, so corner bumps stand out as far as the rest.
      final rise = _bump + (at(centres[index]) - (from + to) / 2).distance;
      path.arcToPoint(
        to,
        radius: Radius.circular((half * half + rise * rise) / (2 * rise)),
      );
      from = to;
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final edge = (Offset.zero & size).deflate(_bump);
    canvas.drawPath(_scalloped(edge), Paint()..color = fill);
    final inner = _base(edge.deflate(_ringGap), WarangRadius.chip);
    final dash = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final PathMetric metric in inner.computeMetrics()) {
      // A whole number of dashes, so none doubles up where the ring closes.
      final count = (metric.length / 7).round();
      final step = metric.length / count;
      for (var index = 0; index < count; index++) {
        canvas.drawPath(
          metric.extractPath(index * step, (index + .5) * step),
          dash,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StampPainter old) =>
      old.fill != fill || old.ring != ring || old.place != place;
}

// ------------------------------------------------------------------ C7

/// C7 chip: a keepsake tint at `clay1`; selected turns the solid colour
/// with an `ink` label and a check mark. A null [tone] is the neutral chip
/// used for Everyday: it has no solid colour, so selected adds a 2 px
/// `boundary` outline instead.
class WarangChip extends StatelessWidget {
  const WarangChip({
    super.key,
    required this.label,
    this.tone,
    this.selected = false,
    this.onSelected,
    this.icon,
  });

  final String label;
  final KeepsakeTone? tone;
  final bool selected;
  final VoidCallback? onSelected;
  final WarangGlyph? icon;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final neutrals = WarangNeutrals.of(context);
    final tone = this.tone;
    final fill = tone == null
        ? neutrals.surfaceRaised
        : (selected ? tone.fill : tone.tint(brightness));
    final ink = tone == null
        ? (selected ? neutrals.ink : neutrals.inkSoft)
        : (selected ? WarangColors.lightInk : tone.text(brightness));
    Widget surface(double press) => ClaySurface(
      depth: ClayDepth.clay1,
      press: press,
      color: fill,
      tone: selected ? tone : null,
      outline: selected && tone == null
          ? BorderSide(color: neutrals.boundary, width: 2)
          : null,
      borderRadius: BorderRadius.circular(WarangRadius.chip),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                WarangIcon(WarangGlyphs.check, size: 18, color: ink),
                const SizedBox(width: 6),
              ] else if (icon != null) ...[
                WarangIcon(icon!, size: 18, color: ink),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WarangType.meta.copyWith(
                    color: ink,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // A chip without an action only labels; it is not announced as a button.
    if (onSelected == null) {
      return Semantics(
        label: label,
        selected: selected,
        excludeSemantics: true,
        child: surface(0),
      );
    }
    return ClayPressable(
      onPressed: onSelected,
      haptic: WarangHaptic.selection,
      selected: selected,
      builder: (context, press) => surface(press),
    );
  }
}

// ------------------------------------------------------------------ C8

/// C8 polaroid: a `surfaceRaised` clay frame with the photo flat inside it
/// and the caption written on the bottom strip. Nothing is drawn over the
/// photo.
class WarangPolaroid extends StatelessWidget {
  const WarangPolaroid({
    super.key,
    required this.photo,
    this.caption,
    this.stamp,
    this.frame = const EdgeInsets.fromLTRB(12, 12, 12, 60),
    this.photoAspectRatio = 1,
    this.captionStyle,
    this.depth = ClayDepth.clay2,
    this.rotationDegrees = 0,
  });

  final Widget photo;
  final String? caption;

  /// Overlaps the top-right corner, as a place stamp does. The room it
  /// rises into is part of this widget, so all of it takes taps.
  final Widget? stamp;
  final EdgeInsets frame;
  final double photoAspectRatio;
  final TextStyle? captionStyle;
  final ClayDepth depth;

  /// Cards may tilt between -2 and +2 degrees (V4).
  final double rotationDegrees;

  static const _stampRise = 18.0;
  static const _stampOverhang = 14.0;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final caption = this.caption?.trim();
    Widget result = ClaySurface(
      depth: depth,
      color: neutrals.surfaceRaised,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(frame.left, frame.top, frame.right, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: photoAspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(WarangRadius.photo),
                child: photo,
              ),
            ),
            // The strip grows with large text, so a caption is never cut.
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: frame.bottom),
              child: caption == null || caption.isEmpty
                  ? null
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              captionStyle ??
                              WarangType.handL.copyWith(color: neutrals.ink),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
    if (stamp != null) {
      result = Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: _stampRise),
            child: result,
          ),
          Positioned(top: 0, right: -_stampOverhang, child: stamp!),
        ],
      );
    }
    if (rotationDegrees != 0) {
      result = Transform.rotate(
        angle: rotationDegrees * math.pi / 180,
        child: result,
      );
    }
    return result;
  }
}

// ------------------------------------------------------------------ C9

/// The C9 dimmer: `ink` 40% in light, black 55% in dark.
Color warangDimmer(Brightness brightness) => brightness == Brightness.dark
    ? Colors.black.withValues(alpha: .55)
    : WarangColors.lightInk.withValues(alpha: .40);

/// Opens a C9 sheet that rises with the `sheet` spring and closes with a
/// downward swipe, a tap on the dimmer, or the system back gesture.
Future<T?> showWarangSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final reduced = WarangMotion.reduced(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: warangDimmer(Theme.of(context).brightness),
    sheetAnimationStyle: AnimationStyle(
      curve: reduced ? Curves.linear : WarangMotion.sheet.settleCurve,
      duration: reduced ? WarangMotion.fade : WarangMotion.sheet.duration,
      reverseDuration: WarangMotion.fade * 1.5,
    ),
    builder: (context) => WarangSheetFrame(child: builder(context)),
  );
}

/// The C9 sheet body: `surface` clay with `rSheet` top corners, an upward
/// `clay3` shadow, and the 40 by 5 handle 14 below the top edge.
class WarangSheetFrame extends StatelessWidget {
  const WarangSheetFrame({super.key, required this.child, this.handle});

  final Widget child;

  /// Laid over the handle strip, for a drag-to-close gesture of its own.
  final Widget? handle;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => ClaySurface(
        depth: ClayDepth.clay3,
        bottomSheet: true,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(WarangRadius.sheet),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 24,
              child: Stack(
                children: [
                  Positioned(
                    top: 14,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: neutrals.boundary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  if (handle != null) Positioned.fill(child: handle!),
                ],
              ),
            ),
            // A tall body scrolls inside a bounded sheet; in an unbounded
            // parent it takes its natural height.
            if (constraints.hasBoundedHeight) Flexible(child: child) else child,
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ C11

/// C11 toggle: an inset pill track and a clay knob. On fills the track with
/// amber and shows a check in the knob, so state is not colour alone.
class WarangToggle extends StatelessWidget {
  const WarangToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final reduced = WarangMotion.reduced(context);
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                WarangHaptic.selection.play();
                onChanged!(!value);
              }
            : null,
        child: SizedBox(
          width: 52,
          height: 48,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: value ? 1 : 0),
              duration: reduced
                  ? WarangMotion.fade
                  : WarangMotion.slide.duration,
              curve: reduced ? Curves.linear : WarangMotion.slide.curve,
              builder: (context, t, _) {
                final position = t.clamp(0.0, 1.0);
                // The knob stretches up to 1.25 times while it travels.
                final stretch = reduced
                    ? 1.0
                    : 1 + .25 * math.sin(math.pi * position);
                final knobWidth = 26 * stretch;
                return RepaintBoundary(
                  child: ClaySurface(
                    depth: ClayDepth.inset,
                    color: Color.lerp(
                      neutrals.surface,
                      WarangKeepsake.amber.fill,
                      position,
                    ),
                    outline: value
                        ? null
                        : BorderSide(color: neutrals.boundary),
                    borderRadius: BorderRadius.circular(WarangRadius.pill),
                    child: SizedBox(
                      width: 52,
                      height: 32,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 3 + (52 - 6 - knobWidth) * t,
                            top: 3,
                            child: ClaySurface(
                              depth: ClayDepth.clay1,
                              color: neutrals.surfaceRaised,
                              borderRadius: BorderRadius.circular(
                                WarangRadius.pill,
                              ),
                              child: SizedBox(
                                width: knobWidth,
                                height: 26,
                                child: value
                                    ? Center(
                                        child: WarangIcon(
                                          WarangGlyphs.check,
                                          size: 16,
                                          color: neutrals.ink,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ C12

/// The C12 toast body: a `surface` pill at `clay2`, 56 tall, with the
/// message in `body` and the action in the amber text colour.
class WarangToast extends StatelessWidget {
  const WarangToast({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.leading,
  });

  /// Drawn before the message, as the cheering maya on a milestone.
  final Widget? leading;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final neutrals = WarangNeutrals.of(context);
    return ClaySurface(
      depth: ClayDepth.clay2,
      borderRadius: BorderRadius.circular(WarangRadius.pill),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: actionLabel == null ? 22 : 6,
            top: 6,
            bottom: 6,
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Text(
                  message,
                  style: WarangType.body.copyWith(color: neutrals.ink),
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(64, 48),
                    foregroundColor: WarangKeepsake.amber.text(brightness),
                    textStyle: WarangType.button,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ C13

/// C13 speech bubble: a `surfaceRaised` pill with `hand` text and a small
/// tail. It pops in, stays about two seconds, then fades, unless
/// [persistent]. Screen readers skip it.
class WarangSpeechBubble extends StatefulWidget {
  const WarangSpeechBubble({
    super.key,
    required this.text,
    this.tailAlignment = 0,
    this.tailDown = true,
    this.persistent = false,
    this.visibleFor = const Duration(seconds: 2),
    this.onHidden,
  });

  final String text;

  /// Where the tail sits along the bubble, from -1 (left) to 1 (right).
  final double tailAlignment;

  /// The tail points down toward the speaker when true, up when false.
  final bool tailDown;
  final bool persistent;
  final Duration visibleFor;
  final VoidCallback? onHidden;

  @override
  State<WarangSpeechBubble> createState() => _WarangSpeechBubbleState();
}

class _WarangSpeechBubbleState extends State<WarangSpeechBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController.unbounded(
    vsync: this,
  );
  Timer? _timer;
  bool _hidden = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (WarangMotion.reduced(context)) {
      _pop.value = 1;
    } else {
      _pop.animateWith(WarangMotion.pop.simulate(0, 1));
    }
    if (!widget.persistent) {
      _timer = Timer(widget.visibleFor, () {
        if (mounted) setState(() => _hidden = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final reduced = WarangMotion.reduced(context);
    final tail = Align(
      alignment: Alignment(widget.tailAlignment, 0),
      child: CustomPaint(
        size: const Size(16, 9),
        painter: _TailPainter(neutrals.surfaceRaised, down: widget.tailDown),
      ),
    );
    final bubble = ClaySurface(
      depth: ClayDepth.clay1,
      color: neutrals.surfaceRaised,
      borderRadius: BorderRadius.circular(WarangRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          widget.text,
          textAlign: TextAlign.center,
          style: WarangType.hand.copyWith(color: neutrals.ink),
        ),
      ),
    );
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _hidden ? 0 : 1,
          duration: reduced
              ? WarangMotion.fade
              : const Duration(milliseconds: 300),
          onEnd: () {
            if (_hidden) widget.onHidden?.call();
          },
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _pop,
              builder: (context, child) => reduced
                  ? Opacity(opacity: _pop.value.clamp(0.0, 1.0), child: child)
                  : Transform.scale(
                      scale: (.6 + .4 * _pop.value).clamp(0.0, 1.2),
                      alignment: Alignment(
                        widget.tailAlignment,
                        widget.tailDown ? 1 : -1,
                      ),
                      child: child,
                    ),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.tailDown ? [bubble, tail] : [tail, bubble],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color, {required this.down});

  final Color color;
  final bool down;

  @override
  void paint(Canvas canvas, Size size) {
    final path = down
        ? (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width, 0)
            ..quadraticBezierTo(
              size.width / 2 + 1,
              size.height * .6,
              size.width / 2,
              size.height,
            )
            ..quadraticBezierTo(size.width / 2 - 1, size.height * .6, 0, 0))
        : (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width, size.height)
            ..quadraticBezierTo(
              size.width / 2 + 1,
              size.height * .4,
              size.width / 2,
              0,
            )
            ..quadraticBezierTo(
              size.width / 2 - 1,
              size.height * .4,
              0,
              size.height,
            ));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) =>
      old.color != color || old.down != down;
}
