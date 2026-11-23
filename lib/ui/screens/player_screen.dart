import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';

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

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
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

    final totalSeconds = player.duration.inSeconds.toDouble();
    final currentSeconds = player.position.inSeconds.toDouble().clamp(
          0.0,
          totalSeconds > 0 ? totalSeconds : 0.0,
        );

    final double screenWidth = MediaQuery.of(context).size.width;
    final double discSize = (screenWidth * 0.72).clamp(220.0, 320.0);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 36),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              'ĐANG PHÁT',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.album.isNotEmpty ? song.album : 'Deezer Music',
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
                        child: CachedNetworkImage(
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
                          _formatDuration(player.position),
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
                    child: IconButton(
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
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      size: 42,
                    ),
                    onPressed: () => player.playNext(),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.repeat_rounded,
                      color: player.isLoop
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      size: 26,
                    ),
                    onPressed: () => player.toggleLoop(),
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
