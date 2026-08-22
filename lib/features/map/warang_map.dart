import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/models.dart';
import '../../data/files/photo_store.dart';
import 'map_tile_store.dart';

class WarangMapSurface extends StatefulWidget {
  const WarangMapSurface({
    super.key,
    required this.moments,
    required this.selectedId,
    required this.palette,
    required this.dark,
    required this.onMomentTap,
    this.onMapTap,
  });

  final List<Moment> moments;
  final String? selectedId;
  final MapPalette palette;
  final bool dark;
  final ValueChanged<Moment> onMomentTap;
  final VoidCallback? onMapTap;

  @override
  WarangMapSurfaceState createState() => WarangMapSurfaceState();
}

class WarangMapSurfaceState extends State<WarangMapSurface> {
  late final MapTileStore _tileStore = MapTileStore();
  final _photoStore = PhotoStore();
  final _mapController = MapController();
  Position? _position;
  DateTime? _staleSince;
  double _currentZoom = 5.8;
  bool _showMoments = true;
  bool _showClusters = true;

  @override
  void dispose() {
    _tileStore.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      FlutterMap(
        mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: 5.8,
        minZoom: 2,
        maxZoom: 18,
        onTap: (_, _) => widget.onMapTap?.call(),
        onMapReady: _restoreCamera,
        onPositionChanged: (camera, hasGesture) {
          _currentZoom = camera.zoom;
          if (hasGesture) {
            unawaited(_tileStore.saveCamera(camera.center, camera.zoom));
            if (mounted) setState(() {});
          }
        },
      ),
      children: [
        ColorFiltered(
          colorFilter: _mapFilter(widget.dark),
          child: TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'ph.warang.app',
            tileProvider: CachedTileProvider(
              store: _tileStore,
              layerId: 'osm-standard',
              onStaleTile: (fetchedAt) {
                if (mounted) setState(() => _staleSince = fetchedAt);
              },
            ),
            maxZoom: 19,
          ),
        ),
        MarkerLayer(
          markers: [
            if (_position != null) _positionMarker(_position!),
            if (_showMoments || _showClusters) ..._momentMarkers(),
          ],
        ),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () {},
            ),
          ],
        ),
      ],
      ),
      Positioned(
        top: 52,
        right: 16,
        child: PopupMenuButton<String>(
          tooltip: 'Map layers',
          onSelected: (value) {
            setState(() {
              if (value == 'moments') _showMoments = !_showMoments;
              if (value == 'clusters') _showClusters = !_showClusters;
            });
          },
          itemBuilder: (context) => [
            CheckedPopupMenuItem(
              value: 'moments',
              checked: _showMoments,
              child: const Text('Your moments'),
            ),
            CheckedPopupMenuItem(
              value: 'clusters',
              checked: _showClusters,
              child: const Text('Clusters'),
            ),
            const PopupMenuItem(enabled: false, child: Text('Base map')),
          ],
          child: Material(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.layers_outlined, size: 20),
            ),
          ),
        ),
      ),
      if (_staleSince != null)
        Positioned(
          top: 105,
          left: 0,
          right: 0,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text(
                  'MAP · CACHED ${_ageDays(_staleSince!)} DAYS AGO',
                  style: TextStyle(
                    fontFamily: 'DM Mono',
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .54),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  int _ageDays(DateTime fetchedAt) {
    final days = DateTime.now().difference(fetchedAt).inDays;
    return math.max(1, days);
  }

  List<Marker> _momentMarkers() {
    final moments = momentsWithMapCoordinates(widget.moments).toList();
    final groups = <List<Moment>>[];
    final threshold = (70000 / math.pow(2, _currentZoom - 4))
        .clamp(2500, 70000)
        .toDouble();
    const distance = Distance();
    for (final moment in moments) {
      final point = LatLng(moment.latitude!, moment.longitude!);
      final group = groups.cast<List<Moment>?>().firstWhere(
        (candidate) {
          if (candidate == null || candidate.isEmpty) return false;
          final origin = candidate.first;
          return distance.as(
                LengthUnit.Meter,
                LatLng(origin.latitude!, origin.longitude!),
                point,
              ) <=
              threshold;
        },
        orElse: () => null,
      );
      if (group == null) {
        groups.add([moment]);
      } else {
        group.add(moment);
      }
    }
    return [
      for (final group in groups)
        if (group.length == 1 && _showMoments) _markerFor(group.single)
        else if (group.length > 1 && _showClusters) _clusterMarker(group),
    ];
  }

  Marker _clusterMarker(List<Moment> group) {
    final latitude = group.map((moment) => moment.latitude!).reduce((a, b) => a + b) / group.length;
    final longitude = group.map((moment) => moment.longitude!).reduce((a, b) => a + b) / group.length;
    return Marker(
      point: LatLng(latitude, longitude),
      width: 52,
      height: 52,
      child: GestureDetector(
        onTap: () => _mapController.move(LatLng(latitude, longitude), _currentZoom + 2),
        child: WarangClusterPin(count: group.length),
      ),
    );
  }

  LatLng get _initialCenter {
    final withCoordinates = widget.moments
        .where((moment) => moment.latitude != null && moment.longitude != null)
        .toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    final latest = withCoordinates.isEmpty ? null : withCoordinates.first;
    return latest == null
        ? const LatLng(11.55, 122.0)
        : LatLng(latest.latitude!, latest.longitude!);
  }

  void _restoreCamera() => unawaited(_restoreCameraAsync());

  Future<void> _restoreCameraAsync() async {
    final saved = await _tileStore.loadCamera();
    final cachedLocation = await _tileStore.loadLocation();
    if (!mounted) return;
    if (cachedLocation != null) {
      setState(() {
        _position = _positionFromCached(cachedLocation);
      });
    }
    if (saved != null) _mapController.move(saved.center, saved.zoom);
    await _refreshLocation(moveToUser: saved == null);
  }

  Future<void> recenter() => _refreshLocation(moveToUser: true);

  Future<void> _refreshLocation({required bool moveToUser}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        final explain = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Place moments on your map'),
            content: const Text(
              'Warang uses your location once to place a moment. It never tracks you in the background.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (explain != true || !mounted) return;
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      final center = LatLng(position.latitude, position.longitude);
      await _tileStore.saveLocation(
        center: center,
        accuracy: position.accuracy,
      );
      if (!mounted) return;
      setState(() => _position = position);
      if (moveToUser) _mapController.move(center, 14);
    } catch (_) {
      // Location is an enhancement; a denial or unavailable fix never blocks
      // the map or the rest of the offline-first app.
    }
  }

  Position _positionFromCached(MapLocationSnapshot location) => Position(
    longitude: location.center.longitude,
    latitude: location.center.latitude,
    timestamp: location.updatedAt,
    accuracy: location.accuracy ?? 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  Marker _positionMarker(Position position) => Marker(
    point: LatLng(position.latitude, position.longitude),
    width: 76,
    height: 76,
    child: const WarangPositionMarker(),
  );

  Marker _markerFor(Moment moment) {
    final selected = moment.id == widget.selectedId;
    final size = selected ? 66.0 : 58.0;
    return Marker(
      point: LatLng(moment.latitude!, moment.longitude!),
      width: size,
      height: size + 9,
      child: FutureBuilder<File?>(
        future: _photoFile(moment.relPath),
        builder: (context, snapshot) => GestureDetector(
          onTap: () => widget.onMomentTap(moment),
          child: WarangPhotoPin(file: snapshot.data, selected: selected),
        ),
      ),
    );
  }

  Future<File?> _photoFile(String? relativePath) async {
    if (relativePath == null) return null;
    final file = await _photoStore.resolve(relativePath);
    return await file.exists() ? file : null;
  }
}

Iterable<Moment> momentsWithMapCoordinates(Iterable<Moment> moments) =>
    moments.where(
      (moment) => moment.latitude != null && moment.longitude != null,
    );

ColorFilter _mapFilter(bool dark) => ColorFilter.matrix(
  dark
      ? const [
          .26, .58, .16, 0, 0,
          .24, .54, .14, 0, 0,
          .18, .42, .12, 0, 0,
          0, 0, 0, 1, 0,
        ]
      : const [
          .62, .34, .04, 0, 8,
          .56, .38, .06, 0, 8,
          .48, .34, .08, 0, 4,
          0, 0, 0, 1, 0,
        ],
);
