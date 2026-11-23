import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LocalAudioStreamServer {
  static final LocalAudioStreamServer instance =
      LocalAudioStreamServer._internal();
  LocalAudioStreamServer._internal();

  HttpServer? _server;
  int _port = 0;
  final Map<String, String> _targetMap = {};

  Future<void> init() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('LocalAudioStreamServer error: $e');
      });
      debugPrint('LocalAudioStreamServer running on http://127.0.0.1:$_port');
    } catch (e) {
      debugPrint('LocalAudioStreamServer.init failed: $e');
    }
  }

  /// Trả về URL proxy cục bộ để vượt rào cản 403 Forbidden của Google CDN
  String getProxyUrl(String videoId, String rawStreamUrl) {
    _targetMap[videoId] = rawStreamUrl;
    if (_port == 0) {
      // Nếu server chưa sẵn sàng, trả về URL gốc
      return rawStreamUrl;
    }
    return 'http://127.0.0.1:$_port/stream/$videoId';
  }

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      final segments = req.uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'stream') {
        final videoId = segments[1];
        final rawUrl = _targetMap[videoId];
        if (rawUrl == null) {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
          return;
        }

        final client = http.Client();
        final targetReq = http.Request('GET', Uri.parse(rawUrl));

        // Google CDN bắt buộc có Range header, nếu không sẽ trả 403
        final rangeHeader = req.headers.value('range');
        if (rangeHeader != null && rangeHeader.isNotEmpty) {
          targetReq.headers['Range'] = rangeHeader;
        } else {
          targetReq.headers['Range'] = 'bytes=0-';
        }

        targetReq.headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

        final targetRes = await client.send(targetReq);
        req.response.statusCode = targetRes.statusCode;

        // Chuyển tiếp các header quan trọng của media stream
        final allowedHeaders = [
          'content-length',
          'content-type',
          'content-range',
          'accept-ranges',
        ];

        targetRes.headers.forEach((key, value) {
          if (allowedHeaders.contains(key.toLowerCase())) {
            req.response.headers.set(key, value);
          }
        });
        req.response.headers.set('Access-Control-Allow-Origin', '*');

        await targetRes.stream.pipe(req.response);
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    } catch (e) {
      debugPrint('LocalAudioStreamServer request error: $e');
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }
}
