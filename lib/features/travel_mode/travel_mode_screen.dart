import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

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

  void _showSearch() {
    _closeDrawer();
    showSearch<void>(
      context: context,
      delegate: MomentSearchDelegate(widget.repository),
    );
  }

  Future<void> _shareBackup() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Warang backup: your photos and moments stay on this phone until you share them.',
      ),
    );
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
              top: 52,
              left: 16,
              child: _HomeMenuButton(onPressed: _openDrawer),
            ),
            if (selected == null) ...[
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
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: WarangSheetPeek(),
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
                child: _RecenterButton(
                  onPressed: () => _mapKey.currentState?.recenter(),
                ),
              ),
            ] else ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _selected = null),
                  child: ColoredBox(
                    color: theme.colorScheme.onSurface.withValues(alpha: .42),
                  ),
                ),
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
              child: _WarangDrawer(
                repository: widget.repository,
                onClose: _closeDrawer,
                onSearch: _showSearch,
                onSettings: () {
                  _closeDrawer();
                  _showSettings();
                },
                onBackup: () {
                  _closeDrawer();
                  _shareBackup();
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
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Icon(Icons.menu, size: 21),
      ),
    ),
  );
}

class _WarangDrawer extends StatelessWidget {
  const _WarangDrawer({
    required this.repository,
    required this.onClose,
    required this.onSearch,
    required this.onSettings,
    required this.onBackup,
    required this.onAbout,
  });

  final WarangRepository repository;
  final VoidCallback onClose;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onBackup;
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
                    _DrawerCount(value: repository.moments.length, label: 'Moments'),
                    const SizedBox(width: 22),
                    _DrawerCount(value: places, label: 'Places'),
                    const SizedBox(width: 22),
                    _DrawerCount(value: repository.trips.length, label: 'Trips'),
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
                      icon: Icons.archive_outlined,
                      label: 'Backup & .travelbook',
                      onTap: onBackup,
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
  const _DrawerRow({required this.icon, required this.label, required this.onTap});
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
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .68)),
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
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
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

  Widget _results(BuildContext context) => FutureBuilder<List<Moment>>(
    future: repository.searchAsync(query),
    builder: (context, snapshot) {
      final moments = snapshot.data ?? const <Moment>[];
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        children: moments
            .map(
              (moment) => ListTile(
                title: Text(moment.caption ?? moment.placeLabel ?? 'Moment'),
                subtitle: Text(
                  DateFormat('dd MMM yyyy').format(moment.capturedAt),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}
