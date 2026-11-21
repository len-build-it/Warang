import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/app_state.dart';
import '../../app/shell/warang_drawer.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';

/// Settings shows only controls that work today; share options return when
/// sharing ships.
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
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final repository = ref.watch(repositoryProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          scrolledUnderElevation: 0,
          backgroundColor: theme.colorScheme.surface,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
          children: [
            const WarangSectionLabel('You'),
            const SizedBox(height: 9),
            WarangSettingsCard(
              children: [
                AnimatedBuilder(
                  animation: repository,
                  builder: (context, _) => _ProfileRow(
                    avatar: ProfileAvatar(
                      profile: repository.profile,
                      photoStore: repository.photoStore,
                      size: 48,
                    ),
                    name: repository.profile.name,
                    onTap: () => editProfileName(context, repository),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const WarangSectionLabel('Storage'),
            const SizedBox(height: 9),
            WarangSettingsCard(
              children: [
                _BytesRow(label: 'Photos on this phone', bytes: _photoBytes),
              ],
            ),
            const SizedBox(height: 20),
            const WarangSectionLabel('Map'),
            const SizedBox(height: 9),
            WarangSettingsCard(
              children: [
                const WarangSettingsRow(
                  label: 'Theme',
                  value: 'Follows your phone',
                ),
                const WarangDivider(),
                _BytesRow(
                  label: 'Offline map cache',
                  bytes: _cacheBytes,
                  trailing: TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: const Size(48, 36),
                    ),
                    onPressed: _clearMapCache,
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const WarangSectionLabel('About'),
            const SizedBox(height: 9),
            WarangSettingsCard(
              children: [
                const WarangSettingsRow(label: 'Version', value: '1.0.0'),
                const WarangDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('warang', style: TextStyle(fontSize: 15.5)),
                      const SizedBox(height: 4),
                      Text(
                        'Aklanon. To go out and explore.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Your photos and pins stay on this phone.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearMapCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear offline map cache?'),
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
            child: const Text('Clear cache'),
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
      'Offline map cache cleared.',
      aboveNavigation: false,
      duration: const Duration(seconds: 2),
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
  Widget build(BuildContext context) => Semantics(
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Stored on this phone only',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            WarangIcon(
              WarangGlyphs.edit,
              size: 18,
              color: WarangNeutrals.of(context).inkSoft,
            ),
          ],
        ),
      ),
    ),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
