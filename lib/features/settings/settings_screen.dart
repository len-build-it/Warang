import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../data/files/photo_store.dart';
import '../map/map_tile_store.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _copyCaption = true;
  bool _cornerMark = true;
  late final MapTileStore _mapTileStore = MapTileStore();

  @override
  void dispose() {
    _mapTileStore.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(repositoryProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
            children: [
              Text('Settings', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 22),
              const WarangSectionLabel('You'),
              const SizedBox(height: 9),
              WarangSettingsCard(
                children: [_ProfileRow(name: repository.profile.name)],
              ),
              const SizedBox(height: 20),
              const WarangSectionLabel('Storage'),
              const SizedBox(height: 9),
              WarangSettingsCard(
                children: [
                  FutureBuilder<int>(
                    future: PhotoStore().storageBytes(),
                    builder: (context, snapshot) => WarangSettingsRow(
                      label: 'Photos on this phone',
                      value: _formatBytes(snapshot.data ?? 0),
                    ),
                  ),
                  const WarangSettingsRow(label: 'Clean up', value: '0 B'),
                ],
              ),
              const SizedBox(height: 20),
              const WarangSectionLabel('Map'),
              const SizedBox(height: 9),
              WarangSettingsCard(
                children: [
                  const WarangSettingsRow(
                    label: 'Theme',
                    value: 'FOLLOWS PHONE',
                  ),
                  const WarangDivider(),
                  FutureBuilder<int>(
                    future: _mapTileStore.totalBytes(),
                    builder: (context, snapshot) => WarangSettingsRow(
                      label: 'Offline map cache',
                      value: _formatBytes(snapshot.data ?? 0),
                      trailing: Text(
                        'Clear',
                        style: TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 13,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: .58),
                        ),
                      ),
                      onTap: _clearMapCache,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const WarangSectionLabel('Sharing'),
              const SizedBox(height: 9),
              WarangSettingsCard(
                children: [
                  WarangSettingsRow(
                    label: 'Copy caption on share',
                    toggle: true,
                    trailing: WarangToggle(
                      value: _copyCaption,
                      onChanged: _setCopyCaption,
                    ),
                  ),
                  const WarangDivider(),
                  WarangSettingsRow(
                    label: 'Corner mark on images',
                    toggle: true,
                    trailing: WarangToggle(
                      value: _cornerMark,
                      onChanged: _setCornerMark,
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
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Everything stays on this phone.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setCopyCaption(bool value) => setState(() => _copyCaption = value);
  void _setCornerMark(bool value) => setState(() => _cornerMark = value);

  Future<void> _clearMapCache() async {
    await _mapTileStore.clear();
    if (mounted) setState(() {});
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: WarangColors.accent,
          ),
          child: Text(
            name.isEmpty ? 'W' : name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: WarangColors.accentInk,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
      ],
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
