import 'package:flutter/material.dart';

import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/models.dart';
import '../../data/repository.dart';

/// What the edit sheet asks its caller to do after it closes.
enum MomentEditOutcome { saved, placeOnMap }

/// Opens the S5 edit sheet for [moment]. Resolves to null when dismissed.
Future<MomentEditOutcome?> showMomentEditSheet(
  BuildContext context, {
  required Moment moment,
  required WarangRepository repository,
}) => showWarangSheet<MomentEditOutcome>(
  context,
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
    final neutrals = WarangNeutrals.of(context);
    final trips = widget.repository.trips;
    final hasLocation =
        widget.moment.latitude != null && widget.moment.longitude != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit moment',
                style: WarangType.titleS.copyWith(color: neutrals.ink),
              ),
              const SizedBox(height: 16),
              WarangField(
                label: 'Caption',
                controller: _caption,
                multiline: true,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                hintText: 'Say something (optional)',
                // The caption is the user's own words on the polaroid.
                style: WarangType.handL.copyWith(color: neutrals.ink),
                hintStyle: WarangType.handL.copyWith(color: neutrals.inkFaint),
              ),
              const SizedBox(height: 14),
              WarangField(
                label: 'Place name',
                controller: _place,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                helperText: 'Shown instead of coordinates.',
              ),
              const SizedBox(height: 14),
              Text(
                'Trip',
                style: WarangType.meta.copyWith(color: neutrals.inkSoft),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    for (final trip in trips) ...[
                      WarangChip(
                        label: trip.title,
                        tone: WarangKeepsake.forTrip(trip),
                        selected: trip.id == _tripId,
                        onSelected: () => setState(() => _tripId = trip.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              WarangButton.secondary(
                label: hasLocation ? 'Move pin on map' : 'Place on map',
                icon: WarangGlyphs.pin,
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
      ),
    );
  }
}
