import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/app.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../data/files/photo_store.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  final _photoStore = PhotoStore();
  XFile? _photo;
  Position? _position;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _openCamera();
    _getPosition();
  }

  Future<void> _openCamera() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (!mounted) return;
    if (photo == null) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _photo = photo);
  }

  Future<void> _getPosition() async {
    final permission = await Permission.location.request();
    if (!permission.isGranted) return;
    try {
      _position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      );
    } catch (_) {
      // Location is optional; a capture must never wait for it or fail without it.
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final photo = _photo;
    if (photo == null || _saving) return;
    setState(() => _saving = true);
    final relative = await _photoStore.importPhoto(File(photo.path));
    await ref
        .read(repositoryProvider)
        .addMoment(
          caption: _captionController.text,
          latitude: _position?.latitude,
          longitude: _position?.longitude,
          relPath: relative,
          capturedAt: DateTime.now(),
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 520,
            child: _photo == null
                ? ColoredBox(
                    color: Theme.of(context).extension<MapPalette>()!.landAlt,
                  )
                : Image.file(File(_photo!.path), fit: BoxFit.cover),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: SizedBox(
                height: 96,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .42),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 62,
            left: 20,
            child: GestureDetector(
              onTap: _openCamera,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: WarangColors.lightInk.withValues(alpha: .50),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  child: Text(
                    'Retake',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: WarangColors.lightSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 520,
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WarangMetadata(DateFormat('h:mm a').format(DateTime.now())),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _captionController,
                      minLines: 4,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          warangInputDecoration(
                            context,
                            hintText: 'Say something (optional)',
                          ).copyWith(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 17,
                              vertical: 15,
                            ),
                          ),
                    ),
                    const SizedBox(height: 18),
                    WarangPrimaryButton(
                      label: _saving ? 'Saving…' : 'Save',
                      onPressed: _saving ? null : _save,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Save now, caption later. One tap is enough.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
