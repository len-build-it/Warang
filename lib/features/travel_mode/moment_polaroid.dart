import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../data/files/photo_store.dart';

/// The moment's photo as a C8 polaroid with its caption and place stamp.
class MomentPolaroid extends StatefulWidget {
  const MomentPolaroid({
    super.key,
    required this.moment,
    required this.photoStore,
    required this.onPlaceOnMap,
  });

  final Moment moment;
  final PhotoStore photoStore;
  final VoidCallback? onPlaceOnMap;

  @override
  State<MomentPolaroid> createState() => _MomentPolaroidState();
}

class _MomentPolaroidState extends State<MomentPolaroid> {
  late Future<File?> _file = _resolve();

  Future<File?> _resolve() async {
    final relPath = widget.moment.relPath;
    if (relPath == null) return null;
    try {
      return await widget.photoStore.resolve(relPath);
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('MomentPolaroid resolve failed: $e');
      }
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant MomentPolaroid oldWidget) {
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
    return WarangPolaroid(
      caption: moment.caption,
      photoAspectRatio: 4 / 3,
      stamp: stamp,
      photo: FutureBuilder<File?>(
        future: _file,
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file == null) return placeholder;
          final cacheWidth =
              (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round();
          return Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth > 0 ? cacheWidth : null,
            frameBuilder: (context, child, frame, sync) =>
                sync || frame != null ? child : placeholder,
            errorBuilder: (_, _, _) => placeholder,
          );
        },
      ),
    );
  }
}
