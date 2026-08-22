import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
  State<WarangMapSurface> createState() => _WarangMapSurfaceState();
}

class _WarangMapSurfaceState extends State<WarangMapSurface> {
  late final MapTileStore _tileStore = MapTileStore();
  final _photoStore = PhotoStore();

  @override
  void dispose() {
    _tileStore.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColorFiltered(
    colorFilter: _mapFilter(widget.dark),
    child: FlutterMap(
      options: MapOptions(
        initialCenter: const LatLng(11.55, 122.0),
        initialZoom: 5.8,
        minZoom: 2,
        maxZoom: 18,
        onTap: (_, _) => widget.onMapTap?.call(),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'ph.warang.app',
          tileProvider: CachedTileProvider(
            store: _tileStore,
            layerId: 'osm-standard',
          ),
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            for (final moment in widget.moments)
              if (moment.latitude != null && moment.longitude != null)
                _markerFor(moment),
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
