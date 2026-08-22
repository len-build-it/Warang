import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/app.dart';
import '../../app/theme/tokens.dart';
import '../../core/models.dart';
import '../../data/files/photo_store.dart';
import '../../data/repository.dart';
import '../capture/capture_screen.dart';
import '../settings/settings_screen.dart';
import '../share/share_service.dart';
import '../trips/trips_sheet.dart';
import 'map_painter.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(repositoryProvider);
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) => _HomeContent(repository: repository),
    );
  }
}

class _HomeContent extends StatefulWidget {
  const _HomeContent({required this.repository});
  final WarangRepository repository;
  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  final _photoStore = PhotoStore();
  Moment? _selected;

  Future<void> _capture() async {
    final camera = await Permission.camera.request();
    if (!camera.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera access is needed to save a photograph.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CaptureScreen()));
    if (saved == true && mounted) setState(() {});
  }

  void _showTrips() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TripsSheet(repository: widget.repository),
  );

  void _showSearch() => showSearch<void>(
    context: context,
    delegate: MomentSearchDelegate(widget.repository),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<MapPalette>()!;
    final moments = widget.repository.moments;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: WarangMapPainter(
              palette: palette,
              dark: theme.brightness == Brightness.dark,
            ),
          ),
          if (moments.isEmpty)
            Center(child: _EmptyMapState(onCapture: _capture)),
          ...moments.asMap().entries.map(
            (entry) => _positionedPin(context, entry.value, entry.key),
          ),
          if (moments.length > 4)
            Positioned(
              left: MediaQuery.sizeOf(context).width * .64,
              top: MediaQuery.sizeOf(context).height * .33,
              child: _ClusterPin(count: moments.length),
            ),
          const _PositionMarker(),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 18,
            right: 18,
            child: _TopControls(
              onSearch: _showSearch,
              onSettings: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ),
          if (_selected != null)
            Positioned.fill(
              child: _MomentCard(
                moment: _selected!,
                repository: widget.repository,
                photoStore: _photoStore,
                onClose: () => setState(() => _selected = null),
              ),
            ),
          if (_selected == null)
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 88,
              left: 0,
              right: 0,
              child: const _SheetHandle(),
            ),
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 28,
            left: 18,
            right: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton.filledTonal(
                      onPressed: _showTrips,
                      icon: const Icon(Icons.layers_outlined),
                    ),
                  ),
                ),
                _CaptureButton(onPressed: _capture),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionedPin(BuildContext context, Moment moment, int index) {
    final size = MediaQuery.sizeOf(context);
    final x = moment.longitude == null
        ? .18 + ((index * .17) % .62)
        : .5 + (moment.longitude! % 1) * .12;
    final y = moment.latitude == null
        ? .25 + ((index * .13) % .43)
        : .47 - (moment.latitude! % 1) * .2;
    return Positioned(
      left: size.width * x,
      top: size.height * y,
      child: GestureDetector(
        onTap: () => setState(() => _selected = moment),
        child: _PhotoPin(moment: moment, photoStore: _photoStore),
      ),
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls({required this.onSearch, required this.onSettings});
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: .88),
        child: IconButton(onPressed: onSearch, icon: const Icon(Icons.search)),
      ),
      const Spacer(),
      CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: .88),
        child: IconButton(onPressed: onSettings, icon: const Icon(Icons.tune)),
      ),
    ],
  );
}

class _EmptyMapState extends StatelessWidget {
  const _EmptyMapState({required this.onCapture});
  final VoidCallback onCapture;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.explore_outlined,
        size: 30,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .45),
      ),
      const SizedBox(height: 10),
      Text(
        'Capture your first moment.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );
}

class _PositionMarker extends StatelessWidget {
  const _PositionMarker();
  @override
  Widget build(BuildContext context) => Positioned(
    left: MediaQuery.sizeOf(context).width * .5 - 10,
    top: MediaQuery.sizeOf(context).height * .48 - 10,
    child: Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: WarangColors.accent.withValues(alpha: .22),
      ),
      child: Center(
        child: Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: WarangColors.accent,
          ),
        ),
      ),
    ),
  );
}

class _PhotoPin extends StatelessWidget {
  const _PhotoPin({required this.moment, required this.photoStore});
  final Moment moment;
  final PhotoStore photoStore;
  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      width: 58,
      height: 66,
      alignment: Alignment.topCenter,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
            child: ClipOval(
              child: moment.relPath == null
                  ? const ColoredBox(
                      color: WarangColors.lightLine,
                      child: Icon(Icons.photo_outlined),
                    )
                  : FutureBuilder<File>(
                      future: photoStore.resolve(moment.relPath!),
                      builder: (context, snapshot) => snapshot.hasData
                          ? Image.file(snapshot.data!, fit: BoxFit.cover)
                          : const ColoredBox(color: WarangColors.lightLine),
                    ),
            ),
          ),
          Positioned(
            bottom: 5,
            child: Icon(Icons.arrow_drop_down, color: surface, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ClusterPin extends StatelessWidget {
  const _ClusterPin({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: WarangColors.accent,
      shape: BoxShape.circle,
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        fontFamily: 'DM Mono',
        color: WarangColors.accentInk,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: WarangColors.accent,
    shape: const CircleBorder(),
    elevation: 2,
    child: InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: const SizedBox(
        width: 74,
        height: 74,
        child: Icon(
          Icons.camera_alt_outlined,
          color: WarangColors.accentInk,
          size: 30,
        ),
      ),
    ),
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 42,
      height: 5,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(5),
      ),
    ),
  );
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.moment,
    required this.repository,
    required this.photoStore,
    required this.onClose,
  });
  final Moment moment;
  final WarangRepository repository;
  final PhotoStore photoStore;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final trip = repository.trips.firstWhere(
      (item) => item.id == moment.tripId,
      orElse: () => repository.everyday,
    );
    final date =
        '${moment.capturedAt.day.toString().padLeft(2, '0')} / ${moment.capturedAt.month.toString().padLeft(2, '0')} / ${moment.capturedAt.year}';
    return ColoredBox(
      color: Colors.black.withValues(alpha: .18),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      trip.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (moment.relPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: FutureBuilder<File>(
                      future: photoStore.resolve(moment.relPath!),
                      builder: (context, snapshot) => snapshot.hasData
                          ? Image.file(
                              snapshot.data!,
                              height: 220,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox(height: 80),
                    ),
                  ),
                if (moment.caption != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      moment.caption!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  '${moment.placeLabel ?? 'Location not added'}  ·  $date',
                  style: const TextStyle(fontFamily: 'DM Mono', fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: moment.relPath == null
                          ? null
                          : () async {
                              final file = await photoStore.resolve(
                                moment.relPath!,
                              );
                              await WarangShareService().shareFile(
                                file,
                                caption: moment.caption,
                              );
                            },
                      icon: const Icon(Icons.ios_share_outlined),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () async {
                        await repository.softDeleteMoment(moment.id);
                        onClose();
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MomentSearchDelegate extends SearchDelegate<void> {
  MomentSearchDelegate(this.repository);
  final WarangRepository repository;
  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );
  @override
  Widget buildResults(BuildContext context) => _results(context);
  @override
  Widget buildSuggestions(BuildContext context) => _results(context);
  Widget _results(BuildContext context) {
    final moments = repository.search(query);
    return ListView.builder(
      itemCount: moments.length,
      itemBuilder: (context, index) {
        final moment = moments[index];
        return ListTile(
          leading: const Icon(Icons.photo_outlined),
          title: Text(moment.caption ?? moment.placeLabel ?? 'Moment'),
          subtitle: Text(
            moment.capturedAt.toLocal().toString().split(' ').first,
          ),
        );
      },
    );
  }
}
