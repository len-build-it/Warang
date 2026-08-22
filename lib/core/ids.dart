import 'package:uuid/uuid.dart';

/// UUID v4 is the only identifier generator used by the local data layer.
String newId() => const Uuid().v4();
