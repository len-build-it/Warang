import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app.dart';
import '../../app/device_providers.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatting.dart';

enum _LocationState { locating, located, unavailable }

/// Reviews a fresh photo and saves it as a moment. Pops with the saved
/// [Moment], or null when the capture is cancelled.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({
    super.key,
    this.initialPhoto,
    this.fetchLocation = true,
  });
  final XFile? initialPhoto;
  final bool fetchLocation;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with SingleTickerProviderStateMixin {
  final _captionController = TextEditingController();
  late final _shrink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  final _capturedAt = DateTime.now();
  XFile? _photo;
  ({double latitude, double longitude})? _position;
  var _location = _LocationState.unavailable;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoto != null) {
      _photo = widget.initialPhoto;
    } else {
      _openCamera();
    }
    if (widget.fetchLocation) {
      _location = _LocationState.locating;
      _getPosition();
    }
  }

  Future<void> _openCamera() async {
    final photo = await ref.read(cameraPickerProvider)();
    if (!mounted) return;
    if (photo == null) {
      // A cancelled retake keeps the photo already on screen.
      if (_photo == null) Navigator.of(context).pop();
      return;
    }
    setState(() => _photo = photo);
  }

  Future<void> _getPosition() async {
    final position = await ref.read(locationReaderProvider)();
    if (!mounted) return;
    setState(() {
      _position = position;
      _location = position == null
          ? _LocationState.unavailable
          : _LocationState.located;
    });
  }

  Future<void> _save() async {
    final photo = _photo;
    if (photo == null || _saving) return;
    setState(() => _saving = true);
    try {
      final caption = _captionController.text.trim();
      final moment = await ref
          .read(repositoryProvider)
          .captureMoment(
            photo: File(photo.path),
            caption: caption.isEmpty ? null : caption,
            latitude: _position?.latitude,
            longitude: _position?.longitude,
            capturedAt: _capturedAt,
          );
      if (!mounted) return;
      // The moment is already written; only then does the photo shrink
      // into its pin and the map take over (S3).
      WarangHaptic.medium.play();
      if (!WarangMotion.reduced(context)) {
        await _shrink.animateTo(1, curve: Curves.easeInCubic);
      }
      if (mounted) Navigator.of(context).pop(moment);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showWarangSnackBar(
        context,
        "Couldn't save this photo. It's still here - try again.",
        aboveNavigation: false,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'Retry', onPressed: _save),
      );
    }
  }

  /// The place stamp: where (or the locating state), then the time.
  List<String> get _placeLines {
    final time = formatTime(_capturedAt);
    final position = _position;
    return switch (_location) {
      _LocationState.locating => ['Locating…', time],
      _LocationState.located => [
        ...formatCoordinates(
          position!.latitude,
          position.longitude,
        ).split(' · '),
        time,
      ],
      _LocationState.unavailable => ['No location yet', time],
    };
  }

  @override
  void dispose() {
    _shrink.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final neutrals = WarangNeutrals.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final safeTop = math.max(topPadding, 12.0) + 8.0;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final photoHeight = (screenHeight * 0.45).clamp(220.0, 480.0);
    final trip = ref.watch(repositoryProvider).tripForCapture(_capturedAt);
    final photoArea = ColoredBox(
      color:
          theme.extension<MapPalette>()?.landAlt ??
          theme.colorScheme.surfaceContainerHighest,
      child: _photo == null
          ? null
          : Image.file(
              File(_photo!.path),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, _, _) =>
                  const Center(child: WarangIcon(WarangGlyphs.photo, size: 36)),
            ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: photoHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // After saving, the photo shrinks into the round pin it
                    // becomes on the map. Nothing is drawn over the photo.
                    AnimatedBuilder(
                      animation: _shrink,
                      child: photoArea,
                      builder: (context, child) {
                        final t = _shrink.value;
                        if (t == 0) return child!;
                        final side = math.min(
                          MediaQuery.sizeOf(context).width,
                          photoHeight,
                        );
                        return Center(
                          child: Transform.scale(
                            scale: 1 - .8 * t,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(side / 2 * t),
                              child: SizedBox(
                                width: lerpDouble(
                                  MediaQuery.sizeOf(context).width,
                                  side,
                                  t,
                                ),
                                height: lerpDouble(photoHeight, side, t),
                                child: child,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: safeTop,
                      left: 16,
                      right: 16,
                      // Wraps rather than overlaps at large text sizes.
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ClayPill(
                            semanticLabel: 'Retake photograph',
                            icon: WarangGlyphs.refresh,
                            label: 'Retake',
                            onPressed: _saving ? null : _openCamera,
                          ),
                          _ClayPill(
                            semanticLabel: 'Cancel capture',
                            icon: WarangGlyphs.close,
                            label: 'Close',
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Wraps at large text sizes, so the chip keeps its words.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        // Room for three lines from the start, so nothing
                        // below moves when the location arrives.
                        SizedBox(
                          width: 120,
                          height: 80,
                          child: Center(
                            child: Semantics(
                              liveRegion: true,
                              child: WarangStamp.place(
                                id: 'capture-${_capturedAt.microsecondsSinceEpoch}',
                                lines: _placeLines,
                                tone: WarangKeepsake.dagat,
                              ),
                            ),
                          ),
                        ),
                        WarangChip(
                          label: 'Saving to ${trip.title}',
                          tone: WarangKeepsake.forTrip(trip),
                          icon: WarangGlyphs.trips,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    WarangField(
                      label: 'Caption',
                      controller: _captionController,
                      multiline: true,
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      hintText: 'Say something (optional)',
                      // The caption is written on the polaroid, by hand.
                      style: WarangType.handL.copyWith(color: neutrals.ink),
                      hintStyle: WarangType.handL.copyWith(
                        color: neutrals.inkFaint,
                      ),
                    ),
                    const SizedBox(height: 18),
                    WarangButton.primary(
                      label: _saving ? 'Saving...' : 'Save',
                      onPressed: _saving ? null : _save,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Save now, caption later. One tap is enough.',
                      textAlign: TextAlign.center,
                      style: WarangType.meta.copyWith(color: neutrals.inkFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A `surface` clay pill, with an icon and a label (S3), for controls that
/// sit on the photo.
class _ClayPill extends StatelessWidget {
  const _ClayPill({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.semanticLabel,
  });

  final WarangGlyph icon;
  final String label;
  final VoidCallback? onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => ClayPressable(
    onPressed: onPressed,
    semanticLabel: semanticLabel,
    builder: (context, press) => ClaySurface(
      depth: ClayDepth.clay2,
      press: press,
      borderRadius: BorderRadius.circular(WarangRadius.pill),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                WarangIcon(icon, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: WarangType.button.copyWith(
                      color: WarangNeutrals.of(context).ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
