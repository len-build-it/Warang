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
    final coverFuture = coverPath == null
        ? Future<File?>.value(null)
        : store
              .resolve(coverPath)
              .then<File?>((file) => file)
              .catchError((_) => null);

    return Scaffold(
      appBar: AppBar(title: Text(trip.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          FutureBuilder<File?>(
            future: coverFuture,
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
                      errorBuilder: (_, _, _) => _fallbackCover(context),
                    ),
                  ),
                );
              }
              return _fallbackCover(context);
            },
          ),
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

  Widget _fallbackCover(BuildContext context) => Container(
    height: 160,
    decoration: BoxDecoration(
      color: Theme.of(context).extension<MapPalette>()!.landAlt,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Center(child: Icon(Icons.landscape_outlined, size: 42)),
  );
}

class _MomentTileThumbnail extends StatelessWidget {
  const _MomentTileThumbnail({required this.moment, required this.photoStore});

  final Moment moment;
  final PhotoStore photoStore;

  @override
  Widget build(BuildContext context) {
    final thumbPath = moment.thumbRelPath ?? moment.relPath;
    if (thumbPath == null) {
      return _fallback(context);
    }
    return FutureBuilder<File?>(
      future: photoStore
          .resolve(thumbPath)
          .then<File?>((f) => f)
          .catchError((_) => null),
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
