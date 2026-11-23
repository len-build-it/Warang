import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/place_categories.dart';
import '../../data/files/photo_store.dart';
import '../../data/places/place_book.dart';
import 'map_tile_store.dart';

class WarangMapSurface extends StatefulWidget {
  const WarangMapSurface({
    super.key,
    required this.moments,
    required this.selectedId,
    this.placingId,
    this.tripRings = const {},
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
    this.markedPlace,
    this.onClearMarkedPlace,
    this.onUserPan,
  });

  final List<Moment> moments;
  final String? selectedId;

  /// The moment whose pin is being placed. The centre pin stands for it, and
  /// no other pin opens until placement ends.
  final String? placingId;

  /// Each trip's fill, by trip id, for its pins' rings (C10). Everyday is
  /// absent and draws `surface`.
  final Map<String, Color> tripRings;
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

  /// A place chosen from map search (FEAT-004 F1), shown as a stamp marker.
  final BookPlace? markedPlace;
  final VoidCallback? onClearMarkedPlace;

  /// Called when the user pans or zooms the map by gesture.
  final VoidCallback? onUserPan;

  @override
  WarangMapSurfaceState createState() => WarangMapSurfaceState();
}

class WarangMapSurfaceState extends State<WarangMapSurface>
    with SingleTickerProviderStateMixin {
  late final MapTileStore _tileStore = widget.tileStore ?? MapTileStore();
  late final PhotoStore _photoStore = widget.photoStore ?? PhotoStore();
  final _mapController = MapController();
  AnimationController? _moveAnim;
  Position? _position;
  DateTime? _staleSince;
  double _currentZoom = 5.8;
  Timer? _rest;
  bool _markedPlaceUncached = false;

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
    if (widget.markedPlace != oldWidget.markedPlace) {
      _checkMarkedPlaceTile();
    }
  }

  Future<void> _checkMarkedPlaceTile() async {
    final place = widget.markedPlace;
    if (place == null) {
      if (_markedPlaceUncached && mounted) {
        setState(() => _markedPlaceUncached = false);
      }
      return;
    }
    final coords = tileCoordsForLatLng(place.latLng, 16);
    final cached = await _tileStore.hasTile(16, coords.x, coords.y);
    if (!mounted || widget.markedPlace != place) return;
    setState(() => _markedPlaceUncached = !cached);
  }

  @override
  void initState() {
    super.initState();
    if (widget.markedPlace != null) {
      _checkMarkedPlaceTile();
    }
  }

  @override
  void dispose() {
    _moveAnim?.dispose();
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
            maxZoom: _maxZoom,
            onTap: (_, _) => widget.onMapTap?.call(),
            onMapReady: _restoreCamera,
            onPositionChanged: (camera, hasGesture) {
              final zoomed = camera.zoom != _currentZoom;
              _currentZoom = camera.zoom;
              // Pins regroup when the app zooms, as well as the user.
              if (zoomed && !hasGesture && mounted) setState(() {});
              if (hasGesture) {
                widget.onUserPan?.call();
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
                // Tiles fade in, except under reduced motion (V6 rule 2).
                tileDisplay: WarangMotion.reduced(context)
                    ? const TileDisplay.instantaneous()
                    : const TileDisplay.fadeIn(),
              ),
            ),
            MarkerLayer(
              markers: [
                if (_position != null) _positionMarker(_position!),
                ..._momentMarkers(),
                if (widget.markedPlace != null)
                  _placeMarker(widget.markedPlace!),
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
    final moments = momentsWithMapCoordinates(widget.moments).where(
      (moment) =>
          moment.id != widget.selectedId && moment.id != widget.placingId,
    );
    return [
      for (final group in _groupByOverlap(moments, _currentZoom))
        if (group.moments.length == 1)
          _markerFor(group.moments.single)
        else
          _clusterMarker(group),
    ];
  }

  static const _maxZoom = 18.0;

  /// Zooms toward a cluster's pins. At full zoom they can never come apart,
  /// so it opens the newest of them, and swiping reaches the rest.
  void _openCluster(_PinGroup group, LatLng point) {
    if (_currentZoom < _maxZoom) {
      _mapController.move(point, math.min(_currentZoom + 2, _maxZoom));
      return;
    }
    if (widget.placingId != null) return;
    widget.onMomentTap(
      group.moments.reduce(
        (a, b) => a.capturedAt.isAfter(b.capturedAt) ? a : b,
      ),
    );
  }

  /// A cluster of one trip takes that trip's fill; any other is amber.
  Color? _clusterRing(_PinGroup group) {
    final tripIds = {for (final moment in group.moments) moment.tripId};
    return tripIds.length == 1 ? widget.tripRings[tripIds.single] : null;
  }

  Marker _clusterMarker(_PinGroup group) {
    final point = _projection.offsetToLatLng(group.centre, _currentZoom);
    return Marker(
      point: point,
      width: WarangClusterPin.size,
      height: WarangClusterPin.size + WarangPhotoPin.pointerRoom,
      alignment: Alignment.topCenter,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          label: '${countLabel(group.moments.length, 'moment')}, zoom in',
          child: GestureDetector(
            onTap: () => _openCluster(group, point),
            child: ExcludeSemantics(
              child: WarangClusterPin(
                count: group.moments.length,
                ringColor: _clusterRing(group),
              ),
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

  /// Moves the map to [point] at [zoom] using the FEAT-003 spring, or jumps
  /// immediately with no animation frames under reduced motion (FEAT-004 F1).
  void moveToPlace(LatLng point, {double zoom = 16.0}) {
    _moveAnim?.stop();
    if (WarangMotion.reduced(context)) {
      _mapController.move(point, zoom);
      return;
    }
    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
    final controller = _moveAnim ??= AnimationController(
      vsync: this,
      duration: WarangMotion.sheet.duration,
    );
    controller.reset();
    void tick() {
      if (!mounted) return;
      final t = WarangMotion.sheet.settleCurve.transform(controller.value);
      _mapController.move(
        LatLng(
          startCenter.latitude + (point.latitude - startCenter.latitude) * t,
          startCenter.longitude + (point.longitude - startCenter.longitude) * t,
        ),
        startZoom + (zoom - startZoom) * t,
      );
    }

    controller
      ..removeListener(tick)
      ..addListener(tick);
    controller.forward().whenComplete(() => controller.removeListener(tick));
  }

  Marker _placeMarker(BookPlace place) {
    final category =
        PlaceCategories.byKey(place.category) ?? PlaceCategories.town;
    final neutrals = WarangNeutrals.of(context);
    return Marker(
      point: place.latLng,
      width: 260,
      height: _markedPlaceUncached ? 108 : 82,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClaySurface(
            depth: ClayDepth.clay2,
            borderRadius: BorderRadius.circular(WarangRadius.control),
            outline: BorderSide(color: neutrals.boundary),
            padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CategoryDisc(category: category, size: 32),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WarangType.titleS.copyWith(color: neutrals.ink),
                      ),
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WarangType.meta.copyWith(
                          color: neutrals.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close place marker',
                  onPressed: widget.onClearMarkedPlace,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const WarangIcon(WarangGlyphs.close, size: 18),
                ),
              ],
            ),
          ),
          if (_markedPlaceUncached) ...[
            const SizedBox(height: 4),
            ClaySurface(
              depth: ClayDepth.clay1,
              borderRadius: BorderRadius.circular(WarangRadius.chip),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Text(
                'Map not saved here yet',
                style: WarangType.caption.copyWith(color: neutrals.inkSoft),
              ),
            ),
          ],
        ],
      ),
    );
  }

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
    final opens = widget.placingId == null;
    final size = selected ? WarangPhotoPin.selectedSize : WarangPhotoPin.size;
    final caption = moment.caption?.trim() ?? '';
    final name = caption.isEmpty
        ? formatMomentTime(moment.capturedAt)
        : caption;
    Widget pin = MergeSemantics(
      child: Semantics(
        button: opens,
        selected: selected,
        label: 'Pin, $name',
        child: FutureBuilder<File?>(
          future: _photoFile(moment),
          builder: (context, snapshot) => GestureDetector(
            onTap: opens ? () => widget.onMomentTap(moment) : null,
            child: ExcludeSemantics(
              child: WarangPhotoPin(
                file: snapshot.data,
                selected: selected,
                ringColor: widget.tripRings[moment.tripId],
              ),
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
        builder: (context, snapshot) => WarangPhotoPin(
          file: snapshot.data,
          selected: true,
          ringColor: widget.tripRings[moment.tripId],
        ),
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

const _projection = Epsg3857();

/// Moments drawn as one marker, with their centre in screen pixels at the
/// zoom they were grouped for.
class _PinGroup {
  _PinGroup(this.moments, this.centre);

  final List<Moment> moments;
  Offset centre;

  void absorb(_PinGroup other) {
    final total = moments.length + other.moments.length;
    centre += (other.centre - centre) * (other.moments.length / total);
    moments.addAll(other.moments);
  }
}

/// Groups only the pins that would overlap at [zoom], so clusters come
/// apart as the map zooms in. A merge moves a group's centre, so it repeats
/// until no two markers overlap. Panning never changes the groups.
List<_PinGroup> _groupByOverlap(Iterable<Moment> moments, double zoom) {
  const apart = WarangPhotoPin.size + WarangPhotoPin.pointerRoom;
  var groups = [
    for (final moment in moments)
      _PinGroup(
        [moment],
        _projection.latLngToOffset(
          LatLng(moment.latitude!, moment.longitude!),
          zoom,
        ),
      ),
  ];
  while (true) {
    final kept = <_PinGroup>[];
    for (final group in groups) {
      final near = kept.indexWhere(
        (other) => (other.centre - group.centre).distance < apart,
      );
      if (near < 0) {
        kept.add(group);
      } else {
        kept[near].absorb(group);
      }
    }
    if (kept.length == groups.length) return kept;
    groups = kept;
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
