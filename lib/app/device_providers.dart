import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

/// Device adapters for the capture flow. Each is a plain function so tests
/// can substitute a fake camera, permission answer, or location fix.

typedef CameraPicker = Future<XFile?> Function();
typedef GalleryPicker = Future<XFile?> Function();
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

/// Checks that device location services are enabled and permission is granted.
/// Returns `null` when location services are disabled, or the resolved
/// [LocationPermission] otherwise. When [onRationale] is provided and the
/// current permission is [LocationPermission.denied], it is called before
/// requesting permission; returning `false` cancels the request.
Future<LocationPermission?> checkLocationAccess({
  Future<bool> Function()? onRationale,
  Future<bool> Function()? isServiceEnabled,
  Future<LocationPermission> Function()? checkPermission,
  Future<LocationPermission> Function()? requestPermission,
}) async {
  final serviceEnabled =
      await (isServiceEnabled ?? Geolocator.isLocationServiceEnabled)();
  if (!serviceEnabled) return null;
  var permission = await (checkPermission ?? Geolocator.checkPermission)();
  if (permission == LocationPermission.denied) {
    if (onRationale != null && !await onRationale()) {
      return LocationPermission.denied;
    }
    permission = await (requestPermission ?? Geolocator.requestPermission)();
  }
  return permission;
}

final cameraPickerProvider = Provider<CameraPicker>((ref) {
  final picker = ImagePicker();
  return () => picker.pickImage(
    source: ImageSource.camera,
    maxWidth: 2000,
    imageQuality: 85,
  );
});

final galleryPickerProvider = Provider<GalleryPicker>((ref) {
  final picker = ImagePicker();
  return () => picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 88,
  );
});

final locationPermissionProvider = Provider<LocationPermissionCheck>(
  (ref) => () async {
    final permission = await checkLocationAccess();
    return permission ?? LocationPermission.denied;
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
    } on Exception catch (_) {
      // Location is optional; a capture never waits for it or fails without it.
      return null;
    }
  };
});
