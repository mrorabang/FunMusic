import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../services/local_music_service.dart';
import 'downloads_screen.dart';
import 'playlist_screen.dart';

class LocalMusicScreen extends StatelessWidget {
  const LocalMusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localMusic = context.watch<LocalMusicService>();
    final player = context.watch<PlayerProvider>();
    final imported = localMusic.importedSongs;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text(
            'Thư viện nhạc thiết bị',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.folder_open_rounded), text: 'Nhạc trong máy'),
              Tab(icon: Icon(Icons.download_done_rounded), text: 'Nhạc đã tải'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Nhạc import từ thiết bị
            Scaffold(
              backgroundColor: Colors.transparent,
              floatingActionButton: FloatingActionButton.extended(
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Nhập file nhạc'),
                onPressed: () async {
                  final count = await localMusic.pickAndImportAudioFiles();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(count > 0
                            ? 'Đã nhập thành công $count bài hát từ máy'
                            : 'Không có file nhạc nào được chọn'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              body: imported.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.audio_file_outlined,
                            size: 70,
                            color:
                                Theme.of(context).colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Chưa có file nhạc nào từ máy',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32.0),
                            child: Text(
                              'Bấm "Nhập file nhạc" bên dưới để chọn các file mp3, m4a, flac, wav có sẵn trong điện thoại.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90, top: 8),
                      itemCount: imported.length,
                      itemBuilder: (context, index) {
                        final song = imported[index];
                        final isCurrent = player.currentSong?.id == song.id;

                        return ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.music_note_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            song.localFilePath?.split('/').last ?? 'File nội bộ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
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
                                  size: 30,
                                ),
                                onPressed: () {
                                  if (isCurrent) {
                                    player.togglePlayPause();
                                  } else {
                                    player.playSong(
                                      song,
                                      playlist: imported,
                                      playlistName: 'Nhạc trong máy',
                                    );
                                  }
                                },
                              ),
                              PopupMenuButton<String>(
                                onSelected: (val) {
                                  if (val == 'playlist') {
                                    showAddToPlaylistSheet(context, song);
                                  } else if (val == 'delete') {
                                    localMusic.removeImportedSong(song.id);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'playlist',
                                    child: Row(
                                      children: [
                                        Icon(Icons.playlist_add_rounded, size: 20),
                                        SizedBox(width: 8),
                                        Text('Thêm vào Playlist'),
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
                                        Text('Xóa khỏi app',
                                            style: TextStyle(
                                                color: Colors.redAccent)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            player.playSong(
                              song,
                              playlist: imported,
                              playlistName: 'Nhạc trong máy',
                            );
                          },
                        );
                      },
                    ),
            ),
            // Tab 2: Nhạc đã tải về máy
            const DownloadsScreen(),
          ],
        ),
      ),
    );
  }
}
