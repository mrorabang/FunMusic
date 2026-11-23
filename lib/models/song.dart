class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final String streamUrl;
  final int duration; // in seconds
  final bool isLocal;
  final String? localFilePath;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
    required this.streamUrl,
    required this.duration,
    this.isLocal = false,
    this.localFilePath,
  });

  factory Song.fromDeezerJson(Map<String, dynamic> json) {
    String artistName = 'Unknown Artist';
    if (json['artist'] != null && json['artist']['name'] != null) {
      artistName = json['artist']['name'].toString();
    }

    String albumTitle = '';
    String cover = '';
    if (json['album'] != null) {
      albumTitle = json['album']['title']?.toString() ?? '';
      cover = json['album']['cover_big']?.toString() ??
          json['album']['cover_medium']?.toString() ??
          json['album']['cover']?.toString() ??
          '';
    }

    return Song(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? 'Unknown Title',
      artist: artistName,
      album: albumTitle,
      coverUrl: cover,
      streamUrl: json['preview']?.toString() ?? '',
      duration: json['duration'] is int
          ? json['duration']
          : int.tryParse(json['duration']?.toString() ?? '0') ?? 0,
      isLocal: false,
    );
  }

  factory Song.fromItunesJson(Map<String, dynamic> json) {
    String cover = json['artworkUrl100']?.toString() ?? '';
    // Tối ưu ảnh bìa iTunes lên 600x600 chất lượng cao
    if (cover.contains('100x100bb')) {
      cover = cover.replaceAll('100x100bb', '600x600bb');
    }

    int durationSec = 30;
    if (json['trackTimeMillis'] != null) {
      durationSec = (json['trackTimeMillis'] / 1000).round();
    }

    return Song(
      id: json['trackId'] is int
          ? json['trackId']
          : int.tryParse(json['trackId']?.toString() ?? '0') ?? 0,
      title: json['trackName']?.toString() ?? 'Unknown Title',
      artist: json['artistName']?.toString() ?? 'Unknown Artist',
      album: json['collectionName']?.toString() ?? '',
      coverUrl: cover,
      streamUrl: json['previewUrl']?.toString() ?? '',
      duration: durationSec,
      isLocal: false,
    );
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      album: json['album']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      streamUrl: json['streamUrl']?.toString() ?? '',
      duration: json['duration'] is int ? json['duration'] : 0,
      isLocal: json['isLocal'] == true,
      localFilePath: json['localFilePath']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'coverUrl': coverUrl,
      'streamUrl': streamUrl,
      'duration': duration,
      'isLocal': isLocal,
      'localFilePath': localFilePath,
    };
  }
}
