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

      // 1. Nếu là bài hát YouTube: Thử tải qua YouTube, nếu YouTube CDN chặn/treo thì tự động fallback tải bản nhạc từ SoundCloud
      if (song.youtubeId != null && song.youtubeId!.isNotEmpty) {
        try {
          success = await _downloadYouTube(song.youtubeId!, file, song.id)
              .timeout(const Duration(seconds: 8), onTimeout: () => false);
        } catch (_) {
          success = false;
        }

        if (!success) {
          debugPrint(
              'YouTube stream download unviable, falling back to SoundCloud for ${song.title}');
          final cleanQuery = '${song.title} ${song.artist}'
              .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
              .trim();
          final scTrans =
              await SoundCloudService.findTranscodingForSearch(cleanQuery);
          if (scTrans != null) {
            success = await _downloadSoundCloudHls(scTrans, file, song.id);
          }
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

  Future<bool> _downloadYouTube(String videoId, File file, int songId) async {
    final yt = YoutubeExplode();
    IOSink? sink;
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) return false;

      final streamInfo = audioStreams.withHighestBitrate();
      final totalBytes = streamInfo.size.totalBytes;
      int receivedBytes = 0;

      sink = file.openWrite();
      final stream = yt.videos.streamsClient
          .get(streamInfo)
          .timeout(const Duration(seconds: 8));

      await for (final chunk in stream) {
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
      return true;
    } catch (e) {
      debugPrint('DownloadService._downloadYouTube error: $e');
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      return false;
    } finally {
      yt.close();
    }
  }

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

  Future<bool> _downloadDirectUrl(String url, File file, int songId) async {
    IOSink? sink;
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) return false;

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      sink = file.openWrite();

      await response.stream.listen((chunk) {
        sink?.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _downloadProgress[songId] =
              (receivedBytes / totalBytes).clamp(0.0, 1.0);
          notifyListeners();
        }
      }).asFuture();

      await sink.flush();
      await sink.close();
      sink = null;
      return true;
    } catch (e) {
      debugPrint('DownloadService._downloadDirectUrl error: $e');
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
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
