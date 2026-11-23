import 'dart:async';

import 'package:flutter/material.dart';
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
import '../home_tab/trip_photo.dart';
import '../maya/maya_companion.dart';

/// The Search dock tab: the moment search that used to open from the
/// drawer, with the same matching and the same results.
class SearchTabScreen extends ConsumerStatefulWidget {
  const SearchTabScreen({super.key});

  @override
  ConsumerState<SearchTabScreen> createState() => _SearchTabScreenState();
}

class _SearchTabScreenState extends ConsumerState<SearchTabScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The field takes focus when the tab opens, as the old search did.
    ref.listen<int>(shellTabProvider, (previous, next) {
      if (next == ShellTab.search) {
        _focus.requestFocus();
      } else if (previous == ShellTab.search) {
        _focus.unfocus();
      }
    });
    final neutrals = WarangNeutrals.of(context);
    final repository = ref.watch(repositoryProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Text(
                'Search',
                style: WarangType.displayL.copyWith(color: neutrals.ink),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => WarangField(
                  controller: _controller,
                  focusNode: _focus,
                  pill: true,
                  hintText: 'Search captions, places, or trips',
                  textInputAction: TextInputAction.search,
                  leading: const WarangIcon(WarangGlyphs.search, size: 22),
                  trailing: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: _controller.clear,
                          icon: const WarangIcon(WarangGlyphs.close, size: 20),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([_controller, repository]),
                builder: (context, _) => MomentSearchResults(
                  repository: repository,
                  photoStore: ref.watch(photoStoreProvider),
                  query: _controller.text,
                  onSelected: (moment) {
                    _focus.unfocus();
                    showMomentOnMap(context, ref, moment);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Moments matching [query], or a clear empty state.
class MomentSearchResults extends StatefulWidget {
  const MomentSearchResults({
    super.key,
    required this.repository,
    required this.photoStore,
    required this.query,
    required this.onSelected,
  });

  final WarangRepository repository;
  final PhotoStore photoStore;
  final String query;
  final ValueChanged<Moment> onSelected;

  @override
  State<MomentSearchResults> createState() => _MomentSearchResultsState();
}

class _MomentSearchResultsState extends State<MomentSearchResults> {
  late Future<List<Moment>> _results;
  late String _query;
  late int _momentCount;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(covariant MomentSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _query ||
        widget.repository.moments.length != _momentCount) {
      _search();
    }
  }

  void _search() {
    _query = widget.query;
    _momentCount = widget.repository.moments.length;
    _results = widget.repository.searchAsync(_query);
  }

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final query = widget.query.trim();
    return FutureBuilder<List<Moment>>(
      future: _results,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final moments = snapshot.data ?? const <Moment>[];
        if (moments.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MayaCompanion(
                    size: 120,
                    place: MayaPlace.search,
                    pose: MayaPose.binoculars,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    query.isEmpty
                        ? 'Moments you capture will appear here'
                        : 'Nothing here yet, try another word',
                    textAlign: TextAlign.center,
                    style: WarangType.hand.copyWith(color: neutrals.inkSoft),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.only(
            top: 8,
            bottom: WarangLayout.dockClearance(context) + 16,
          ),
          itemCount: moments.length,
          itemBuilder: (context, index) => _Staggered(
            // Results arrive 30 ms apart, the first ten at most.
            key: ValueKey('${widget.query}/${moments[index].id}'),
            delay: Duration(milliseconds: 30 * index.clamp(0, 10)),
            child: _ResultRow(
              moment: moments[index],
              photoStore: widget.photoStore,
              onTap: () => widget.onSelected(moments[index]),
            ),
          ),
        );
      },
    );
  }
}

/// A result (S9): a 56 polaroid thumbnail, the caption in `titleS`, and
/// the place and date in `meta`.
class _ResultRow extends StatelessWidget {
  const _ResultRow({
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
    final caption = moment.caption?.trim() ?? '';
    final place = moment.placeLabel?.trim() ?? '';
    final title = caption.isNotEmpty
        ? caption
        : (place.isNotEmpty ? place : 'Untitled moment');
    final date = formatDate(moment.capturedAt);
    final detail = caption.isNotEmpty && place.isNotEmpty
        ? '$place · $date'
        : date;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: WarangPolaroid(
                  depth: ClayDepth.clay1,
                  frame: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  photo: MomentPhoto(
                    moment: moment,
                    photoStore: photoStore,
                    glyphSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WarangType.meta.copyWith(color: neutrals.inkFaint),
                    ),
                  ],
                ),
              ),
              if (PlaceCategories.byKey(moment.placeCategory)
                  case final category?)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: CategoryDisc(category: category, size: 32),
                )
              else if (moment.latitude != null && moment.longitude != null)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: WarangIcon(WarangGlyphs.pin, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slides a result up into place after [delay]; under reduced motion it
/// simply appears.
class _Staggered extends StatefulWidget {
  const _Staggered({super.key, required this.delay, required this.child});
  final Duration delay;
  final Widget child;

  @override
  State<_Staggered> createState() => _StaggeredState();
}

class _StaggeredState extends State<_Staggered>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: WarangMotion.slide.duration,
  );
  Timer? _start;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_start != null || _controller.value > 0) return;
    if (WarangMotion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    _start = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final t = WarangMotion.slide.curve.transform(_controller.value);
      return Opacity(
        opacity: _controller.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      );
    },
    child: widget.child,
  );
}
