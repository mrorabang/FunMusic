import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/deezer_service.dart';
import '../widgets/mini_player.dart';

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
      songs = await DeezerService.getTopChart(limit: 30);
    } else {
      songs = await DeezerService.searchSongs(query, limit: 30);
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

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

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
            const Text(
              'Deezer Music',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
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
                hintText: 'Tìm bài hát, ca sĩ (Sơn Tùng, Adele...)...',
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

                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
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
                              trailing: IconButton(
                                icon: Icon(
                                  isCurrentPlaying && player.isPlaying
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_outline_rounded,
                                  color: isCurrentPlaying
                                      ? Theme.of(context).colorScheme.primary
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
