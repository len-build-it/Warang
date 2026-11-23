import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

/// Device adapters for the capture flow. Each is a plain function so tests
/// can substitute a fake camera, permission answer, or location fix.

typedef CameraPicker = Future<XFile?> Function();
typedef LocationPermissionCheck = Future<LocationPermission> Function();

/// A single GPS fix with optional horizontal accuracy in metres.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    this.accuracyM,
  });

  final double latitude;
  final double longitude;
  final double? accuracyM;
}

typedef LocationReader = Future<LocationFix?> Function();

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
      return LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy.isFinite ? position.accuracy : null,
      );
    } catch (_) {
      // Location is optional; a capture never waits for it or fails without it.
      return null;
    }
  };
});
