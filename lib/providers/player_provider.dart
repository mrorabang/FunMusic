import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/music_api_service.dart';
import '../services/notification_service.dart';
import '../services/pip_service.dart';

enum LoopMode {
  all('Lặp toàn bộ danh sách'),
  single('Lặp 1 bài'),
  none('Không lặp');

  final String label;
  const LoopMode(this.label);
}

class PlayerProvider with ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  List<Song> _playlist = [];
  int _currentIndex = -1;
  String? _activePlaylistName;

  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isBuffering = false;

  LoopMode _loopMode = LoopMode.all;
  bool _isShuffle = false;

  PlayerProvider() {
    _initAudioSession();
    _initAudioListeners();
  }

  // Getters
  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  String? get activePlaylistName => _activePlaylistName;
  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _playlist.length)
          ? _playlist[_currentIndex]
          : null;
  bool get isPlaying => _state == PlayerState.playing;
  bool get isPaused => _state == PlayerState.paused;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  LoopMode get loopMode => _loopMode;
  bool get isShuffle => _isShuffle;

  Future<void> _initAudioSession() async {
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.defaultToSpeaker,
          },
        ),
      ));
    } catch (e) {
      debugPrint('AudioContext error: $e');
    }
  }

  void _initAudioListeners() {
    _player.onPlayerStateChanged.listen((state) {
      _state = state;
      PipService.setPlayingState(state == PlayerState.playing);
      if (currentSong != null) {
        NotificationService.showMediaNotification(
          song: currentSong!,
          isPlaying: state == PlayerState.playing,
        );
      }
      notifyListeners();
    });

    _player.onPositionChanged.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.onDurationChanged.listen((dur) {
      _duration = dur;
      notifyListeners();
    });

    // Tự động chuyển bài tiếp theo khi hết bài
    _player.onPlayerComplete.listen((_) {
      _handleSongCompletion();
    });
  }

  Future<void> _handleSongCompletion() async {
    if (_playlist.isEmpty) return;

    if (_loopMode == LoopMode.single) {
      // Lặp lại bài đang phát
      await seek(Duration.zero);
      if (currentSong != null) {
        await _playCurrent();
      }
      return;
    }

    // Tự động chuyển bài kế tiếp
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
      await _player.stop();
      _position = Duration.zero;
      _duration = Duration.zero;

      if (song.isLocal && song.localFilePath != null) {
        await _player.play(DeviceFileSource(song.localFilePath!));
      } else {
        String playUrl = song.streamUrl;
        if (playUrl.isEmpty && song.youtubeId != null) {
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

        if (playUrl.isNotEmpty) {
          await _player.play(UrlSource(playUrl)).timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              debugPrint('Audio playback timed out for ${song.title}');
              throw TimeoutException('Không thể kết nối luồng phát âm thanh');
            },
          );
        } else {
          debugPrint('Cannot play song: streamUrl is empty for ${song.title}');
        }
      }

      await NotificationService.showMediaNotification(
        song: currentSong ?? song,
        isPlaying: true,
      );
      await PipService.setPlayingState(true);
    } catch (e) {
      _isBuffering = false;
      _state = PlayerState.stopped;
      notifyListeners();
      debugPrint('PlayerProvider._playCurrent error: $e');
    }
  }

  Future<void> togglePlayPause() async {
    if (currentSong == null) return;
    if (isPlaying) {
      await _player.pause();
    } else {
      if (_state == PlayerState.paused) {
        await _player.resume();
      } else {
        await _playCurrent();
      }
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
        // Hết danh sách playlist
        if (_loopMode == LoopMode.all) {
          _currentIndex = 0; // Quay về bài đầu tiên của playlist
        } else if (autoTriggered && _loopMode == LoopMode.none) {
          // Không lặp và đã hết bài: dừng phát
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

  Future<void> seek(Duration newPosition) async {
    await _player.seek(newPosition);
  }

  void cycleLoopMode() {
    switch (_loopMode) {
      case LoopMode.all:
        _loopMode = LoopMode.single;
        break;
      case LoopMode.single:
        _loopMode = LoopMode.none;
        break;
      case LoopMode.none:
        _loopMode = LoopMode.all;
        break;
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  @override
  void dispose() {
    NotificationService.cancel();
    _player.dispose();
    super.dispose();
  }
}
