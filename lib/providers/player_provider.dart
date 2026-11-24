import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song.dart';
import '../services/download_service.dart';
import '../services/music_api_service.dart';
import '../services/notification_service.dart';
import '../services/pip_service.dart';
import '../services/soundcloud_service.dart';

enum LoopMode {
  all('Lặp toàn bộ danh sách'),
  single('Lặp 1 bài'),
  none('Không lặp');

  final String label;
  const LoopMode(this.label);
}

class PlayerProvider with ChangeNotifier {
  final ja.AudioPlayer _player = ja.AudioPlayer();

  List<Song> _playlist = [];
  int _currentIndex = -1;
  String? _activePlaylistName;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isBuffering = false;

  LoopMode _loopMode = LoopMode.all;
  bool _isShuffle = false;

  PlayerProvider() {
    _initAudioListeners();
  }

  // Getters
  bool get isYoutubeActive => false;

  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  String? get activePlaylistName => _activePlaylistName;
  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _playlist.length)
          ? _playlist[_currentIndex]
          : null;

  bool get isPlaying =>
      _player.playing &&
      _player.processingState != ja.ProcessingState.completed;

  bool get isPaused =>
      !_player.playing &&
      _player.processingState != ja.ProcessingState.idle;

  bool get isBuffering {
    if (_isBuffering) return true;
    return _player.processingState == ja.ProcessingState.buffering ||
        _player.processingState == ja.ProcessingState.loading;
  }

  Duration get position => _position;
  Duration get duration => _duration;
  LoopMode get loopMode => _loopMode;
  bool get isShuffle => _isShuffle;

  void _initAudioListeners() {
    // Lắng nghe sự kiện tháo tai nghe / ngắt kết nối AirPods để tự động tạm dừng (chuẩn iOS)
    AudioSession.instance.then((session) {
      session.becomingNoisyEventStream.listen((_) {
        if (isPlaying) {
          pause();
        }
      });
    });

    _player.playerStateStream.listen((state) {
      final playing = state.playing &&
          state.processingState != ja.ProcessingState.completed;
      PipService.setPlayingState(playing);
      if (currentSong != null) {
        NotificationService.showMediaNotification(
          song: currentSong!,
          isPlaying: playing,
        );
      }
      if (state.processingState == ja.ProcessingState.completed) {
        _handleSongCompletion();
      }
      notifyListeners();
    });

    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  Future<void> _handleSongCompletion() async {
    if (_playlist.isEmpty) return;

    if (_loopMode == LoopMode.single) {
      await seek(Duration.zero);
      await _player.play();
      return;
    }

    await playNext(autoTriggered: true);
  }

  Future<void> playSong(
    Song song, {
    List<Song>? playlist,
    String? playlistName,
  }) async {
    if (playlist != null && playlist.isNotEmpty) {
      _playlist = List.from(playlist);
      _activePlaylistName = playlistName;
      _currentIndex = _playlist.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) {
        _playlist.insert(0, song);
        _currentIndex = 0;
      }
    } else {
      if (!_playlist.any((s) => s.id == song.id)) {
        _playlist.add(song);
      }
      _currentIndex = _playlist.indexWhere((s) => s.id == song.id);
    }

    notifyListeners();
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final song = currentSong;
    if (song == null) return;

    try {
      _position = Duration.zero;
      _duration = song.duration > 0
          ? Duration(seconds: song.duration)
          : Duration.zero;

      final mediaItem = MediaItem(
        id: song.id.toString(),
        album: song.album.isNotEmpty ? song.album : 'Q Music',
        title: song.title,
        artist: song.artist.isNotEmpty ? song.artist : 'Nghệ sĩ',
        artUri: song.coverUrl.isNotEmpty ? Uri.tryParse(song.coverUrl) : null,
        duration: song.duration > 0 ? Duration(seconds: song.duration) : null,
      );

      // 1. Ưu tiên cao nhất: Bài hát offline đã tải về máy (hoạt động 100% không cần mạng)
      if (song.isLocal &&
          song.localFilePath != null &&
          File(song.localFilePath!).existsSync()) {
        final source = ja.AudioSource.file(
          song.localFilePath!,
          tag: mediaItem,
        );
        await _player.setAudioSource(source);
        await _player.play();
      }
      // 2. Bài hát trực tuyến (YouTube Music, SoundCloud, Deezer, iTunes, Custom API)
      else {
        String playUrl = song.streamUrl;
        if (playUrl.isEmpty) {
          _isBuffering = true;
          notifyListeners();

          final resolved = await MusicApiService.resolveStreamUrl(song);
          if (resolved != null && resolved.isNotEmpty) {
            playUrl = resolved;
            if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
              _playlist[_currentIndex] = song.copyWith(streamUrl: resolved);
            }
          }
          _isBuffering = false;
          notifyListeners();
        }

        bool playedSuccessfully = false;
        final headers = {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
          'Accept-Encoding': 'identity',
        };

        if (playUrl.isNotEmpty) {
          try {
            debugPrint(
                'Loading Native Background Audio (Lockscreen/AirPods active): $playUrl');
            final source = ja.AudioSource.uri(
              Uri.parse(playUrl),
              tag: mediaItem,
              headers: headers,
            );
            await _player.setAudioSource(source);
            await _player.play();
            playedSuccessfully = true;
          } catch (e) {
            debugPrint('Primary stream playback error ($e). Attempting auto smart fallback...');
          }
        }

        // Tự động kích hoạt Smart Fallback nếu stream chính bị chặn 403 Forbidden hoặc lỗi tải
        if (!playedSuccessfully) {
          _isBuffering = true;
          notifyListeners();
          final fallbackUrl = await _resolveFallbackStream(song);
          _isBuffering = false;
          notifyListeners();

          if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
            debugPrint('Playing audio via Smart Fallback: $fallbackUrl');
            final fbSource = ja.AudioSource.uri(
              Uri.parse(fallbackUrl),
              tag: mediaItem,
              headers: headers,
            );
            await _player.setAudioSource(fbSource);
            await _player.play();
            playedSuccessfully = true;
          } else {
            debugPrint(
                'Cannot play song: both primary and fallback streams failed for ${song.title}');
          }
        }
      }

      await NotificationService.showMediaNotification(
        song: currentSong ?? song,
        isPlaying: true,
      );
      await PipService.setPlayingState(true);
    } catch (e) {
      _isBuffering = false;
      notifyListeners();
      debugPrint('PlayerProvider._playCurrent error: $e');
    }
  }

  Future<String?> _resolveFallbackStream(Song song) async {
    try {
      final queries = DownloadService.buildSearchQueries(song.title, song.artist);
      for (final q in queries) {
        final scSongs = await SoundCloudService.searchSongs(q, limit: 3);
        if (scSongs.isNotEmpty) {
          for (final sc in scSongs) {
            if (sc.soundcloudTranscodingUrl != null &&
                sc.soundcloudTranscodingUrl!.isNotEmpty) {
              final stream = await SoundCloudService.resolveStreamUrl(
                  sc.soundcloudTranscodingUrl!);
              if (stream != null && stream.isNotEmpty) {
                return stream;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('_resolveFallbackStream error: $e');
    }
    return null;
  }

  Future<void> togglePlayPause() async {
    if (currentSong == null) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ja.ProcessingState.completed) {
        await seek(Duration.zero);
      }
      await _player.play();
    }
  }

  Future<void> playNext({bool autoTriggered = false}) async {
    if (_playlist.isEmpty) return;

    if (_isShuffle) {
      if (_playlist.length > 1) {
        int nextIndex = _currentIndex;
        while (nextIndex == _currentIndex) {
          nextIndex = Random().nextInt(_playlist.length);
        }
        _currentIndex = nextIndex;
      }
    } else {
      if (_currentIndex < _playlist.length - 1) {
        _currentIndex++;
      } else {
        if (_loopMode == LoopMode.all) {
          _currentIndex = 0;
        } else if (autoTriggered && _loopMode == LoopMode.none) {
          await _player.stop();
          _position = Duration.zero;
          notifyListeners();
          return;
        } else {
          _currentIndex = 0;
        }
      }
    }

    notifyListeners();
    await _playCurrent();
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (_isShuffle) {
      _currentIndex = Random().nextInt(_playlist.length);
    } else {
      _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    }

    notifyListeners();
    await _playCurrent();
  }

  Future<Duration> seek(Duration newPosition) async {
    await _player.seek(newPosition);
    return newPosition;
  }

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  void cycleLoopMode() {
    switch (_loopMode) {
      case LoopMode.all:
        _loopMode = LoopMode.single;
        _player.setLoopMode(ja.LoopMode.one);
        break;
      case LoopMode.single:
        _loopMode = LoopMode.none;
        _player.setLoopMode(ja.LoopMode.off);
        break;
      case LoopMode.none:
        _loopMode = LoopMode.all;
        _player.setLoopMode(ja.LoopMode.all);
        break;
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _player.setShuffleModeEnabled(_isShuffle);
    notifyListeners();
  }

  @override
  void dispose() {
    NotificationService.cancel();
    _player.dispose();
    super.dispose();
  }
}
