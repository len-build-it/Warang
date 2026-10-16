import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/theme/components.dart';
import '../../core/formatting.dart';
import '../../core/models.dart';

/// Creates a trip, or edits [trip] when given. Pops with the saved title.
class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({super.key, this.trip});

  final Trip? trip;

  /// Opens the form as a full-screen dialog.
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
  late final _title = TextEditingController(text: widget.trip?.title);
  late final _place = TextEditingController(text: widget.trip?.place);
  late DateTimeRange? _dates = _initialDates();
  String? _titleError;
  String? _datesError;
  bool _saving = false;

  bool get _editing => widget.trip != null;

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
    if (picked != null) {
      setState(() {
        _dates = picked;
        _datesError = null;
      });
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final dates = _dates;
    setState(() {
      _titleError = title.isEmpty ? 'Trip name is required' : null;
      _datesError = dates != null && dates.end.isBefore(dates.start)
          ? 'The trip cannot end before it starts'
          : null;
    });
    if (_titleError != null || _datesError != null || _saving) return;
    setState(() => _saving = true);
    final repository = ref.read(repositoryProvider);
    final place = _place.text.trim();
    try {
      if (_editing) {
        await repository.updateTrip(
          widget.trip!.id,
          title: title,
          place: place,
          start: dates?.start,
          end: dates?.end,
        );
      } else {
        await repository.addTrip(
          title,
          place.isEmpty ? null : place,
          dates?.start,
          dates?.end,
        );
      }
      if (mounted) Navigator.of(context).pop(title);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showWarangSnackBar(
        context,
        "Couldn't save this trip. Try again.",
        aboveNavigation: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dates = _dates;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit trip' : 'New trip'),
        backgroundColor: theme.colorScheme.surface,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          TextField(
            controller: _title,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
            },
            decoration: InputDecoration(
              labelText: 'Trip name',
              errorText: _titleError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _place,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Place (optional)'),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Dates (optional)',
              helperText:
                  'Photos you take between these dates go into this trip.',
              helperMaxLines: 2,
              errorText: _datesError,
              contentPadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dates == null
                        ? 'No dates'
                        : formatTripRange(dates.start, dates.end),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                if (dates != null)
                  IconButton(
                    tooltip: 'Clear dates',
                    onPressed: () => setState(() => _dates = null),
                    icon: const Icon(Icons.close),
                  ),
                IconButton(
                  tooltip: 'Choose dates',
                  onPressed: _pickDates,
                  icon: const Icon(Icons.date_range_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          WarangPrimaryButton(
            label: _saving ? 'Saving...' : (_editing ? 'Save' : 'Create'),
            height: 54,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
