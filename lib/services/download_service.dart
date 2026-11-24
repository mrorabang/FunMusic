import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';
import 'soundcloud_service.dart';

class DownloadService with ChangeNotifier {
  static final DownloadService instance = DownloadService._internal();
  DownloadService._internal();

  final List<Song> _downloadedSongs = [];
  final Map<int, double> _downloadProgress = {}; // songId -> 0.0 .. 1.0

  List<Song> get downloadedSongs => _downloadedSongs;
  Map<int, double> get downloadProgress => _downloadProgress;

  static const String _kDownloadedSongsKey = 'k_downloaded_songs_v1';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_kDownloadedSongsKey) ?? [];
      _downloadedSongs.clear();
      for (final jsonStr in jsonList) {
        try {
          final map = json.decode(jsonStr);
          final song = Song.fromJson(map);
          if (song.localFilePath != null &&
              File(song.localFilePath!).existsSync()) {
            _downloadedSongs.add(song);
          }
        } catch (_) {}
      }

      // Quét thêm thư mục downloads để không bỏ sót file đã tải về máy
      final appDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${appDir.path}/downloads');
      if (downloadDir.existsSync()) {
        for (final entity in downloadDir.listSync()) {
          if (entity is File &&
              (entity.path.endsWith('.m4a') || entity.path.endsWith('.mp3')) &&
              entity.lengthSync() > 1000) {
            if (!_downloadedSongs.any((s) => s.localFilePath == entity.path)) {
              final fileName = entity.path.split('/').last.split('.').first;
              final songId =
                  int.tryParse(fileName) ?? entity.path.hashCode.abs();
              _downloadedSongs.add(Song(
                id: songId,
                title: 'Bài hát tải về ($fileName)',
                artist: 'Offline',
                album: 'Nhạc đã tải',
                coverUrl: '',
                streamUrl: '',
                duration: 0,
                isLocal: true,
                localFilePath: entity.path,
              ));
            }
          }
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('DownloadService.init error: $e');
    }
  }

  bool isDownloaded(int songId) {
    return _downloadedSongs.any((s) => s.id == songId);
  }

  bool isDownloading(int songId) {
    return _downloadProgress.containsKey(songId);
  }

  double? getProgress(int songId) {
    return _downloadProgress[songId];
  }

  Future<bool> downloadSong(Song song) async {
    if (isDownloaded(song.id) || isDownloading(song.id)) return true;

    _downloadProgress[song.id] = 0.0;
    notifyListeners();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${appDir.path}/downloads');
      if (!downloadDir.existsSync()) {
        downloadDir.createSync(recursive: true);
      }

      final filePath = '${downloadDir.path}/${song.id}.m4a';
      final file = File(filePath);

      bool success = false;

      // 1. Nếu là bài hát YouTube: Hệ thống tải đa tầng chống 403 Google CDN
      if (song.youtubeId != null && song.youtubeId!.isNotEmpty) {
        // Tầng 1: SoundCloud Smart Match (lossless/AAC HLS siêu tốc, miễn nhiễm 403)
        success = await _downloadYouTubeViaSoundCloud(song, file);

        // Tầng 2: Nếu chưa tìm thấy, tải qua Public Piped / Invidious Streams API (Direct Audio Proxy)
        if (!success) {
          debugPrint('Trying Piped Audio Streams API for: ${song.title}');
          success =
              await _downloadYouTubeViaPiped(song.youtubeId!, file, song.id);
        }

        // Tầng 3: Nếu vẫn chưa được, thử qua YoutubeExplode iOS/Android client
        if (!success) {
          debugPrint('Trying YoutubeExplode direct stream for: ${song.title}');
          success = await _downloadYouTube(song.youtubeId!, file, song.id);
        }
      }
      // 2. Nếu là bài hát SoundCloud HLS
      else if (song.soundcloudTranscodingUrl != null &&
          song.soundcloudTranscodingUrl!.isNotEmpty) {
        success = await _downloadSoundCloudHls(
            song.soundcloudTranscodingUrl!, file, song.id);
      }
      // 3. Nếu có link stream trực tiếp (Deezer, iTunes, direct MP3/M4A)
      else if (song.streamUrl.isNotEmpty) {
        success = await _downloadDirectUrl(song.streamUrl, file, song.id);
      }

      if (success && file.existsSync() && file.lengthSync() > 1000) {
        final localSong = Song(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          coverUrl: song.coverUrl,
          streamUrl: song.streamUrl,
          duration: song.duration,
          isLocal: true,
          localFilePath: filePath,
          youtubeId: song.youtubeId,
        );

        _downloadedSongs.removeWhere((s) => s.id == song.id);
        _downloadedSongs.insert(0, localSong);
        await _saveToStorage();

        _downloadProgress.remove(song.id);
        notifyListeners();
        return true;
      } else {
        if (file.existsSync()) {
          try {
            file.deleteSync();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('DownloadService.downloadSong error: $e');
    }

    _downloadProgress.remove(song.id);
    notifyListeners();
    return false;
  }

  /// Tầng 1: Tải bài hát YouTube qua SoundCloud Smart Match
  Future<bool> _downloadYouTubeViaSoundCloud(Song song, File file) async {
    final queries = buildSearchQueries(song.title, song.artist);
    for (final q in queries) {
      try {
        final scTrans = await SoundCloudService.findTranscodingForSearch(q);
        if (scTrans != null && scTrans.isNotEmpty) {
          debugPrint('SoundCloud Smart Match found for "$q"');
          final ok = await _downloadSoundCloudHls(scTrans, file, song.id);
          if (ok && file.existsSync() && file.lengthSync() > 1000) {
            return true;
          }
        }
      } catch (e) {
        debugPrint('SoundCloud Smart Match error for query "$q": $e');
      }
    }
    return false;
  }

  /// Thuật toán phân tích và làm sạch tiêu đề YouTube thông minh
  static List<String> buildSearchQueries(String rawTitle, String artist) {
    final queries = <String>[];

    // Loại bỏ nội dung trong ngoặc đơn, ngoặc vuông (MV, Official, Audio, Lyrics...)
    String cleaned = rawTitle
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), ' ')
        .replaceAll(
            RegExp(
                r'\b(official\s*(music\s*)?video|official\s*audio|official\s*mv|official\s*visualizer|mv|lyrics?|audio|hd|4k|prod\.?(\s*by)?|visualizer|remix)\b',
                caseSensitive: false),
            ' ');

    // Tách theo các ký tự | - :
    final splitParts = cleaned
        .split(RegExp(r'[\|\-:]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    String coreTitle = cleaned;
    if (splitParts.isNotEmpty) {
      final nonArtistParts = splitParts
          .where((p) =>
              !p.toLowerCase().contains(artist.toLowerCase()) &&
              p.length > 2)
          .toList();
      if (nonArtistParts.isNotEmpty) {
        coreTitle = nonArtistParts.join(' ');
      } else {
        coreTitle = splitParts.first;
      }
    }
    coreTitle = coreTitle.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (coreTitle.isNotEmpty &&
        artist.isNotEmpty &&
        !coreTitle.toLowerCase().contains(artist.toLowerCase())) {
      queries.add('$coreTitle $artist');
    }
    if (coreTitle.isNotEmpty) {
      queries.add(coreTitle);
    }

    // Thêm từng phần riêng biệt trong tiêu đề phân tách bởi | hoặc -
    for (final part in splitParts) {
      final p = part.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (p.length >= 3 && p.length <= 50) {
        queries.add(p);
        if (artist.isNotEmpty && !p.toLowerCase().contains(artist.toLowerCase())) {
          queries.add('$p $artist');
        }
      }
    }

    final simple = rawTitle
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (simple.isNotEmpty) {
      queries.add(simple);
      if (artist.isNotEmpty &&
          !simple.toLowerCase().contains(artist.toLowerCase())) {
        queries.add('$simple $artist');
      }
    }

    return queries.toSet().toList();
  }

  /// Tầng 2: Tải bài hát YouTube qua Piped Audio Proxy API
  Future<bool> _downloadYouTubeViaPiped(
      String videoId, File file, int songId) async {
    final pipedInstances = [
      'https://api.piped.private.coffee',
      'https://pipedapi.kavin.rocks',
      'https://cf.piped.video',
    ];

    for (final instance in pipedInstances) {
      try {
        final uri = Uri.parse('$instance/streams/$videoId');
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = json.decode(utf8.decode(res.bodyBytes));
          final audioStreams = data['audioStreams'] as List?;
          String? directUrl;

          if (audioStreams != null && audioStreams.isNotEmpty) {
            audioStreams.sort((a, b) {
              final bA = a['bitrate'] is int ? a['bitrate'] : 0;
              final bB = b['bitrate'] is int ? b['bitrate'] : 0;
              return (bB as int).compareTo(bA as int);
            });
            directUrl = audioStreams.first['url']?.toString();
          }

          if (directUrl == null || directUrl.isEmpty) {
            final videoStreams = data['videoStreams'] as List?;
            if (videoStreams != null && videoStreams.isNotEmpty) {
              directUrl = videoStreams.first['url']?.toString();
            }
          }

          if (directUrl != null && directUrl.isNotEmpty) {
            debugPrint('Found Piped stream: $directUrl');
            final ok = await _downloadDirectUrl(directUrl, file, songId);
            if (ok && file.existsSync() && file.lengthSync() > 1000) {
              return true;
            }
          }
        }
      } catch (e) {
        debugPrint('Piped instance $instance failed: $e');
      }
    }
    return false;
  }

  /// Tầng 3: Tải bài hát qua YoutubeExplode client
  Future<bool> _downloadYouTube(String videoId, File file, int songId) async {
    final yt = YoutubeExplode();
    IOSink? sink;
    http.Client? client;
    try {
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.ios,
          YoutubeApiClient.androidVr,
          YoutubeApiClient.androidSdkless,
        ],
      );
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) return false;

      final mp4Streams = audioStreams
          .where((s) => s.container.name.toLowerCase() == 'mp4')
          .toList();
      final streamInfo = mp4Streams.isNotEmpty
          ? mp4Streams.withHighestBitrate()
          : audioStreams.withHighestBitrate();

      final totalBytes = streamInfo.size.totalBytes;
      int receivedBytes = 0;

      sink = file.openWrite();
      client = http.Client();
      final req = http.Request('GET', streamInfo.url);
      req.headers['User-Agent'] =
          'com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; vi_VN)';
      req.headers['Range'] = 'bytes=0-';

      final res = await client.send(req).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 && res.statusCode != 206) {
        return false;
      }

      await for (final chunk in res.stream.timeout(const Duration(seconds: 20))) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _downloadProgress[songId] =
              (receivedBytes / totalBytes).clamp(0.0, 1.0);
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;
      client.close();
      client = null;
      return true;
    } catch (e) {
      debugPrint('DownloadService._downloadYouTube error: $e');
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client?.close();
      return false;
    } finally {
      yt.close();
    }
  }

  /// Tải nhạc đa luồng HLS SoundCloud (6 workers, cực nhanh)
  Future<bool> _downloadSoundCloudHls(
      String transcodingUrl, File file, int songId) async {
    IOSink? sink;
    http.Client? client;
    try {
      final clientId = await SoundCloudService.getClientId();
      final streamRes = await http
          .get(Uri.parse('$transcodingUrl?client_id=$clientId'))
          .timeout(const Duration(seconds: 8));
      if (streamRes.statusCode != 200) return false;

      final playlistUrl = jsonDecode(streamRes.body)['url'] as String?;
      if (playlistUrl == null || playlistUrl.isEmpty) return false;

      final m3u8Res = await http
          .get(Uri.parse(playlistUrl))
          .timeout(const Duration(seconds: 8));
      if (m3u8Res.statusCode != 200) return false;

      final lines = m3u8Res.body.split('\n');
      final segmentUrls = <String>[];
      String? initUrl;

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;
        if (line.startsWith('#EXT-X-MAP:URI="')) {
          initUrl = line.substring(16, line.length - 1);
        } else if (!line.startsWith('#')) {
          final segUrl = line.startsWith('http')
              ? line
              : Uri.parse(playlistUrl).resolve(line).toString();
          segmentUrls.add(segUrl);
        }
      }

      if (segmentUrls.isEmpty) return false;

      final totalSegments = segmentUrls.length + (initUrl != null ? 1 : 0);
      int completedSegments = 0;
      final results = List<List<int>?>.filled(segmentUrls.length, null);

      client = http.Client();
      const concurrency = 6;
      int nextIndex = 0;

      Future<void> worker() async {
        while (true) {
          final idx = nextIndex++;
          if (idx >= segmentUrls.length) break;
          try {
            final res = await client!
                .get(Uri.parse(segmentUrls[idx]))
                .timeout(const Duration(seconds: 15));
            if (res.statusCode == 200) {
              results[idx] = res.bodyBytes;
            }
          } catch (_) {}
          completedSegments++;
          _downloadProgress[songId] =
              (completedSegments / totalSegments).clamp(0.0, 1.0);
          notifyListeners();
        }
      }

      Future<List<int>?> initFuture = initUrl != null
          ? client.get(Uri.parse(initUrl)).then((r) {
              completedSegments++;
              _downloadProgress[songId] =
                  (completedSegments / totalSegments).clamp(0.0, 1.0);
              notifyListeners();
              return r.statusCode == 200 ? r.bodyBytes : null;
            }).catchError((_) => null)
          : Future.value(null);

      await Future.wait([
        initFuture,
        ...List.generate(concurrency, (_) => worker()),
      ]);

      final initBytes = await initFuture;
      sink = file.openWrite();
      if (initBytes != null) sink.add(initBytes);
      for (final seg in results) {
        if (seg != null) sink.add(seg);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      client.close();
      client = null;
      return true;
    } catch (e) {
      debugPrint('DownloadService._downloadSoundCloudHls error: $e');
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client?.close();
      return false;
    }
  }

  /// Tải file từ direct URL (MP3/M4A)
  Future<bool> _downloadDirectUrl(String url, File file, int songId) async {
    IOSink? sink;
    http.Client? client;
    try {
      client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      final response =
          await client.send(request).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 && response.statusCode != 206) {
        return false;
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      sink = file.openWrite();

      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 20))) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _downloadProgress[songId] =
              (receivedBytes / totalBytes).clamp(0.0, 1.0);
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;
      client.close();
      client = null;
      return true;
    } catch (e) {
      debugPrint('DownloadService._downloadDirectUrl error: $e');
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client?.close();
      return false;
    }
  }

  Future<void> deleteSong(int songId) async {
    try {
      final index = _downloadedSongs.indexWhere((s) => s.id == songId);
      if (index != -1) {
        final song = _downloadedSongs[index];
        if (song.localFilePath != null) {
          final file = File(song.localFilePath!);
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
        _downloadedSongs.removeAt(index);
        await _saveToStorage();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('DownloadService.deleteSong error: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList =
          _downloadedSongs.map((s) => json.encode(s.toJson())).toList();
      await prefs.setStringList(_kDownloadedSongsKey, jsonList);
    } catch (e) {
      debugPrint('DownloadService._saveToStorage error: $e');
    }
  }
}
