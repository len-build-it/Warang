import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/app_state.dart';
import '../../app/shell/you_sheet.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../maya/maya_companion.dart';
import 'about_screen.dart';

/// Settings (S11), opened from the You sheet. It shows only controls that
/// work today.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late Future<int> _photoBytes;
  late Future<int> _cacheBytes;

  @override
  void initState() {
    super.initState();
    _photoBytes = ref.read(photoStoreProvider).storageBytes();
    _cacheBytes = ref.read(mapTileStoreProvider).totalBytes();
  }

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final repository = ref.watch(repositoryProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 4, 20, 34),
            children: [
              const Align(alignment: Alignment.centerLeft, child: BackButton()),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 0, 22),
                child: Semantics(
                  header: true,
                  child: Text(
                    'Settings',
                    style: WarangType.displayL.copyWith(color: neutrals.ink),
                  ),
                ),
              ),
              _Group(
                label: 'You',
                children: [
                  AnimatedBuilder(
                    animation: repository,
                    builder: (context, _) => _ProfileRow(
                      avatar: ProfileAvatar(
                        profile: repository.profile,
                        photoStore: repository.photoStore,
                        colour: WarangKeepsake.forUser(repository.trips).fill,
                        size: 48,
                      ),
                      name: repository.profile.name,
                      onTap: () => editProfileName(context, repository),
                    ),
                  ),
                ],
              ),
              _Group(
                label: 'Storage',
                children: [
                  _BytesRow(label: 'Photos on this phone', bytes: _photoBytes),
                ],
              ),
              _Group(
                label: 'Map',
                children: [
                  const WarangSettingsRow(
                    label: 'Theme',
                    value: 'Follows your phone',
                  ),
                  _BytesRow(
                    label: 'Saved map areas',
                    bytes: _cacheBytes,
                    trailing: WarangButton.quiet(
                      label: 'Clear',
                      expand: false,
                      onPressed: _clearMapCache,
                    ),
                  ),
                ],
              ),
              const _Group(
                label: 'About',
                children: [
                  WarangSettingsRow(
                    label: 'Version',
                    value: AboutScreen.version,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MayaCompanion(
                    size: 40,
                    place: MayaPlace.settings,
                    pose: contextPose(
                      now: DateTime.now(),
                      trips: repository.trips,
                      moments: repository.moments,
                      fallback: MayaPose.sitting,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Everything stays on this phone',
                      style: WarangType.meta.copyWith(color: neutrals.inkFaint),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearMapCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear saved map areas?'),
        content: const Text(
          'Areas you have visited will need a connection again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear map areas'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final store = ref.read(mapTileStoreProvider);
    await store.clear();
    if (!mounted) return;
    setState(() {
      _cacheBytes = store.totalBytes();
    });
    showWarangSnackBar(
      context,
      'Saved map areas cleared.',
      aboveNavigation: false,
      duration: const Duration(seconds: 2),
    );
  }
}

/// A settings group: its label in `meta` `inkSoft`, then a `surface` clay
/// card of rows.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 0, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: WarangType.meta.copyWith(color: neutrals.inkSoft),
            ),
          ),
          WarangSettingsCard(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const WarangDivider(),
                child,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BytesRow extends StatelessWidget {
  const _BytesRow({required this.label, required this.bytes, this.trailing});
  final String label;
  final Future<int> bytes;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => FutureBuilder<int>(
    future: bytes,
    builder: (context, snapshot) => WarangSettingsRow(
      label: label,
      // Show a dash until the size is known instead of a misleading 0 B.
      value: snapshot.hasData ? _formatBytes(snapshot.data!) : '-',
      trailing: trailing,
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.avatar,
    required this.name,
    required this.onTap,
  });
  final Widget avatar;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    return Semantics(
      button: true,
      label: 'Edit name',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: WarangType.titleS.copyWith(color: neutrals.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Only on this phone',
                      style: WarangType.meta.copyWith(color: neutrals.inkFaint),
                    ),
                  ],
                ),
              ),
              const WarangIcon(WarangGlyphs.edit, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
