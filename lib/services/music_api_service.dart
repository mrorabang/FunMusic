import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'soundcloud_service.dart';
import 'youtube_music_service.dart';

enum MusicApiSource {
  soundcloud('SoundCloud (Full 100% bài hát)'),
  deezer('Deezer API (Preview 30s)'),
  itunes('Apple iTunes Search API'),
  youtube('YouTube Music (Beta)');

  final String displayName;
  const MusicApiSource(this.displayName);
}

class MusicApiService {
  static MusicApiSource currentSource = MusicApiSource.soundcloud;

  static const String _deezerBaseUrl = 'https://api.deezer.com';
  static const String _itunesBaseUrl = 'https://itunes.apple.com';

  /// Tìm kiếm bài hát theo nguồn đang chọn
  static Future<List<Song>> searchSongs(String query, {int limit = 30}) async {
    if (currentSource == MusicApiSource.soundcloud) {
      return SoundCloudService.searchSongs(query, limit: limit);
    } else if (currentSource == MusicApiSource.youtube) {
      return YouTubeMusicService.searchSongs(query, limit: limit);
    } else if (currentSource == MusicApiSource.itunes) {
      return _searchItunes(query, limit: limit);
    }
    return _searchDeezer(query, limit: limit);
  }

  /// Lấy danh sách Top Charts
  static Future<List<Song>> getTopChart({int limit = 25}) async {
    if (currentSource == MusicApiSource.soundcloud) {
      return SoundCloudService.getTopChart(limit: limit);
    } else if (currentSource == MusicApiSource.youtube) {
      return YouTubeMusicService.getTopChart(limit: limit);
    } else if (currentSource == MusicApiSource.itunes) {
      return _searchItunes('Top Hits 2026', limit: limit);
    }
    return _getDeezerTopChart(limit: limit);
  }

  /// Phân giải link stream (hỗ trợ phát trực tuyến full bài SoundCloud & YouTube)
  static Future<String?> resolveStreamUrl(Song song) async {
    if (song.isLocal && song.localFilePath != null) {
      return song.localFilePath;
    }
    if (song.soundcloudTranscodingUrl != null &&
        song.soundcloudTranscodingUrl!.isNotEmpty) {
      return SoundCloudService.resolveStreamUrl(
          song.soundcloudTranscodingUrl!);
    }
    if (song.youtubeId != null && song.youtubeId!.isNotEmpty) {
      return YouTubeMusicService.resolveStreamUrl(song.youtubeId!);
    }
    return song.streamUrl;
  }

  // --- Deezer Implementation ---
  static Future<List<Song>> _searchDeezer(String query, {int limit = 30}) async {
    final q = query.trim().isEmpty ? 'Top Hits' : query.trim();
    try {
      final uri = Uri.parse('$_deezerBaseUrl/search').replace(queryParameters: {
        'q': q,
        'limit': limit.toString(),
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['data'] is List) {
          final List list = data['data'];
          return list
              .where((item) =>
                  item['preview'] != null &&
                  item['preview'].toString().isNotEmpty)
              .map((item) => Song.fromDeezerJson(item))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Deezer error: $e');
    }
    return [];
  }

  static Future<List<Song>> _getDeezerTopChart({int limit = 25}) async {
    try {
      final uri = Uri.parse('$_deezerBaseUrl/chart/0/tracks').replace(queryParameters: {
        'limit': limit.toString(),
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['data'] is List) {
          final List list = data['data'];
          return list
              .where((item) =>
                  item['preview'] != null &&
                  item['preview'].toString().isNotEmpty)
              .map((item) => Song.fromDeezerJson(item))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Deezer chart error: $e');
    }
    return _searchDeezer('Top Hits', limit: limit);
  }

  // --- iTunes Implementation ---
  static Future<List<Song>> _searchItunes(String query, {int limit = 30}) async {
    final term = query.trim().isEmpty ? 'Top Hits' : query.trim();
    try {
      final uri = Uri.parse('$_itunesBaseUrl/search').replace(queryParameters: {
        'term': term,
        'entity': 'song',
        'limit': limit.toString(),
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['results'] is List) {
          final List list = data['results'];
          return list
              .where((item) =>
                  item['previewUrl'] != null &&
                  item['previewUrl'].toString().isNotEmpty)
              .map((item) => Song.fromItunesJson(item))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('iTunes error: $e');
    }
    return [];
  }
}
