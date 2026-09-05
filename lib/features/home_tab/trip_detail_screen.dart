import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/models.dart';
import '../../data/files/photo_store.dart';

class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({
    super.key,
    required this.trip,
    required this.moments,
    this.photoStore,
  });

  final Trip trip;
  final List<Moment> moments;
  final PhotoStore? photoStore;

  Moment? _findCoverMoment() {
    if (trip.coverMomentId != null) {
      for (final moment in moments) {
        if (moment.id == trip.coverMomentId &&
            (moment.relPath != null || moment.thumbRelPath != null)) {
          return moment;
        }
      }
    }
    for (final moment in moments) {
      if (moment.relPath != null || moment.thumbRelPath != null) {
        return moment;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dates = trip.startDate == null
        ? 'NO DATES'
        : '${DateFormat('dd MMM yyyy').format(trip.startDate!).toUpperCase()}${trip.endDate == null ? '' : ' - ${DateFormat('dd MMM yyyy').format(trip.endDate!).toUpperCase()}'}';
    final store = photoStore ?? PhotoStore();
    final coverMoment = _findCoverMoment();
    final coverPath = coverMoment?.relPath ?? coverMoment?.thumbRelPath;

    return Scaffold(
      appBar: AppBar(title: Text(trip.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _TripCoverImage(coverPath: coverPath, photoStore: store),
          const SizedBox(height: 16),
          if (trip.place != null && trip.place!.isNotEmpty)
            Text(trip.place!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          WarangMetadata('$dates · ${moments.length} MOMENTS'),
          if (trip.description != null && trip.description!.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              trip.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: 28),
          const WarangSectionLabel('Moments'),
          const SizedBox(height: 10),
          if (moments.isEmpty)
            Text(
              'Your moments from this trip will appear here.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...moments.map(
              (moment) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _MomentTileThumbnail(
                  moment: moment,
                  photoStore: store,
                ),
                title: Text(
                  moment.caption ?? moment.placeLabel ?? 'Moment',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  DateFormat('dd MMM yyyy · h:mm a').format(moment.capturedAt),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TripCoverImage extends StatefulWidget {
  const _TripCoverImage({required this.coverPath, required this.photoStore});

  final String? coverPath;
  final PhotoStore photoStore;

  @override
  State<_TripCoverImage> createState() => _TripCoverImageState();
}

class _TripCoverImageState extends State<_TripCoverImage> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _TripCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverPath != widget.coverPath ||
        oldWidget.photoStore != widget.photoStore) {
      _resolve();
    }
  }

  void _resolve() {
    final path = widget.coverPath;
    _future = path == null
        ? null
        : widget.photoStore
              .resolve(path)
              .then<File?>((f) => f)
              .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) {
      return _fallback(context);
    }
    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null && file.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(context),
              ),
            ),
          );
        }
        return _fallback(context);
      },
    );
  }

  Widget _fallback(BuildContext context) => Container(
    height: 160,
    decoration: BoxDecoration(
      color: Theme.of(context).extension<MapPalette>()!.landAlt,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Center(child: Icon(Icons.landscape_outlined, size: 42)),
  );
}

class _MomentTileThumbnail extends StatefulWidget {
  const _MomentTileThumbnail({required this.moment, required this.photoStore});

  final Moment moment;
  final PhotoStore photoStore;

  @override
  State<_MomentTileThumbnail> createState() => _MomentTileThumbnailState();
}

class _MomentTileThumbnailState extends State<_MomentTileThumbnail> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _MomentTileThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moment.thumbRelPath != widget.moment.thumbRelPath ||
        oldWidget.moment.relPath != widget.moment.relPath ||
        oldWidget.photoStore != widget.photoStore) {
      _resolve();
    }
  }

  void _resolve() {
    final path = widget.moment.thumbRelPath ?? widget.moment.relPath;
    _future = path == null
        ? null
        : widget.photoStore
              .resolve(path)
              .then<File?>((f) => f)
              .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) {
      return _fallback(context);
    }
    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null && file.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(context),
              ),
            ),
          );
        }
        return _fallback(context);
      },
    );
  }

  Widget _fallback(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: Theme.of(context).extension<MapPalette>()!.landAlt,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Center(child: Icon(Icons.photo_camera_outlined, size: 20)),
  );
}
