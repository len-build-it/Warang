import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/formatting.dart';
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
    this.tileStore,
    this.photoStore,
    this.dimmed = false,
    this.onDimmerTap,
    this.landingId,
    this.moving,
  });

  final List<Moment> moments;
  final String? selectedId;
  final MapPalette palette;
  final bool dark;
  final ValueChanged<Moment> onMomentTap;
  final VoidCallback? onMapTap;

  /// Shared stores from the composition root; the map creates and owns its
  /// own only when they are omitted.
  final MapTileStore? tileStore;
  final PhotoStore? photoStore;

  /// Dims the map under an open moment; the selected pin stays above the
  /// dimmer (S4). A tap on the dimmer calls [onDimmerTap].
  final bool dimmed;
  final VoidCallback? onDimmerTap;

  /// A just-saved moment whose pin lands with the C10 new-pin motion.
  final String? landingId;

  /// Set true while the user moves the map and false once it rests.
  final ValueNotifier<bool>? moving;

  @override
  WarangMapSurfaceState createState() => WarangMapSurfaceState();
}

class WarangMapSurfaceState extends State<WarangMapSurface> {
  late final MapTileStore _tileStore = widget.tileStore ?? MapTileStore();
  late final PhotoStore _photoStore = widget.photoStore ?? PhotoStore();
  final _mapController = MapController();
  Position? _position;
  DateTime? _staleSince;
  double _currentZoom = 5.8;
  Timer? _rest;

  /// Photo lookups, kept so panning never restarts them and pins never
  /// flash empty between frames.
  final _photos = <String, Future<File?>>{};

  /// Pins that already played their landing.
  final _landed = <String>{};

  /// Pins popping away after a delete, and pins springing back after undo.
  final _leaving = <String, Moment>{};
  final _returning = <String>{};

  @override
  void didUpdateWidget(covariant WarangMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final now = {for (final moment in widget.moments) moment.id};
    final before = {for (final moment in oldWidget.moments) moment.id: moment};
    final removedSelected = oldWidget.selectedId;
    if (removedSelected != null &&
        !now.contains(removedSelected) &&
        before[removedSelected]?.latitude != null) {
      _leaving[removedSelected] = before[removedSelected]!;
    }
    for (final id in now) {
      if (!before.containsKey(id) && _leaving.remove(id) != null) {
        _returning.add(id);
      }
    }
  }

  @override
  void dispose() {
    _rest?.cancel();
    if (widget.tileStore == null) _tileStore.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topOffset = math.max(MediaQuery.paddingOf(context).top, 12.0) + 8.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: 5.8,
            // Shown where no tile has loaded yet, such as offline areas.
            backgroundColor: widget.palette.land,
            minZoom: 2,
            maxZoom: 18,
            onTap: (_, _) => widget.onMapTap?.call(),
            onMapReady: _restoreCamera,
            onPositionChanged: (camera, hasGesture) {
              final zoomed = camera.zoom != _currentZoom;
              _currentZoom = camera.zoom;
              // Pins regroup when the app zooms, as well as the user.
              if (zoomed && !hasGesture && mounted) setState(() {});
              if (hasGesture) {
                widget.moving?.value = true;
                _rest?.cancel();
                _rest = Timer(const Duration(milliseconds: 180), () {
                  widget.moving?.value = false;
                });
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
                ..._momentMarkers(),
              ],
            ),
            if (widget.dimmed)
              SizedBox.expand(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onDimmerTap,
                  child: ColoredBox(
                    color: warangDimmer(Theme.of(context).brightness),
                  ),
                ),
              ),
            MarkerLayer(
              markers: [
                for (final moment in widget.moments)
                  if (moment.id == widget.selectedId &&
                      moment.latitude != null &&
                      moment.longitude != null)
                    _markerFor(moment),
                for (final moment in _leaving.values) _leavingMarker(moment),
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
        if (_staleSince != null)
          Positioned(
            top: topOffset + 54,
            left: 0,
            right: 0,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    'Map saved ${countLabel(_ageDays(_staleSince!), 'day')} ago',
                    style: WarangType.caption.copyWith(
                      color: WarangNeutrals.of(context).inkFaint,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  int _ageDays(DateTime fetchedAt) {
    final days = DateTime.now().difference(fetchedAt).inDays;
    return math.max(1, days);
  }

  List<Marker> _momentMarkers() {
    // The selected pin is drawn on its own layer, above any dimmer.
    final moments = momentsWithMapCoordinates(
      widget.moments,
    ).where((moment) => moment.id != widget.selectedId).toList();
    final groups = <List<Moment>>[];
    final threshold = (70000 / math.pow(2, _currentZoom - 4))
        .clamp(2500, 70000)
        .toDouble();
    const distance = Distance();
    for (final moment in moments) {
      final point = LatLng(moment.latitude!, moment.longitude!);
      final group = groups.cast<List<Moment>?>().firstWhere((candidate) {
        if (candidate == null || candidate.isEmpty) return false;
        final origin = candidate.first;
        return distance.as(
              LengthUnit.Meter,
              LatLng(origin.latitude!, origin.longitude!),
              point,
            ) <=
            threshold;
      }, orElse: () => null);
      if (group == null) {
        groups.add([moment]);
      } else {
        group.add(moment);
      }
    }
    return [
      for (final group in groups)
        if (group.length == 1)
          _markerFor(group.single)
        else
          _clusterMarker(group),
    ];
  }

  Marker _clusterMarker(List<Moment> group) {
    final latitude =
        group.map((moment) => moment.latitude!).reduce((a, b) => a + b) /
        group.length;
    final longitude =
        group.map((moment) => moment.longitude!).reduce((a, b) => a + b) /
        group.length;
    return Marker(
      point: LatLng(latitude, longitude),
      width: WarangClusterPin.size,
      height: WarangClusterPin.size + WarangPhotoPin.pointerRoom,
      alignment: Alignment.topCenter,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          label: '${countLabel(group.length, 'moment')}, zoom in',
          child: GestureDetector(
            onTap: () => _mapController.move(
              LatLng(latitude, longitude),
              _currentZoom + 2,
            ),
            child: ExcludeSemantics(
              child: WarangClusterPin(count: group.length),
            ),
          ),
        ),
      ),
    );
  }

  LatLng get _initialCenter {
    final withCoordinates =
        widget.moments
            .where(
              (moment) => moment.latitude != null && moment.longitude != null,
            )
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

  /// The point under the centre of the map, used for manual pin placement.
  ({double latitude, double longitude}) get center {
    final point = _mapController.camera.center;
    return (latitude: point.latitude, longitude: point.longitude);
  }

  void moveToCoordinate(
    double latitude,
    double longitude, [
    double zoom = 15.0,
  ]) => _mapController.move(LatLng(latitude, longitude), zoom);

  /// Keeps a selected pin in the visible strip from [top] to [bottom], as
  /// above the moment card (S4).
  ///
  /// With a [zoom], the pin moves to the middle of the strip at that zoom.
  /// Without one the map moves only if the pin would be hidden, keeping the
  /// zoom: opening a pin that is already in view never moves the map.
  void showPinBetween(
    LatLng point, {
    required double top,
    required double bottom,
    double? zoom,
  }) {
    final camera = _mapController.camera;
    final view = camera.nonRotatedSize;
    const width = WarangPhotoPin.selectedSize;
    const height = width + WarangPhotoPin.pointerRoom;
    var x = view.width / 2;
    if (zoom == null) {
      final tip = camera.latLngToScreenOffset(point);
      final acrossInView =
          tip.dx >= width / 2 && tip.dx <= view.width - width / 2;
      if (acrossInView && tip.dy - height >= top && tip.dy <= bottom) return;
      if (acrossInView) x = tip.dx;
    }
    // The tip is the point, so it sits half a pin below the strip's middle.
    final y = (top + bottom + height) / 2;
    _mapController.move(
      point,
      zoom ?? camera.zoom,
      offset: Offset(x - view.width / 2, y - view.height / 2),
    );
  }

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
    final size = selected ? WarangPhotoPin.selectedSize : WarangPhotoPin.size;
    final caption = moment.caption?.trim() ?? '';
    final name = caption.isEmpty
        ? formatMomentTime(moment.capturedAt)
        : caption;
    Widget pin = MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Pin, $name',
        child: FutureBuilder<File?>(
          future: _photoFile(moment),
          builder: (context, snapshot) => GestureDetector(
            onTap: () => widget.onMomentTap(moment),
            child: ExcludeSemantics(
              child: WarangPhotoPin(file: snapshot.data, selected: selected),
            ),
          ),
        ),
      ),
    );
    if (selected) {
      pin = _PinPop(
        key: ValueKey('selected-${moment.id}'),
        from: WarangPhotoPin.size / WarangPhotoPin.selectedSize,
        child: pin,
      );
    } else if (_returning.remove(moment.id)) {
      pin = _PinPop(key: ValueKey('return-${moment.id}'), from: 0, child: pin);
    }
    if (moment.id == widget.landingId &&
        (_landed.add(moment.id) || _landing.contains(moment.id))) {
      _landing.add(moment.id);
      pin = LandingPin(
        key: ValueKey('land-${moment.id}'),
        onLanded: () => _landing.remove(moment.id),
        child: pin,
      );
    }
    return Marker(
      point: LatLng(moment.latitude!, moment.longitude!),
      width: size,
      height: size + WarangPhotoPin.pointerRoom,
      // The pointer's tip sits on the moment's spot.
      alignment: Alignment.topCenter,
      child: pin,
    );
  }

  /// Pins whose landing is still playing, so rebuilds keep the animation.
  final _landing = <String>{};

  Marker _leavingMarker(Moment moment) => Marker(
    point: LatLng(moment.latitude!, moment.longitude!),
    width: WarangPhotoPin.selectedSize,
    height: WarangPhotoPin.selectedSize + WarangPhotoPin.pointerRoom,
    alignment: Alignment.topCenter,
    child: _PinLeave(
      key: ValueKey('leave-${moment.id}'),
      onDone: () {
        if (mounted) setState(() => _leaving.remove(moment.id));
      },
      child: FutureBuilder<File?>(
        future: _photoFile(moment),
        builder: (context, snapshot) =>
            WarangPhotoPin(file: snapshot.data, selected: true),
      ),
    ),
  );

  Future<File?> _photoFile(Moment moment) {
    final relativePath = moment.thumbRelPath ?? moment.relPath;
    if (relativePath == null) return Future<File?>.value();
    return _photos.putIfAbsent(relativePath, () async {
      final file = await _photoStore.resolve(relativePath);
      return await file.exists() ? file : null;
    });
  }
}

/// The C10 new pin: it drops from 40 above its spot with `pop`, leaves a
/// clay splat ring that fades over 300 ms, and taps a light haptic as it
/// lands. Under reduced motion it fades in.
class LandingPin extends StatefulWidget {
  const LandingPin({super.key, required this.child, this.onLanded});
  final Widget child;
  final VoidCallback? onLanded;

  @override
  State<LandingPin> createState() => _LandingPinState();
}

class _LandingPinState extends State<LandingPin> with TickerProviderStateMixin {
  late final AnimationController _drop = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _splat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  Timer? _touchdown;
  bool _started = false;
  bool _reduced = false;

  /// True while the pin is still falling or the splat is fading.
  bool get animating => _drop.isAnimating || _splat.isAnimating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = WarangMotion.reduced(context);
    if (_reduced) {
      _drop
          .animateTo(1, duration: WarangMotion.fade, curve: Curves.linear)
          .whenComplete(() => widget.onLanded?.call());
      return;
    }
    _drop
        .animateWith(WarangMotion.pop.simulate(0, 1))
        .whenComplete(() => widget.onLanded?.call());
    // The pin first touches its spot about a third of the way through.
    _touchdown = Timer(WarangMotion.pop.duration * .35, () {
      if (!mounted) return;
      WarangHaptic.light.play();
      _splat.forward();
    });
  }

  @override
  void dispose() {
    _touchdown?.cancel();
    _drop.dispose();
    _splat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = WarangKeepsake.amber.fill;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_drop, _splat]),
        builder: (context, child) {
          if (_reduced) {
            return Opacity(opacity: _drop.value.clamp(0.0, 1.0), child: child);
          }
          final splat = _splat.value;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              if (splat > 0 && splat < 1)
                Positioned(
                  bottom: -8 - 10 * splat,
                  child: IgnorePointer(
                    child: Container(
                      width: 20 + 40 * splat,
                      height: (20 + 40 * splat) * .4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: ring.withValues(alpha: 1 - splat),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(0, -40 * (1 - _drop.value)),
                child: child,
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A pin growing into place with the `pop` spring, from [from] of its size.
class _PinPop extends StatelessWidget {
  const _PinPop({super.key, required this.from, required this.child});
  final double from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = WarangMotion.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced && from > 0 ? 1 : from, end: 1),
      duration: reduced ? WarangMotion.fade : WarangMotion.pop.duration,
      curve: reduced ? Curves.linear : WarangMotion.pop.curve,
      builder: (context, value, child) => reduced
          ? Opacity(opacity: value.clamp(0.0, 1.0), child: child)
          : Transform.scale(
              scale: value,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
      child: child,
    );
  }
}

/// A deleted pin popping away (or fading under reduced motion).
class _PinLeave extends StatelessWidget {
  const _PinLeave({super.key, required this.onDone, required this.child});
  final VoidCallback onDone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = WarangMotion.reduced(context);
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: reduced
            ? WarangMotion.fade
            : const Duration(milliseconds: 220),
        curve: reduced ? Curves.linear : Curves.easeInBack,
        onEnd: onDone,
        builder: (context, value, child) => reduced
            ? Opacity(opacity: value.clamp(0.0, 1.0), child: child)
            : Transform.scale(
                scale: value.clamp(0.0, 1.2),
                alignment: Alignment.bottomCenter,
                child: child,
              ),
        child: child,
      ),
    );
  }
}

Iterable<Moment> momentsWithMapCoordinates(Iterable<Moment> moments) => moments
    .where((moment) => moment.latitude != null && moment.longitude != null);

ColorFilter _mapFilter(bool dark) => ColorFilter.matrix(
  dark
      ? const [
          .26,
          .58,
          .16,
          0,
          0,
          .24,
          .54,
          .14,
          0,
          0,
          .18,
          .42,
          .12,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]
      : const [
          .62,
          .34,
          .04,
          0,
          8,
          .56,
          .38,
          .06,
          0,
          8,
          .48,
          .34,
          .08,
          0,
          4,
          0,
          0,
          0,
          1,
          0,
        ],
);
