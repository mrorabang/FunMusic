import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/download_service.dart';
import '../../services/music_api_service.dart';
import '../widgets/mini_player.dart';
import 'local_music_screen.dart';
import 'playlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

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
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final allSources = MusicApiService.getAllSources();
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.tune_rounded,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Quản lý nguồn API nhạc',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Chạm để chuyển đổi nguồn nghe ngay\n• Bấm ⭐ để đặt làm API mặc định mỗi khi vào app',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // Danh sách APIs
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: allSources.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final source = allSources[index];
                          final isSelected =
                              MusicApiService.currentSourceId == source.id;
                          final isDefault =
                              MusicApiService.defaultSourceId == source.id;

                          return Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.12)
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              leading: Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      source.name,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (isDefault)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.amber.withValues(alpha: 0.5),
                                            width: 0.8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.star_rounded,
                                              size: 13, color: Colors.amber),
                                          SizedBox(width: 2),
                                          Text(
                                            'Mặc định',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.amber,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (source.isCustom)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.teal.withValues(alpha: 0.5),
                                            width: 0.8),
                                      ),
                                      child: const Text(
                                        'Custom',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.tealAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  source.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Nút đặt làm mặc định
                                  IconButton(
                                    tooltip: isDefault
                                        ? 'Đang là API mặc định khi mở app'
                                        : 'Đặt làm API mặc định mỗi khi vào app',
                                    icon: Icon(
                                      isDefault
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: isDefault
                                          ? Colors.amber
                                          : Colors.grey,
                                      size: 24,
                                    ),
                                    onPressed: () async {
                                      await MusicApiService.setDefaultSource(
                                          source.id);
                                      setModalState(() {});
                                      setState(() {});
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Đã đặt "${source.name}" làm API mặc định khi mở app!'),
                                            duration:
                                                const Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  // Nút xóa nếu là Custom API
                                  if (source.isCustom)
                                    IconButton(
                                      tooltip: 'Xóa API tùy chỉnh này',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 22,
                                      ),
                                      onPressed: () async {
                                        final confirm =
                                            await _showDeleteConfirmDialog(
                                                ctx, source);
                                        if (confirm == true) {
                                          await MusicApiService
                                              .deleteCustomSource(source.id);
                                          setModalState(() {});
                                          setState(() {});
                                          _loadData(_searchController
                                                  .text.isNotEmpty
                                              ? _searchController.text
                                              : _currentFilter);
                                        }
                                      },
                                    ),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  MusicApiService.selectSource(source.id);
                                });
                                Navigator.of(ctx).pop();
                                _loadData(_searchController.text.isNotEmpty
                                    ? _searchController.text
                                    : _currentFilter);
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    // Nút thêm API mới
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Thêm API mới (Custom API)'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          _showAddCustomApiDialog(context, onAdded: () {
                            setModalState(() {});
                            setState(() {});
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmDialog(
      BuildContext context, ApiSourceItem source) {
    return showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Xóa API tùy chỉnh'),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa nguồn API "${source.name}" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomApiDialog(BuildContext context,
      {required VoidCallback onAdded}) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.add_link_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Thêm API mới', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notice Format
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Colors.amber, size: 18),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Quy chuẩn định dạng API (Format Notice)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• Phương thức: HTTP GET\n'
                        '• URL Endpoint mẫu:\n'
                        '  https://api.domain.com/search?q={query}&limit={limit}\n'
                        '  (hoặc tự động gắn ?q=...&limit=...)\n'
                        '• Định dạng JSON phản hồi:\n'
                        '  Mảng [ { ... } ] hoặc đối tượng có key "results", "data", "tracks".\n'
                        '• Mỗi bài hát cần hỗ trợ:\n'
                        '  - id: Mã bài hát (số hoặc chuỗi)\n'
                        '  - title: Tên bài hát (bắt buộc)\n'
                        '  - artist: Tên nghệ sĩ/ca sĩ\n'
                        '  - stream_url: Link stream nhạc (.mp3, .m4a, aac...)\n'
                        '  - cover: Link ảnh bìa album/bài hát (tùy chọn)\n'
                        '  - duration: Thời lượng (giây hoặc mm:ss / hh:mm:ss)',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tên hiển thị API *',
                    hintText: 'VD: Server Nhạc Cá Nhân',
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                    labelText: 'URL Search Endpoint *',
                    hintText: 'https://api.example.com/search',
                    prefixIcon: const Icon(Icons.link_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('Đóng'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Lưu API'),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final url = urlCtrl.text.trim();
                if (name.isEmpty || url.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập đầy đủ Tên và URL API!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                if (!url.startsWith('http://') &&
                    !url.startsWith('https://')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'URL API phải bắt đầu bằng http:// hoặc https://'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                await MusicApiService.addCustomSource(name, url);
                onAdded();
                if (dCtx.mounted) {
                  Navigator.of(dCtx).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã thêm API "$name" thành công!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _currentTabIndex,
                  children: [
                    // Tab 0: Khám phá trực tuyến
                    _buildExploreTab(context),
                    // Tab 1: Quản lý Playlist
                    const PlaylistScreen(),
                    // Tab 2: Thư viện máy & Tải về
                    const LocalMusicScreen(),
                  ],
                ),
              ),
              // Mini Player luôn ghim phía trên thanh điều hướng
              const MiniPlayer(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentTabIndex,
            onDestinationSelected: (idx) {
              setState(() {
                _currentTabIndex = idx;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Khám phá',
              ),
              NavigationDestination(
                icon: Icon(Icons.queue_music_outlined),
                selectedIcon: Icon(Icons.queue_music_rounded),
                label: 'Playlist',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder_rounded),
                label: 'Thiết bị & Tải về',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExploreTab(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final downloadService = context.watch<DownloadService>();

    return Scaffold(
      backgroundColor: Colors.transparent,
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
              'Q Music (${MusicApiService.currentSourceName})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Chọn nguồn API nhạc',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showApiSourceDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
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
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
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
                        onRefresh: () => _loadData(
                            _searchController.text.isNotEmpty
                                ? _searchController.text
                                : _currentFilter),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _songs.length +
                              (_featuredSongs.isNotEmpty ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_featuredSongs.isNotEmpty && index == 0) {
                              return _buildFeaturedCarousel(
                                  _featuredSongs, player);
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
                                        placeholder: (context, url) =>
                                            Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.grey.shade800,
                                          child: const Icon(Icons.music_note),
                                        ),
                                        errorWidget: (context, url, err) =>
                                            Container(
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
                                    tooltip:
                                        isDownloaded ? 'Đã tải' : 'Tải về máy',
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
                                        player.playSong(
                                          song,
                                          playlist: _songs,
                                          playlistName: 'Khám phá: $_currentFilter',
                                        );
                                      }
                                    },
                                  ),
                                  // Menu Thêm vào Playlist
                                  IconButton(
                                    icon: const Icon(Icons.more_vert_rounded,
                                        size: 20),
                                    onPressed: () =>
                                        showAddToPlaylistSheet(context, song),
                                  ),
                                ],
                              ),
                              onTap: () {
                                player.playSong(
                                  song,
                                  playlist: _songs,
                                  playlistName: 'Khám phá: $_currentFilter',
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
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
                onTap: () => player.playSong(
                  song,
                  playlist: _songs,
                  playlistName: 'Khám phá: $_currentFilter',
                ),
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
