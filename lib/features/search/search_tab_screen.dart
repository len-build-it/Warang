import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/app_state.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../data/files/photo_store.dart';
import '../../data/repository.dart';

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
    final theme = Theme.of(context);
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const WarangIcon(WarangGlyphs.searchEmpty, size: 48),
                  const SizedBox(height: 14),
                  Text(
                    query.isEmpty
                        ? 'No moments captured yet'
                        : 'No matches found for "$query"',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    query.isEmpty
                        ? 'Moments you capture will appear here.'
                        : 'Try searching for a different caption or place name.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.only(
            bottom: WarangLayout.dockClearance(context) + 16,
          ),
          itemCount: moments.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, indent: 72, color: neutrals.hairline),
          itemBuilder: (context, index) {
            final moment = moments[index];
            final hasCaption =
                moment.caption != null && moment.caption!.trim().isNotEmpty;
            final hasPlace =
                moment.placeLabel != null &&
                moment.placeLabel!.trim().isNotEmpty;
            final title = hasCaption
                ? moment.caption!
                : (hasPlace ? moment.placeLabel! : 'Untitled moment');
            final dateStr = formatDate(moment.capturedAt);
            final subtitle = hasCaption && hasPlace
                ? '${moment.placeLabel} - $dateStr'
                : dateStr;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              leading: _MomentSearchThumbnail(
                moment: moment,
                photoStore: widget.photoStore,
              ),
              title: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: WarangType.body.copyWith(
                  color: neutrals.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WarangType.meta.copyWith(color: neutrals.inkFaint),
              ),
              trailing: moment.latitude != null && moment.longitude != null
                  ? const WarangIcon(WarangGlyphs.recenter, size: 20)
                  : null,
              onTap: () => widget.onSelected(moment),
            );
          },
        );
      },
    );
  }
}

class _MomentSearchThumbnail extends StatefulWidget {
  const _MomentSearchThumbnail({
    required this.moment,
    required this.photoStore,
  });

  final Moment moment;
  final PhotoStore photoStore;

  @override
  State<_MomentSearchThumbnail> createState() => _MomentSearchThumbnailState();
}

class _MomentSearchThumbnailState extends State<_MomentSearchThumbnail> {
  Future<File?>? _fileFuture;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void didUpdateWidget(covariant _MomentSearchThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moment.relPath != widget.moment.relPath ||
        oldWidget.moment.thumbRelPath != widget.moment.thumbRelPath) {
      _loadFile();
    }
  }

  void _loadFile() {
    final path = widget.moment.thumbRelPath ?? widget.moment.relPath;
    _fileFuture = path == null
        ? null
        : widget.photoStore.resolve(path).then((f) async {
            return await f.exists() ? f : null;
          });
  }

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    const placeholder = WarangIcon(WarangGlyphs.photo, size: 20);
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: neutrals.hairline,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: _fileFuture == null
          ? placeholder
          : FutureBuilder<File?>(
              future: _fileFuture,
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file != null) return Image.file(file, fit: BoxFit.cover);
                return placeholder;
              },
            ),
    );
  }
}
