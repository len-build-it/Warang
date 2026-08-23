import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/models.dart';
import '../../data/files/photo_store.dart';
import '../../data/repository.dart';

class TravelbookSecurityException implements Exception {
  const TravelbookSecurityException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TravelbookService {
  TravelbookService({required this.repository, PhotoStore? photoStore})
    : photoStore = photoStore ?? PhotoStore();
  final WarangRepository repository;
  final PhotoStore photoStore;
  static const formatVersion = 1;
  static const maxArchiveBytes = 50 * 1024 * 1024;
  static const maxUncompressedBytes = 200 * 1024 * 1024;
  static const maxEntryBytes = 12 * 1024 * 1024;
  static const maxEntries = 1000;

  Future<File> exportTrip(Trip trip) async {
    final moments = repository.moments
        .where((moment) => moment.tripId == trip.id)
        .toList();
    final archive = Archive();
    final manifest = <String, dynamic>{
      'formatVersion': formatVersion,
      'trip': trip.toJson(),
      'moments': <Map<String, dynamic>>[],
    };
    for (final moment in moments) {
      final json = moment.toJson();
      if (moment.relPath != null) {
        final source = await photoStore.resolve(moment.relPath!);
        if (await source.exists()) {
          final name = 'photos/${p.basename(moment.relPath!)}';
          archive.addFile(ArchiveFile.bytes(name, await source.readAsBytes()));
          json['archivePath'] = name;
        }
      }
      (manifest['moments'] as List<Map<String, dynamic>>).add(json);
    }
    archive.addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
    final bytes = ZipEncoder().encodeBytes(archive);
    final directory = await getTemporaryDirectory();
    final file = File(
      p.join(
        directory.path,
        '${trip.title.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-').toLowerCase()}.travelbook',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> importArchive(File source) async {
    final bytes = await source.readAsBytes();
    if (bytes.length > maxArchiveBytes) {
      throw const TravelbookSecurityException('This travelbook is too large.');
    }
    final decoded = ZipDecoder().decodeBytes(bytes);
    if (decoded.length > maxEntries) {
      throw const TravelbookSecurityException(
        'This travelbook has too many entries.',
      );
    }
    var uncompressed = 0;
    ArchiveFile? manifestFile;
    final files = <String, Uint8List>{};
    for (final entry in decoded) {
      if (!entry.isFile || entry.isSymbolicLink || !_safeEntry(entry.name)) {
        throw const TravelbookSecurityException(
          'This travelbook contains an unsafe path.',
        );
      }
      if (entry.size > maxEntryBytes) {
        throw const TravelbookSecurityException(
          'A file in this travelbook is too large.',
        );
      }
      uncompressed += entry.size;
      if (uncompressed > maxUncompressedBytes) {
        throw const TravelbookSecurityException(
          'This travelbook expands beyond the safe limit.',
        );
      }
      if (entry.name == 'manifest.json') {
        manifestFile = entry;
      } else if (entry.name.startsWith('photos/')) {
        files[entry.name] = entry.content;
      }
    }
    if (manifestFile == null) {
      throw const TravelbookSecurityException(
        'This travelbook has no manifest.',
      );
    }
    final manifest =
        jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;
    if (manifest['formatVersion'] != formatVersion) {
      throw const TravelbookSecurityException(
        'This travelbook format is not supported.',
      );
    }
    final trip = Trip.fromJson((manifest['trip'] as Map<String, dynamic>));
    final importedMoments = <Moment>[];
    for (final raw in (manifest['moments'] as List<dynamic>)) {
      final json = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      final archivePath = json['archivePath'] as String?;
      var relPath = json['relPath'] as String?;
      if (archivePath != null) {
        final image = files[archivePath];
        if (image == null || !_looksLikeImage(image)) {
          throw const TravelbookSecurityException(
            'A photo in this travelbook is invalid.',
          );
        }
        late final StoredPhoto stored;
        try {
          stored = await photoStore.storeBytesAsset(image);
        } on FormatException {
          throw const TravelbookSecurityException(
            'A photo in this travelbook is invalid.',
          );
        }
        relPath = stored.relPath;
        json['thumbRelPath'] = stored.thumbRelPath;
        json['width'] = stored.width;
        json['height'] = stored.height;
        json['bytes'] = stored.bytes;
      }
      importedMoments.add(
        Moment(
          id: json['id'] as String,
          tripId: trip.id,
          capturedAt: DateTime.parse(json['capturedAt'] as String),
          caption: json['caption'] as String?,
          latitude: (json['latitude'] as num?)?.toDouble(),
          longitude: (json['longitude'] as num?)?.toDouble(),
          placeLabel: json['placeLabel'] as String?,
          relPath: relPath,
          thumbRelPath: json['thumbRelPath'] as String?,
          width: json['width'] as int? ?? 0,
          height: json['height'] as int? ?? 0,
          bytes: json['bytes'] as int? ?? 0,
        ),
      );
    }
    await repository.upsertImportedTrip(trip, importedMoments);
  }

  bool _safeEntry(String name) {
    if (name.isEmpty ||
        p.isAbsolute(name) ||
        name.contains('\\') ||
        name.split('/').contains('..')) {
      return false;
    }
    final normalized = p.posix.normalize(name);
    return normalized == name && !normalized.startsWith('../');
  }

  bool _looksLikeImage(Uint8List bytes) {
    final jpeg =
        bytes.length > 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    final png =
        bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final webp =
        bytes.length > 12 &&
        utf8.decode(bytes.sublist(0, 4), allowMalformed: true) == 'RIFF' &&
        utf8.decode(bytes.sublist(8, 12), allowMalformed: true) == 'WEBP';
    return jpeg || png || webp;
  }
}
