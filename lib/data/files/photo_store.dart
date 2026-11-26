import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/ids.dart';
import '../db/database.dart';

const _maxImagePixels = 30 * 1000 * 1000;

class StoredPhoto {
  const StoredPhoto({
    required this.relPath,
    required this.thumbRelPath,
    required this.width,
    required this.height,
    required this.bytes,
  });

  final String relPath;
  final String thumbRelPath;
  final int width;
  final int height;
  final int bytes;
}

class PhotoSweepResult {
  const PhotoSweepResult({
    required this.deletedFiles,
    required this.softDeletedRows,
  });

  final int deletedFiles;
  final int softDeletedRows;
}

class PhotoStore {
  PhotoStore({this.documentsDirectory});
  final Directory? documentsDirectory;
  Directory? _documentsDirectory;
  static const maxLongEdge = 2000;
  static const thumbnailLongEdge = 320;
  static const jpegQuality = 85;

  Future<Directory> get _root async => _documentsDirectory ??=
      documentsDirectory ?? await getApplicationDocumentsDirectory();

  Future<StoredPhoto> importPhotoAsset(File source, {DateTime? now}) async {
    return _storeDecoded(await source.readAsBytes(), now: now);
  }

  /// Stores a profile image outside the Photos tree so the photo orphan
  /// sweep does not mistake an active avatar for an unreferenced moment photo.
  Future<String> importAvatar(File source, {DateTime? now}) async {
    final rawBytes = await source.readAsBytes();
    final bytes = await Isolate.run(() => _encodeAvatarBytes(rawBytes));
    final relative = _relativePath(
      p.posix.join('warang', 'profile', '${newId()}.jpg'),
    );
    final destination = await resolve(relative);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(bytes, flush: true);
    return relative;
  }

  Future<File> resolve(String relativePath) async {
    final normalizedRelative = validateRelativePath(relativePath);
    final root = await _root;
    final file = File(p.join(root.path, normalizedRelative));
    final normalizedRoot = p.normalize(root.path) + p.separator;
    if (!p.normalize(file.path).startsWith(normalizedRoot)) {
      throw ArgumentError('Path escapes the documents directory');
    }
    return file;
  }

  /// Validates and normalizes a path persisted in the database.
  ///
  /// Persisted paths are always POSIX-style relative paths, even on Windows.
  static String validateRelativePath(String relativePath) {
    if (relativePath.isEmpty ||
        p.isAbsolute(relativePath) ||
        relativePath.startsWith('/') ||
        relativePath.startsWith('\\') ||
        relativePath.contains(':')) {
      throw ArgumentError(
        'Photo paths must be relative to the documents directory',
      );
    }
    final normalized = p.posix.normalize(relativePath.replaceAll('\\', '/'));
    if (normalized == '.' ||
        normalized.startsWith('../') ||
        normalized == '..' ||
        normalized.contains('/../')) {
      throw ArgumentError('Photo path escapes the documents directory');
    }
    return normalized;
  }

  Future<int> storageBytes() async {
    final root = await _root;
    final directory = Directory(p.join(root.path, 'warang', 'photos'));
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<StoredPhoto> storeBytesAsset(Uint8List bytes, {DateTime? now}) async {
    return _storeDecoded(bytes, now: now);
  }

  Future<PhotoSweepResult> sweepOrphans(WarangDatabase database) async {
    final activeRows = await database.photosDao.getActive();
    final liveRows = await database.photosDao.getLive();
    final liveIds = liveRows.map((row) => row.id).toSet();
    final validRows = <String>{};
    final invalidRows = <String>[];

    for (final row in activeRows) {
      final full = await _tryResolve(row.relPath);
      final thumb = await _tryResolve(row.thumbRelPath);
      final exists =
          full != null &&
          thumb != null &&
          await full.exists() &&
          await thumb.exists();
      if (liveIds.contains(row.id) && exists) {
        validRows.add(row.id);
      } else {
        invalidRows.add(row.id);
      }
    }

    if (invalidRows.isNotEmpty) {
      final now = DateTime.now();
      await database.transaction(() async {
        for (final id in invalidRows) {
          await database.photosDao.softDelete(id, now);
        }
      });
    }

    final referenced = <String>{};
    for (final row in liveRows) {
      if (!validRows.contains(row.id)) continue;
      referenced.add(validateRelativePath(row.relPath));
      referenced.add(validateRelativePath(row.thumbRelPath));
    }

    var deletedFiles = 0;
    final root = await _root;
    final photosRoot = Directory(p.join(root.path, 'warang', 'photos'));
    if (await photosRoot.exists()) {
      await for (final entity in photosRoot.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relative = _relativePath(
          p.relative(entity.path, from: root.path),
        );
        if (referenced.contains(relative)) continue;
        try {
          await entity.delete();
          deletedFiles++;
        } on FileSystemException {
          // A concurrent cleanup or removable file should not abort startup.
        }
      }
    }
    return PhotoSweepResult(
      deletedFiles: deletedFiles,
      softDeletedRows: invalidRows.length,
    );
  }

  Future<StoredPhoto> _storeDecoded(Uint8List bytes, {DateTime? now}) async {
    final encoded = await Isolate.run(() => _encodePhotoAndThumb(bytes));
    final date = now ?? DateTime.now();
    final id = newId();
    final directory = p.posix.join(
      'warang',
      'photos',
      '${date.year}',
      date.month.toString().padLeft(2, '0'),
    );
    final relative = _relativePath(p.posix.join(directory, '$id.jpg'));
    final thumbRelative = _relativePath(
      p.posix.join(directory, 'thumbs', '$id.jpg'),
    );
    final destination = await resolve(relative);
    final thumbDestination = await resolve(thumbRelative);
    await destination.parent.create(recursive: true);
    await thumbDestination.parent.create(recursive: true);
    try {
      await destination.writeAsBytes(encoded.fullBytes, flush: true);
      await thumbDestination.writeAsBytes(encoded.thumbBytes, flush: true);
    } on Exception {
      await _deleteIfExists(destination);
      await _deleteIfExists(thumbDestination);
      rethrow;
    }
    return StoredPhoto(
      relPath: relative,
      thumbRelPath: thumbRelative,
      width: encoded.width,
      height: encoded.height,
      bytes: encoded.fullBytes.length,
    );
  }

  Future<File?> _tryResolve(String path) async {
    try {
      return await resolve(path);
    } on ArgumentError {
      return null;
    }
  }

  /// Removes both files of a photo that never became part of a moment.
  Future<void> discard(StoredPhoto photo) async {
    await _deleteIfExists(await resolve(photo.relPath));
    await _deleteIfExists(await resolve(photo.thumbRelPath));
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  String _relativePath(String path) => validateRelativePath(path);
}

Uint8List _encodeAvatarBytes(Uint8List bytes) {
  final decoded = _decodeChecked(bytes);
  final normalized = _resizeForLongEdge(decoded, PhotoStore.maxLongEdge);
  return Uint8List.fromList(
    img.encodeJpg(normalized, quality: PhotoStore.jpegQuality),
  );
}

({Uint8List fullBytes, Uint8List thumbBytes, int width, int height})
_encodePhotoAndThumb(Uint8List bytes) {
  final decoded = _decodeChecked(bytes);
  final normalized = _resizeForLongEdge(decoded, PhotoStore.maxLongEdge);
  final fullBytes = Uint8List.fromList(
    img.encodeJpg(normalized, quality: PhotoStore.jpegQuality),
  );
  final thumbnail = _resizeForLongEdge(
    normalized,
    PhotoStore.thumbnailLongEdge,
  );
  final thumbBytes = Uint8List.fromList(
    img.encodeJpg(thumbnail, quality: PhotoStore.jpegQuality),
  );
  return (
    fullBytes: fullBytes,
    thumbBytes: thumbBytes,
    width: normalized.width,
    height: normalized.height,
  );
}

img.Image _decodeChecked(Uint8List bytes) {
  img.DecodeInfo? info;
  try {
    info = img.findDecoderForData(bytes)?.startDecode(bytes);
  } on Exception {
    throw const FormatException('Unsupported image file');
  }
  if (info != null && info.width * info.height > _maxImagePixels) {
    throw const FormatException('Image dimensions are too large');
  }
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Exception {
    throw const FormatException('Unsupported image file');
  }
  if (decoded == null) throw const FormatException('Unsupported image file');
  if (decoded.width * decoded.height > _maxImagePixels) {
    throw const FormatException('Image dimensions are too large');
  }
  return img.bakeOrientation(decoded);
}

img.Image _resizeForLongEdge(img.Image source, int longEdge) {
  final currentLongEdge = source.width > source.height
      ? source.width
      : source.height;
  if (currentLongEdge <= longEdge) return source.clone();
  if (source.width >= source.height) {
    return img.copyResize(source, width: longEdge);
  }
  return img.copyResize(source, height: longEdge);
}
