import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
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
  final ja.AudioPlayer _player = ja.AudioPlayer();
  late final YoutubePlayerController _ytController;

  List<Song> _playlist = [];
  int _currentIndex = -1;
  String? _activePlaylistName;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isBuffering = false;

  PlayerState _ytPlayerState = PlayerState.unknown;
  bool _isYoutubeActive = false;

  StreamSubscription? _ytStateSub;
  StreamSubscription? _ytVideoSub;

  LoopMode _loopMode = LoopMode.all;
  bool _isShuffle = false;

  PlayerProvider() {
    _initAudioListeners();
    _initYoutubeController();
  }

  // Getters
  YoutubePlayerController get ytController => _ytController;
  bool get isYoutubeActive => _isYoutubeActive;

  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  String? get activePlaylistName => _activePlaylistName;
  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _playlist.length)
          ? _playlist[_currentIndex]
          : null;

  bool get isPlaying {
    if (_isYoutubeActive) {
      return _ytPlayerState == PlayerState.playing;
    }
    return _player.playing &&
        _player.processingState != ja.ProcessingState.completed;
  }

  bool get isPaused {
    if (_isYoutubeActive) {
      return _ytPlayerState == PlayerState.paused;
    }
    return !_player.playing &&
        _player.processingState != ja.ProcessingState.idle;
  }

  bool get isBuffering {
    if (_isBuffering) return true;
    if (_isYoutubeActive) {
      return _ytPlayerState == PlayerState.buffering;
    }
    return _player.processingState == ja.ProcessingState.buffering ||
        _player.processingState == ja.ProcessingState.loading;
  }

  Duration get position => _position;
  Duration get duration => _duration;
  LoopMode get loopMode => _loopMode;
  bool get isShuffle => _isShuffle;

  void _initAudioListeners() {
    _player.playerStateStream.listen((state) {
      if (_isYoutubeActive) return;

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
      if (_isYoutubeActive) return;
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      if (_isYoutubeActive) return;
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  void _initYoutubeController() {
    _ytController = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        playsInline: true,
        mute: false,
        enableCaption: false,
        showVideoAnnotations: false,
        privacyEnhancedMode: false,
        strictRelatedVideos: true,
        origin: 'https://www.youtube-nocookie.com',
        videoStateUpdateInterval: 250,
      ),
    );

    _ytStateSub = _ytController.stream.listen((val) {
      if (!_isYoutubeActive) return;

      _ytPlayerState = val.playerState;
      final playing = val.playerState == PlayerState.playing;
      PipService.setPlayingState(playing);
      if (currentSong != null) {
        NotificationService.showMediaNotification(
          song: currentSong!,
          isPlaying: playing,
        );
      }
      if (val.playerState == PlayerState.ended) {
        _handleSongCompletion();
      }
      if (val.metaData.duration.inSeconds > 0) {
        _duration = val.metaData.duration;
      }
      notifyListeners();
    });

    _ytVideoSub = _ytController.videoStateStream.listen((vState) {
      if (!_isYoutubeActive) return;
      _position = vState.position;
      notifyListeners();
    });
  }

  Future<void> _handleSongCompletion() async {
    if (_playlist.isEmpty) return;

    if (_loopMode == LoopMode.single) {
      await seek(Duration.zero);
      if (_isYoutubeActive) {
        await _ytController.playVideo();
      } else {
        await _player.play();
      }
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

      if (song.youtubeId != null && song.youtubeId!.isNotEmpty) {
        _isYoutubeActive = true;
        await _player.stop();
        _isBuffering = true;
        notifyListeners();

        debugPrint('Playing YouTube video via IFrame: ${song.youtubeId}');
        await _ytController.loadVideoById(videoId: song.youtubeId!);
        await Future.delayed(const Duration(milliseconds: 300));
        await _ytController.playVideo();
        _isBuffering = false;
        notifyListeners();
      } else {
        _isYoutubeActive = false;
        try {
          await _ytController.pauseVideo();
        } catch (_) {}

        await _player.stop();

        if (song.isLocal && song.localFilePath != null) {
          await _player.setFilePath(song.localFilePath!);
          await _player.play();
        } else {
          String playUrl = song.streamUrl;
          if (playUrl.isEmpty && (song.soundcloudTranscodingUrl != null)) {
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
            debugPrint('Loading ExoPlayer with URL: $playUrl');
            await _player
                .setUrl(
              playUrl,
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept-Encoding': 'identity',
              },
            )
                .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint('Audio loading timed out for ${song.title}');
                throw TimeoutException('Không thể kết nối luồng phát âm thanh');
              },
            );
            await _player.play();
          } else {
            debugPrint('Cannot play song: streamUrl is empty for ${song.title}');
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

  Future<void> togglePlayPause() async {
    if (currentSong == null) return;
    if (_isYoutubeActive) {
      if (_ytPlayerState == PlayerState.playing) {
        await _ytController.pauseVideo();
      } else {
        await _ytController.playVideo();
      }
    } else {
      if (_player.playing) {
        await _player.pause();
      } else {
        if (_player.processingState == ja.ProcessingState.completed) {
          await seek(Duration.zero);
        }
        await _player.play();
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
        if (_loopMode == LoopMode.all) {
          _currentIndex = 0;
        } else if (autoTriggered && _loopMode == LoopMode.none) {
          if (_isYoutubeActive) {
            await _ytController.stopVideo();
          } else {
            await _player.stop();
          }
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
    if (_isYoutubeActive) {
      await _ytController.seekTo(
        seconds: newPosition.inSeconds.toDouble(),
        allowSeekAhead: true,
      );
      _position = newPosition;
      notifyListeners();
    } else {
      await _player.seek(newPosition);
    }
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
    _ytStateSub?.cancel();
    _ytVideoSub?.cancel();
    _ytController.close();
    NotificationService.cancel();
    _player.dispose();
    super.dispose();
  }
}
