import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/app.dart';
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
      /* GPS is optional. */
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
          placeLabel: _position == null ? null : 'Current location',
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Save moment'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close),
        ),
      ),
      body: photo == null
          ? const Center(
              child: CircularProgressIndicator(color: WarangColors.accent),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(photo.path),
                    height: 400,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _captionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Say something (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${_position == null ? 'Location not found' : 'Current location'}  ·  ${TimeOfDay.now().format(context)}',
                  style: const TextStyle(fontFamily: 'DM Mono', fontSize: 12),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: WarangColors.accent,
                    foregroundColor: WarangColors.accentInk,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ],
            ),
    );
  }
}
