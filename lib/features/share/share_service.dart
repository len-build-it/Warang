import 'dart:io';

import 'package:share_plus/share_plus.dart';

class WarangShareService {
  Future<void> shareFile(File file, {String? caption}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: caption),
    );
  }
}
