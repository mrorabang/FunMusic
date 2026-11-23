import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/notification_service.dart';
import '../services/pip_service.dart';

class PlayerProvider with ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  List<Song> _playlist = [];
  int _currentIndex = -1;

  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _isLoop = true;
  bool _isShuffle = false;

  PlayerProvider() {
    _initAudioSession();
    _initAudioListeners();
  }

  // Getters
  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _playlist.length)
          ? _playlist[_currentIndex]
          : null;
  bool get isPlaying => _state == PlayerState.playing;
  bool get isPaused => _state == PlayerState.paused;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isLoop => _isLoop;
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

    _player.onPlayerComplete.listen((_) {
      playNext();
    });
  }

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    if (playlist != null && playlist.isNotEmpty) {
      _playlist = List.from(playlist);
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

    try {
      await _player.stop();
      _position = Duration.zero;
      _duration = Duration.zero;

      if (song.isLocal && song.localFilePath != null) {
        await _player.play(DeviceFileSource(song.localFilePath!));
      } else {
        await _player.play(UrlSource(song.streamUrl));
      }

      await NotificationService.showMediaNotification(
        song: song,
        isPlaying: true,
      );
      await PipService.setPlayingState(true);
    } catch (e) {
      debugPrint('PlayerProvider.playSong error: $e');
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
        if (currentSong!.isLocal && currentSong!.localFilePath != null) {
          await _player.play(DeviceFileSource(currentSong!.localFilePath!));
        } else {
          await _player.play(UrlSource(currentSong!.streamUrl));
        }
      }
    }
  }

  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    if (_isShuffle) {
      _currentIndex = Random().nextInt(_playlist.length);
    } else {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    }

    final nextSong = _playlist[_currentIndex];
    await playSong(nextSong);
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

    final prevSong = _playlist[_currentIndex];
    await playSong(prevSong);
  }

  Future<void> seek(Duration newPosition) async {
    await _player.seek(newPosition);
  }

  void toggleLoop() {
    _isLoop = !_isLoop;
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
