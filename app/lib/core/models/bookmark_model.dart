class Bookmark {
  const Bookmark({
    required this.id,
    required this.mediaId,
    required this.position,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String mediaId;
  final Duration position;
  final String note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'mediaId': mediaId,
        'positionMs': position.inMilliseconds,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: json['id'] as String,
        mediaId: json['mediaId'] as String,
        position: Duration(milliseconds: json['positionMs'] as int),
        note: json['note'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
