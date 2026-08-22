import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/app.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/models.dart';
import '../../data/files/photo_store.dart';
import '../../data/repository.dart';
import '../capture/capture_screen.dart';
import '../settings/settings_screen.dart';
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
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CaptureScreen()));
  }

  void _showTrips() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: .46),
    builder: (_) => TripsSheet(repository: widget.repository),
  );

  void _showSettings() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final moments = widget.repository.moments;
    final visibleMoments = moments.length > 5
        ? moments.take(5).toList()
        : moments;
    final size = MediaQuery.sizeOf(context);
    final selected = _selected;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: selected == null
            ? (dark ? Brightness.light : Brightness.dark)
            : Brightness.light,
        statusBarBrightness: selected == null
            ? (dark ? Brightness.dark : Brightness.light)
            : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: WarangMapPainter(
                palette: theme.extension<MapPalette>()!,
                dark: dark,
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: WarangTopScrim(),
            ),
            if (selected == null) ...[
              ...visibleMoments.asMap().entries.map(
                (entry) => _buildPin(entry.value, entry.key, size, false),
              ),
              if (moments.length > 5)
                Positioned(
                  left: 187,
                  top: 552,
                  child: WarangClusterPin(count: moments.length - 5),
                ),
              Positioned(
                left: size.width / 2 - 38,
                top: size.height / 2 - 38,
                child: const WarangPositionMarker(),
              ),
              if (moments.isEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 158,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: .09,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 9,
                        ),
                        child: Text(
                          'Capture your first moment.',
                          style: TextStyle(fontSize: 13.5),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: WarangSheetPeek(onTap: _showTrips),
              ),
              Positioned(
                bottom: 62,
                left: 0,
                right: 0,
                child: Center(child: WarangCaptureButton(onPressed: _capture)),
              ),
              Positioned(
                right: 20,
                bottom: 150,
                child: _RecenterButton(onPressed: () {}),
              ),
              Positioned(
                top: 52,
                right: 16,
                child: GestureDetector(
                  onLongPress: _showSettings,
                  child: const SizedBox(width: 44, height: 44),
                ),
              ),
            ] else ...[
              ...moments
                  .asMap()
                  .entries
                  .where((entry) => entry.value.id != selected.id)
                  .map(
                    (entry) => _buildPin(entry.value, entry.key, size, false),
                  ),
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _selected = null),
                  child: ColoredBox(
                    color: theme.colorScheme.onSurface.withValues(alpha: .42),
                  ),
                ),
              ),
              _buildPin(
                selected,
                moments.indexWhere((item) => item.id == selected.id),
                size,
                true,
              ),
              Positioned.fill(
                child: _MomentCard(
                  moment: selected,
                  repository: widget.repository,
                  photoStore: _photoStore,
                  onClose: () => setState(() => _selected = null),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPin(Moment moment, int index, Size size, bool selected) {
    const positions = [
      Offset(100, 272),
      Offset(238, 222),
      Offset(156, 398),
      Offset(288, 362),
      Offset(82, 508),
      Offset(214, 552),
    ];
    final position = positions[index % positions.length];
    final pinSize = selected ? 66.0 : 58.0;
    final top = position.dy - pinSize - 9;
    final left = position.dx - pinSize / 2;
    final future = moment.relPath == null
        ? Future<File?>.value(null)
        : _photoStore.resolve(moment.relPath!).then<File?>((file) => file);
    return Positioned(
      left: left,
      top: top,
      child: FutureBuilder<File?>(
        future: future,
        builder: (context, snapshot) => GestureDetector(
          onTap: () => setState(() => _selected = moment),
          child: WarangPhotoPin(file: snapshot.data, selected: selected),
        ),
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: const CircleBorder(),
    elevation: 0,
    shadowColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: .14),
    child: InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Icon(Icons.gps_fixed, size: 20),
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
    final future = moment.relPath == null
        ? Future<File?>.value(null)
        : photoStore.resolve(moment.relPath!).then<File?>((file) => file);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 472,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .28),
              blurRadius: 40,
              offset: const Offset(0, -14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<File?>(
              future: future,
              builder: (context, snapshot) => ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 224,
                  child: snapshot.data == null
                      ? ColoredBox(
                          color: Theme.of(
                            context,
                          ).extension<MapPalette>()!.landAlt,
                        )
                      : Image.file(snapshot.data!, fit: BoxFit.cover),
                ),
              ),
            ),
            if (moment.caption?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              Text(
                moment.caption!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16.5,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'DM Mono',
                  fontSize: 11,
                  letterSpacing: 1.6,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .54),
                ),
                children: [
                  if (moment.placeLabel == null)
                    TextSpan(
                      text: 'ADD LOCATION',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .72),
                      ),
                    ),
                  if (moment.placeLabel != null)
                    TextSpan(text: moment.placeLabel!.toUpperCase()),
                  TextSpan(
                    text:
                        ' · ${DateFormat('dd MMM yyyy').format(moment.capturedAt).toUpperCase()} · ${DateFormat('h:mm a').format(moment.capturedAt).toUpperCase()}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final label in ['Share', 'Edit', 'Delete']) ...[
                  Expanded(
                    child: WarangQuietButton(
                      label: label,
                      onPressed: label == 'Delete'
                          ? () async {
                              await repository.softDeleteMoment(moment.id);
                              onClose();
                            }
                          : null,
                    ),
                  ),
                  if (label != 'Delete') const SizedBox(width: 10),
                ],
              ],
            ),
            const Spacer(),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    6,
                    (index) => Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == 0
                            ? Theme.of(context).colorScheme.onSurface
                            : (Theme.of(context).brightness == Brightness.dark
                                  ? WarangColors.darkDotInactive
                                  : WarangColors.lightDotInactive),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Swipe for nearby moments',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    height: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .54),
                  ),
                ),
              ],
            ),
          ],
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

  Widget _results(BuildContext context) => ListView(
    children: repository
        .search(query)
        .map(
          (moment) => ListTile(
            title: Text(moment.caption ?? moment.placeLabel ?? 'Moment'),
            subtitle: Text(DateFormat('dd MMM yyyy').format(moment.capturedAt)),
          ),
        )
        .toList(),
  );
}
