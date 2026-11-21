import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/app_state.dart';
import '../../app/shell/you_sheet.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../data/files/photo_store.dart';
import '../../data/repository.dart';
import '../map/warang_map.dart';
import 'moment_edit_sheet.dart';

/// The map home (S2): the map, the avatar bubble, the recenter button, the
/// moment card (S4), and pin placement (S5). The dock lives in the shell.
class TravelModeScreen extends ConsumerStatefulWidget {
  const TravelModeScreen({super.key, this.onOpenYou});

  /// Opens the You sheet; null hides the avatar bubble.
  final VoidCallback? onOpenYou;

  @override
  ConsumerState<TravelModeScreen> createState() => TravelModeScreenState();
}

class TravelModeScreenState extends ConsumerState<TravelModeScreen> {
  final _mapKey = GlobalKey<WarangMapSurfaceState>();
  final _moving = ValueNotifier<bool>(false);

  /// A just-saved moment whose pin lands on the map.
  String? _landingId;

  @override
  void dispose() {
    _moving.dispose();
    super.dispose();
  }

  /// Shows a just-saved [moment] landing on the map and confirms its trip.
  void showCaptured(Moment moment) {
    setState(() => _landingId = moment.id);
    _focus(moment);
    final repository = ref.read(repositoryProvider);
    final trip = repository.trips.where((trip) => trip.id == moment.tripId);
    showWarangSnackBar(
      context,
      'Saved to ${trip.isEmpty ? 'Everyday' : trip.first.title}',
    );
  }

  Future<void> _delete(Moment moment) async {
    final repository = ref.read(repositoryProvider);
    final selection = ref.read(selectedMomentProvider.notifier);
    WarangHaptic.medium.play();
    await repository.softDeleteMoment(moment.id);
    selection.clear();
    if (!mounted) return;
    showWarangSnackBar(
      context,
      'Moment deleted',
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await repository.restoreMoment(moment.id);
          final restored = momentById(repository, moment.id);
          if (restored != null) selection.select(restored);
        },
      ),
    );
  }

  /// Moves the card to the moment captured just before (-1) or after (+1)
  /// this one, among the moments that have a pin.
  void _swipe(Moment current, int direction) {
    final pinned = momentsWithMapCoordinates(
      ref.read(repositoryProvider).moments,
    ).toList()..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    final index = pinned.indexWhere((moment) => moment.id == current.id);
    final next = index + direction;
    if (index < 0 || next < 0 || next >= pinned.length) return;
    ref.read(selectedMomentProvider.notifier).select(pinned[next], focus: true);
  }

  void _startPlacement(Moment moment) {
    ref.read(selectedMomentProvider.notifier).clear();
    ref.read(placingMomentProvider.notifier).start(moment.id);
    _focus(moment);
  }

  void _endPlacement() {
    final placing = ref.read(placingMomentProvider);
    final moment = placing == null
        ? null
        : momentById(ref.read(repositoryProvider), placing);
    ref.read(placingMomentProvider.notifier).stop();
    if (moment != null) {
      ref.read(selectedMomentProvider.notifier).select(moment);
    }
  }

  Future<void> _confirmPlacement() async {
    final id = ref.read(placingMomentProvider);
    final center = _mapKey.currentState?.center;
    if (id == null || center == null) return;
    await ref
        .read(repositoryProvider)
        .setMomentLocation(id, center.latitude, center.longitude);
    if (mounted) _endPlacement();
  }

  void _focus(Moment moment) {
    if (moment.latitude == null || moment.longitude == null) return;
    _mapKey.currentState?.moveToCoordinate(moment.latitude!, moment.longitude!);
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(repositoryProvider);
    ref.listen<MomentSelection?>(selectedMomentProvider, (previous, next) {
      if (next == null || !next.focus) return;
      final moment = momentById(repository, next.momentId);
      if (moment != null) _focus(moment);
    });
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) => _content(context, repository),
    );
  }

  Widget _content(BuildContext context, WarangRepository repository) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final moments = repository.moments;
    final size = MediaQuery.sizeOf(context);
    final selection = ref.watch(selectedMomentProvider);
    final selected = selection == null
        ? null
        : momentById(repository, selection.momentId);
    final placingId = ref.watch(placingMomentProvider);
    final placing = placingId == null
        ? null
        : momentById(repository, placingId);
    final selectionNotifier = ref.read(selectedMomentProvider.notifier);
    final photoStore = ref.watch(photoStoreProvider);
    final navHeight = WarangLayout.navigationHeight(context);
    final clearance = WarangLayout.dockClearance(context);
    final topOffset = math.max(MediaQuery.paddingOf(context).top, 12.0) + 8.0;
    final region = AnnotatedRegion<SystemUiOverlayStyle>(
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
                tileStore: ref.watch(mapTileStoreProvider),
                photoStore: photoStore,
                onMomentTap: selectionNotifier.select,
                onMapTap: selected == null ? null : selectionNotifier.clear,
                dimmed: selected != null,
                onDimmerTap: selectionNotifier.clear,
                landingId: _landingId,
                moving: _moving,
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: WarangTopScrim(),
            ),
            if (widget.onOpenYou != null && selected == null)
              Positioned(
                top: topOffset,
                left: 16,
                child: AvatarBubble(
                  repository: repository,
                  onPressed: widget.onOpenYou!,
                ),
              ),
            if (placingId != null) ...[
              IgnorePointer(
                child: Center(
                  child: _PlacementPin(
                    moment: placing,
                    photoStore: photoStore,
                    moving: _moving,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _PlacementBar(
                  onCancel: _endPlacement,
                  onConfirm: _confirmPlacement,
                ),
              ),
            ] else if (selected == null) ...[
              if (moments.isEmpty)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: clearance + 6,
                  child: Center(
                    child: ConstrainedBox(
                      // Narrow enough to clear the recenter button.
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: const WarangSpeechBubble(
                        text: 'Tap the camera to drop your first pin',
                        persistent: true,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 16,
                bottom: navHeight + 16,
                child: _RecenterButton(
                  onPressed: () => _mapKey.currentState?.recenter(),
                ),
              ),
            ] else
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 560,
                      maxHeight: size.height - topOffset - 64,
                    ),
                    child: MomentCard(
                      moment: selected,
                      repository: repository,
                      photoStore: photoStore,
                      onClose: selectionNotifier.clear,
                      onDelete: () => _delete(selected),
                      onPlaceOnMap: () => _startPlacement(selected),
                      onSwipe: (direction) => _swipe(selected, direction),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    // Back leaves placement without changing the moment.
    return PopScope(
      canPop: placingId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && placingId != null) _endPlacement();
      },
      child: region,
    );
  }
}

/// The live moment with [id], or null once it is deleted.
Moment? momentById(WarangRepository repository, String id) {
  for (final moment in repository.moments) {
    if (moment.id == id) return moment;
  }
  return null;
}

/// The S5 centre pin: the moment's own clay pin. It lifts 8 while the map
/// moves and drops back with `pop` when it rests. Its pointer marks the
/// exact centre of the map.
class _PlacementPin extends StatefulWidget {
  const _PlacementPin({
    required this.moment,
    required this.photoStore,
    required this.moving,
  });

  final Moment? moment;
  final PhotoStore photoStore;
  final ValueListenable<bool> moving;

  @override
  State<_PlacementPin> createState() => _PlacementPinState();
}

class _PlacementPinState extends State<_PlacementPin> {
  late Future<File?> _file = _resolve();

  Future<File?> _resolve() async {
    final path = widget.moment?.thumbRelPath ?? widget.moment?.relPath;
    if (path == null) return null;
    final file = await widget.photoStore.resolve(path);
    return await file.exists() ? file : null;
  }

  @override
  void didUpdateWidget(covariant _PlacementPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moment?.id != widget.moment?.id) _file = _resolve();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = WarangMotion.reduced(context);
    const height = WarangPhotoPin.size + WarangPhotoPin.pointerRoom;
    return Semantics(
      label: 'Pin at the centre of the map',
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.moving,
        builder: (context, moving, child) => TweenAnimationBuilder<double>(
          tween: Tween(end: moving && !reduced ? -8 : 0),
          duration: moving
              ? WarangMotion.press
              : (reduced ? WarangMotion.fade : WarangMotion.pop.duration),
          curve: moving
              ? WarangMotion.pressCurve
              : (reduced ? Curves.linear : WarangMotion.pop.curve),
          builder: (context, lift, child) => Transform.translate(
            // The pointer's tip sits on the centre, so the pin rises half
            // its height above it.
            offset: Offset(0, -height / 2 + lift),
            child: child,
          ),
          child: child,
        ),
        child: FutureBuilder<File?>(
          future: _file,
          builder: (context, snapshot) => WarangPhotoPin(file: snapshot.data),
        ),
      ),
    );
  }
}

class _PlacementBar extends StatelessWidget {
  const _PlacementBar({required this.onCancel, required this.onConfirm});
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => WarangSheetFrame(
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Move the map to the spot',
              textAlign: TextAlign.center,
              style: WarangType.body.copyWith(
                color: WarangNeutrals.of(context).inkSoft,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: WarangButton.secondary(
                    label: 'Cancel',
                    onPressed: onCancel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: WarangButton.primary(
                    label: 'Confirm',
                    onPressed: onConfirm,
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

/// The S2 recenter button: a 40 `surface` clay circle with the compass, in
/// a 48 touch target.
class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ClayPressable(
    onPressed: onPressed,
    semanticLabel: 'Recenter map on current location',
    tooltip: 'Recenter',
    builder: (context, press) => SizedBox.square(
      dimension: 48,
      child: Center(
        child: ClaySurface(
          depth: ClayDepth.clay2,
          press: press,
          circle: true,
          child: const SizedBox.square(
            dimension: 40,
            child: Center(child: WarangIcon(WarangGlyphs.recenter, size: 22)),
          ),
        ),
      ),
    ),
  );
}

/// S4 moment card: a C9 sheet over the dimmed map with the photo as a
/// polaroid, a place stamp on its corner, the date below, then Edit and
/// Delete. Swiping sideways moves between moments.
class MomentCard extends StatefulWidget {
  const MomentCard({
    super.key,
    required this.moment,
    required this.repository,
    required this.photoStore,
    required this.onClose,
    this.onDelete,
    this.onPlaceOnMap,
    this.onSwipe,
  });
  final Moment moment;
  final WarangRepository repository;
  final PhotoStore photoStore;
  final VoidCallback onClose;

  /// Deletes the moment; when null the card deletes it and closes.
  final VoidCallback? onDelete;

  /// Starts manual pin placement; when null the location actions are hidden.
  final VoidCallback? onPlaceOnMap;

  /// Asks for the previous (-1) or next (+1) moment.
  final ValueChanged<int>? onSwipe;

  @override
  State<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<MomentCard> {
  /// The direction of the last swipe: the outgoing polaroid leaves that way.
  int _direction = 1;

  Future<void> _edit() async {
    final outcome = await showMomentEditSheet(
      context,
      moment: widget.moment,
      repository: widget.repository,
    );
    if (outcome == MomentEditOutcome.placeOnMap) widget.onPlaceOnMap?.call();
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete;
    if (onDelete != null) return onDelete();
    await widget.repository.softDeleteMoment(widget.moment.id);
    widget.onClose();
  }

  void _onSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250 || widget.onSwipe == null) return;
    // A swipe to the left brings the next moment in from the right.
    final direction = velocity < 0 ? 1 : -1;
    setState(() => _direction = direction);
    widget.onSwipe!(direction);
  }

  @override
  Widget build(BuildContext context) {
    final moment = widget.moment;
    final neutrals = WarangNeutrals.of(context);
    final reduced = WarangMotion.reduced(context);
    return WarangSheetFrame(
      handle: Semantics(
        label: 'Close moment',
        button: true,
        onTap: widget.onClose,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 300) widget.onClose();
          },
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onHorizontalDragEnd: _onSwipe,
                child: AnimatedSwitcher(
                  duration: reduced
                      ? WarangMotion.fade
                      : WarangMotion.slide.duration,
                  switchInCurve: reduced
                      ? Curves.linear
                      : WarangMotion.slide.curve,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    if (reduced) {
                      return FadeTransition(opacity: animation, child: child);
                    }
                    final incoming = child.key == ValueKey(moment.id);
                    return AnimatedBuilder(
                      animation: animation,
                      child: child,
                      builder: (context, child) {
                        final away = 1 - animation.value;
                        final sign = incoming ? _direction : -_direction;
                        return FractionalTranslation(
                          translation: Offset(sign * away * 1.1, 0),
                          child: Transform.rotate(
                            angle: incoming
                                ? 0
                                : -_direction * away * 4 * math.pi / 180,
                            child: child,
                          ),
                        );
                      },
                    );
                  },
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  child: _MomentPolaroid(
                    key: ValueKey(moment.id),
                    moment: moment,
                    photoStore: widget.photoStore,
                    onPlaceOnMap: widget.onPlaceOnMap,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                formatMomentTime(moment.capturedAt),
                style: WarangType.meta.copyWith(color: neutrals.inkFaint),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: WarangButton.secondary(
                      label: 'Edit',
                      icon: WarangGlyphs.edit,
                      onPressed: _edit,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WarangButton.danger(
                      label: 'Delete',
                      icon: WarangGlyphs.delete,
                      onPressed: _delete,
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
}

/// The moment's photo as a C8 polaroid with its caption and place stamp.
class _MomentPolaroid extends StatefulWidget {
  const _MomentPolaroid({
    super.key,
    required this.moment,
    required this.photoStore,
    required this.onPlaceOnMap,
  });

  final Moment moment;
  final PhotoStore photoStore;
  final VoidCallback? onPlaceOnMap;

  @override
  State<_MomentPolaroid> createState() => _MomentPolaroidState();
}

class _MomentPolaroidState extends State<_MomentPolaroid> {
  late Future<File?> _file = _resolve();

  Future<File?> _resolve() async {
    final relPath = widget.moment.relPath;
    if (relPath == null) return null;
    try {
      return await widget.photoStore.resolve(relPath);
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant _MomentPolaroid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moment.relPath != widget.moment.relPath ||
        oldWidget.photoStore != widget.photoStore) {
      _file = _resolve();
    }
  }

  @override
  Widget build(BuildContext context) {
    final moment = widget.moment;
    final label = moment.placeLabel?.trim();
    final hasCoordinates = moment.latitude != null && moment.longitude != null;
    final canAddLocation = !hasCoordinates && widget.onPlaceOnMap != null;
    final placeLines = label != null && label.isNotEmpty
        ? [label]
        : hasCoordinates
        ? formatCoordinates(moment.latitude!, moment.longitude!).split(' · ')
        : [canAddLocation ? 'Add location' : 'No location'];
    final placeholder = ColoredBox(
      color: Theme.of(context).extension<MapPalette>()!.landAlt,
      child: const Center(child: WarangIcon(WarangGlyphs.photo, size: 36)),
    );
    Widget stamp = WarangStamp.place(
      id: 'place-${moment.id}',
      lines: placeLines,
      tone: WarangKeepsake.dagat,
    );
    if (canAddLocation) {
      stamp = Semantics(
        container: true,
        button: true,
        label: 'Add location',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPlaceOnMap,
          child: stamp,
        ),
      );
    }
    return Padding(
      // Room for the stamp that overlaps the top-right corner.
      padding: const EdgeInsets.only(top: 18, right: 14),
      child: WarangPolaroid(
        caption: moment.caption,
        photoAspectRatio: 4 / 3,
        stamp: stamp,
        photo: FutureBuilder<File?>(
          future: _file,
          builder: (context, snapshot) {
            final file = snapshot.data;
            if (file == null || !file.existsSync()) return placeholder;
            return Image.file(
              file,
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, sync) =>
                  sync || frame != null ? child : placeholder,
              errorBuilder: (_, _, _) => placeholder,
            );
          },
        ),
      ),
    );
  }
}
