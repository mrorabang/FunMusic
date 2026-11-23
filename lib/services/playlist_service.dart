import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import '../models/song.dart';

class PlaylistService with ChangeNotifier {
  static final PlaylistService instance = PlaylistService._internal();
  PlaylistService._internal();

  final List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  static const String _kPlaylistsKey = 'k_user_playlists_v1';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_kPlaylistsKey) ?? [];
      _playlists.clear();
      for (final jsonStr in jsonList) {
        try {
          final map = json.decode(jsonStr);
          _playlists.add(Playlist.fromJson(map));
        } catch (_) {}
      }

      // Tạo playlist mẫu nếu chưa có
      if (_playlists.isEmpty) {
        _playlists.add(Playlist(
          id: 'favorites',
          name: 'Bài hát yêu thích ❤️',
          createdAt: DateTime.now(),
          songs: [],
        ));
        await _saveToStorage();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('PlaylistService.init error: $e');
    }
  }

  Future<Playlist> createPlaylist(String name) async {
    final newPlaylist = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Playlist mới' : name.trim(),
      createdAt: DateTime.now(),
      songs: [],
    );
    _playlists.add(newPlaylist);
    await _saveToStorage();
    notifyListeners();
    return newPlaylist;
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> renamePlaylist(String id, String newName) async {
    final index = _playlists.indexWhere((p) => p.id == id);
    if (index != -1 && newName.trim().isNotEmpty) {
      _playlists[index].name = newName.trim();
      await _saveToStorage();
      notifyListeners();
    }
  }

  Future<bool> addSongToPlaylist(String playlistId, Song song) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      if (!playlist.songs.any((s) => s.id == song.id)) {
        playlist.songs.add(song);
        await _saveToStorage();
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  Future<void> removeSongFromPlaylist(String playlistId, int songId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index].songs.removeWhere((s) => s.id == songId);
      await _saveToStorage();
      notifyListeners();
    }
  }

  bool isSongInPlaylist(String playlistId, int songId) {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      return _playlists[index].songs.any((s) => s.id == songId);
    }
    return false;
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _playlists.map((p) => json.encode(p.toJson())).toList();
      await prefs.setStringList(_kPlaylistsKey, jsonList);
    } catch (e) {
      debugPrint('PlaylistService._saveToStorage error: $e');
    }
  }
}
