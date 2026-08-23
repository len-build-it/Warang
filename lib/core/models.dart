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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatarRelPath': avatarRelPath,
    'bio': bio,
    'authorId': authorId,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    avatarRelPath: json['avatarRelPath'] as String?,
    bio: json['bio'] as String?,
    authorId: json['authorId'] as String? ?? 'local',
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
    deletedAt: _date(json['deletedAt']),
  );
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'place': place,
    'description': description,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'coverMomentId': coverMomentId,
    'isEveryday': isEveryday,
    'tagsJson': tagsJson,
    'deletedAt': deletedAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'authorId': authorId,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'] as String,
    title: json['title'] as String,
    place: json['place'] as String?,
    description: json['description'] as String?,
    startDate: _date(json['startDate']),
    endDate: _date(json['endDate']),
    coverMomentId: json['coverMomentId'] as String?,
    isEveryday: json['isEveryday'] as bool? ?? false,
    tagsJson: json['tagsJson'] as String? ?? '[]',
    deletedAt: _date(json['deletedAt']),
    updatedAt: _date(json['updatedAt']),
    authorId: json['authorId'] as String? ?? 'local',
    createdAt: _date(json['createdAt']),
  );
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'tripId': tripId,
    'capturedAt': capturedAt.toIso8601String(),
    'caption': caption,
    'latitude': latitude,
    'longitude': longitude,
    'accuracyM': accuracyM,
    'placeLabel': placeLabel,
    'sortIndex': sortIndex,
    'relPath': relPath,
    'thumbRelPath': thumbRelPath,
    'width': width,
    'height': height,
    'bytes': bytes,
    'deletedAt': deletedAt?.toIso8601String(),
    'authorId': authorId,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory Moment.fromJson(Map<String, dynamic> json) => Moment(
    id: json['id'] as String,
    tripId: json['tripId'] as String,
    capturedAt: DateTime.parse(json['capturedAt'] as String),
    caption: json['caption'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    accuracyM: (json['accuracyM'] as num?)?.toDouble(),
    placeLabel: json['placeLabel'] as String?,
    sortIndex: json['sortIndex'] as int? ?? 0,
    relPath: json['relPath'] as String?,
    thumbRelPath: json['thumbRelPath'] as String?,
    width: json['width'] as int? ?? 0,
    height: json['height'] as int? ?? 0,
    bytes: json['bytes'] as int? ?? 0,
    deletedAt: _date(json['deletedAt']),
    authorId: json['authorId'] as String? ?? 'local',
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
  );
}

class Photo {
  const Photo({
    required this.id,
    required this.momentId,
    required this.relPath,
    required this.thumbRelPath,
    required this.width,
    required this.height,
    required this.bytes,
    this.position = 0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.authorId = 'local',
  });

  final String id;
  final String momentId;
  final String relPath;
  final String thumbRelPath;
  final int width;
  final int height;
  final int bytes;
  final int position;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String authorId;
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse(value as String);
