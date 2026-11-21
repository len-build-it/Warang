import 'dart:io';
import 'dart:math' as math;

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

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _captionController = TextEditingController();
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

  String get _locationLine {
    final time = formatTime(_capturedAt);
    final position = _position;
    return switch (_location) {
      _LocationState.locating => 'Locating… · $time',
      _LocationState.located =>
        '${formatCoordinates(position!.latitude, position.longitude)} · $time',
      _LocationState.unavailable => 'No location yet · $time',
    };
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;
    final safeTop = math.max(topPadding, 12.0) + 8.0;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final photoHeight = (screenHeight * 0.45).clamp(220.0, 480.0);

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
                    _photo == null
                        ? ColoredBox(
                            color:
                                theme.extension<MapPalette>()?.landAlt ??
                                theme.colorScheme.surfaceContainerHighest,
                          )
                        : Image.file(
                            File(_photo!.path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, _) => ColoredBox(
                              color:
                                  theme.extension<MapPalette>()?.landAlt ??
                                  theme.colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: WarangIcon(WarangGlyphs.photo, size: 36),
                              ),
                            ),
                          ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: safeTop + 48,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.55),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: safeTop,
                      left: 16,
                      child: Semantics(
                        button: true,
                        label: 'Retake photograph',
                        child: InkWell(
                          onTap: _openCamera,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                WarangIcon(
                                  WarangGlyphs.refresh,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Retake',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: safeTop,
                      right: 16,
                      child: Semantics(
                        button: true,
                        label: 'Cancel capture',
                        child: InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.55),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const WarangIcon(
                              WarangGlyphs.close,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: WarangMetadata(_locationLine),
                    ),
                    const SizedBox(height: 6),
                    WarangMetadata(
                      'Saving to ${ref.watch(repositoryProvider).tripForCapture(_capturedAt).title}',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _captionController,
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      decoration:
                          warangInputDecoration(
                            context,
                            hintText: 'Say something (optional)',
                          ).copyWith(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        color: WarangNeutrals.of(context).inkFaint,
                      ),
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
