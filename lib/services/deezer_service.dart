import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class DeezerService {
  static const String _baseUrl = 'https://api.deezer.com';

  /// Tìm kiếm bài hát theo từ khóa (tên bài hát, ca sĩ)
  static Future<List<Song>> searchSongs(String query, {int limit = 30}) async {
    if (query.trim().isEmpty) {
      return getTopChart(limit: limit);
    }

    try {
      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'q': query.trim(),
        'limit': limit.toString(),
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] != null && data['data'] is List) {
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
      debugPrint('DeezerService.searchSongs error: $e');
    }
    return [];
  }

  /// Lấy danh sách bài hát bảng xếp hạng (Top Charts)
  static Future<List<Song>> getTopChart({int limit = 25}) async {
    try {
      final uri = Uri.parse('$_baseUrl/chart/0/tracks').replace(queryParameters: {
        'limit': limit.toString(),
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] != null && data['data'] is List) {
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
      debugPrint('DeezerService.getTopChart error: $e');
    }
    // Fallback: tìm kiếm nhạc thịnh hành
    return searchSongs('Top Hits', limit: limit);
  }
}
