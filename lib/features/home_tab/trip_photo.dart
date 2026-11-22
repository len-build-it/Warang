import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/models.dart';
import '../../data/files/photo_store.dart';

/// A moment's photo, flat, filling its box; the polaroid glyph on the map's
/// land colour while it loads or when there is none. Nothing is drawn over
/// the photo.
class MomentPhoto extends StatefulWidget {
  const MomentPhoto({
    super.key,
    required this.moment,
    required this.photoStore,
    this.thumbnail = true,
    this.glyphSize = 28,
  });

  final Moment? moment;
  final PhotoStore photoStore;

  /// Uses the small copy, which is enough below about 320 px.
  final bool thumbnail;
  final double glyphSize;

  @override
  State<MomentPhoto> createState() => _MomentPhotoState();
}

class _MomentPhotoState extends State<MomentPhoto> {
  late Future<File?> _file = _resolve();

  String? get _path => widget.thumbnail
      ? widget.moment?.thumbRelPath ?? widget.moment?.relPath
      : widget.moment?.relPath ?? widget.moment?.thumbRelPath;

  Future<File?> _resolve() async {
    final path = _path;
    if (path == null) return null;
    try {
      final file = await widget.photoStore.resolve(path);
      return file.existsSync() ? file : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant MomentPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPath = widget.thumbnail
        ? oldWidget.moment?.thumbRelPath ?? oldWidget.moment?.relPath
        : oldWidget.moment?.relPath ?? oldWidget.moment?.thumbRelPath;
    if (oldPath != _path || oldWidget.photoStore != widget.photoStore) {
      _file = _resolve();
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).extension<MapPalette>()!.landAlt,
      child: Center(
        child: WarangIcon(WarangGlyphs.photo, size: widget.glyphSize),
      ),
    );
    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return placeholder;
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          frameBuilder: (context, child, frame, sync) =>
              sync || frame != null ? child : placeholder,
          errorBuilder: (_, _, _) => placeholder,
        );
      },
    );
  }
}

/// A trip's cover: its chosen cover moment, else its newest with a photo.
Moment? coverMoment(Trip trip, List<Moment> tripMoments) {
  bool hasPhoto(Moment moment) =>
      moment.relPath != null || moment.thumbRelPath != null;
  for (final moment in tripMoments) {
    if (moment.id == trip.coverMomentId && hasPhoto(moment)) return moment;
  }
  for (final moment in tripMoments) {
    if (hasPhoto(moment)) return moment;
  }
  return null;
}
