import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'services/download_service.dart';
import 'services/local_audio_stream_server.dart';
import 'services/local_music_service.dart';
import 'services/music_api_service.dart';
import 'services/notification_service.dart';
import 'services/playlist_service.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Khởi tạo dịch vụ âm thanh nền chuyên nghiệp (hỗ trợ Lockscreen, Control Center, AirPods)
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.obnil.flutter_music_app.audio',
    androidNotificationChannelName: 'Q Music Playback',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'mipmap/ic_launcher',
  );

  // Cấu hình AVAudioSession chuyên nghiệp cho iOS (phát nền khi khóa màn hình, điều khiển AirPods)
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e) {
    debugPrint('AudioSession init error: $e');
  }

  // Khởi tạo tất cả các dịch vụ nền
  await NotificationService.init();
  await LocalAudioStreamServer.instance.init();
  await DownloadService.instance.init();
  await PlaylistService.instance.init();
  await LocalMusicService.instance.init();
  await MusicApiService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider.value(value: DownloadService.instance),
        ChangeNotifierProvider.value(value: PlaylistService.instance),
        ChangeNotifierProvider.value(value: LocalMusicService.instance),
      ],
      child: const MusicApp(),
    ),
  );
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Q Music',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B5CF6),
          brightness: Brightness.dark,
          surface: const Color(0xFF12121A),
          surfaceContainerHighest: const Color(0xFF1E1E2C),
          primary: const Color(0xFFA78BFA),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F16),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
