import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/app.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/models.dart';
import '../../data/files/photo_store.dart';
import '../../data/repository.dart';
import '../capture/capture_screen.dart';
import '../settings/settings_screen.dart';
import '../map/warang_map.dart';

class TravelModeScreen extends ConsumerWidget {
  const TravelModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(repositoryProvider);
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) => _TravelModeContent(repository: repository),
    );
  }
}

class _TravelModeContent extends StatefulWidget {
  const _TravelModeContent({required this.repository});
  final WarangRepository repository;

  @override
  State<_TravelModeContent> createState() => _TravelModeContentState();
}

class _TravelModeContentState extends State<_TravelModeContent> {
  final _photoStore = PhotoStore();
  final _mapKey = GlobalKey<WarangMapSurfaceState>();
  Moment? _selected;
  bool _drawerOpen = false;

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

  void _showSettings() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  Future<void> _showSearch() async {
    _closeDrawer();
    final selectedMoment = await showSearch<Moment?>(
      context: context,
      delegate: MomentSearchDelegate(
        widget.repository,
        photoStore: _photoStore,
      ),
    );
    if (selectedMoment != null && mounted) {
      setState(() => _selected = selectedMoment);
      if (selectedMoment.latitude != null && selectedMoment.longitude != null) {
        _mapKey.currentState?.moveToCoordinate(
          selectedMoment.latitude!,
          selectedMoment.longitude!,
        );
      }
    }
  }

  void _openDrawer() => setState(() => _drawerOpen = true);
  void _closeDrawer() {
    if (_drawerOpen && mounted) setState(() => _drawerOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final moments = widget.repository.moments;
    final size = MediaQuery.sizeOf(context);
    final selected = _selected;
    final navHeight = WarangLayout.navigationHeight(context);
    final topOffset = math.max(MediaQuery.paddingOf(context).top, 12.0) + 8.0;
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
            Positioned.fill(
              child: WarangMapSurface(
                key: _mapKey,
                moments: moments,
                selectedId: selected?.id,
                palette: theme.extension<MapPalette>()!,
                dark: dark,
                onMomentTap: (moment) => setState(() => _selected = moment),
                onMapTap: selected == null
                    ? null
                    : () => setState(() => _selected = null),
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: WarangTopScrim(),
            ),
            Positioned(
              top: topOffset,
              left: 16,
              child: _HomeMenuButton(onPressed: _openDrawer),
            ),
            if (selected == null) ...[
              if (moments.isEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: navHeight + 104,
                  child: Center(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: .94,
                          ),
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
                ),
              Positioned(
                bottom: navHeight + 16,
                left: 0,
                right: 0,
                child: Center(child: WarangCaptureButton(onPressed: _capture)),
              ),
              Positioned(
                right: 16,
                bottom: navHeight + 29,
                child: _RecenterButton(
                  onPressed: () => _mapKey.currentState?.recenter(),
                ),
              ),
            ] else ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selected = null),
                  child: ColoredBox(
                    color: theme.colorScheme.onSurface.withValues(alpha: .42),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: navHeight + 8,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 520,
                      maxHeight: size.height - navHeight - topOffset - 24,
                    ),
                    child: MomentCard(
                      moment: selected,
                      repository: widget.repository,
                      photoStore: _photoStore,
                      onClose: () => setState(() => _selected = null),
                    ),
                  ),
                ),
              ),
            ],
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_drawerOpen,
                child: AnimatedOpacity(
                  opacity: _drawerOpen ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: GestureDetector(
                    onTap: _closeDrawer,
                    child: ColoredBox(
                      color: theme.colorScheme.onSurface.withValues(alpha: .42),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: _drawerOpen ? 0 : -size.width * .82,
              top: 0,
              bottom: 0,
              width: size.width * .82,
              child: WarangDrawer(
                repository: widget.repository,
                onClose: _closeDrawer,
                onSearch: _showSearch,
                onSettings: () {
                  _closeDrawer();
                  _showSettings();
                },
                onAbout: () {
                  _closeDrawer();
                  showAboutDialog(
                    context: context,
                    applicationName: 'Warang',
                    applicationVersion: '1.0.0',
                    applicationLegalese: 'Aklanon. To go out and explore.',
                  );
                },
              ),
            ),
            if (!_drawerOpen)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 24,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 180) _openDrawer();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeMenuButton extends StatelessWidget {
  const _HomeMenuButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => WarangGlassIconButton(
    icon: const Icon(Icons.menu),
    onPressed: onPressed,
    semanticLabel: 'Open navigation drawer',
    tooltip: 'Menu',
  );
}

class WarangDrawer extends StatelessWidget {
  const WarangDrawer({
    super.key,
    required this.repository,
    required this.onClose,
    required this.onSearch,
    required this.onSettings,
    required this.onAbout,
  });

  final WarangRepository repository;
  final VoidCallback onClose;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = repository.profile;
    final places = repository.moments
        .map((moment) => moment.placeLabel?.trim())
        .whereType<String>()
        .where((place) => place.isNotEmpty)
        .toSet()
        .length;
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -180) onClose();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DrawerAvatar(profile: profile, onTap: _pickAvatar),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name.isEmpty ? 'Your Warang' : profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Public Sans',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Stored on this phone only',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit name',
                      onPressed: () => _editName(context),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _DrawerCount(
                      value: repository.moments.length,
                      label: 'Moments',
                    ),
                    const SizedBox(width: 22),
                    _DrawerCount(value: places, label: 'Places'),
                    const SizedBox(width: 22),
                    _DrawerCount(
                      value: repository.trips.length,
                      label: 'Trips',
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Divider(height: 1),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    _DrawerRow(
                      icon: Icons.search,
                      label: 'Search',
                      onTap: onSearch,
                    ),
                    _DrawerRow(
                      icon: Icons.tune,
                      label: 'Settings',
                      onTap: onSettings,
                    ),
                    _DrawerRow(
                      icon: Icons.info_outline,
                      label: 'About Warang',
                      onTap: onAbout,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Text(
                  'WARANG  ·  VERSION 1.0.0  ·  BUILD 1',
                  style: TextStyle(
                    fontFamily: 'DM Mono',
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface.withValues(alpha: .42),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: repository.profile.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await repository.setName(name);
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked != null) await repository.setAvatar(File(picked.path));
  }
}

class _DrawerAvatar extends StatelessWidget {
  const _DrawerAvatar({required this.profile, required this.onTap});
  final Profile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fallback = profile.name.isEmpty
        ? 'W'
        : profile.name.substring(0, 1).toUpperCase();
    final path = profile.avatarRelPath;
    if (path == null || path.isEmpty) {
      return GestureDetector(onTap: onTap, child: _fallback(fallback));
    }
    return FutureBuilder<File>(
      future: PhotoStore().resolve(path),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.existsSync()) {
          return GestureDetector(onTap: onTap, child: _fallback(fallback));
        }
        return GestureDetector(
          onTap: onTap,
          child: ClipOval(
            child: Image.file(
              snapshot.data!,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(fallback),
            ),
          ),
        );
      },
    );
  }

  Widget _fallback(String letter) => Container(
    width: 52,
    height: 52,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: WarangColors.accent,
      shape: BoxShape.circle,
    ),
    child: Text(
      letter,
      style: const TextStyle(
        fontFamily: 'Bricolage Grotesque',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: WarangColors.accentInk,
      ),
    ),
  );
}

class _DrawerCount extends StatelessWidget {
  const _DrawerCount({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$value',
        style: const TextStyle(
          fontFamily: 'DM Mono',
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'DM Mono',
          fontSize: 9,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .54),
        ),
      ),
    ],
  );
}

class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .68),
            ),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(fontSize: 15.5)),
          ],
        ),
      ),
    ),
  );
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => WarangGlassIconButton(
    icon: const Icon(Icons.gps_fixed),
    onPressed: onPressed,
    semanticLabel: 'Recenter map on current location',
    tooltip: 'Recenter',
  );
}

class MomentCard extends StatefulWidget {
  const MomentCard({
    super.key,
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
  State<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<MomentCard> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant MomentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moment.relPath != widget.moment.relPath ||
        oldWidget.photoStore != widget.photoStore) {
      _resolve();
    }
  }

  void _resolve() {
    final relPath = widget.moment.relPath;
    _future = relPath == null
        ? Future<File?>.value(null)
        : widget.photoStore
              .resolve(relPath)
              .then<File?>((file) => file)
              .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    final moment = widget.moment;
    final repository = widget.repository;
    final onClose = widget.onClose;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    final placeText =
        moment.placeLabel != null && moment.placeLabel!.trim().isNotEmpty
        ? moment.placeLabel!.trim().toUpperCase()
        : 'NO LOCATION';
    final dateText = DateFormat(
      'dd MMM yyyy',
    ).format(moment.capturedAt).toUpperCase();
    final timeText = DateFormat(
      'h:mm a',
    ).format(moment.capturedAt).toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withValues(
              alpha: dark ? .35 : .22,
            ),
            blurRadius: 28,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Restrained printed photograph frame:
            Container(
              decoration: BoxDecoration(
                color: dark
                    ? WarangColors.darkSurface
                    : WarangColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: dark ? WarangColors.darkLine : WarangColors.lightLine,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: dark ? 0.22 : 0.08,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(7),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 224,
                  width: double.infinity,
                  child: FutureBuilder<File?>(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.hasData &&
                          snapshot.data != null &&
                          snapshot.data!.existsSync()) {
                        return Image.file(snapshot.data!, fit: BoxFit.cover);
                      }
                      return ColoredBox(
                        color: theme.extension<MapPalette>()!.landAlt,
                        child: const Center(
                          child: Icon(Icons.photo_outlined, size: 36),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (moment.caption?.isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Text(
                moment.caption!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 16.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Readable opaque caption/metadata area with stamp-like stored metadata:
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.65),
                ),
              ),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'DM Mono',
                    fontSize: 11,
                    letterSpacing: 1.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: .64),
                  ),
                  children: [
                    TextSpan(
                      text: placeText,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: moment.placeLabel == null ? .72 : .88,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(text: ' · $dateText · $timeText'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            WarangQuietButton(
              label: 'Delete',
              onPressed: () async {
                await repository.softDeleteMoment(moment.id);
                onClose();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MomentSearchDelegate extends SearchDelegate<Moment?> {
  MomentSearchDelegate(this.repository, {PhotoStore? photoStore})
    : photoStore = photoStore ?? PhotoStore();
  final WarangRepository repository;
  final PhotoStore photoStore;

  @override
  String? get searchFieldLabel => 'Search captions, places, or trips...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Clear',
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
        icon: const Icon(Icons.clear),
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: FutureBuilder<List<Moment>>(
        future: repository.searchAsync(query),
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
                    Icon(
                      Icons.search_off_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      query.trim().isEmpty
                          ? 'No moments captured yet'
                          : 'No matches found for "${query.trim()}"',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      query.trim().isEmpty
                          ? 'Moments you capture will appear here.'
                          : 'Try searching for a different caption or place name.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: moments.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 72,
              color: theme.colorScheme.outline.withValues(alpha: 0.25),
            ),
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
              final dateStr = DateFormat(
                'dd MMM yyyy',
              ).format(moment.capturedAt);
              final subtitle = hasCaption && hasPlace
                  ? '$hasPlace - $dateStr'
                  : dateStr;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: _MomentSearchThumbnail(
                  moment: moment,
                  photoStore: photoStore,
                ),
                title: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: moment.latitude != null && moment.longitude != null
                    ? Icon(
                        Icons.near_me_outlined,
                        size: 18,
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      )
                    : null,
                onTap: () => close(context, moment),
              );
            },
          );
        },
      ),
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
    if (path == null) {
      _fileFuture = null;
    } else {
      _fileFuture = widget.photoStore.resolve(path).then((f) async {
        return await f.exists() ? f : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _fileFuture == null
          ? Icon(
              Icons.image_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            )
          : FutureBuilder<File?>(
              future: _fileFuture,
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file != null) {
                  return Image.file(file, fit: BoxFit.cover);
                }
                return Icon(
                  Icons.image_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                );
              },
            ),
    );
  }
}
