import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/app_state.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatting.dart';
import '../../core/memory_stats.dart';
import '../../core/models.dart';
import '../../data/files/photo_store.dart';
import '../../data/repository.dart';
import 'analytics_charts.dart';
import 'trip_detail_screen.dart';
import 'trip_form_screen.dart';

class HomeTabScreen extends ConsumerWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(repositoryProvider);
    final photoStore = ref.watch(photoStoreProvider);
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) =>
          _HomeTabContent(repository: repository, photoStore: photoStore),
    );
  }
}

class _HomeTabContent extends StatefulWidget {
  const _HomeTabContent({required this.repository, required this.photoStore});
  final WarangRepository repository;
  final PhotoStore photoStore;

  @override
  State<_HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<_HomeTabContent> {
  PhotoStore get _photoStore => widget.photoStore;

  Future<void> _createTrip() async {
    final title = await TripFormScreen.open(context);
    if (title != null && mounted) {
      showWarangSnackBar(context, 'Trip "$title" created.');
    }
  }

  String? _findTripCoverPath(Trip trip, List<Moment> tripMoments) {
    if (trip.coverMomentId != null) {
      for (final m in tripMoments) {
        if (m.id == trip.coverMomentId &&
            (m.thumbRelPath != null || m.relPath != null)) {
          return m.thumbRelPath ?? m.relPath;
        }
      }
    }
    for (final m in tripMoments) {
      if (m.thumbRelPath != null || m.relPath != null) {
        return m.thumbRelPath ?? m.relPath;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final trips = widget.repository.trips;
    final everyday = widget.repository.everyday;
    final moments = widget.repository.moments;
    final realTrips = trips.where((trip) => !trip.isEveryday).toList();
    final analytics = MemoryStats.from(
      moments,
      everydayId: everyday.id,
      now: DateTime.now(),
    );
    final everydayMoments = moments
        .where((moment) => moment.tripId == everyday.id)
        .toList(growable: false);
    final everydayCoverPath = _findTripCoverPath(everyday, everydayMoments);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            22,
            20,
            WarangLayout.navigationHeight(context) + 24,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Trips',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'A shelf of the places you have been.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 30),
            const WarangSectionLabel('Your memories'),
            const SizedBox(height: 12),
            _EverydayRow(
              trip: everyday,
              count: everydayMoments.length,
              coverPath: everydayCoverPath,
              photoStore: _photoStore,
              onTap: () => _openTrip(everyday),
            ),
            const SizedBox(height: 18),
            if (realTrips.isEmpty)
              const _TripEmptyState()
            else
              ...realTrips.map((trip) {
                final tripMoments = moments
                    .where((moment) => moment.tripId == trip.id)
                    .toList(growable: false);
                final tripCoverPath = _findTripCoverPath(trip, tripMoments);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _TripCard(
                    trip: trip,
                    count: tripMoments.length,
                    coverPath: tripCoverPath,
                    photoStore: _photoStore,
                    onTap: () => _openTrip(trip),
                  ),
                );
              }),
            WarangButton.primary(label: 'New trip', onPressed: _createTrip),
            const SizedBox(height: 34),
            const WarangSectionLabel('On-device analytics'),
            const SizedBox(height: 12),
            _StatRow(snapshot: analytics),
            const SizedBox(height: 18),
            if (!analytics.ready)
              const _AnalyticsEmptyState()
            else ...[
              _ChartCard(
                title: 'Moments captured',
                subtitle: 'Last six months',
                child: MomentsBarChart(
                  values: analytics.monthlyMoments,
                  labels: analytics.monthLabels,
                ),
              ),
              const SizedBox(height: 14),
              _ChartCard(
                title: 'Trips over time',
                subtitle: 'Cumulative',
                child: TripTrendChart(
                  values: analytics.cumulativeTrips,
                  labels: analytics.monthLabels,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openTrip(Trip trip) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.snapshot});
  final MemoryStats snapshot;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _StatCard(value: snapshot.moments, label: 'Moments'),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _StatCard(value: snapshot.places, label: 'Places'),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _StatCard(value: snapshot.days, label: 'Days'),
      ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 13, 12, 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: WarangType.titleS),
        const SizedBox(height: 3),
        WarangMetadata(label),
      ],
    ),
  );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 18),
            ),
            const Spacer(),
            WarangMetadata(subtitle),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(height: 142, child: child),
      ],
    ),
  );
}

class _AnalyticsEmptyState extends StatelessWidget {
  const _AnalyticsEmptyState();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      children: [
        Image.asset('design/warang-maya.png', width: 54, height: 54),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Come back after your first few captures. Your patterns will appear here.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

class _TripEmptyState extends StatelessWidget {
  const _TripEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Image.asset('design/warang-maya.png', width: 42, height: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Trips you make will live here.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}

class _EverydayRow extends StatelessWidget {
  const _EverydayRow({
    required this.trip,
    required this.count,
    required this.onTap,
    this.coverPath,
    this.photoStore,
  });
  final Trip trip;
  final int count;
  final VoidCallback onTap;
  final String? coverPath;
  final PhotoStore? photoStore;

  @override
  Widget build(BuildContext context) {
    final store = photoStore ?? PhotoStore();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).extension<MapPalette>()!.landAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: _EverydayThumbnail(
                coverPath: coverPath,
                photoStore: store,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Everyday',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 5),
                  WarangMetadata(
                    'Casual captures · ${countLabel(count, 'moment')}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EverydayThumbnail extends StatefulWidget {
  const _EverydayThumbnail({required this.coverPath, required this.photoStore});

  final String? coverPath;
  final PhotoStore photoStore;

  @override
  State<_EverydayThumbnail> createState() => _EverydayThumbnailState();
}

class _EverydayThumbnailState extends State<_EverydayThumbnail> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _EverydayThumbnail oldWidget) {
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
      return const WarangIcon(WarangGlyphs.theme, size: 22);
    }
    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null && file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const WarangIcon(WarangGlyphs.theme, size: 22),
          );
        }
        return const WarangIcon(WarangGlyphs.theme, size: 22);
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.count,
    required this.onTap,
    this.coverPath,
    this.photoStore,
  });
  final Trip trip;
  final int count;
  final VoidCallback onTap;
  final String? coverPath;
  final PhotoStore? photoStore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = photoStore ?? PhotoStore();
    final planned =
        trip.startDate != null && trip.startDate!.isAfter(DateTime.now());
    final start = trip.startDate;
    final end = trip.endDate ?? start;
    final range = start == null || end == null
        ? 'No dates · ${countLabel(count, 'moment')}'
        : '${formatTripRange(start, end)} · ${countLabel(count, 'moment')}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 136,
              child: _TripBannerImage(coverPath: coverPath, photoStore: store),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (trip.place != null &&
                            trip.place!.trim().isNotEmpty) ...[
                          Text(
                            trip.place!.trim(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: WarangNeutrals.of(context).inkSoft,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(trip.title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        WarangMetadata(range),
                      ],
                    ),
                  ),
                  if (planned) const _PlannedChip(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripBannerImage extends StatefulWidget {
  const _TripBannerImage({required this.coverPath, required this.photoStore});

  final String? coverPath;
  final PhotoStore photoStore;

  @override
  State<_TripBannerImage> createState() => _TripBannerImageState();
}

class _TripBannerImageState extends State<_TripBannerImage> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _TripBannerImage oldWidget) {
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
          return Image.file(
            file,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, sync) =>
                sync || frame != null ? child : _fallback(context),
            errorBuilder: (_, _, _) => _fallback(context),
          );
        }
        return _fallback(context);
      },
    );
  }

  Widget _fallback(BuildContext context) => ColoredBox(
    color: Theme.of(context).extension<MapPalette>()!.landAlt,
    child: const Center(child: WarangIcon(WarangGlyphs.photo, size: 34)),
  );
}

class _PlannedChip extends StatelessWidget {
  const _PlannedChip();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.outlineVariant,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Text('Planned', style: WarangType.caption),
    ),
  );
}
