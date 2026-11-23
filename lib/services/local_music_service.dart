import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

class LocalMusicService with ChangeNotifier {
  static final LocalMusicService instance = LocalMusicService._internal();
  LocalMusicService._internal();

  final List<Song> _importedSongs = [];
  List<Song> get importedSongs => _importedSongs;

  static const String _kImportedSongsKey = 'k_imported_local_songs_v1';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_kImportedSongsKey) ?? [];
      _importedSongs.clear();
      for (final jsonStr in jsonList) {
        try {
          final map = json.decode(jsonStr);
          final song = Song.fromJson(map);
          if (song.localFilePath != null && File(song.localFilePath!).existsSync()) {
            _importedSongs.add(song);
          }
        } catch (_) {}
      }
      notifyListeners();
    } catch (e) {
      debugPrint('LocalMusicService.init error: $e');
    }
  }

  /// Chọn file âm thanh từ máy và nhập vào ứng dụng
  Future<int> pickAndImportAudioFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'flac', 'aac', 'ogg'],
      );

      if (files.isNotEmpty) {
        int addedCount = 0;
        for (final platformFile in files) {
          if (platformFile.path == null) continue;

          final file = File(platformFile.path!);
          if (!file.existsSync()) continue;

          // Tạo ID duy nhất từ đường dẫn file
          final int songId = platformFile.path.hashCode.abs();

          // Kiểm tra xem đã import chưa
          if (_importedSongs.any((s) => s.id == songId || s.localFilePath == platformFile.path)) {
            continue;
          }

          // Lấy tên bài hát từ tên file
          String title = platformFile.name;
          final dotIndex = title.lastIndexOf('.');
          if (dotIndex != -1) {
            title = title.substring(0, dotIndex);
          }

          final song = Song(
            id: songId,
            title: title,
            artist: 'Bộ nhớ thiết bị',
            album: 'Nhạc trong máy',
            coverUrl: '', // Sử dụng icon mặc định
            streamUrl: '',
            duration: 0,
            isLocal: true,
            localFilePath: platformFile.path,
          );

          _importedSongs.insert(0, song);
          addedCount++;
        }

        if (addedCount > 0) {
          await _saveToStorage();
          notifyListeners();
        }
        return addedCount;
      }
    } catch (e) {
      debugPrint('LocalMusicService.pickAndImportAudioFiles error: $e');
    }
    return 0;
  }

  Future<void> removeImportedSong(int id) async {
    _importedSongs.removeWhere((s) => s.id == id);
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _importedSongs.map((s) => json.encode(s.toJson())).toList();
      await prefs.setStringList(_kImportedSongsKey, jsonList);
    } catch (e) {
      debugPrint('LocalMusicService._saveToStorage error: $e');
    }
  }
}
