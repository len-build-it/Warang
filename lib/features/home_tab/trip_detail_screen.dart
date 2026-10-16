import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app.dart';
import '../../app/app_state.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/models.dart';
import '../../data/files/photo_store.dart';
import '../../data/repository.dart';
import 'trip_form_screen.dart';

enum _TripAction { edit, delete }

/// One trip and its moments, kept live against the repository.
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(repositoryProvider);
    final photoStore = ref.watch(photoStoreProvider);
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final trip = repository.trips.where((t) => t.id == tripId).firstOrNull;
        if (trip == null) {
          // The trip was deleted while open; leave once this frame is done.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold();
        }
        final moments = repository.moments
            .where((moment) => moment.tripId == trip.id)
            .toList(growable: false);
        return _TripDetailView(
          trip: trip,
          moments: moments,
          photoStore: photoStore,
          repository: repository,
          onOpenMoment: (moment) => showMomentOnMap(context, ref, moment),
        );
      },
    );
  }
}

class _TripDetailView extends StatelessWidget {
  const _TripDetailView({
    required this.trip,
    required this.moments,
    required this.photoStore,
    required this.repository,
    required this.onOpenMoment,
  });

  final Trip trip;
  final List<Moment> moments;
  final PhotoStore photoStore;
  final WarangRepository repository;
  final ValueChanged<Moment> onOpenMoment;

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

  Future<void> _onAction(BuildContext context, _TripAction action) async {
    switch (action) {
      case _TripAction.edit:
        await TripFormScreen.open(context, trip: trip);
      case _TripAction.delete:
        final count = moments.length;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete this trip?'),
            content: Text(
              count == 0
                  ? 'The trip has no moments.'
                  : 'Its $count ${count == 1 ? 'moment moves' : 'moments move'} to Everyday.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete trip'),
              ),
            ],
          ),
        );
        if (confirmed == true) await repository.deleteTrip(trip.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dates = trip.isEveryday
        ? 'CASUAL CAPTURES'
        : trip.startDate == null
        ? 'NO DATES'
        : '${DateFormat('dd MMM yyyy').format(trip.startDate!).toUpperCase()}${trip.endDate == null ? '' : ' - ${DateFormat('dd MMM yyyy').format(trip.endDate!).toUpperCase()}'}';
    final coverMoment = _findCoverMoment();
    final coverPath = coverMoment?.relPath ?? coverMoment?.thumbRelPath;

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.title),
        actions: [
          if (!trip.isEveryday)
            PopupMenuButton<_TripAction>(
              tooltip: 'Trip options',
              onSelected: (action) => _onAction(context, action),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _TripAction.edit,
                  child: Text('Edit trip'),
                ),
                PopupMenuItem(
                  value: _TripAction.delete,
                  child: Text('Delete trip'),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _TripCoverImage(coverPath: coverPath, photoStore: photoStore),
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
              trip.startDate == null
                  ? 'Your moments from this trip will appear here. Add dates to collect photos automatically, or move a moment here from its Edit sheet.'
                  : 'Your moments from this trip will appear here.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...moments.map(
              (moment) => ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => onOpenMoment(moment),
                leading: _MomentTileThumbnail(
                  moment: moment,
                  photoStore: photoStore,
                ),
                title: Text(
                  moment.caption ?? moment.placeLabel ?? 'Moment',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  DateFormat('dd MMM yyyy · h:mm a').format(moment.capturedAt),
                ),
                trailing: const Icon(Icons.chevron_right),
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
                frameBuilder: (context, child, frame, sync) =>
                    sync || frame != null ? child : _fallback(context),
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
                frameBuilder: (context, child, frame, sync) =>
                    sync || frame != null ? child : _fallback(context),
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
