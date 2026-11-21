import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/memory_stats.dart';
import '../../core/models.dart';
import '../../data/files/photo_store.dart';
import '../../data/repository.dart';
import '../theme/tokens.dart';

/// Navigation drawer hosted by the shell scaffold, so it covers every tab and
/// the bottom navigation while open.
class WarangDrawer extends StatelessWidget {
  const WarangDrawer({
    super.key,
    required this.repository,
    required this.onSearch,
    required this.onSettings,
    required this.onAbout,
  });

  final WarangRepository repository;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = repository.profile;
    final places = distinctPlaces(repository.moments);
    final trips = repository.trips.where((trip) => !trip.isEveryday).length;
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatar(
                    profile: profile,
                    photoStore: repository.photoStore,
                    onTap: _pickAvatar,
                  ),
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
                    onPressed: () => editProfileName(context, repository),
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
                  _DrawerCount(value: trips, label: 'Trips'),
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
                'Warang · version 1.0.0 · build 1',
                style: WarangType.caption.copyWith(
                  color: WarangNeutrals.of(context).inkFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked != null) await repository.setAvatar(File(picked.path));
  }
}

/// Asks for a new display name and saves a non-empty answer.
Future<void> editProfileName(
  BuildContext context,
  WarangRepository repository,
) async {
  final controller = TextEditingController(text: repository.profile.name);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name'),
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

/// Circular profile picture with an initial fallback on amber.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.profile,
    required this.photoStore,
    this.onTap,
    this.size = 52,
  });

  final Profile profile;
  final PhotoStore photoStore;
  final VoidCallback? onTap;
  final double size;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Future<File?>? _file;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.avatarRelPath != widget.profile.avatarRelPath) {
      _resolve();
    }
  }

  void _resolve() {
    final path = widget.profile.avatarRelPath;
    _file = path == null || path.isEmpty
        ? null
        : widget.photoStore
              .resolve(path)
              .then<File?>((file) async => await file.exists() ? file : null)
              .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.profile.name;
    final fallback = _fallback(
      name.isEmpty ? 'W' : name.substring(0, 1).toUpperCase(),
    );
    final avatar = _file == null
        ? fallback
        : FutureBuilder<File?>(
            future: _file,
            builder: (context, snapshot) {
              final file = snapshot.data;
              if (file == null) return fallback;
              return ClipOval(
                child: Image.file(
                  file,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
              );
            },
          );
    if (widget.onTap == null) return avatar;
    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: GestureDetector(onTap: widget.onTap, child: avatar),
    );
  }

  Widget _fallback(String letter) => Container(
    width: widget.size,
    height: widget.size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: WarangColors.accent,
      shape: BoxShape.circle,
    ),
    child: Text(
      letter,
      style: TextStyle(
        fontFamily: WarangType.textFamily,
        fontSize: widget.size * .38,
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
      Text('$value', style: WarangType.titleS),
      const SizedBox(height: 2),
      Text(
        label,
        style: WarangType.caption.copyWith(
          color: WarangNeutrals.of(context).inkFaint,
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
            Icon(icon, size: 20, color: WarangNeutrals.of(context).inkSoft),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(fontSize: 15.5)),
          ],
        ),
      ),
    ),
  );
}
