class SubtitleTrack {
  const SubtitleTrack({required this.label, required this.uri, this.language});

  final String label;
  final String uri;
  final String? language;

  Map<String, Object?> toJson() => {'label': label, 'uri': uri, 'language': language};

  factory SubtitleTrack.fromJson(Map<String, Object?> json) {
    return SubtitleTrack(
      label: json['label'] as String,
      uri: json['uri'] as String,
      language: json['language'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtitleTrack && runtimeType == other.runtimeType && uri == other.uri;

  @override
  int get hashCode => uri.hashCode;
}

class AudioTrack {
  const AudioTrack({required this.label, required this.id, this.language});

  final String label;
  final String id;
  final String? language;

  Map<String, Object?> toJson() => {'label': label, 'id': id, 'language': language};

  factory AudioTrack.fromJson(Map<String, Object?> json) {
    return AudioTrack(
      label: json['label'] as String,
      id: json['id'] as String,
      language: json['language'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTrack && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum MediaKind { audio, video }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.uri,
    required this.kind,
    this.artist,
    this.album,
    this.genre,
    this.duration,
    this.addedAt,
    this.lastPlayedAt,
    this.folderPath,
    this.artworkUri,
    this.thumbnailUri,
    this.subtitleTracks = const [],
    this.isFavorite = false,
    this.resumePosition = Duration.zero,
  });

  final String id;
  final String title;
  final String uri;
  final MediaKind kind;
  final String? artist;
  final String? album;
  final String? genre;
  final Duration? duration;
  final DateTime? addedAt;
  final DateTime? lastPlayedAt;
  final String? folderPath;
  final String? artworkUri;
  final String? thumbnailUri;
  final List<SubtitleTrack> subtitleTracks;
  final bool isFavorite;
  final Duration resumePosition;

  bool get isVideo => kind == MediaKind.video;

  MediaItem copyWith({
    String? id,
    String? title,
    String? uri,
    MediaKind? kind,
    String? artist,
    String? album,
    String? genre,
    Duration? duration,
    DateTime? addedAt,
    DateTime? lastPlayedAt,
    String? folderPath,
    String? artworkUri,
    String? thumbnailUri,
    List<SubtitleTrack>? subtitleTracks,
    bool? isFavorite,
    Duration? resumePosition,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      uri: uri ?? this.uri,
      kind: kind ?? this.kind,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      duration: duration ?? this.duration,
      addedAt: addedAt ?? this.addedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      folderPath: folderPath ?? this.folderPath,
      artworkUri: artworkUri ?? this.artworkUri,
      thumbnailUri: thumbnailUri ?? this.thumbnailUri,
      subtitleTracks: subtitleTracks ?? this.subtitleTracks,
      isFavorite: isFavorite ?? this.isFavorite,
      resumePosition: resumePosition ?? this.resumePosition,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'uri': uri,
        'kind': kind.name,
        'artist': artist,
        'album': album,
        'genre': genre,
        'durationMs': duration?.inMilliseconds,
        'addedAt': addedAt?.toIso8601String(),
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
        'folderPath': folderPath,
        'artworkUri': artworkUri,
        'thumbnailUri': thumbnailUri,
        'subtitleTracks': subtitleTracks.map((track) => track.toJson()).toList(growable: false),
        'isFavorite': isFavorite,
        'resumePositionMs': resumePosition.inMilliseconds,
      };

  factory MediaItem.fromJson(Map<String, Object?> json) {
    return MediaItem(
      id: json['id'] as String,
      title: json['title'] as String,
      uri: json['uri'] as String,
      kind: MediaKind.values.byName(json['kind'] as String),
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      genre: json['genre'] as String?,
      duration: json['durationMs'] == null ? null : Duration(milliseconds: json['durationMs'] as int),
      addedAt: json['addedAt'] == null ? null : DateTime.parse(json['addedAt'] as String),
      lastPlayedAt: json['lastPlayedAt'] == null ? null : DateTime.parse(json['lastPlayedAt'] as String),
      folderPath: json['folderPath'] as String?,
      artworkUri: json['artworkUri'] as String?,
      thumbnailUri: json['thumbnailUri'] as String?,
      subtitleTracks: (json['subtitleTracks'] as List<Object?>? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(SubtitleTrack.fromJson)
          .toList(growable: false),
      isFavorite: json['isFavorite'] as bool? ?? false,
      resumePosition: Duration(milliseconds: json['resumePositionMs'] as int? ?? 0),
    );
  }
}

class Playlist {
  Playlist({required this.id, required this.name, required this.itemIds});

  final String id;
  final String name;
  final List<String> itemIds;

  Playlist copyWith({
    String? name,
    List<String>? itemIds,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'itemIds': itemIds,
      };

  factory Playlist.fromJson(Map<String, Object?> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      itemIds: List<String>.from(json['itemIds'] as List),
    );
  }
}
