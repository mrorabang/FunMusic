import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/download_service.dart';
import '../../services/music_api_service.dart';
import '../../services/pip_service.dart';
import '../widgets/mini_player.dart';
import 'downloads_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Song> _songs = [];
  List<Song> _featuredSongs = [];
  bool _isLoading = true;
  String _currentFilter = 'Top Hits';

  final List<String> _filters = [
    'Top Hits',
    'V-Pop',
    'US-UK',
    'Acoustic',
    'Chill',
    'Rock',
    'EDM',
  ];

  @override
  void initState() {
    super.initState();
    _loadData(_currentFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData(String query) async {
    setState(() {
      _isLoading = true;
    });

    List<Song> songs;
    if (query == 'Top Hits') {
      songs = await MusicApiService.getTopChart(limit: 30);
    } else {
      songs = await MusicApiService.searchSongs(query, limit: 30);
    }

    if (mounted) {
      setState(() {
        _songs = songs;
        _featuredSongs = songs.take(6).toList();
        _isLoading = false;
      });
    }
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isNotEmpty) {
      _loadData(query.trim());
    }
  }

  void _showApiSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    const Text(
                      'Chọn nguồn API nhạc',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...MusicApiSource.values.map((source) {
                  final isSelected = MusicApiService.currentSource == source;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    title: Text(
                      source.displayName,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      source == MusicApiSource.deezer
                          ? 'Server chính thức Deezer (mp3 preview 30s, ảnh HD)'
                          : 'Server Apple iTunes (m4a chất lượng cao, không giới hạn)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      setState(() {
                        MusicApiService.currentSource = source;
                      });
                      Navigator.of(ctx).pop();
                      _loadData(_searchController.text.isNotEmpty
                          ? _searchController.text
                          : _currentFilter);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final downloadService = context.watch<DownloadService>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.tertiary,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              MusicApiService.currentSource == MusicApiSource.deezer
                  ? 'Fun Music (Deezer)'
                  : 'Fun Music (iTunes)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Nút PiP
          IconButton(
            tooltip: 'Thu nhỏ PiP ra màn hình chính',
            icon: const Icon(Icons.picture_in_picture_alt_rounded),
            onPressed: () => PipService.enterPip(),
          ),
          // Nút Đổi API
          IconButton(
            tooltip: 'Chọn nguồn API nhạc',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showApiSourceDialog,
          ),
          // Nút Đến Trang Đã Tải Về
          IconButton(
            tooltip: 'Nhạc đã tải về máy',
            icon: Badge(
              isLabelVisible: downloadService.downloadedSongs.isNotEmpty,
              label: Text('${downloadService.downloadedSongs.length}'),
              child: const Icon(Icons.download_done_rounded),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmitted,
              decoration: InputDecoration(
                hintText: 'Tìm bài hát, ca sĩ...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _loadData(_currentFilter);
                        },
                      )
                    : null,
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (text) => setState(() {}),
            ),
          ),

          // Genre / Topic Filter Chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (context, i) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _currentFilter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _currentFilter = filter;
                        _searchController.clear();
                      });
                      _loadData(filter);
                    }
                  },
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _songs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.music_off_rounded,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text(
                              'Không tìm thấy bài hát nào',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _loadData('Top Hits'),
                              child: const Text('Tải lại BXH'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadData(_searchController.text.isNotEmpty
                            ? _searchController.text
                            : _currentFilter),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _songs.length + (_featuredSongs.isNotEmpty ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_featuredSongs.isNotEmpty && index == 0) {
                              return _buildFeaturedCarousel(_featuredSongs, player);
                            }

                            final songIndex =
                                _featuredSongs.isNotEmpty ? index - 1 : index;
                            final song = _songs[songIndex];
                            final isCurrentPlaying =
                                player.currentSong?.id == song.id;
                            final isDownloaded =
                                downloadService.isDownloaded(song.id);
                            final isDownloading =
                                downloadService.isDownloading(song.id);
                            final downloadProgress =
                                downloadService.getProgress(song.id);

                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: song.coverUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: song.coverUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.grey.shade800,
                                          child: const Icon(Icons.music_note),
                                        ),
                                        errorWidget: (context, url, err) => Container(
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
                                  fontWeight: isCurrentPlaying
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isCurrentPlaying
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
                                  // Nút Download
                                  IconButton(
                                    tooltip: isDownloaded
                                        ? 'Đã tải'
                                        : 'Tải về máy',
                                    icon: isDownloading
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              value: downloadProgress,
                                              strokeWidth: 2,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          )
                                        : Icon(
                                            isDownloaded
                                                ? Icons.download_done_rounded
                                                : Icons.download_rounded,
                                            size: 22,
                                            color: isDownloaded
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Colors.grey,
                                          ),
                                    onPressed: isDownloaded || isDownloading
                                        ? null
                                        : () async {
                                            final ok = await downloadService
                                                .downloadSong(song);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(ok
                                                      ? 'Đã tải xong: ${song.title}'
                                                      : 'Tải bài hát thất bại'),
                                                  duration: const Duration(
                                                      seconds: 2),
                                                ),
                                              );
                                            }
                                          },
                                  ),
                                  // Nút Play / Pause
                                  IconButton(
                                    icon: Icon(
                                      isCurrentPlaying && player.isPlaying
                                          ? Icons.pause_circle_filled_rounded
                                          : Icons.play_circle_outline_rounded,
                                      color: isCurrentPlaying
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Colors.grey,
                                      size: 32,
                                    ),
                                    onPressed: () {
                                      if (isCurrentPlaying) {
                                        player.togglePlayPause();
                                      } else {
                                        player.playSong(song, playlist: _songs);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                player.playSong(song, playlist: _songs);
                              },
                            );
                          },
                        ),
                      ),
          ),

          // Persistent Mini Player
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildFeaturedCarousel(List<Song> featured, PlayerProvider player) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Nổi bật & Đề xuất',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: featured.length,
            separatorBuilder: (context, i) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final song = featured[index];
              final isCurrent = player.currentSong?.id == song.id;

              return GestureDetector(
                onTap: () => player.playSong(song, playlist: _songs),
                child: SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CachedNetworkImage(
                              imageUrl: song.coverUrl,
                              width: 130,
                              height: 130,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 130,
                                height: 130,
                                color: Colors.grey.shade800,
                                child: const Icon(Icons.music_note, size: 40),
                              ),
                              errorWidget: (context, url, err) => Container(
                                width: 130,
                                height: 130,
                                color: Colors.grey.shade800,
                                child: const Icon(Icons.music_note, size: 40),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCurrent && player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Danh sách bài hát',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
