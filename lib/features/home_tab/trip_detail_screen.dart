import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/app_state.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/place_categories.dart';
import '../../data/files/photo_store.dart';
import '../../data/repository.dart';
import 'home_tab_screen.dart' show TripName;
import '../maya/maya_companion.dart';
import 'trip_form_screen.dart';
import 'trip_photo.dart';

/// One trip and its moments (S7), kept live against the repository.
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

  /// The options sheet: Edit trip, and Delete trip after a confirmation.
  Future<void> _options(BuildContext context) => showWarangSheet<void>(
    context,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WarangButton.secondary(
              label: 'Edit trip',
              icon: WarangGlyphs.edit,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                TripFormScreen.open(context, trip: trip);
              },
            ),
            const SizedBox(height: 12),
            WarangButton.danger(
              label: 'Delete trip',
              icon: WarangGlyphs.delete,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context);
              },
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _confirmDelete(BuildContext context) async {
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
    if (confirmed == true) {
      WarangHaptic.medium.play();
      await repository.deleteTrip(trip.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final neutrals = WarangNeutrals.of(context);
    final tone = WarangKeepsake.forTrip(trip);
    final band = tone?.tint(brightness) ?? neutrals.surface;
    final detail = tone?.text(brightness) ?? neutrals.inkFaint;
    final start = trip.startDate;
    final count = countLabel(moments.length, 'moment');
    // Everyday has no dates, so it shows only its count (V8).
    final summary = trip.isEveryday
        ? count
        : start == null
        ? 'No dates · $count'
        : '${formatDate(start)}${trip.endDate == null ? '' : ' - ${formatDate(trip.endDate!)}'} · $count';
    final place = trip.place?.trim();
    final dark = brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ColoredBox(
                color: band,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const BackButton(),
                            const Spacer(),
                            if (!trip.isEveryday)
                              IconButton(
                                tooltip: 'Trip options',
                                onPressed: () => _options(context),
                                icon: const WarangIcon(WarangGlyphs.more),
                              ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: 128,
                                child: WarangPolaroid(
                                  frame: const EdgeInsets.fromLTRB(7, 7, 7, 22),
                                  rotationDegrees: -2,
                                  photo: MomentPhoto(
                                    moment: coverMoment(trip, moments),
                                    photoStore: photoStore,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Semantics(
                                      header: true,
                                      child: TripName(
                                        trip.title,
                                        color: neutrals.ink,
                                      ),
                                    ),
                                    if (place != null && place.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        place,
                                        style: WarangType.meta.copyWith(
                                          color: detail,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      summary,
                                      style: WarangType.meta.copyWith(
                                        color: detail,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (moments.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const MayaCompanion(
                        size: 120,
                        place: MayaPlace.trip,
                        pose: MayaPose.packedBag,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        start == null && !trip.isEveryday
                            ? 'Your moments from this trip will appear here. Add dates to collect photos automatically, or move a moment here from its Edit sheet.'
                            : 'Your moments from this trip will appear here.',
                        textAlign: TextAlign.center,
                        style: WarangType.body.copyWith(
                          color: neutrals.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  28 + MediaQuery.paddingOf(context).bottom,
                ),
                // Two columns in rows that take their tallest print's
                // height, so captions grow with the text size.
                sliver: SliverList.separated(
                  itemCount: (moments.length + 1) ~/ 2,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (context, row) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final column in [0, 1]) ...[
                        if (column == 1) const SizedBox(width: 16),
                        Expanded(
                          child: row * 2 + column < moments.length
                              ? _MomentPrint(
                                  moment: moments[row * 2 + column],
                                  photoStore: photoStore,
                                  onTap: () =>
                                      onOpenMoment(moments[row * 2 + column]),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A moment in the grid: a small polaroid with its caption, or its date
/// when it has none.
class _MomentPrint extends StatelessWidget {
  const _MomentPrint({
    required this.moment,
    required this.photoStore,
    required this.onTap,
  });

  final Moment moment;
  final PhotoStore photoStore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final caption = moment.caption?.trim();
    final written = caption != null && caption.isNotEmpty;
    // Shantell Sans is only for words the user wrote (V3).
    final label = written
        ? caption
        : moment.placeLabel ?? formatMomentTime(moment.capturedAt);
    final category = PlaceCategories.byKey(moment.placeCategory);
    return ClayPressable(
      onPressed: onTap,
      semanticLabel: '$label, show on map',
      builder: (context, press) => Stack(
        children: [
          WarangPolaroid(
            frame: const EdgeInsets.fromLTRB(8, 8, 8, 52),
            captionStyle: written
                ? WarangType.hand.copyWith(color: neutrals.ink)
                : WarangType.meta.copyWith(color: neutrals.inkFaint),
            caption: label,
            photo: MomentPhoto(moment: moment, photoStore: photoStore),
          ),
          if (category != null)
            Positioned(
              top: 12,
              left: 12,
              child: CategoryDisc(category: category, size: 32),
            ),
        ],
      ),
    );
  }
}
