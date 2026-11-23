import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'place_book.dart';

/// Descriptor of the bundled place book asset shipped with this app build.
class PlaceBookAssetSpec {
  const PlaceBookAssetSpec({
    required this.assetKey,
    required this.schemaVersion,
    required this.sourceDate,
    this.expectedBytes,
  });

  final String assetKey;
  final String schemaVersion;
  final String sourceDate;
  final int? expectedBytes;

  String get fileName => 'place_book_${schemaVersion}_$sourceDate.sqlite';

  static const bundled = PlaceBookAssetSpec(
    assetKey: 'assets/place_book/place_book.sqlite',
    schemaVersion: '1',
    sourceDate: '2026-11-22',
    expectedBytes: 25964544,
  );
}

/// Copies the bundled place book asset to app support storage atomically.
class PlaceBookInstaller {
  PlaceBookInstaller({
    this.spec = PlaceBookAssetSpec.bundled,
    AssetBundle? bundle,
    Future<Directory> Function()? supportDirectory,
  }) : _bundle = bundle ?? rootBundle,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final PlaceBookAssetSpec spec;
  final AssetBundle _bundle;
  final Future<Directory> Function() _supportDirectory;

  /// Ensures the place book file is present and complete in support storage.
  Future<File> ensureInstalled() async {
    final dir = await _supportDirectory();
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, spec.fileName));
    final tmp = File('${target.path}.tmp');

    if (await target.exists()) {
      final existingLength = await target.length();
      final expected = spec.expectedBytes;
      if (expected != null && existingLength == expected) {
        await _cleanupOldFiles(dir, keepName: spec.fileName);
        return target;
      }
      if (expected == null && existingLength > 0 && !await tmp.exists()) {
        await _cleanupOldFiles(dir, keepName: spec.fileName);
        return target;
      }
    }

    final byteData = await _bundle.load(spec.assetKey);
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    if (await tmp.exists()) {
      await tmp.delete();
    }
    await tmp.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await tmp.rename(target.path);
    await _cleanupOldFiles(dir, keepName: spec.fileName);
    return target;
  }

  Future<void> _cleanupOldFiles(
    Directory dir, {
    required String keepName,
  }) async {
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith('place_book_')) continue;
      if (name == keepName) continue;
      try {
        await entity.delete();
      } catch (_) {
        // Best-effort cleanup of superseded or interrupted copies.
      }
    }
  }
}

enum PlaceBookStatus { preparing, ready, failed }

@immutable
class PlaceBookState {
  const PlaceBookState._({required this.status, this.book, this.error});

  const PlaceBookState.preparing() : this._(status: PlaceBookStatus.preparing);

  const PlaceBookState.ready(PlaceBook book)
    : this._(status: PlaceBookStatus.ready, book: book);

  const PlaceBookState.failed([Object? error])
    : this._(status: PlaceBookStatus.failed, error: error);

  final PlaceBookStatus status;
  final PlaceBook? book;
  final Object? error;

  bool get isReady => status == PlaceBookStatus.ready && book != null;
}

final placeBookInstallerProvider = Provider<PlaceBookInstaller>(
  (ref) => PlaceBookInstaller(),
);

final placeBookProvider = NotifierProvider<PlaceBookNotifier, PlaceBookState>(
  PlaceBookNotifier.new,
);

class PlaceBookNotifier extends Notifier<PlaceBookState> {
  bool _started = false;
  PlaceBook? _book;

  @override
  PlaceBookState build() {
    ref.onDispose(() {
      _book?.close();
      _book = null;
    });
    return const PlaceBookState.preparing();
  }

  /// Prepares the place book once, or retries after a failure.
  Future<void> ensureReady({bool retry = false}) async {
    if (state.isReady) return;
    if (_started && !retry) return;
    _started = true;
    state = const PlaceBookState.preparing();
    try {
      final installer = ref.read(placeBookInstallerProvider);
      final file = await installer.ensureInstalled();
      final book = PlaceBook.openFile(file);
      _book = book;
      state = PlaceBookState.ready(book);
    } catch (error) {
      _started = false;
      state = PlaceBookState.failed(error);
    }
  }
}
