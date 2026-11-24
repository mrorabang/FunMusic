import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import 'soundcloud_service.dart';
import 'youtube_music_service.dart';

enum MusicApiSource {
  soundcloud('SoundCloud (Full 100% bài hát)'),
  deezer('Deezer API (Preview 30s)'),
  itunes('Apple iTunes Search API'),
  youtube('YouTube Music (Full 100% bài hát)'),
  custom('Nguồn tùy chỉnh (Custom API)');

  final String displayName;
  const MusicApiSource(this.displayName);
}

class ApiSourceItem {
  final String id;
  final String name;
  final String? searchUrl;
  final String description;
  final bool isCustom;

  const ApiSourceItem({
    required this.id,
    required this.name,
    this.searchUrl,
    required this.description,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'searchUrl': searchUrl,
        'description': description,
        'isCustom': isCustom,
      };

  factory ApiSourceItem.fromJson(Map<String, dynamic> json) => ApiSourceItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        searchUrl: json['searchUrl'] as String?,
        description: json['description'] as String? ?? 'Custom API',
        isCustom: true,
      );
}

class MusicApiService {
  static const String _kDefaultSourceKey = 'k_default_music_api_source';
  static const String _kCustomSourcesKey = 'k_custom_music_api_sources';

  static final List<ApiSourceItem> builtInSources = [
    const ApiSourceItem(
      id: 'soundcloud',
      name: 'SoundCloud',
      description: 'Full bài hát 100%, stream tốc độ cao (HLS AAC)',
      isCustom: false,
    ),
    const ApiSourceItem(
      id: 'youtube',
      name: 'YouTube Music',
      description: 'Full bài hát 100%, kho nhạc khổng lồ (IFrame Web)',
      isCustom: false,
    ),
    const ApiSourceItem(
      id: 'deezer',
      name: 'Deezer API',
      description: 'Server Deezer (mp3 preview 30s, ảnh bìa HD)',
      isCustom: false,
    ),
    const ApiSourceItem(
      id: 'itunes',
      name: 'Apple iTunes',
      description: 'Server Apple iTunes (m4a preview 30s)',
      isCustom: false,
    ),
  ];

  static String currentSourceId = 'soundcloud';
  static String defaultSourceId = 'soundcloud';
  static List<ApiSourceItem> customSources = [];

  static const String _deezerBaseUrl = 'https://api.deezer.com';
  static const String _itunesBaseUrl = 'https://itunes.apple.com';

  /// Khởi tạo và đọc cấu hình nguồn mặc định & API tùy chỉnh từ bộ nhớ
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Đọc danh sách Custom APIs
      final customJsonList = prefs.getStringList(_kCustomSourcesKey) ?? [];
      customSources = customJsonList
          .map((str) => ApiSourceItem.fromJson(json.decode(str)))
          .toList();

      // Đọc API mặc định
      defaultSourceId = prefs.getString(_kDefaultSourceKey) ?? 'soundcloud';

      // Kiểm tra tính hợp lệ
      final all = getAllSources();
      if (!all.any((s) => s.id == defaultSourceId)) {
        defaultSourceId = 'soundcloud';
      }

      // Tự động chọn API mặc định mỗi khi vào ứng dụng
      currentSourceId = defaultSourceId;
    } catch (e) {
      debugPrint('MusicApiService.init error: $e');
    }
  }

  /// Lấy tất cả các nguồn API (bao gồm tích hợp và người dùng thêm)
  static List<ApiSourceItem> getAllSources() {
    return [...builtInSources, ...customSources];
  }

  /// Lấy thông tin nguồn đang kích hoạt
  static ApiSourceItem get currentSourceItem {
    return getAllSources().firstWhere(
      (s) => s.id == currentSourceId,
      orElse: () => builtInSources.first,
    );
  }

  /// Tên nguồn đang chọn để hiển thị trên AppBar
  static String get currentSourceName => currentSourceItem.name;

  /// Tương thích ngược với enum MusicApiSource
  static MusicApiSource get currentSource {
    if (currentSourceId == 'soundcloud') return MusicApiSource.soundcloud;
    if (currentSourceId == 'youtube') return MusicApiSource.youtube;
    if (currentSourceId == 'deezer') return MusicApiSource.deezer;
    if (currentSourceId == 'itunes') return MusicApiSource.itunes;
    return MusicApiSource.custom;
  }

  static set currentSource(MusicApiSource source) {
    if (source == MusicApiSource.soundcloud) currentSourceId = 'soundcloud';
    if (source == MusicApiSource.youtube) currentSourceId = 'youtube';
    if (source == MusicApiSource.deezer) currentSourceId = 'deezer';
    if (source == MusicApiSource.itunes) currentSourceId = 'itunes';
  }

  /// Chọn nguồn đang phát
  static void selectSource(String sourceId) {
    currentSourceId = sourceId;
  }

  /// Đặt nguồn mặc định mỗi khi vào app
  static Future<void> setDefaultSource(String sourceId) async {
    defaultSourceId = sourceId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDefaultSourceKey, sourceId);
    } catch (e) {
      debugPrint('setDefaultSource error: $e');
    }
  }

  /// Thêm API mới
  static Future<void> addCustomSource(String name, String searchUrl,
      {String? description}) async {
    final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final newSource = ApiSourceItem(
      id: newId,
      name: name.trim(),
      searchUrl: searchUrl.trim(),
      description: (description != null && description.trim().isNotEmpty)
          ? description.trim()
          : searchUrl.trim(),
      isCustom: true,
    );
    customSources.add(newSource);
    await _saveCustomSources();
  }

  /// Xóa Custom API
  static Future<void> deleteCustomSource(String sourceId) async {
    customSources.removeWhere((s) => s.id == sourceId);
    await _saveCustomSources();

    if (currentSourceId == sourceId) {
      currentSourceId = 'soundcloud';
    }
    if (defaultSourceId == sourceId) {
      defaultSourceId = 'soundcloud';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDefaultSourceKey, 'soundcloud');
    }
  }

  static Future<void> _saveCustomSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList =
          customSources.map((s) => json.encode(s.toJson())).toList();
      await prefs.setStringList(_kCustomSourcesKey, jsonList);
    } catch (e) {
      debugPrint('Save custom sources error: $e');
    }
  }

  /// Tìm kiếm bài hát theo nguồn đang chọn
  static Future<List<Song>> searchSongs(String query, {int limit = 30}) async {
    if (currentSourceId == 'soundcloud') {
      return SoundCloudService.searchSongs(query, limit: limit);
    } else if (currentSourceId == 'youtube') {
      return YouTubeMusicService.searchSongs(query, limit: limit);
    } else if (currentSourceId == 'itunes') {
      return _searchItunes(query, limit: limit);
    } else if (currentSourceId == 'deezer') {
      return _searchDeezer(query, limit: limit);
    } else {
      final custom = customSources.firstWhere(
        (s) => s.id == currentSourceId,
        orElse: () => builtInSources.first,
      );
      if (custom.isCustom) {
        return _searchCustomApi(custom, query, limit: limit);
      }
    }
    return _searchDeezer(query, limit: limit);
  }

  /// Lấy danh sách Top Charts
  static Future<List<Song>> getTopChart({int limit = 25}) async {
    if (currentSourceId == 'soundcloud') {
      return SoundCloudService.getTopChart(limit: limit);
    } else if (currentSourceId == 'youtube') {
      return YouTubeMusicService.getTopChart(limit: limit);
    } else if (currentSourceId == 'itunes') {
      return _searchItunes('Top Hits 2026', limit: limit);
    } else if (currentSourceId == 'deezer') {
      return _getDeezerTopChart(limit: limit);
    } else {
      final custom = customSources.firstWhere(
        (s) => s.id == currentSourceId,
        orElse: () => builtInSources.first,
      );
      if (custom.isCustom) {
        return _searchCustomApi(custom, 'Top Hits', limit: limit);
      }
    }
    return _getDeezerTopChart(limit: limit);
  }

  /// Phân giải link stream (hỗ trợ phát trực tuyến full bài SoundCloud & YouTube & Custom)
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
      final ytUrl = await YouTubeMusicService.resolveStreamUrl(song.youtubeId!);
      if (ytUrl != null && ytUrl.isNotEmpty) {
        return ytUrl;
      }
      debugPrint('YouTube direct stream unavailable, attempting SoundCloud fallback for: ${song.title}');
      try {
        final scSongs = await SoundCloudService.searchSongs('${song.title} ${song.artist}', limit: 3);
        if (scSongs.isNotEmpty && scSongs.first.soundcloudTranscodingUrl != null) {
          return await SoundCloudService.resolveStreamUrl(scSongs.first.soundcloudTranscodingUrl!);
        }
      } catch (e) {
        debugPrint('SoundCloud fallback error: $e');
      }
    }
    if (song.streamUrl.isNotEmpty) {
      return song.streamUrl;
    }
    return null;
  }

  // --- Custom API Implementation ---
  static Future<List<Song>> _searchCustomApi(
      ApiSourceItem api, String query, {int limit = 30}) async {
    final rawUrl = api.searchUrl?.trim() ?? '';
    if (rawUrl.isEmpty) return [];

    try {
      Uri uri;
      if (rawUrl.contains('{query}')) {
        final replaced = rawUrl
            .replaceAll('{query}', Uri.encodeComponent(query))
            .replaceAll('{limit}', limit.toString());
        uri = Uri.parse(replaced);
      } else {
        final parsedUri = Uri.parse(rawUrl);
        final qParams = Map<String, String>.from(parsedUri.queryParameters);
        qParams['q'] = query;
        qParams['limit'] = limit.toString();
        uri = parsedUri.replace(queryParameters: qParams);
      }

      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        List items = [];
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map) {
          for (final key in ['results', 'data', 'tracks', 'songs', 'items']) {
            if (decoded[key] is List) {
              items = decoded[key];
              break;
            }
          }
        }

        final List<Song> results = [];
        for (var item in items) {
          if (item is Map) {
            final song = _parseCustomSongJson(item);
            if (song != null) {
              results.add(song);
            }
          }
        }
        return results;
      }
    } catch (e) {
      debugPrint('Custom API error: $e');
    }
    return [];
  }

  static Song? _parseCustomSongJson(Map item) {
    try {
      final rawId = item['id'] ?? item['song_id'] ?? item['track_id'];
      final id = rawId is int
          ? rawId
          : int.tryParse(rawId?.toString() ?? '') ??
              item.toString().hashCode.abs();

      final title = (item['title'] ?? item['name'] ?? item['track_name'] ?? 'Không tên')
          .toString();
      final artist = (item['artist'] ??
              item['singer'] ??
              item['author'] ??
              item['artist_name'] ??
              'Nghệ sĩ')
          .toString();
      final album = (item['album'] ?? item['album_name'] ?? '').toString();
      final coverUrl = (item['cover'] ??
              item['cover_url'] ??
              item['artwork'] ??
              item['image'] ??
              item['thumbnail'] ??
              '')
          .toString();
      final streamUrl = (item['stream_url'] ??
              item['url'] ??
              item['audio_url'] ??
              item['preview'] ??
              item['link'] ??
              '')
          .toString();

      int durationSec = 0;
      final rawDur =
          item['duration'] ?? item['length'] ?? item['duration_seconds'];
      if (rawDur is int) {
        durationSec = rawDur;
      } else if (rawDur is String) {
        final parts = rawDur.split(':');
        if (parts.length == 2) {
          durationSec = (int.tryParse(parts[0]) ?? 0) * 60 +
              (int.tryParse(parts[1]) ?? 0);
        } else if (parts.length == 3) {
          durationSec = (int.tryParse(parts[0]) ?? 0) * 3600 +
              (int.tryParse(parts[1]) ?? 0) * 60 +
              (int.tryParse(parts[2]) ?? 0);
        } else {
          durationSec = int.tryParse(rawDur) ?? 0;
        }
      }

      final ytId = item['youtube_id'] ?? item['yt_id'] ?? item['youtubeId'];
      final scTrans =
          item['transcoding_url'] ?? item['soundcloud_transcoding_url'];

      return Song(
        id: id,
        title: title,
        artist: artist,
        album: album,
        coverUrl: coverUrl,
        streamUrl: streamUrl,
        duration: durationSec,
        isLocal: false,
        youtubeId: ytId?.toString(),
        soundcloudTranscodingUrl: scTrans?.toString(),
      );
    } catch (e) {
      debugPrint('Parse custom song error: $e');
      return null;
    }
  }

  // --- Deezer Implementation ---
  static Future<List<Song>> _searchDeezer(String query,
      {int limit = 30}) async {
    final q = query.trim().isEmpty ? 'Top Hits' : query.trim();
    try {
      final uri =
          Uri.parse('$_deezerBaseUrl/search').replace(queryParameters: {
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
      final uri = Uri.parse('$_deezerBaseUrl/chart/0/tracks')
          .replace(queryParameters: {
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
  static Future<List<Song>> _searchItunes(String query,
      {int limit = 30}) async {
    final term = query.trim().isEmpty ? 'Top Hits' : query.trim();
    try {
      final uri =
          Uri.parse('$_itunesBaseUrl/search').replace(queryParameters: {
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
