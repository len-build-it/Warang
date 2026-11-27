import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/trip_rules.dart';

/// The trip colours' names, so a colour is never chosen by colour alone.
const tripColorNames = {
  'gumamela': 'Coral',
  'dagat': 'Sea',
  'kalamansi': 'Lime',
  'ube': 'Ube',
  'langit': 'Sky',
  'santan': 'Pink',
};

/// Creates a trip, or edits [trip] when given, one question at a time (S8):
/// where to, where it is, when, and its colour. Only the name is required.
/// Pops with the saved title.
class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({super.key, this.trip});

  final Trip? trip;

  /// Opens the form as a full-screen sheet.
  static Future<String?> open(BuildContext context, {Trip? trip}) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => TripFormScreen(trip: trip),
        ),
      );

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  static const _questions = [
    'Where to?',
    'Where is it?',
    'When?',
    'Pick a colour',
  ];

  late final _title = TextEditingController(text: widget.trip?.title);
  late final _place = TextEditingController(text: widget.trip?.place);
  late DateTimeRange? _dates = _initialDates();
  late String _color = widget.trip == null
      ? tripColorKeys.first
      : tripColorKey(widget.trip!)!;
  int _step = 0;
  String? _titleError;
  bool _saving = false;

  bool get _editing => widget.trip != null;
  bool get _last => _step == _questions.length - 1;

  @override
  void initState() {
    super.initState();
    if (!_editing) {
      // A new trip starts on the colour after the last trip's.
      ref.read(repositoryProvider).nextTripColor().then((color) {
        if (mounted) setState(() => _color = color);
      });
    }
  }

  DateTimeRange? _initialDates() {
    final start = widget.trip?.startDate;
    final end = widget.trip?.endDate;
    return start == null || end == null
        ? null
        : DateTimeRange(start: start, end: end);
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: _dates,
      helpText: 'Trip dates',
    );
    if (!mounted) return;
    if (picked != null) setState(() => _dates = picked);
  }

  void _next() {
    if (_step == 0 && _title.text.trim().isEmpty) {
      setState(() => _titleError = 'Trip name is required');
      return;
    }
    if (_last) {
      _save();
    } else {
      setState(() => _step++);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    final dates = _dates;
    final place = _place.text.trim();
    setState(() => _saving = true);
    final repository = ref.read(repositoryProvider);
    try {
      if (_editing) {
        await repository.updateTrip(
          widget.trip!.id,
          title: title,
          place: place,
          start: dates?.start,
          end: dates?.end,
          colorKey: _color,
        );
      } else {
        await repository.addTrip(
          title,
          place.isEmpty ? null : place,
          dates?.start,
          dates?.end,
          colorKey: _color,
        );
      }
      if (mounted) Navigator.of(context).pop(title);
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showWarangSnackBar(
        context,
        "Couldn't save this trip. Try again.",
        aboveNavigation: false,
      );
    }
  }

  Widget _answer(BuildContext context) => switch (_step) {
    0 => WarangField(
      key: const ValueKey('name'),
      label: 'Trip name',
      controller: _title,
      autofocus: true,
      errorText: _titleError,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      onChanged: (_) {
        if (_titleError != null) setState(() => _titleError = null);
      },
      onSubmitted: (_) => _next(),
    ),
    1 => WarangField(
      key: const ValueKey('place'),
      label: 'Place (optional)',
      controller: _place,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _next(),
    ),
    2 => _DatesAnswer(
      key: const ValueKey('dates'),
      dates: _dates,
      onPick: _pickDates,
      onClear: () => setState(() => _dates = null),
    ),
    _ => _ColourAnswer(
      key: const ValueKey('colour'),
      selected: _color,
      onSelected: (color) => setState(() => _color = color),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final reduced = WarangMotion.reduced(context);
    final done = _saving
        ? 'Saving...'
        : _editing
        ? 'Save'
        : 'Create';
    return PopScope(
      // Back steps back through the questions before it leaves.
      canPop: !_saving && _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving && _step > 0) setState(() => _step--);
      },
      child: Scaffold(
        backgroundColor: neutrals.surface,
        appBar: AppBar(
          title: Text(_editing ? 'Edit trip' : 'New trip'),
          backgroundColor: neutrals.surface,
          scrolledUnderElevation: 0,
          // Close leaves from any question; only Back steps back.
          leading: CloseButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Text(
                      'Step ${_step + 1} of ${_questions.length}',
                      style: WarangType.meta.copyWith(color: neutrals.inkFaint),
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      header: true,
                      child: Text(
                        _questions[_step],
                        style: WarangType.displayM.copyWith(
                          color: neutrals.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: reduced
                          ? WarangMotion.fade
                          : WarangMotion.slide.duration,
                      child: _answer(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: WarangButton.secondary(
                          besidePrimary: true,
                          label: 'Back',
                          icon: WarangGlyphs.back,
                          onPressed: _saving
                              ? null
                              : () => setState(() => _step--),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: WarangButton.primary(
                        label: _last ? done : 'Next',
                        onPressed: _saving ? null : _next,
                      ),
                    ),
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

class _DatesAnswer extends StatelessWidget {
  const _DatesAnswer({
    super.key,
    required this.dates,
    required this.onPick,
    required this.onClear,
  });

  final DateTimeRange? dates;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final dates = this.dates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dates (optional)',
          style: WarangType.meta.copyWith(color: neutrals.inkSoft),
        ),
        const SizedBox(height: 8),
        ClaySurface(
          depth: ClayDepth.inset,
          outline: BorderSide(color: neutrals.boundary),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dates == null
                          ? 'No dates'
                          : formatTripRange(dates.start, dates.end),
                      style: WarangType.bodyL.copyWith(
                        color: dates == null ? neutrals.inkFaint : neutrals.ink,
                      ),
                    ),
                  ),
                  if (dates != null)
                    IconButton(
                      tooltip: 'Clear dates',
                      onPressed: onClear,
                      icon: const WarangIcon(WarangGlyphs.close),
                    ),
                  IconButton(
                    tooltip: 'Choose dates',
                    onPressed: onPick,
                    icon: const WarangIcon(WarangGlyphs.calendar),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Photos you take between these dates go into this trip.',
          style: WarangType.meta.copyWith(color: neutrals.inkFaint),
        ),
      ],
    );
  }
}

class _ColourAnswer extends StatelessWidget {
  const _ColourAnswer({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 12,
    children: [
      for (final key in tripColorKeys)
        WarangChip(
          label: tripColorNames[key] ?? key,
          tone: WarangKeepsake.byKey(key),
          selected: key == selected,
          onSelected: () => onSelected(key),
        ),
    ],
  );
}
