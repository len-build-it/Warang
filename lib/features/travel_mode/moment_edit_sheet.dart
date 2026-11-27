import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/models.dart';
import '../../core/place_categories.dart';
import '../../data/places/place_book.dart';
import '../../data/repository.dart';
import '../places/place_picker_sheet.dart';

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
  late String _tripId = widget.moment.tripId;
  late String? _placeName = widget.moment.placeLabel;
  late String? _categoryKey = widget.moment.placeCategory;
  BookPlace? _pickedBookPlace;
  String? _pickedUserName;
  bool _clearedPlace = false;
  bool _saving = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  bool get _hasPlace =>
      !_clearedPlace &&
      (_pickedBookPlace != null ||
          _pickedUserName != null ||
          (_placeName != null && _placeName!.trim().isNotEmpty));

  Future<void> _pickPlace() async {
    final near =
        widget.moment.latitude != null && widget.moment.longitude != null
        ? LatLng(widget.moment.latitude!, widget.moment.longitude!)
        : null;
    final picked = await showPlacePickerSheet(
      context,
      near: near,
      allowUserPlace: true,
      allowClear: _hasPlace,
      showNearbyWhenEmpty: true,
      userPlaces: widget.repository.places,
    );
    if (!mounted || picked == null) return;
    setState(() {
      switch (picked) {
        case BookPlacePick(:final place):
          _pickedBookPlace = place;
          _pickedUserName = null;
          _clearedPlace = false;
          _placeName = place.name;
          _categoryKey = place.category;
        case UserPlacePick(:final name, :final existing):
          _pickedBookPlace = null;
          _pickedUserName = name;
          _clearedPlace = false;
          _placeName = existing?.name ?? name;
          _categoryKey = existing?.categoryKey;
        case ClearPlacePick():
          _pickedBookPlace = null;
          _pickedUserName = null;
          _clearedPlace = true;
          _placeName = null;
          _categoryKey = null;
      }
    });
  }

  /// Saves the fields, then closes with [outcome]; moving the pin keeps any
  /// text already typed.
  Future<void> _save([
    MomentEditOutcome outcome = MomentEditOutcome.saved,
  ]) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final existingCategory = widget.moment.placeId == null
          ? null
          : widget.repository.placeById(widget.moment.placeId!)?.categoryKey;
      final updateCategory =
          !_clearedPlace &&
          (_pickedBookPlace != null ||
              _pickedUserName != null ||
              existingCategory != _categoryKey);
      await widget.repository.editMomentDetails(
        widget.moment.id,
        caption: _caption.text,
        tripId: _tripId,
        clearPlace: _clearedPlace,
        bookPlace: _pickedBookPlace,
        userPlaceName: _pickedUserName,
        initialPlaceId: widget.moment.placeId,
        categoryKey: _categoryKey,
        updateCategory: updateCategory,
      );
      if (mounted) Navigator.of(context).pop(outcome);
    } on Exception catch (_) {
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
    final category = PlaceCategories.byKey(_categoryKey);
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
              Text(
                'Place',
                style: WarangType.meta.copyWith(color: neutrals.inkSoft),
              ),
              const SizedBox(height: 8),
              ClayPressable(
                onPressed: _saving ? null : _pickPlace,
                semanticLabel: _hasPlace
                    ? 'Place, $_placeName, change place'
                    : 'Add a place',
                builder: (context, press) => ClaySurface(
                  depth: ClayDepth.inset,
                  press: press,
                  color: neutrals.surfaceRaised,
                  outline: BorderSide(color: neutrals.boundary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 36),
                    child: Row(
                      children: [
                        if (_hasPlace && category != null)
                          CategoryDisc(category: category, size: 32)
                        else
                          WarangIcon(
                            WarangGlyphs.pin,
                            size: 20,
                            color: neutrals.inkSoft,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _hasPlace ? _placeName! : 'Add a place',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WarangType.body.copyWith(
                              color: _hasPlace
                                  ? neutrals.ink
                                  : neutrals.inkFaint,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        WarangIcon(
                          WarangGlyphs.chevron,
                          size: 18,
                          color: neutrals.inkFaint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_hasPlace) ...[
                const SizedBox(height: 14),
                Text(
                  'Category',
                  style: WarangType.meta.copyWith(color: neutrals.inkSoft),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      for (final cat in PlaceCategories.all) ...[
                        WarangChip(
                          label: cat.name,
                          tone: cat.tone,
                          icon: cat.glyph,
                          selected: cat.key == _categoryKey,
                          onSelected: () => setState(
                            () => _categoryKey = _categoryKey == cat.key
                                ? null
                                : cat.key,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
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
