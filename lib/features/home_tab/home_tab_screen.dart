import 'dart:math' as math;

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
import 'trip_detail_screen.dart';
import 'trip_form_screen.dart';
import 'trip_photo.dart';

/// The Trips shelf (S6): three stamps, Everyday, then each trip as a card in
/// its own colour, and New trip at the end. It replaced the dashboard and
/// its charts (D-4).
class HomeTabScreen extends ConsumerStatefulWidget {
  const HomeTabScreen({super.key});

  @override
  ConsumerState<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends ConsumerState<HomeTabScreen> {
  /// Trips already on the shelf; one that appears later springs on.
  Set<String>? _shelved;

  Future<void> _createTrip() async {
    final title = await TripFormScreen.open(context);
    if (title != null && mounted) {
      showWarangSnackBar(context, 'Trip "$title" created.');
    }
  }

  void _openTrip(Trip trip) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)));

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(repositoryProvider);
    final photoStore = ref.watch(photoStoreProvider);
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final everyday = repository.everyday;
        final moments = repository.moments;
        final trips =
            repository.trips.where((trip) => !trip.isEveryday).toList()..sort(
              (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                a.createdAt ?? DateTime(0),
              ),
            );
        final arrived = _shelved == null
            ? const <String>{}
            : {
                for (final trip in trips)
                  if (!_shelved!.contains(trip.id)) trip.id,
              };
        _shelved = {for (final trip in trips) trip.id};
        List<Moment> momentsOf(Trip trip) =>
            moments.where((moment) => moment.tripId == trip.id).toList();
        final stats = MemoryStats.from(moments);
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                22,
                20,
                WarangLayout.dockClearance(context) + 16,
              ),
              children: [
                Text(
                  'Trips',
                  style: WarangType.displayL.copyWith(
                    color: WarangNeutrals.of(context).ink,
                  ),
                ),
                const SizedBox(height: 20),
                _Stamps(stats: stats),
                const SizedBox(height: 24),
                _EverydayCard(
                  trip: everyday,
                  moments: momentsOf(everyday),
                  photoStore: photoStore,
                  onTap: () => _openTrip(everyday),
                ),
                const SizedBox(height: 22),
                if (trips.isEmpty)
                  const _EmptyShelf()
                else
                  for (final (index, trip) in trips.indexed)
                    Padding(
                      key: ValueKey(trip.id),
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _ArrivesOnShelf(
                        arriving: arrived.contains(trip.id),
                        child: TripShelfCard(
                          trip: trip,
                          moments: momentsOf(trip),
                          photoStore: photoStore,
                          // Cards lean alternately, as on a real shelf.
                          tiltDegrees: index.isEven ? -1.5 : 1.5,
                          onTap: () => _openTrip(trip),
                        ),
                      ),
                    ),
                const SizedBox(height: 4),
                WarangButton.primary(
                  label: 'New trip',
                  icon: WarangGlyphs.trips,
                  onPressed: _createTrip,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stamps extends StatelessWidget {
  const _Stamps({required this.stats});
  final MemoryStats stats;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      WarangStamp.count(
        id: 'shelf-moments',
        number: stats.moments,
        word: stats.moments == 1 ? 'moment' : 'moments',
        tone: WarangKeepsake.amber,
        countUp: true,
      ),
      WarangStamp.count(
        id: 'shelf-places',
        number: stats.places,
        word: stats.places == 1 ? 'place' : 'places',
        tone: WarangKeepsake.dagat,
        countUp: true,
      ),
      WarangStamp.count(
        id: 'shelf-days',
        number: stats.days,
        word: stats.days == 1 ? 'day' : 'days',
        tone: WarangKeepsake.ube,
        countUp: true,
      ),
    ],
  );
}

/// Everyday: a wide `surface` clay card with a fan of its three newest
/// photos.
class _EverydayCard extends StatelessWidget {
  const _EverydayCard({
    required this.trip,
    required this.moments,
    required this.photoStore,
    required this.onTap,
  });

  final Trip trip;
  final List<Moment> moments;
  final PhotoStore photoStore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final withPhotos = moments
        .where(
          (moment) => moment.relPath != null || moment.thumbRelPath != null,
        )
        .take(3)
        .toList();
    return ClayPressable(
      onPressed: onTap,
      semanticLabel:
          'Everyday, ${countLabel(moments.length, 'moment')}, open trip',
      builder: (context, press) => ClaySurface(
        depth: ClayDepth.clay2,
        press: press,
        borderRadius: BorderRadius.circular(WarangRadius.card),
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
        child: Row(
          children: [
            _Fan(moments: withPhotos, photoStore: photoStore),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Everyday',
                    style: WarangType.titleS.copyWith(color: neutrals.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    countLabel(moments.length, 'moment'),
                    style: WarangType.meta.copyWith(color: neutrals.inkFaint),
                  ),
                ],
              ),
            ),
            const WarangIcon(WarangGlyphs.chevron, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Up to three small polaroids, fanned out; one empty frame when there are
/// none yet.
class _Fan extends StatelessWidget {
  const _Fan({required this.moments, required this.photoStore});
  final List<Moment> moments;
  final PhotoStore photoStore;

  static const _print = 54.0;

  @override
  Widget build(BuildContext context) {
    final shown = moments.isEmpty ? <Moment?>[null] : moments.reversed.toList();
    // The newest photo is drawn last, on top, in the middle.
    const leans = [-2.0, 2.0, 0.0];
    const shifts = [-14.0, 14.0, 0.0];
    final offset = 3 - shown.length;
    return SizedBox(
      width: _print + 30,
      height: _print + 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final (index, moment) in shown.indexed)
            Transform.translate(
              offset: Offset(shown.length == 1 ? 0 : shifts[index + offset], 0),
              child: SizedBox(
                width: _print,
                child: WarangPolaroid(
                  depth: ClayDepth.clay1,
                  frame: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  rotationDegrees: shown.length == 1
                      ? 0
                      : leans[index + offset],
                  photo: MomentPhoto(
                    moment: moment,
                    photoStore: photoStore,
                    glyphSize: 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One trip on the shelf: its tint at `clay2`, its cover as a polaroid, its
/// name, place, dates, and count.
class TripShelfCard extends StatelessWidget {
  const TripShelfCard({
    super.key,
    required this.trip,
    required this.moments,
    required this.photoStore,
    required this.onTap,
    this.tiltDegrees = 0,
  });

  final Trip trip;
  final List<Moment> moments;
  final PhotoStore photoStore;
  final VoidCallback onTap;
  final double tiltDegrees;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final neutrals = WarangNeutrals.of(context);
    final tone = WarangKeepsake.forTrip(trip)!;
    final start = trip.startDate;
    final end = trip.endDate ?? start;
    final when = start == null || end == null
        ? 'No dates'
        : formatTripRange(start, end);
    final planned = start != null && start.isAfter(DateTime.now());
    final place = trip.place?.trim();
    final detail = tone.text(brightness);
    return Transform.rotate(
      angle: tiltDegrees * math.pi / 180,
      child: ClayPressable(
        onPressed: onTap,
        semanticLabel: '${trip.title}, open trip',
        builder: (context, press) => ClaySurface(
          depth: ClayDepth.clay2,
          press: press,
          color: tone.tint(brightness),
          borderRadius: BorderRadius.circular(WarangRadius.card),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 112,
                child: WarangPolaroid(
                  depth: ClayDepth.clay1,
                  frame: const EdgeInsets.fromLTRB(6, 6, 6, 18),
                  photo: MomentPhoto(
                    moment: coverMoment(trip, moments),
                    photoStore: photoStore,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    TripName(trip.title, color: neutrals.ink),
                    if (place != null && place.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        place,
                        style: WarangType.meta.copyWith(color: detail),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '$when · ${countLabel(moments.length, 'moment')}',
                      style: WarangType.meta.copyWith(color: detail),
                    ),
                    if (planned) ...[
                      const SizedBox(height: 10),
                      WarangChip(label: 'Planned', tone: tone),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A trip's name in `displayM` when it fits on one line; a longer name
/// drops to `titleS` over two lines, because Bagel Fat One is never used
/// for more than one line (V3).
class TripName extends StatelessWidget {
  const TripName(this.name, {super.key, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final display = WarangType.displayM.copyWith(color: color);
      final painter = TextPainter(
        text: TextSpan(text: name, style: display),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout(maxWidth: constraints.maxWidth);
      final fits = !painter.didExceedMaxLines;
      painter.dispose();
      return Text(
        name,
        maxLines: fits ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        style: fits ? display : WarangType.titleS.copyWith(color: color),
      );
    },
  );
}

/// A trip made while the shelf is open springs onto it with `pop`; under
/// reduced motion it fades in.
class _ArrivesOnShelf extends StatelessWidget {
  const _ArrivesOnShelf({required this.arriving, required this.child});
  final bool arriving;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = WarangMotion.reduced(context);
    // Only the first build's start counts, so the spring plays out even
    // though the card stops being new on the next rebuild.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: arriving ? 0 : 1, end: 1),
      duration: reduced ? WarangMotion.fade : WarangMotion.pop.duration,
      curve: reduced ? Curves.linear : WarangMotion.pop.curve,
      builder: (context, value, child) => reduced
          ? Opacity(opacity: value.clamp(0.0, 1.0), child: child)
          : Transform.scale(scale: .6 + .4 * value, child: child),
      child: child,
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      children: [
        ExcludeSemantics(
          child: Image.asset('design/warang-maya.png', width: 120, height: 120),
        ),
        const SizedBox(height: 10),
        Text(
          "Plan a trip and I'll pack my bag",
          textAlign: TextAlign.center,
          style: WarangType.hand.copyWith(
            color: WarangNeutrals.of(context).inkSoft,
          ),
        ),
      ],
    ),
  );
}
