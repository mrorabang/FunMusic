import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

enum MusicApiSource {
  deezer('Deezer API (Mặc định)'),
  itunes('Apple iTunes Search API');

  final String displayName;
  const MusicApiSource(this.displayName);
}

class MusicApiService {
  static MusicApiSource currentSource = MusicApiSource.deezer;

  static const String _deezerBaseUrl = 'https://api.deezer.com';
  static const String _itunesBaseUrl = 'https://itunes.apple.com';

  /// Tìm kiếm bài hát theo nguồn đang chọn
  static Future<List<Song>> searchSongs(String query, {int limit = 30}) async {
    if (currentSource == MusicApiSource.itunes) {
      return _searchItunes(query, limit: limit);
    }
    return _searchDeezer(query, limit: limit);
  }

  /// Lấy danh sách Top Charts
  static Future<List<Song>> getTopChart({int limit = 25}) async {
    if (currentSource == MusicApiSource.itunes) {
      return _searchItunes('Top Hits 2026', limit: limit);
    }
    return _getDeezerTopChart(limit: limit);
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
