import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class SoundCloudService {
  static String? _clientId;
  static DateTime? _clientIdFetchedAt;
  static const String _fallbackClientId = 'glXhJxvYKPM87la70dG2G1bJ03AdA3hN';

  /// Lấy hoặc cập nhật client_id động từ trang chủ SoundCloud
  static Future<String> getClientId() async {
    if (_clientId != null &&
        _clientIdFetchedAt != null &&
        DateTime.now().difference(_clientIdFetchedAt!).inHours < 12) {
      return _clientId!;
    }

    try {
      final res = await http
          .get(Uri.parse('https://soundcloud.com'))
          .timeout(const Duration(seconds: 5));
      final matches = RegExp(r'https://a-v2\.sndcdn\.com/assets/[^"]+\.js')
          .allMatches(res.body);
      final scriptUrls =
          matches.map((m) => m.group(0)!).toList().reversed.take(6);

      for (final sUrl in scriptUrls) {
        final jsRes =
            await http.get(Uri.parse(sUrl)).timeout(const Duration(seconds: 5));
        final m =
            RegExp(r'client_id[:=]"([a-zA-Z0-9]{32})"').firstMatch(jsRes.body);
        if (m != null) {
          _clientId = m.group(1);
          _clientIdFetchedAt = DateTime.now();
          debugPrint('SoundCloudService dynamic clientId: $_clientId');
          return _clientId!;
        }
      }
    } catch (e) {
      debugPrint('SoundCloudService getClientId error: $e');
    }

    _clientId ??= _fallbackClientId;
    return _clientId!;
  }

  /// Tìm kiếm bài hát trên SoundCloud (Full 100% thời lượng)
  static Future<List<Song>> searchSongs(String query, {int limit = 30}) async {
    final clientId = await getClientId();
    final q = query.trim().isEmpty ? 'Top Hits Việt Nam' : query.trim();

    try {
      final uri =
          Uri.parse('https://api-v2.soundcloud.com/search/tracks').replace(
        queryParameters: {
          'q': q,
          'client_id': clientId,
          'limit': limit.toString(),
        },
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint('SoundCloud search returned status: ${res.statusCode}');
        return [];
      }

      final data = json.decode(utf8.decode(res.bodyBytes));
      final List collection = data['collection'] ?? [];
      final List<Song> results = [];

      for (final item in collection) {
        final title = item['title']?.toString() ?? 'Unknown Title';
        final artist = item['user']?['username']?.toString() ?? 'Nghệ sĩ';
        final durationMs = item['duration'] is int ? item['duration'] : 0;
        final rawArtwork = item['artwork_url']?.toString() ??
            item['user']?['avatar_url']?.toString() ??
            '';
        final coverUrl = rawArtwork.replaceAll('-large', '-t500x500');

        // Tìm luồng phát stream URL trong transcodings (ưu tiên mp4a HLS hoặc progressive, tránh format mpegurl bị 404)
        final transcodings = item['media']?['transcodings'] as List? ?? [];
        if (transcodings.isEmpty) continue;

        dynamic selectedTrans;
        for (final t in transcodings) {
          final format = t['format'] as Map<String, dynamic>?;
          final mime = format?['mime_type']?.toString() ?? '';
          final protocol = format?['protocol']?.toString() ?? '';
          if (mime.contains('mp4a') || protocol == 'progressive') {
            selectedTrans = t;
            break;
          }
        }
        selectedTrans ??= transcodings.first;

        final transUrl = selectedTrans['url']?.toString() ?? '';
        if (transUrl.isEmpty) continue;

        final rawId = item['id'];
        final songId = rawId is int
            ? rawId
            : int.tryParse(rawId.toString()) ?? title.hashCode.abs();

        results.add(Song(
          id: songId,
          title: title,
          artist: artist,
          album: 'SoundCloud',
          coverUrl: coverUrl,
          streamUrl: '',
          duration: (durationMs ~/ 1000),
          isLocal: false,
          soundcloudTranscodingUrl: transUrl,
        ));
      }

      return results;
    } catch (e) {
      debugPrint('SoundCloudService searchSongs error: $e');
      return [];
    }
  }

  /// Lấy bảng xếp hạng / Top bài hát
  static Future<List<Song>> getTopChart({int limit = 30}) async {
    return searchSongs('Top Hits Việt Nam 2026', limit: limit);
  }

  /// Phân giải link stream phát trực tiếp
  static Future<String?> resolveStreamUrl(String transcodingUrl) async {
    try {
      final clientId = await getClientId();
      final url = '$transcodingUrl?client_id=$clientId';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final streamUrl = data['url']?.toString();
        return streamUrl;
      }
    } catch (e) {
      debugPrint('SoundCloudService.resolveStreamUrl error: $e');
    }
    return null;
  }
}
