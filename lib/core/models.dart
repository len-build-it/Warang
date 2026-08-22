class Profile {
  const Profile({
    required this.id,
    required this.name,
    this.avatarRelPath,
    this.authorId = 'local',
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });
  final String id;
  final String name;
  final String? avatarRelPath;
  final String authorId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatarRelPath': avatarRelPath,
    'authorId': authorId,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };
  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    avatarRelPath: json['avatarRelPath'] as String?,
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
    this.startDate,
    this.endDate,
    this.isEveryday = false,
    this.deletedAt,
    this.updatedAt,
    this.authorId = 'local',
    this.createdAt,
  });
  final String id;
  final String title;
  final String? place;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isEveryday;
  final DateTime? deletedAt;
  final DateTime? updatedAt;
  final String authorId;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'place': place,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'isEveryday': isEveryday,
    'deletedAt': deletedAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'authorId': authorId,
    'createdAt': createdAt?.toIso8601String(),
  };
  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'] as String,
    title: json['title'] as String,
    place: json['place'] as String?,
    startDate: _date(json['startDate']),
    endDate: _date(json['endDate']),
    isEveryday: json['isEveryday'] as bool? ?? false,
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
    this.placeLabel,
    this.relPath,
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
  final String? placeLabel;
  final String? relPath;
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
    'placeLabel': placeLabel,
    'relPath': relPath,
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
    placeLabel: json['placeLabel'] as String?,
    relPath: json['relPath'] as String?,
    deletedAt: _date(json['deletedAt']),
    authorId: json['authorId'] as String? ?? 'local',
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
  );
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse(value as String);
