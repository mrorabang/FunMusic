import 'package:flutter/services.dart';

class PipService {
  static const MethodChannel _channel =
      MethodChannel('com.obnil.flutter_music_app/pip');

  /// Kích hoạt chế độ PiP (Picture-in-Picture)
  static Future<bool> enterPip() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('enterPip');
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Cập nhật trạng thái đang phát để tự động vào PiP khi vuốt về Home
  static Future<void> setPlayingState(bool isPlaying) async {
    try {
      await _channel.invokeMethod('setPlayingState', {'isPlaying': isPlaying});
    } catch (_) {}
  }

  /// Kiểm tra thiết bị có hỗ trợ PiP không
  static Future<bool> isPipSupported() async {
    try {
      final bool? supported =
          await _channel.invokeMethod<bool>('isPipSupported');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }
}
