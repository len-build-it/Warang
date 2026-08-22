import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/models.dart';
import '../../data/repository.dart';

class TripsSheet extends StatefulWidget {
  const TripsSheet({super.key, required this.repository});
  final WarangRepository repository;

  @override
  State<TripsSheet> createState() => _TripsSheetState();
}

class _TripsSheetState extends State<TripsSheet> {
  Future<void> _createTrip() async {
    final title = TextEditingController();
    final place = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New trip'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Trip name'),
            ),
            TextField(
              controller: place,
              decoration: const InputDecoration(labelText: 'Place (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true && title.text.trim().isNotEmpty) {
      await widget.repository.addTrip(title.text, place.text, null, null);
    }
    title.dispose();
    place.dispose();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .04,
    minChildSize: .04,
    maxChildSize: .924,
    snap: true,
    snapSizes: const [.04, .45, .924],
    builder: (context, controller) => Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      child: AnimatedBuilder(
        animation: widget.repository,
        builder: (context, _) {
          final realTrips = widget.repository.trips
              .where((trip) => !trip.isEveryday)
              .toList();
          final count = widget.repository.moments.length;
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('Trips', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  WarangMetadata('$count MOMENTS'),
                ],
              ),
              const SizedBox(height: 18),
              _EverydayRow(
                trip: widget.repository.everyday,
                count: widget.repository.moments
                    .where(
                      (moment) =>
                          moment.tripId == widget.repository.everyday.id,
                    )
                    .length,
              ),
              const SizedBox(height: 22),
              const WarangSectionLabel('Trips'),
              const SizedBox(height: 12),
              if (realTrips.isEmpty) _TripPlaceholder(),
              ...realTrips.map(
                (trip) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _TripCard(
                    trip: trip,
                    count: widget.repository.moments
                        .where((moment) => moment.tripId == trip.id)
                        .length,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              WarangPrimaryButton(
                label: 'New trip',
                height: 54,
                onPressed: _createTrip,
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _EverydayRow extends StatelessWidget {
  const _EverydayRow({required this.trip, required this.count});
  final Trip trip;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
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
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Everyday',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 18,
                letterSpacing: -.36,
              ),
            ),
            const SizedBox(height: 5),
            WarangMetadata('CASUAL CAPTURES · $count MOMENTS'),
          ],
        ),
      ],
    ),
  );
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.count});
  final Trip trip;
  final int count;

  @override
  Widget build(BuildContext context) {
    final planned =
        trip.startDate != null && trip.startDate!.isAfter(DateTime.now());
    final range = trip.startDate == null
        ? 'NO DATES · $count MOMENTS'
        : '${DateFormat('MMM d').format(trip.startDate!).toUpperCase()}${trip.endDate == null ? '' : '–${DateFormat('d').format(trip.endDate!)}'} · $count MOMENTS';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 132,
            child: ColoredBox(
              color: Theme.of(context).extension<MapPalette>()!.landAlt,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    WarangMetadata(range),
                    if (planned) ...[
                      const SizedBox(width: 8),
                      const _PlannedChip(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      'Trips you make will live here.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _PlannedChip extends StatelessWidget {
  const _PlannedChip();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.outline,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Text(
        'PLANNED',
        style: TextStyle(
          fontFamily: 'DM Mono',
          fontSize: 9,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.4,
        ),
      ),
    ),
  );
}
