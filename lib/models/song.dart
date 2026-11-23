class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final String streamUrl;
  final int duration; // in seconds

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
    required this.streamUrl,
    required this.duration,
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
    };
  }
}
