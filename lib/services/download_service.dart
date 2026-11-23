import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

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
          if (song.localFilePath != null && File(song.localFilePath!).existsSync()) {
            _downloadedSongs.add(song);
          }
        } catch (_) {}
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
    if (song.streamUrl.isEmpty) return false;

    _downloadProgress[song.id] = 0.0;
    notifyListeners();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${appDir.path}/downloads');
      if (!downloadDir.existsSync()) {
        downloadDir.createSync(recursive: true);
      }

      final ext = song.streamUrl.contains('.m4a') ? 'm4a' : 'mp3';
      final filePath = '${downloadDir.path}/${song.id}.$ext';
      final file = File(filePath);

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(song.streamUrl));
      final response = await client.send(request);

      if (response.statusCode == 200) {
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;
        final sink = file.openWrite();

        await response.stream.listen((chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            _downloadProgress[song.id] = (receivedBytes / totalBytes).clamp(0.0, 1.0);
            notifyListeners();
          }
        }).asFuture();

        await sink.flush();
        await sink.close();

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
        );

        _downloadedSongs.insert(0, localSong);
        await _saveToStorage();

        _downloadProgress.remove(song.id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('DownloadService.downloadSong error: $e');
    }

    _downloadProgress.remove(song.id);
    notifyListeners();
    return false;
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
      final jsonList = _downloadedSongs.map((s) => json.encode(s.toJson())).toList();
      await prefs.setStringList(_kDownloadedSongsKey, jsonList);
    } catch (e) {
      debugPrint('DownloadService._saveToStorage error: $e');
    }
  }
}
