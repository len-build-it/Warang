import 'package:flutter/material.dart';

import '../../app/theme/components.dart';
import '../../core/models.dart';
import '../../data/repository.dart';

/// What the edit sheet asks its caller to do after it closes.
enum MomentEditOutcome { saved, placeOnMap }

/// Opens the edit sheet for [moment]. Resolves to null when dismissed.
Future<MomentEditOutcome?> showMomentEditSheet(
  BuildContext context, {
  required Moment moment,
  required WarangRepository repository,
}) => showModalBottomSheet<MomentEditOutcome>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  builder: (context) => MomentEditSheet(moment: moment, repository: repository),
);

class MomentEditSheet extends StatefulWidget {
  const MomentEditSheet({
    super.key,
    required this.moment,
    required this.repository,
  });

  final Moment moment;
  final WarangRepository repository;

  @override
  State<MomentEditSheet> createState() => _MomentEditSheetState();
}

class _MomentEditSheetState extends State<MomentEditSheet> {
  late final _caption = TextEditingController(text: widget.moment.caption);
  late final _place = TextEditingController(text: widget.moment.placeLabel);
  late String _tripId = widget.moment.tripId;
  bool _saving = false;

  @override
  void dispose() {
    _caption.dispose();
    _place.dispose();
    super.dispose();
  }

  /// Saves the fields, then closes with [outcome]; moving the pin keeps any
  /// text already typed.
  Future<void> _save([
    MomentEditOutcome outcome = MomentEditOutcome.saved,
  ]) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateMoment(
        widget.moment.id,
        caption: _caption.text,
        placeLabel: _place.text,
        tripId: _tripId,
      );
      if (mounted) Navigator.of(context).pop(outcome);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showWarangSnackBar(
        context,
        "Couldn't save these changes. Try again.",
        aboveNavigation: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trips = widget.repository.trips;
    final hasLocation =
        widget.moment.latitude != null && widget.moment.longitude != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Edit moment', style: theme.textTheme.titleLarge),
            const SizedBox(height: 18),
            TextField(
              controller: _caption,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Caption'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _place,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Place name',
                helperText: 'Shown instead of coordinates.',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              icon: const RotatedBox(
                quarterTurns: 1,
                child: WarangIcon(WarangGlyphs.chevron, size: 20),
              ),
              initialValue: _tripId,
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration(labelText: 'Trip'),
              items: [
                for (final trip in trips)
                  DropdownMenuItem(
                    value: trip.id,
                    child: Text(
                      trip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _tripId = value);
              },
            ),
            const SizedBox(height: 16),
            WarangButton.quiet(
              label: hasLocation ? 'Move pin on map' : 'Place on map',
              onPressed: _saving
                  ? null
                  : () => _save(MomentEditOutcome.placeOnMap),
            ),
            const SizedBox(height: 12),
            WarangButton.primary(
              label: _saving ? 'Saving...' : 'Save',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
