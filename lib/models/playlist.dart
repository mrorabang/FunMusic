import 'song.dart';

class Playlist {
  final String id;
  String name;
  final DateTime createdAt;
  final List<Song> songs;

  Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.songs,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'songs': songs.map((s) => s.toJson()).toList(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Playlist',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      songs: (json['songs'] as List? ?? [])
          .map((item) => Song.fromJson(item))
          .toList(),
    );
  }
}
