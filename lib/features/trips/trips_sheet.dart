import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) {
    final trips = widget.repository.trips;
    return DraggableScrollableSheet(
      initialChildSize: .40,
      minChildSize: .20,
      maxChildSize: .90,
      snap: true,
      snapSizes: const [.40, .90],
      builder: (context, controller) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        child: AnimatedBuilder(
          animation: widget.repository,
          builder: (context, _) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Text(
                    'Your trips',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _createTrip,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _EverydayRow(
                trip: widget.repository.everyday,
                count: widget.repository.moments
                    .where(
                      (moment) =>
                          moment.tripId == widget.repository.everyday.id,
                    )
                    .length,
              ),
              ...trips
                  .where((trip) => !trip.isEveryday)
                  .map(
                    (trip) => _TripCard(
                      trip: trip,
                      count: widget.repository.moments
                          .where((moment) => moment.tripId == trip.id)
                          .length,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EverydayRow extends StatelessWidget {
  const _EverydayRow({required this.trip, required this.count});
  final Trip trip;
  final int count;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: WarangColors.accent,
        foregroundColor: WarangColors.accentInk,
        child: Icon(Icons.wb_sunny_outlined),
      ),
      title: Text(trip.title),
      subtitle: Text('$count moments · always here'),
    ),
  );
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.count});
  final Trip trip;
  final int count;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.landscape_outlined),
      ),
      title: Text(trip.title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        '${trip.place ?? 'Place not added'} · $count moments',
        style: const TextStyle(fontFamily: 'DM Mono', fontSize: 11),
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}
