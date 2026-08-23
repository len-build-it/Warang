import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';

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

  /// Imports an image and returns its database-ready relative path.
  ///
  /// [importPhotoAsset] should be used by new callers that also need the
  /// generated thumbnail and dimensions.
  Future<String> importPhoto(File source, {DateTime? now}) async {
    return (await importPhotoAsset(source, now: now)).relPath;
  }

  Future<StoredPhoto> importPhotoAsset(File source, {DateTime? now}) async {
    return _storeDecoded(await source.readAsBytes(), now: now);
  }

  /// Stores a profile image outside the Photos tree so the photo orphan
  /// sweep does not mistake an active avatar for an unreferenced moment photo.
  Future<String> importAvatar(File source, {DateTime? now}) async {
    final decoded = _decode(await source.readAsBytes());
    final normalized = _resizeForLongEdge(decoded, maxLongEdge);
    final bytes = Uint8List.fromList(
      img.encodeJpg(normalized, quality: jpegQuality),
    );
    final relative = _relativePath(
      p.posix.join('warang', 'profile', '${const Uuid().v4()}.jpg'),
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

  Future<String> storeBytes(Uint8List bytes, {String extension = 'jpg'}) async {
    return (await storeBytesAsset(bytes)).relPath;
  }

  Future<StoredPhoto> storeBytesAsset(Uint8List bytes, {DateTime? now}) async {
    return _storeDecoded(bytes, now: now);
  }

  Future<PhotoSweepResult> sweepOrphans(WarangDatabase database) async {
    final activeRows = await database.photosDao.getActive();
    final liveRows = await database.photosDao.getLive();
    final liveIds = liveRows.map((row) => row.id).toSet();
    final validRows = <String>[];
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

    final now = DateTime.now();
    for (final id in invalidRows) {
      await database.photosDao.softDelete(id, now);
    }

    final referenced = <String>{};
    for (final row in liveRows) {
      if (!validRows.contains(row.id)) continue;
      referenced.add(validateRelativePath(row.relPath));
      referenced.add(validateRelativePath(row.thumbRelPath));
    }

    var deletedFiles = 0;
    final photosRoot = Directory(
      p.join((await _root).path, 'warang', 'photos'),
    );
    if (await photosRoot.exists()) {
      await for (final entity in photosRoot.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relative = _relativePath(
          p.relative(entity.path, from: (await _root).path),
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
    final decoded = _decode(bytes);
    final normalized = _resizeForLongEdge(decoded, maxLongEdge);
    final fullBytes = Uint8List.fromList(
      img.encodeJpg(normalized, quality: jpegQuality),
    );
    final thumbnail = _resizeForLongEdge(normalized, thumbnailLongEdge);
    final thumbBytes = Uint8List.fromList(
      img.encodeJpg(thumbnail, quality: jpegQuality),
    );
    final date = now ?? DateTime.now();
    final id = const Uuid().v4();
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
      await destination.writeAsBytes(fullBytes, flush: true);
      await thumbDestination.writeAsBytes(thumbBytes, flush: true);
    } catch (_) {
      await _deleteIfExists(destination);
      await _deleteIfExists(thumbDestination);
      rethrow;
    }
    return StoredPhoto(
      relPath: relative,
      thumbRelPath: thumbRelative,
      width: normalized.width,
      height: normalized.height,
      bytes: fullBytes.length,
    );
  }

  img.Image _decode(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      throw const FormatException('Unsupported image file');
    }
    if (decoded == null) throw const FormatException('Unsupported image file');
    if (decoded.width * decoded.height > 30 * 1000 * 1000) {
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

  Future<File?> _tryResolve(String path) async {
    try {
      return await resolve(path);
    } on ArgumentError {
      return null;
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  String _relativePath(String path) => validateRelativePath(path);
}
