import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/models.dart';

class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({
    super.key,
    required this.trip,
    required this.moments,
  });

  final Trip trip;
  final List<Moment> moments;

  @override
  Widget build(BuildContext context) {
    final dates = trip.startDate == null
        ? 'NO DATES'
        : '${DateFormat('dd MMM yyyy').format(trip.startDate!).toUpperCase()}${trip.endDate == null ? '' : ' – ${DateFormat('dd MMM yyyy').format(trip.endDate!).toUpperCase()}'}';
    return Scaffold(
      appBar: AppBar(title: Text(trip.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Theme.of(context).extension<MapPalette>()!.landAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Icon(Icons.landscape_outlined, size: 42),
            ),
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
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).extension<MapPalette>()!.landAlt,
                  child: const Icon(Icons.photo_camera_outlined, size: 19),
                ),
                title: Text(moment.caption ?? moment.placeLabel ?? 'Moment'),
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
