import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/download_service.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final downloadService = context.watch<DownloadService>();
    final player = context.watch<PlayerProvider>();
    final downloaded = downloadService.downloadedSongs;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Nhạc đã tải về máy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: downloaded.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download_done_rounded,
                    size: 70,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có bài hát nào được tải về',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bấm biểu tượng tải xuống ở bất kỳ bài hát nào để nghe offline',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: downloaded.length,
              itemBuilder: (context, index) {
                final song = downloaded[index];
                final isCurrent = player.currentSong?.id == song.id;

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: song.coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: song.coverUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade800,
                              child: const Icon(Icons.music_note),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade800,
                              child: const Icon(Icons.music_note),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey.shade800,
                            child: const Icon(Icons.music_note),
                          ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    '${song.artist} • Đã lưu offline',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isCurrent && player.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_outline_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        onPressed: () {
                          if (isCurrent) {
                            player.togglePlayPause();
                          } else {
                            player.playSong(song, playlist: downloaded);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 22, color: Colors.redAccent),
                        onPressed: () {
                          _confirmDelete(context, song, downloadService);
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    player.playSong(song, playlist: downloaded);
                  },
                );
              },
            ),
    );
  }

  void _confirmDelete(
      BuildContext context, Song song, DownloadService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bài hát đã tải?'),
        content: Text('Bạn có chắc muốn xóa bài hát "${song.title}" khỏi bộ nhớ máy?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              service.deleteSong(song.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
