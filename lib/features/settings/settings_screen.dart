import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../data/files/photo_store.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(repositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('You', style: Theme.of(context).textTheme.labelLarge),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(repository.profile.name),
              subtitle: const Text('Stored on this phone only'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 20),
          Text('Storage', style: Theme.of(context).textTheme.labelLarge),
          Card(
            child: FutureBuilder<int>(
              future: PhotoStore().storageBytes(),
              builder: (context, snapshot) => ListTile(
                leading: const Icon(Icons.sd_storage_outlined),
                title: Text('${_formatBytes(snapshot.data ?? 0)} used'),
                subtitle: const Text('Photos and thumbnails'),
                trailing: TextButton(
                  onPressed: () {},
                  child: const Text('Clean up'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Map', style: Theme.of(context).textTheme.labelLarge),
          const Card(
            child: ListTile(
              leading: Icon(Icons.brightness_6_outlined),
              title: Text('Theme follows your phone'),
              subtitle: Text(
                'Light and dark palettes are picked automatically',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Sharing', style: Theme.of(context).textTheme.labelLarge),
          const Card(
            child: ListTile(
              leading: Icon(Icons.ios_share_outlined),
              title: Text('Caption copied on share'),
              subtitle: Text(
                'Everything stays on this phone until you share it',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('About', style: Theme.of(context).textTheme.labelLarge),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Warang'),
              subtitle: Text('Aklanon for “to go out and explore”'),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
