class Profile {
  const Profile({
    required this.id,
    required this.name,
    this.avatarRelPath,
    this.bio,
    this.authorId = 'local',
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String? avatarRelPath;
  final String? bio;
  final String authorId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
}

class Trip {
  const Trip({
    required this.id,
    required this.title,
    this.place,
    this.description,
    this.startDate,
    this.endDate,
    this.coverMomentId,
    this.isEveryday = false,
    this.tagsJson = '[]',
    this.deletedAt,
    this.updatedAt,
    this.authorId = 'local',
    this.createdAt,
  });

  final String id;
  final String title;
  final String? place;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? coverMomentId;
  final bool isEveryday;
  final String tagsJson;
  final DateTime? deletedAt;
  final DateTime? updatedAt;
  final String authorId;
  final DateTime? createdAt;
}

class Moment {
  const Moment({
    required this.id,
    required this.tripId,
    required this.capturedAt,
    this.caption,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.placeLabel,
    this.sortIndex = 0,
    this.relPath,
    this.thumbRelPath,
    this.width = 0,
    this.height = 0,
    this.bytes = 0,
    this.deletedAt,
    this.authorId = 'local',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tripId;
  final DateTime capturedAt;
  final String? caption;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final String? placeLabel;
  final int sortIndex;

  /// Compatibility projection of the first row in the Photos table.
  final String? relPath;
  final String? thumbRelPath;
  final int width;
  final int height;
  final int bytes;
  final DateTime? deletedAt;
  final String authorId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
