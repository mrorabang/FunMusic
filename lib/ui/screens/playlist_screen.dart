import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/playlist_service.dart';

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playlistService = context.watch<PlaylistService>();
    final player = context.watch<PlayerProvider>();
    final playlists = playlistService.playlists;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Danh sách phát (Playlist)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Tạo Playlist mới',
            icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
            onPressed: () => _showCreatePlaylistDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: playlists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    size: 70,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có Playlist nào',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Tạo Playlist mới'),
                    onPressed: () => _showCreatePlaylistDialog(context),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100, top: 8),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final pl = playlists[index];
                final isCurrentPlaylist =
                    player.activePlaylistName == pl.name;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: isCurrentPlaylist
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    leading: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.queue_music_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      pl.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isCurrentPlaylist
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      '${pl.songs.length} bài hát${isCurrentPlaylist ? ' • Đang chọn phát' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isCurrentPlaylist
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pl.songs.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              isCurrentPlaylist && player.isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              size: 34,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () {
                              if (isCurrentPlaylist) {
                                player.togglePlayPause();
                              } else {
                                // CHỈ PHÁT NHẠC TRONG PLAYLIST NÀY
                                player.playSong(
                                  pl.songs.first,
                                  playlist: pl.songs,
                                  playlistName: pl.name,
                                );
                              }
                            },
                          ),
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'rename') {
                              _showRenameDialog(context, pl);
                            } else if (val == 'delete') {
                              _confirmDeletePlaylist(context, pl);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 20),
                                  SizedBox(width: 8),
                                  Text('Đổi tên'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline,
                                      size: 20, color: Colors.redAccent),
                                  SizedBox(width: 8),
                                  Text('Xóa playlist',
                                      style:
                                          TextStyle(color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo Playlist mới'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập tên Playlist (vd: Nhạc Chill, Gym...)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                PlaylistService.instance.createPlaylist(controller.text.trim());
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Playlist playlist) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tên mới'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                PlaylistService.instance
                    .renamePlaylist(playlist.id, controller.text.trim());
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlaylist(BuildContext context, Playlist playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa Playlist?'),
        content: Text('Bạn có chắc muốn xóa playlist "${playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              PlaylistService.instance.deletePlaylist(playlist.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;
  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final playlistService = context.watch<PlaylistService>();
    final player = context.watch<PlayerProvider>();

    final playlist = playlistService.playlists
        .firstWhere((p) => p.id == playlistId, orElse: () => Playlist(id: '', name: '', createdAt: DateTime.now(), songs: []));

    if (playlist.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Playlist không tồn tại')),
      );
    }

    final isCurrentPlaylist = player.activePlaylistName == playlist.name;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          if (playlist.songs.isNotEmpty)
            IconButton(
              tooltip: 'Phát toàn bộ Playlist này',
              icon: Icon(
                isCurrentPlaylist && player.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () {
                if (isCurrentPlaylist) {
                  player.togglePlayPause();
                } else {
                  player.playSong(
                    playlist.songs.first,
                    playlist: playlist.songs,
                    playlistName: playlist.name,
                  );
                }
              },
            ),
        ],
      ),
      body: playlist.songs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_off_rounded,
                    size: 60,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text('Playlist này chưa có bài hát nào'),
                  const SizedBox(height: 6),
                  Text(
                    'Hãy bấm nút "..." trên bất kỳ bài hát nào để thêm vào đây',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: playlist.songs.length,
              itemBuilder: (context, index) {
                final song = playlist.songs[index];
                final isCurrent = player.currentSong?.id == song.id &&
                    player.activePlaylistName == playlist.name;

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
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                        ),
                        onPressed: () {
                          if (isCurrent) {
                            player.togglePlayPause();
                          } else {
                            player.playSong(
                              song,
                              playlist: playlist.songs,
                              playlistName: playlist.name,
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 20, color: Colors.grey),
                        onPressed: () {
                          PlaylistService.instance
                              .removeSongFromPlaylist(playlist.id, song.id);
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    player.playSong(
                      song,
                      playlist: playlist.songs,
                      playlistName: playlist.name,
                    );
                  },
                );
              },
            ),
    );
  }
}

/// Tiện ích hiển thị bảng chọn Playlist để thêm bài hát
void showAddToPlaylistSheet(BuildContext context, Song song) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final playlistService = ctx.watch<PlaylistService>();
      final playlists = playlistService.playlists;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thêm vào Playlist',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Playlist mới'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showCreateAndAddDialog(context, song);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text('Chưa có playlist nào. Hãy bấm "Playlist mới" để tạo.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (c, idx) {
                      final pl = playlists[idx];
                      final alreadyIn =
                          playlistService.isSongInPlaylist(pl.id, song.id);

                      return ListTile(
                        leading: Icon(
                          Icons.queue_music_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(pl.name),
                        subtitle: Text('${pl.songs.length} bài hát'),
                        trailing: alreadyIn
                            ? const Icon(Icons.check_circle_rounded,
                                color: Colors.green)
                            : const Icon(Icons.add_circle_outline_rounded),
                        onTap: () async {
                          if (!alreadyIn) {
                            await playlistService.addSongToPlaylist(pl.id, song);
                            if (context.mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã thêm vào "${pl.name}"'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

void _showCreateAndAddDialog(BuildContext context, Song song) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Tạo Playlist mới'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Nhập tên Playlist',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (controller.text.trim().isNotEmpty) {
              final pl = await PlaylistService.instance
                  .createPlaylist(controller.text.trim());
              await PlaylistService.instance.addSongToPlaylist(pl.id, song);
              if (context.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã tạo và thêm vào "${pl.name}"'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          },
          child: const Text('Tạo & Thêm'),
        ),
      ],
    ),
  );
}
