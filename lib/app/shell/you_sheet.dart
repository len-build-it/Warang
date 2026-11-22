import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/memory_stats.dart';
import '../../core/models.dart';
import '../../data/files/photo_store.dart';
import '../../data/repository.dart';
import '../theme/components.dart';
import '../theme/tokens.dart';

/// C3 avatar bubble: the profile photo, or the maya on the user's colour,
/// in a 48 clay circle. It opens the You sheet.
class AvatarBubble extends StatelessWidget {
  const AvatarBubble({
    super.key,
    required this.repository,
    required this.onPressed,
  });

  final WarangRepository repository;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repository,
    builder: (context, _) => ClayPressable(
      onPressed: onPressed,
      semanticLabel: 'You, profile and settings',
      tooltip: 'You',
      builder: (context, press) => ClaySurface(
        depth: ClayDepth.clay2,
        press: press,
        circle: true,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: ProfileAvatar(
            profile: repository.profile,
            photoStore: repository.photoStore,
            colour: WarangKeepsake.forUser(repository.trips).fill,
            size: 42,
          ),
        ),
      ),
    ),
  );
}

/// Opens the You sheet: photo, name, the three counts, Settings, and About.
/// It holds every function the old drawer had except Search, which moved
/// to the dock.
Future<void> showYouSheet(
  BuildContext context, {
  required WarangRepository repository,
  required VoidCallback onSettings,
  required VoidCallback onAbout,
}) => showWarangSheet<void>(
  context,
  builder: (sheetContext) => AnimatedBuilder(
    animation: repository,
    builder: (sheetContext, _) => YouSheet(
      repository: repository,
      onSettings: () {
        Navigator.of(sheetContext).pop();
        onSettings();
      },
      onAbout: () {
        Navigator.of(sheetContext).pop();
        onAbout();
      },
    ),
  ),
);

class YouSheet extends StatelessWidget {
  const YouSheet({
    super.key,
    required this.repository,
    required this.onSettings,
    required this.onAbout,
  });

  final WarangRepository repository;
  final VoidCallback onSettings;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final profile = repository.profile;
    final places = distinctPlaces(repository.moments);
    final trips = repository.trips.where((trip) => !trip.isEveryday).length;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  profile: profile,
                  photoStore: repository.photoStore,
                  colour: WarangKeepsake.forUser(repository.trips).fill,
                  size: 72,
                  onTap: () => pickProfilePhoto(repository),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        button: true,
                        hint: 'Edit name',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => editProfileName(context, repository),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                profile.name.isEmpty
                                    ? 'Your Warang'
                                    : profile.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: WarangType.displayM.copyWith(
                                  color: neutrals.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'Only on this phone',
                        style: WarangType.meta.copyWith(
                          color: neutrals.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                WarangStamp.count(
                  id: 'you-moments',
                  number: repository.moments.length,
                  word: repository.moments.length == 1 ? 'moment' : 'moments',
                  tone: WarangKeepsake.amber,
                ),
                WarangStamp.count(
                  id: 'you-places',
                  number: places,
                  word: places == 1 ? 'place' : 'places',
                  tone: WarangKeepsake.dagat,
                ),
                WarangStamp.count(
                  id: 'you-trips',
                  number: trips,
                  word: trips == 1 ? 'trip' : 'trips',
                  tone: WarangKeepsake.ube,
                ),
              ],
            ),
            const SizedBox(height: 22),
            ClaySurface(
              depth: ClayDepth.clay1,
              borderRadius: BorderRadius.circular(WarangRadius.card),
              clipBehavior: Clip.antiAlias,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    _YouRow(
                      icon: WarangGlyphs.settings,
                      label: 'Settings',
                      onTap: onSettings,
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      endIndent: 16,
                      color: neutrals.hairline,
                    ),
                    _YouRow(
                      icon: WarangGlyphs.info,
                      label: 'About Warang',
                      onTap: onAbout,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YouRow extends StatelessWidget {
  const _YouRow({required this.icon, required this.label, required this.onTap});

  final WarangGlyph icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              WarangIcon(icon, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: WarangType.body.copyWith(color: neutrals.ink),
                ),
              ),
              const WarangIcon(WarangGlyphs.chevron, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the user pick a new profile photo from the gallery.
Future<void> pickProfilePhoto(WarangRepository repository) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 88,
  );
  if (picked != null) await repository.setAvatar(File(picked.path));
}

/// Asks for a new display name and saves a non-empty answer.
Future<void> editProfileName(
  BuildContext context,
  WarangRepository repository,
) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(initial: repository.profile.name),
  );
  if (name != null && name.trim().isNotEmpty) {
    await repository.setName(name);
  }
}

/// The name editor owns its controller, so the field keeps a live
/// controller while the dialog animates away.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Your name'),
    content: TextField(
      controller: _controller,
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
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}

/// Circular profile picture, or the maya on the user's colour when there is
/// no photo (C3): their first trip's colour, or amber.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.profile,
    required this.photoStore,
    this.onTap,
    this.size = 52,
    this.colour,
  });

  final Profile profile;
  final PhotoStore photoStore;

  /// Behind the maya when there is no photo; amber when null.
  final Color? colour;
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
    final fallback = _maya();
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
    if (widget.onTap == null) return ExcludeSemantics(child: avatar);
    return Semantics(
      button: true,
      label: 'Change profile photo',
      excludeSemantics: true,
      child: GestureDetector(onTap: widget.onTap, child: avatar),
    );
  }

  /// The maya's head on the user's colour, cropped from the bundled artwork until the
  /// layered maya arrives (FEAT-003 D-2).
  Widget _maya() {
    final size = widget.size;
    // In the 1254 square artwork, a circle of radius 214 around (650, 403)
    // holds the whole face and leaves out the camera and the W.
    const side = 1254.0;
    const face = Offset(650, 403);
    const radius = 214.0;
    final scale = size / (2 * radius);
    final art = side * scale;
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: ColoredBox(
          color: widget.colour ?? WarangKeepsake.amber.fill,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: size / 2 - face.dx * scale,
                top: size / 2 - face.dy * scale,
                width: art,
                height: art,
                child: Image.asset(
                  'design/warang-maya.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
