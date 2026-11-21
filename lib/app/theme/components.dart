import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'clay_components.dart';
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

class WarangCaptureButton extends StatefulWidget {
  const WarangCaptureButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<WarangCaptureButton> createState() => _WarangCaptureButtonState();
}

class _WarangCaptureButtonState extends State<WarangCaptureButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (mounted && _pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'Capture',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? .96 : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: WarangColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      (dark
                              ? Colors.black
                              : Theme.of(context).colorScheme.onSurface)
                          .withValues(alpha: dark ? .55 : .26),
                  blurRadius: dark ? 28 : 24,
                  offset: Offset(0, dark ? 12 : 10),
                ),
              ],
            ),
            child: const SizedBox(
              width: 74,
              height: 74,
              child: Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: WarangColors.accentInk, width: 2.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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

class WarangPhotoPin extends StatelessWidget {
  const WarangPhotoPin({super.key, this.file, this.selected = false});
  final File? file;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 66.0 : 58.0;
    final pointer = selected ? 12.0 : 11.0;
    final ringFill = Theme.of(context).colorScheme.surface;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size + 9,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: (size - pointer) / 2,
            top: size - (selected ? 7 : 6),
            child: Transform.rotate(
              angle: .785,
              child: Container(
                width: pointer,
                height: pointer,
                decoration: BoxDecoration(
                  color: ringFill,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: ringFill,
              shape: BoxShape.circle,
              boxShadow: [
                if (dark && selected)
                  BoxShadow(
                    color: WarangColors.darkInk.withValues(alpha: .10),
                    blurRadius: 0,
                    spreadRadius: 1,
                  ),
                BoxShadow(
                  color:
                      (dark
                              ? Colors.black
                              : Theme.of(context).colorScheme.onSurface)
                          .withValues(
                            alpha: dark
                                ? .50
                                : selected
                                ? .35
                                : .22,
                          ),
                  blurRadius: dark
                      ? (selected ? 16 : 16)
                      : (selected ? 20 : 12),
                  offset: Offset(
                    0,
                    dark ? (selected ? 6 : 6) : (selected ? 8 : 5),
                  ),
                ),
              ],
            ),
            child: ClipOval(
              child: file == null
                  ? ColoredBox(
                      color: Theme.of(context).extension<MapPalette>()!.landAlt,
                    )
                  : Image.file(file!, fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }
}

class WarangClusterPin extends StatelessWidget {
  const WarangClusterPin({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 54,
      height: 63,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 21.5,
            top: 48,
            child: Transform.rotate(
              angle: .785,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: WarangColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WarangColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      (dark
                              ? Colors.black
                              : Theme.of(context).colorScheme.onSurface)
                          .withValues(alpha: dark ? .50 : .24),
                  blurRadius: dark ? 18 : 14,
                  offset: Offset(0, dark ? 6 : 5),
                ),
              ],
            ),
            child: Text(
              '$count',
              style: WarangType.stampNumber.copyWith(
                fontSize: 20,
                color: WarangColors.accentInk,
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

class WarangGlassSurface extends StatelessWidget {
  const WarangGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.padding,
    this.blurSigma = WarangGlass.blurSigma,
    this.tintAlpha,
    this.showShadow = true,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final double? tintAlpha;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.maybeOf(context);
    final highContrast = mediaQuery?.highContrast ?? false;

    final defaultRadius = shape == BoxShape.circle
        ? null
        : (borderRadius ?? BorderRadius.circular(14));
    final defaultAlpha = dark ? WarangGlass.darkAlpha : WarangGlass.lightAlpha;
    final alpha = tintAlpha ?? defaultAlpha;

    final surfaceColor = highContrast
        ? theme.colorScheme.surface
        : theme.colorScheme.surface.withValues(alpha: alpha);

    final outlineColor = highContrast
        ? theme.colorScheme.outline
        : (dark ? WarangColors.darkLine : WarangColors.lightLine).withValues(
            alpha: dark ? 0.50 : 0.65,
          );

    final innerDecoration = BoxDecoration(
      color: surfaceColor,
      shape: shape,
      borderRadius: defaultRadius,
      border: Border.all(color: outlineColor, width: 1),
    );

    final outerDecoration = showShadow
        ? BoxDecoration(
            shape: shape,
            borderRadius: defaultRadius,
            boxShadow: [
              BoxShadow(
                color: (dark ? Colors.black : theme.colorScheme.onSurface)
                    .withValues(alpha: dark ? 0.30 : 0.08),
                blurRadius: dark ? 16 : 12,
                offset: const Offset(0, 3),
              ),
            ],
          )
        : null;

    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    if (highContrast) {
      final solid = DecoratedBox(decoration: innerDecoration, child: content);
      return outerDecoration == null
          ? solid
          : DecoratedBox(decoration: outerDecoration, child: solid);
    }

    final frosted = BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: DecoratedBox(decoration: innerDecoration, child: content),
    );

    final clipped = shape == BoxShape.circle
        ? ClipOval(child: frosted)
        : ClipRRect(
            borderRadius: defaultRadius ?? BorderRadius.circular(14),
            child: frosted,
          );

    return outerDecoration == null
        ? clipped
        : DecoratedBox(decoration: outerDecoration, child: clipped);
  }
}

class WarangGlassIconButton extends StatelessWidget {
  const WarangGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 48,
    this.iconSize = 20,
    this.tooltip,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = Semantics(
      button: true,
      label: semanticLabel,
      child: WarangGlassSurface(
        shape: BoxShape.circle,
        child: SizedBox(
          width: size,
          height: size,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              focusColor: WarangColors.accent.withValues(alpha: 0.20),
              hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              splashColor: WarangColors.accent.withValues(alpha: 0.24),
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    size: iconSize,
                    color: theme.colorScheme.onSurface,
                  ),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
