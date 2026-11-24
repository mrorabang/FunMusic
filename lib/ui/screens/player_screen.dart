import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/player_provider.dart';
import '../../services/download_service.dart';
import 'playlist_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _discAnimController;

  @override
  void initState() {
    super.initState();
    _discAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    final player = context.read<PlayerProvider>();
    if (player.isPlaying) {
      _discAnimController.repeat();
    }
  }

  @override
  void dispose() {
    _discAnimController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d, {bool forceHours = false}) {
    if (d.inSeconds <= 0) {
      return forceHours ? '0:00:00' : '00:00';
    }
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (hours > 0 || forceHours) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final downloadService = context.watch<DownloadService>();
    final song = player.currentSong;

    if (player.isPlaying && !_discAnimController.isAnimating) {
      _discAnimController.repeat();
    } else if (!player.isPlaying && _discAnimController.isAnimating) {
      _discAnimController.stop();
    }

    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Không có bài hát đang phát')),
      );
    }

    final isDownloaded = downloadService.isDownloaded(song.id);
    final isDownloading = downloadService.isDownloading(song.id);
    final progress = downloadService.getProgress(song.id);

    final totalSeconds = player.duration.inSeconds.toDouble();
    final currentSeconds = player.position.inSeconds.toDouble().clamp(
          0.0,
          totalSeconds > 0 ? totalSeconds : 0.0,
        );

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenHeight < 350; // PiP Mode
    final double discSize = (screenWidth * 0.70).clamp(180.0, 300.0);

    if (isSmallScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipOval(
                child: song.coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: song.coverUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade900,
                        child: const Icon(Icons.music_note, color: Colors.white),
                      ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(
                  player.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => player.togglePlayPause(),
              ),
            ],
          ),
        ),
      );
    }

    // Biểu tượng chế độ lặp
    IconData loopIcon;
    Color loopColor;
    String loopTooltip;
    switch (player.loopMode) {
      case LoopMode.all:
        loopIcon = Icons.repeat_rounded;
        loopColor = Theme.of(context).colorScheme.primary;
        loopTooltip = 'Lặp toàn bộ danh sách';
        break;
      case LoopMode.single:
        loopIcon = Icons.repeat_one_rounded;
        loopColor = Theme.of(context).colorScheme.primary;
        loopTooltip = 'Lặp lại 1 bài này';
        break;
      case LoopMode.none:
        loopIcon = Icons.repeat_rounded;
        loopColor = Colors.grey;
        loopTooltip = 'Không lặp';
        break;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 36),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Xem trên YouTube (nếu là bài hát từ YouTube)
          if (song.youtubeId != null && song.youtubeId!.isNotEmpty)
            IconButton(
              tooltip: 'Mở xem trên YouTube',
              icon: const Icon(Icons.smart_display_outlined, size: 24),
              onPressed: () async {
                final uri = Uri.parse('https://www.youtube.com/watch?v=${song.youtubeId}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          // Thêm vào Playlist
          IconButton(
            tooltip: 'Thêm bài hát vào Playlist',
            icon: const Icon(Icons.playlist_add_rounded, size: 26),
            onPressed: () => showAddToPlaylistSheet(context, song),
          ),
          // Nút Download
          if (!song.isLocal)
            IconButton(
              tooltip: isDownloading
                  ? 'Đang tải: ${((progress ?? 0) * 100).clamp(0, 100).toInt()}%'
                  : (isDownloaded ? 'Đã tải về máy' : 'Tải bài hát về máy'),
              icon: isDownloading
                  ? SizedBox(
                      width: 32,
                      height: 32,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: (progress != null && progress > 0)
                                ? progress
                                : null,
                            strokeWidth: 2.5,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.2),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          Text(
                            '${((progress ?? 0) * 100).clamp(0, 100).toInt()}%',
                            style: TextStyle(
                              fontSize: (progress != null && progress >= 1.0)
                                  ? 8.0
                                  : 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Icon(
                      isDownloaded
                          ? Icons.download_done_rounded
                          : Icons.download_rounded,
                      color: isDownloaded
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      size: 26,
                    ),
              onPressed: isDownloaded || isDownloading
                  ? null
                  : () async {
                      final success = await downloadService.downloadSong(song);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'Đã tải thành công "${song.title}"'
                                : 'Tải bài hát thất bại'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
            ),
          const SizedBox(width: 8),
        ],
        title: Column(
          children: [
            Text(
              player.activePlaylistName != null
                  ? 'PLAYLIST: ${player.activePlaylistName!.toUpperCase()}'
                  : 'ĐANG PHÁT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.album.isNotEmpty ? song.album : 'Q Music',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(height: 10),
              // Rotating Vinyl Disc
              Center(
                child: RotationTransition(
                  turns: _discAnimController,
                  child: Container(
                    width: discSize,
                    height: discSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.35),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.grey.shade900,
                        width: 10,
                      ),
                    ),
                    child: Center(
                      child: ClipOval(
                        child: song.coverUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: song.coverUrl,
                                width: discSize * 0.65,
                                height: discSize * 0.65,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey.shade800,
                                  child: const Icon(Icons.music_note, size: 50),
                                ),
                                errorWidget: (context, url, err) => Container(
                                  color: Colors.grey.shade800,
                                  child: const Icon(Icons.music_note, size: 50),
                                ),
                              )
                            : Container(
                                color: Colors.grey.shade800,
                                child: const Icon(Icons.music_note, size: 50),
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title & Artist
              Column(
                children: [
                  Text(
                    song.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              // Slider & Times
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: totalSeconds > 0 ? currentSeconds : 0.0,
                      max: totalSeconds > 0 ? totalSeconds : 1.0,
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      onChanged: (val) {
                        player.seek(Duration(seconds: val.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(player.position,
                              forceHours: player.duration.inHours > 0),
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _formatDuration(player.duration),
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: 'Ngẫu nhiên',
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: player.isShuffle
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      size: 26,
                    ),
                    onPressed: () => player.toggleShuffle(),
                  ),
                  IconButton(
                    tooltip: 'Bài trước',
                    icon: const Icon(
                      Icons.skip_previous_rounded,
                      size: 42,
                    ),
                    onPressed: () => player.playPrevious(),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: player.isBuffering
                        ? const SizedBox(
                            width: 44,
                            height: 44,
                            child: Padding(
                              padding: EdgeInsets.all(10.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : IconButton(
                            tooltip: player.isPlaying ? 'Tạm dừng' : 'Phát',
                            icon: Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 44,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            onPressed: () => player.togglePlayPause(),
                          ),
                  ),
                  IconButton(
                    tooltip: 'Bài tiếp theo',
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      size: 42,
                    ),
                    onPressed: () => player.playNext(),
                  ),
                  IconButton(
                    tooltip: loopTooltip,
                    icon: Icon(
                      loopIcon,
                      color: loopColor,
                      size: 26,
                    ),
                    onPressed: () => player.cycleLoopMode(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
