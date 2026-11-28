import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/models.dart';
import '../../core/place_categories.dart';
import '../../data/places/place_book.dart';
import '../../data/places/place_book_installer.dart';
import '../maya/maya_companion.dart';

/// Outcome of [showPlacePickerSheet].
sealed class PlacePickResult {
  const PlacePickResult();
}

/// User chose a place from the bundled OpenStreetMap place book.
class BookPlacePick extends PlacePickResult {
  const BookPlacePick(this.place);
  final BookPlace place;
}

/// User chose one of their own existing places or typed a new custom name.
class UserPlacePick extends PlacePickResult {
  const UserPlacePick(this.name, {this.existing});
  final String name;
  final Place? existing;
}

/// User chose "No place" to clear the moment's place.
class ClearPlacePick extends PlacePickResult {
  const ClearPlacePick();
}

/// Opens the place picker / place search sheet (FEAT-004 F1, F2, F3, F4).
Future<PlacePickResult?> showPlacePickerSheet(
  BuildContext context, {
  LatLng? near,
  bool allowUserPlace = true,
  bool allowClear = false,
  bool showNearbyWhenEmpty = true,
  List<Place> userPlaces = const [],
  String? initialQuery,
}) => showWarangSheet<PlacePickResult>(
  context,
  builder: (context) => PlacePickerSheet(
    near: near,
    allowUserPlace: allowUserPlace,
    allowClear: allowClear,
    showNearbyWhenEmpty: showNearbyWhenEmpty,
    userPlaces: userPlaces,
    initialQuery: initialQuery,
  ),
);

class PlacePickerSheet extends ConsumerStatefulWidget {
  const PlacePickerSheet({
    super.key,
    this.near,
    this.allowUserPlace = true,
    this.allowClear = false,
    this.showNearbyWhenEmpty = true,
    this.userPlaces = const [],
    this.initialQuery,
  });

  final LatLng? near;
  final bool allowUserPlace;
  final bool allowClear;
  final bool showNearbyWhenEmpty;
  final List<Place> userPlaces;
  final String? initialQuery;

  @override
  ConsumerState<PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends ConsumerState<PlacePickerSheet> {
  late final _controller = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  final _focus = FocusNode();
  Timer? _debounce;
  List<BookPlace> _nearby = const [];
  List<BookPlace> _results = const [];
  bool _loading = false;
  bool _queryFailed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      unawaited(_runQuery());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(WarangMotion.fade, _runQuery);
  }

  Future<void> _runQuery() async {
    final state = ref.read(placeBookProvider);
    final book = state.book;
    if (!state.isReady || book == null) return;
    final gen = ++_generation;
    final query = _controller.text.trim();
    if (query.isEmpty) {
      if (!widget.showNearbyWhenEmpty || widget.near == null) {
        if (mounted && gen == _generation) {
          setState(() {
            _nearby = const [];
            _results = const [];
            _loading = false;
            _queryFailed = false;
          });
        }
        return;
      }
      setState(() {
        _loading = true;
        _queryFailed = false;
      });
      try {
        final nearby = await book.nearby(widget.near!, 150);
        if (!mounted || gen != _generation) return;
        setState(() {
          _nearby = nearby;
          _results = const [];
        });
      } on Object catch (_) {
        if (!mounted || gen != _generation) return;
        setState(() {
          _nearby = const [];
          _results = const [];
          _queryFailed = true;
        });
      } finally {
        if (mounted && gen == _generation) {
          setState(() => _loading = false);
        }
      }
      return;
    }

    if (query.length < 2) {
      if (mounted && gen == _generation) {
        setState(() {
          _results = const [];
          _loading = false;
          _queryFailed = false;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _queryFailed = false;
    });
    try {
      final found = await book.search(query, near: widget.near);
      if (!mounted || gen != _generation) return;
      setState(() => _results = found);
    } on Object catch (_) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _results = const [];
        _queryFailed = true;
      });
    } finally {
      if (mounted && gen == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  List<Place> _matchingUserPlaces(String query) {
    if (!widget.allowUserPlace || query.isEmpty) return const [];
    final lower = query.toLowerCase();
    return widget.userPlaces
        .where((place) => place.name.toLowerCase().contains(lower))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PlaceBookState>(placeBookProvider, (previous, next) {
      if (previous?.status != PlaceBookStatus.ready && next.isReady) {
        unawaited(_runQuery());
      }
    });

    final neutrals = WarangNeutrals.of(context);
    final bookState = ref.watch(placeBookProvider);
    final query = _controller.text.trim();
    final matchingUser = _matchingUserPlaces(query);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: WarangField(
                  controller: _controller,
                  focusNode: _focus,
                  pill: true,
                  hintText: 'Search places in the Philippines',
                  textInputAction: TextInputAction.search,
                  leading: const WarangIcon(WarangGlyphs.search, size: 22),
                  trailing: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: _controller.clear,
                          icon: const WarangIcon(WarangGlyphs.close, size: 20),
                        ),
                ),
              ),
              Flexible(
                child: _buildBody(
                  context,
                  neutrals: neutrals,
                  bookState: bookState,
                  query: query,
                  matchingUser: matchingUser,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required WarangNeutrals neutrals,
    required PlaceBookState bookState,
    required String query,
    required List<Place> matchingUser,
  }) {
    final items = <Widget>[];

    if (query.isEmpty) {
      if (bookState.status == PlaceBookStatus.preparing) {
        items.add(_PreparingNotice(neutrals: neutrals));
      } else if (bookState.status == PlaceBookStatus.failed) {
        items.add(
          _FailedNotice(
            neutrals: neutrals,
            onRetry: () =>
                ref.read(placeBookProvider.notifier).ensureReady(retry: true),
          ),
        );
      } else if (_loading) {
        items.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      } else if (_queryFailed) {
        items.add(_FailedNotice(neutrals: neutrals, onRetry: _runQuery));
      } else if (widget.showNearbyWhenEmpty && _nearby.isNotEmpty) {
        items.add(_SectionHeader('Nearby', neutrals: neutrals));
        for (final place in _nearby) {
          items.add(
            _BookPlaceRow(
              place: place,
              onTap: () => Navigator.of(context).pop(BookPlacePick(place)),
            ),
          );
        }
      } else {
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Text(
              'Search places in the Philippines',
              textAlign: TextAlign.center,
              style: WarangType.hand.copyWith(color: neutrals.inkSoft),
            ),
          ),
        );
      }
    } else {
      if (matchingUser.isNotEmpty) {
        items.add(_SectionHeader('Your places', neutrals: neutrals));
        for (final place in matchingUser) {
          items.add(
            _UserPlaceRow(
              place: place,
              onTap: () => Navigator.of(
                context,
              ).pop(UserPlacePick(place.name, existing: place)),
            ),
          );
        }
      }

      if (bookState.status == PlaceBookStatus.preparing) {
        items.add(_PreparingNotice(neutrals: neutrals));
      } else if (bookState.status == PlaceBookStatus.failed) {
        items.add(
          _FailedNotice(
            neutrals: neutrals,
            onRetry: () =>
                ref.read(placeBookProvider.notifier).ensureReady(retry: true),
          ),
        );
      } else if (_loading) {
        items.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      } else if (_queryFailed) {
        items.add(_FailedNotice(neutrals: neutrals, onRetry: _runQuery));
      } else if (_results.isNotEmpty) {
        items.add(_SectionHeader('Places', neutrals: neutrals));
        for (final place in _results) {
          items.add(
            _BookPlaceRow(
              place: place,
              onTap: () => Navigator.of(context).pop(BookPlacePick(place)),
            ),
          );
        }
      } else if (!widget.allowUserPlace && query.length >= 2) {
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MayaCompanion(
                  size: 100,
                  place: MayaPlace.search,
                  pose: MayaPose.binoculars,
                ),
                const SizedBox(height: 12),
                Text(
                  'No place by that name yet',
                  textAlign: TextAlign.center,
                  style: WarangType.hand.copyWith(color: neutrals.inkSoft),
                ),
              ],
            ),
          ),
        );
      }

      if (widget.allowUserPlace) {
        items.add(
          _ActionRow(
            icon: WarangGlyphs.pin,
            label: 'Use "$query" as your own place',
            onTap: () => Navigator.of(context).pop(UserPlacePick(query)),
          ),
        );
      }
    }

    if (widget.allowClear) {
      items.add(
        _ActionRow(
          icon: WarangGlyphs.close,
          label: 'No place',
          onTap: () => Navigator.of(context).pop(const ClearPlacePick()),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: items,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.neutrals});

  final String title;
  final WarangNeutrals neutrals;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
    child: Text(
      title,
      style: WarangType.meta.copyWith(color: neutrals.inkFaint),
    ),
  );
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WarangType.titleS.copyWith(color: neutrals.ink),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WarangType.meta.copyWith(
                          color: neutrals.inkFaint,
                        ),
                      ),
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

class _BookPlaceRow extends StatelessWidget {
  const _BookPlaceRow({required this.place, required this.onTap});

  final BookPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category =
        PlaceCategories.byKey(place.category) ?? PlaceCategories.town;
    return _PlaceRow(
      leading: CategoryDisc(category: category, size: 40),
      title: place.name,
      subtitle: place.locationSubtitle,
      onTap: onTap,
    );
  }
}

class _UserPlaceRow extends StatelessWidget {
  const _UserPlaceRow({required this.place, required this.onTap});

  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final category = PlaceCategories.byKey(place.categoryKey);
    return _PlaceRow(
      leading: category != null
          ? CategoryDisc(category: category, size: 40)
          : SizedBox.square(
              dimension: 40,
              child: ClaySurface(
                depth: ClayDepth.clay1,
                circle: true,
                color: neutrals.surfaceRaised,
                child: const Center(
                  child: WarangIcon(WarangGlyphs.pin, size: 20),
                ),
              ),
            ),
      title: place.name,
      subtitle: category?.name ?? 'Your place',
      onTap: onTap,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final WarangGlyph icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              WarangIcon(icon, size: 20, color: neutrals.inkSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: WarangType.body.copyWith(color: neutrals.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreparingNotice extends StatelessWidget {
  const _PreparingNotice({required this.neutrals});

  final WarangNeutrals neutrals;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            'Getting places ready',
            style: WarangType.body.copyWith(color: neutrals.inkSoft),
          ),
        ),
      ],
    ),
  );
}

class _FailedNotice extends StatelessWidget {
  const _FailedNotice({required this.neutrals, required this.onRetry});

  final WarangNeutrals neutrals;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Places are not available right now',
          textAlign: TextAlign.center,
          style: WarangType.body.copyWith(color: neutrals.inkSoft),
        ),
        const SizedBox(height: 12),
        WarangButton.quiet(
          label: 'Try again',
          expand: false,
          onPressed: onRetry,
        ),
      ],
    ),
  );
}
