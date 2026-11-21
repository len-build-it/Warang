import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

/// Device adapters for the capture flow. Each is a plain function so tests
/// can substitute a fake camera, permission answer, or location fix.

typedef CameraPicker = Future<XFile?> Function();
typedef LocationPermissionCheck = Future<LocationPermission> Function();
typedef LocationReader =
    Future<({double latitude, double longitude})?> Function();

final cameraPickerProvider = Provider<CameraPicker>((ref) {
  final picker = ImagePicker();
  return () => picker.pickImage(
    source: ImageSource.camera,
    maxWidth: 2000,
    imageQuality: 85,
  );
});

final locationPermissionProvider = Provider<LocationPermissionCheck>(
  (ref) => () async {
    final current = await Geolocator.checkPermission();
    return current == LocationPermission.denied
        ? Geolocator.requestPermission()
        : current;
  },
);

/// One-shot location read; null when permission or a fix is unavailable.
final locationReaderProvider = Provider<LocationReader>((ref) {
  final checkPermission = ref.watch(locationPermissionProvider);
  return () async {
    try {
      final permission = await checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      // Location is optional; a capture never waits for it or fails without it.
      return null;
    }
  };
});
