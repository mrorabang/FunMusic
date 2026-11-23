import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class YouTubeMusicService {
  static final YoutubeExplode _yt = YoutubeExplode();
  static final Map<String, String> _streamCache = {};

  static const String _innertubeSearchUrl =
      'https://music.youtube.com/youtubei/v1/search';

  static const Map<String, String> _innertubeHeaders = {
    'Content-Type': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://music.youtube.com/',
    'Origin': 'https://music.youtube.com',
  };

  /// Lấy Audio Stream URL chất lượng cao (AAC m4a hoặc Opus) trực tiếp từ YouTube
  static Future<String?> resolveStreamUrl(String videoId) async {
    if (_streamCache.containsKey(videoId)) {
      return _streamCache[videoId];
    }

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) return null;

      // Ưu tiên stream định dạng mp4 (AAC) để hỗ trợ mượt mà trên cả Android (ExoPlayer) lẫn iOS (AVPlayer)
      final mp4Streams = audioStreams
          .where((s) => s.container.name.toLowerCase() == 'mp4')
          .toList();

      AudioStreamInfo streamInfo;
      if (mp4Streams.isNotEmpty) {
        streamInfo = mp4Streams.withHighestBitrate();
      } else {
        streamInfo = audioStreams.withHighestBitrate();
      }

      final url = streamInfo.url.toString();
      _streamCache[videoId] = url;
      return url;
    } catch (e) {
      debugPrint('YouTubeMusicService.resolveStreamUrl error for $videoId: $e');
      return null;
    }
  }

  /// Tìm kiếm bài hát qua InnerTube API (client WEB_REMIX)
  static Future<List<Song>> searchSongs(String query, {int limit = 30}) async {
    final q = query.trim().isEmpty ? 'Top Hits Việt Nam' : query.trim();

    try {
      final body = json.encode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240101.01.00',
            'hl': 'vi',
            'gl': 'VN',
          }
        },
        'query': q,
      });

      final res = await http
          .post(
            Uri.parse(_innertubeSearchUrl),
            headers: _innertubeHeaders,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        debugPrint('InnerTube search returned status ${res.statusCode}');
        return [];
      }

      final data = json.decode(res.body);
      final tabs =
          data['contents']?['tabbedSearchResultsRenderer']?['tabs'] as List?;
      final tabContent = tabs?[0]?['tabRenderer']?['content'];
      final sectionList =
          tabContent?['sectionListRenderer']?['contents'] as List?;
      if (sectionList == null) return [];

      final List<Song> results = [];
      final Set<String> seenIds = {};

      for (final section in sectionList) {
        List items = [];
        if (section['itemSectionRenderer'] != null) {
          items = section['itemSectionRenderer']['contents'] ?? [];
        } else if (section['musicShelfRenderer'] != null) {
          items = section['musicShelfRenderer']['contents'] ?? [];
        } else if (section['musicCardShelfRenderer'] != null) {
          final card = section['musicCardShelfRenderer'];
          final cardSong = _parseCardShelf(card);
          if (cardSong != null && seenIds.add(cardSong.youtubeId!)) {
            results.add(cardSong);
          }
        }

        for (final raw in items) {
          final item = raw['musicResponsiveListItemRenderer'];
          if (item == null) continue;

          final song = _parseListItem(item);
          if (song != null && song.youtubeId != null && seenIds.add(song.youtubeId!)) {
            results.add(song);
            if (results.length >= limit) break;
          }
        }

        if (results.length >= limit) break;
      }

      return results;
    } catch (e) {
      debugPrint('YouTubeMusicService.searchSongs error: $e');
      return [];
    }
  }

  /// Lấy danh sách Top Charts Việt Nam
  static Future<List<Song>> getTopChart({int limit = 30}) async {
    return searchSongs('Top Hits Việt Nam 2026', limit: limit);
  }

  static Song? _parseCardShelf(Map<String, dynamic> card) {
    try {
      final title = card['title']?['runs']?[0]?['text']?.toString() ?? '';
      final nav = card['title']?['runs']?[0]?['navigationEndpoint'] ??
          card['buttons']?[0]?['buttonRenderer']?['command'];
      final videoId = nav?['watchEndpoint']?['videoId']?.toString();
      if (videoId == null || videoId.isEmpty) return null;

      final subtitleRuns = card['subtitle']?['runs'] as List?;
      String artist = 'Nghệ sĩ';
      if (subtitleRuns != null && subtitleRuns.isNotEmpty) {
        final texts = subtitleRuns
            .map((r) => r['text'].toString())
            .where((t) => t != ' • ' && t != 'Bài hát' && t != 'Song')
            .toList();
        if (texts.isNotEmpty) artist = texts[0];
      }

      final coverUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

      return Song(
        id: videoId.hashCode.abs(),
        title: title,
        artist: artist,
        album: 'YouTube Music',
        coverUrl: coverUrl,
        streamUrl: '',
        duration: 0,
        isLocal: false,
        youtubeId: videoId,
      );
    } catch (_) {
      return null;
    }
  }

  static Song? _parseListItem(Map<String, dynamic> item) {
    try {
      String videoId = item['playlistItemData']?['videoId']?.toString() ?? '';
      String title = '';
      String artist = 'Nghệ sĩ';
      String album = 'YouTube Music';
      int durationSec = 0;

      final flexCols = item['flexColumns'] as List?;
      if (flexCols == null || flexCols.isEmpty) return null;

      // Col 0: Title
      final titleRuns = flexCols[0]?['musicResponsiveListItemFlexColumnRenderer']
          ?['text']?['runs'] as List?;
      if (titleRuns != null && titleRuns.isNotEmpty) {
        title = titleRuns.map((r) => r['text'].toString()).join();
        if (videoId.isEmpty) {
          final nav = titleRuns[0]?['navigationEndpoint'];
          videoId = nav?['watchEndpoint']?['videoId']?.toString() ?? '';
        }
      }

      // Col 1: Subtitle (Type • Artist • Album • Duration)
      if (flexCols.length > 1) {
        final subRuns = flexCols[1]?['musicResponsiveListItemFlexColumnRenderer']
            ?['text']?['runs'] as List?;
        if (subRuns != null && subRuns.isNotEmpty) {
          final texts = subRuns
              .map((r) => r['text'].toString())
              .where((t) => t != ' • ')
              .toList();

          final cleanTexts = texts
              .where((t) =>
                  t != 'Bài hát' &&
                  t != 'Video' &&
                  t != 'Song' &&
                  !t.contains('lượt phát') &&
                  !t.contains('views'))
              .toList();

          if (cleanTexts.isNotEmpty) {
            artist = cleanTexts[0];
          }
          if (cleanTexts.length > 1) {
            for (final text in cleanTexts) {
              if (text.contains(':')) {
                durationSec = _parseDuration(text);
              } else if (text != artist) {
                album = text;
              }
            }
          }
        }
      }

      // Nếu videoId vẫn trống, tìm trong overlay play button
      if (videoId.isEmpty) {
        final overlayNav = item['overlay']
            ?['musicItemThumbnailOverlayRenderer']?['content']
            ?['musicPlayButtonRenderer']?['playNavigationEndpoint'];
        videoId = overlayNav?['watchEndpoint']?['videoId']?.toString() ?? '';
      }

      if (videoId.isEmpty || title.isEmpty) return null;

      // Ảnh bìa HD
      String coverUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
      final thumbs = item['thumbnail']?['musicThumbnailRenderer']?['thumbnail']
          ?['thumbnails'] as List?;
      if (thumbs != null && thumbs.isNotEmpty) {
        final rawUrl = thumbs.last['url']?.toString() ?? '';
        if (rawUrl.isNotEmpty) {
          coverUrl = rawUrl.replaceAll(RegExp(r'=w\d+-h\d+'), '=w500-h500');
        }
      }

      return Song(
        id: videoId.hashCode.abs(),
        title: title,
        artist: artist,
        album: album,
        coverUrl: coverUrl,
        streamUrl: '',
        duration: durationSec,
        isLocal: false,
        youtubeId: videoId,
      );
    } catch (_) {
      return null;
    }
  }

  static int _parseDuration(String durStr) {
    try {
      final parts = durStr.split(':');
      if (parts.length == 2) {
        return (int.tryParse(parts[0]) ?? 0) * 60 +
            (int.tryParse(parts[1]) ?? 0);
      } else if (parts.length == 3) {
        return (int.tryParse(parts[0]) ?? 0) * 3600 +
            (int.tryParse(parts[1]) ?? 0) * 60 +
            (int.tryParse(parts[2]) ?? 0);
      }
    } catch (_) {}
    return 0;
  }
}
