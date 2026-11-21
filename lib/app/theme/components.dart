import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'clay.dart';
import 'clay_components.dart';
import 'motion.dart';
import 'palette.dart';
import 'tokens.dart';
import 'warang_icons.dart';

export 'clay.dart';
export 'clay_components.dart';
export 'motion.dart';
export 'palette.dart';
export 'warang_icons.dart';

InputDecoration warangInputDecoration(
  BuildContext context, {
  String? hintText,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: WarangNeutrals.of(context).inkFaint),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
  );
}

/// Shows a C12 toast above the navigation when [aboveNavigation] is true.
///
/// It rises above the dock, leaves after [duration], and offers [action]
/// (for example "Undo") inside the pill.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showWarangSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
  bool aboveNavigation = true,
}) {
  final bottom = aboveNavigation
      ? WarangLayout.navigationHeight(context) + 8
      : 16.0;
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: WarangToast(
        message: message,
        actionLabel: action?.label,
        onAction: action == null
            ? null
            : () {
                messenger.hideCurrentSnackBar(
                  reason: SnackBarClosedReason.action,
                );
                action.onPressed();
              },
      ),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
    ),
  );
}

/// A two-layer clay icon: a soft fill glyph under a 2.5 px stroke glyph.
///
/// Unselected icons use an `inkSoft` stroke on a `hairline` fill; selected
/// icons fill with amber and take an `ink` stroke (FEAT-003 V7).
class WarangIcon extends StatelessWidget {
  const WarangIcon(
    this.glyph, {
    super.key,
    this.size,
    this.color,
    this.fillColor,
    this.selected = false,
    this.semanticLabel,
  });

  final WarangGlyph glyph;
  final double? size;
  final Color? color;
  final Color? fillColor;
  final bool selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final size = this.size ?? IconTheme.of(context).size ?? 24;
    final stroke = color ?? (selected ? neutrals.ink : neutrals.inkSoft);
    final fill =
        fillColor ?? (selected ? WarangColors.accent : neutrals.hairline);
    final fillGlyph = glyph.fill;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            if (fillGlyph != null) Icon(fillGlyph, size: size, color: fill),
            Icon(glyph.stroke, size: size, color: stroke),
          ],
        ),
      ),
    );
  }
}

class WarangMetadata extends StatelessWidget {
  const WarangMetadata(
    this.text, {
    super.key,
    this.align = TextAlign.left,
    this.water = false,
  });
  final String text;
  final TextAlign align;
  final bool water;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: WarangType.meta.copyWith(
      color: water
          ? Theme.of(context).extension<MapPalette>()!.labelWater
          : WarangNeutrals.of(context).inkFaint,
    ),
  );
}

class WarangSectionLabel extends StatelessWidget {
  const WarangSectionLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(
      label,
      style: WarangType.meta.copyWith(
        color: WarangNeutrals.of(context).inkSoft,
      ),
    ),
  );
}

class WarangTopScrim extends StatelessWidget {
  const WarangTopScrim({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: SizedBox(
        height: 78,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (dark ? WarangColors.darkGround : WarangColors.lightGround)
                    .withValues(alpha: dark ? .78 : .82),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// C2 capture button: a 76 amber clay disc inside a 4 px `surface` ring,
/// with the aperture ring pressed into it.
///
/// Pressing plays `press` and a light haptic; the camera opens on release
/// with no added delay while the button springs back underneath.
class WarangCaptureButton extends StatelessWidget {
  const WarangCaptureButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  static const diameter = 76.0;

  @override
  Widget build(BuildContext context) => ClayPressable(
    onPressed: onPressed,
    haptic: WarangHaptic.light,
    semanticLabel: 'Capture a moment',
    builder: (context, press) => ClaySurface(
      depth: ClayDepth.clay3,
      press: press,
      circle: true,
      padding: const EdgeInsets.all(4),
      child: ClaySurface(
        depth: ClayDepth.clay1,
        press: press,
        tone: WarangKeepsake.amber,
        circle: true,
        child: const SizedBox.square(
          dimension: diameter,
          child: Center(
            child: CustomPaint(
              size: Size.square(30),
              painter: _AperturePainter(),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The aperture: a 2.5 px `ink` ring with an inset shade inside it.
class _AperturePainter extends CustomPainter {
  const _AperturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1.25;
    final inner = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            WarangKeepsake.amber.clayShade,
            WarangKeepsake.amber.fill.withValues(alpha: 0),
          ],
        ).createShader(inner),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = WarangColors.lightInk,
    );
  }

  @override
  bool shouldRepaint(covariant _AperturePainter oldDelegate) => false;
}

class WarangPositionMarker extends StatefulWidget {
  const WarangPositionMarker({super.key});

  @override
  State<WarangPositionMarker> createState() => _WarangPositionMarkerState();
}

class _WarangPositionMarkerState extends State<WarangPositionMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      if (_controller.isAnimating) _controller.stop();
      _controller.value = 1.0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: const Size.square(76),
        painter: _PositionMarkerPainter(
          pulse: disabled ? 1 : Curves.easeInOut.transform(_controller.value),
          surface: Theme.of(context).colorScheme.surface,
          dark: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    );
  }
}

class _PositionMarkerPainter extends CustomPainter {
  const _PositionMarkerPainter({
    required this.pulse,
    required this.surface,
    required this.dark,
  });
  final double pulse;
  final Color surface;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const accent = WarangColors.accent;
    canvas.drawCircle(
      center,
      38 * (.86 + pulse * .14),
      Paint()..color = accent.withValues(alpha: dark ? .22 : .18),
    );
    final cone = Path()
      ..moveTo(center.dx - 26, center.dy - 22)
      ..lineTo(center.dx + 26, center.dy - 22)
      ..lineTo(center.dx, center.dy + 1)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0),
            accent.withValues(alpha: dark ? .42 : .40),
          ],
        ).createShader(Rect.fromLTWH(center.dx - 26, center.dy - 22, 52, 23)),
    );
    canvas.drawCircle(center, 8.5, Paint()..color = accent);
    canvas.drawCircle(
      center,
      8.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = surface,
    );
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: 8.5)),
      Colors.black.withValues(alpha: dark ? .55 : .30),
      dark ? 8 : 7,
      false,
    );
  }

  @override
  bool shouldRepaint(covariant _PositionMarkerPainter oldDelegate) =>
      oldDelegate.pulse != pulse ||
      oldDelegate.surface != surface ||
      oldDelegate.dark != dark;
}

/// C10 photo pin: a pre-painted clay disc whose rim is the trip's colour
/// (`surface` for Everyday), a 2 px `surfaceRaised` inner ring, the photo,
/// and a rounded pointer in the rim colour.
class WarangPhotoPin extends StatelessWidget {
  const WarangPhotoPin({
    super.key,
    this.file,
    this.selected = false,
    this.ringColor,
  });
  final File? file;
  final bool selected;

  /// The trip's fill; null is Everyday, drawn in `surface`.
  final Color? ringColor;

  static const size = 58.0;
  static const selectedSize = 70.0;

  /// Room below the disc for the pointer.
  static const pointerRoom = 9.0;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final outer = selected ? selectedSize : size;
    final photo = selected ? 60.0 : 48.0;
    final ring = ringColor ?? neutrals.surface;
    final placeholder = ColoredBox(
      color: Theme.of(context).extension<MapPalette>()!.landAlt,
    );
    final file = this.file;
    return SizedBox(
      width: outer,
      height: outer + pointerRoom,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: outer - 7,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: ring,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          ),
          ClayDisc(
            diameter: outer,
            fill: ring,
            depth: selected ? ClayDepth.clay3 : ClayDepth.clay1,
          ),
          SizedBox.square(
            dimension: outer,
            child: Center(
              child: Container(
                width: photo + 4,
                height: photo + 4,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: neutrals.surfaceRaised,
                  shape: BoxShape.circle,
                ),
                // The photo itself is drawn flat, with nothing over it.
                child: ClipOval(
                  child: file == null
                      ? placeholder
                      : Image.file(
                          file,
                          fit: BoxFit.cover,
                          cacheWidth:
                              (photo * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          errorBuilder: (_, _, _) => placeholder,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// C10 cluster pin: a 54 amber clay disc with its count in `stampNumber`.
/// A cluster of one trip may pass that trip's fill as [ringColor].
class WarangClusterPin extends StatelessWidget {
  const WarangClusterPin({super.key, required this.count, this.ringColor});
  final int count;
  final Color? ringColor;

  static const size = 54.0;

  @override
  Widget build(BuildContext context) {
    final ring = ringColor ?? WarangKeepsake.amber.fill;
    return SizedBox(
      width: size,
      height: size + 9,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: size - 7,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: ring,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          ),
          ClayDisc(
            diameter: size,
            fill: ring,
            tone: ringColor == null ? WarangKeepsake.amber : null,
          ),
          SizedBox.square(
            dimension: size,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: WarangKeepsake.amber.fill,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: WarangType.stampNumber.copyWith(
                    fontSize: 20,
                    color: WarangColors.lightInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WarangSettingsCard extends StatelessWidget {
  const WarangSettingsCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class WarangSettingsRow extends StatelessWidget {
  const WarangSettingsRow({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.emphasized = false,
    this.toggle = false,
  });
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool emphasized;
  final bool toggle;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 15,
          vertical: toggle ? 12 : 14,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: WarangType.body.copyWith(
                  fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
                  color: emphasized
                      ? (Theme.of(context).brightness == Brightness.dark
                            ? WarangColors.darkAccentText
                            : WarangColors.lightAccentText)
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: WarangType.meta.copyWith(
                  color: WarangNeutrals.of(context).inkSoft,
                ),
              ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    ),
  );
}

class WarangDivider extends StatelessWidget {
  const WarangDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 15),
    child: Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}
