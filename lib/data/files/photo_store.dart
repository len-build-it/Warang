import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class PhotoStore {
  PhotoStore({this.documentsDirectory});
  final Directory? documentsDirectory;
  Directory? _documentsDirectory;

  Future<Directory> get _root async => _documentsDirectory ??=
      documentsDirectory ?? await getApplicationDocumentsDirectory();

  Future<String> importPhoto(File source, {DateTime? now}) async {
    final date = now ?? DateTime.now();
    final id = const Uuid().v4();
    final relative = p.join(
      'warang',
      'photos',
      '${date.year}',
      date.month.toString().padLeft(2, '0'),
      '$id.jpg',
    );
    final destination = await resolve(relative);
    await destination.parent.create(recursive: true);
    await source.copy(destination.path);
    return relative.replaceAll('\\', '/');
  }

  Future<File> resolve(String relativePath) async {
    if (p.isAbsolute(relativePath) ||
        relativePath.startsWith('/') ||
        relativePath.contains(':')) {
      throw ArgumentError(
        'Photo paths must be relative to the documents directory',
      );
    }
    final root = await _root;
    final file = File(p.join(root.path, relativePath));
    final normalizedRoot = p.normalize(root.path) + p.separator;
    if (!p.normalize(file.path).startsWith(normalizedRoot)) {
      throw ArgumentError('Path escapes the documents directory');
    }
    return file;
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
    final id = const Uuid().v4();
    final now = DateTime.now();
    final relative = p.join(
      'warang',
      'photos',
      '${now.year}',
      now.month.toString().padLeft(2, '0'),
      '$id.$extension',
    );
    final destination = await resolve(relative);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(bytes, flush: true);
    return relative.replaceAll('\\', '/');
  }
}
