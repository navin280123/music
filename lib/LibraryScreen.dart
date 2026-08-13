import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/AppTheme.dart';
import 'package:music/ArtworkHelper.dart';
import 'package:music/PlaylistManager.dart';
import 'package:music/TagEditorSheet.dart';

class LibraryScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final AudioPlayer audioPlayer;
  final Function(int) playTrack;
  final Function(String) playFilePath;

  const LibraryScreen({
    super.key,
    required this.audioFiles,
    required this.audioPlayer,
    required this.playTrack,
    required this.playFilePath,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E20) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Create New Playlist", style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "e.g. Chill Vibes, Workout, Roadtrip",
              filled: true,
              fillColor: isDark ? const Color(0xFF28282A) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final created = await PlaylistManager.instance.createPlaylist(name);
                  if (context.mounted) {
                    Navigator.pop(context);
                    if (!created) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("A playlist with this name already exists")),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Create"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final scaffoldBg = isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold;
    final activeCol = isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary;
    final subTextCol = AppTheme.textSecondaryColor(context);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.headerBg(context),
            border: Border(bottom: BorderSide(color: AppTheme.border(context))),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: activeCol,
            labelColor: activeCol,
            unselectedLabelColor: subTextCol,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            tabs: const [
              Tab(icon: Icon(Icons.favorite_rounded, size: 18), text: "Favorites"),
              Tab(icon: Icon(Icons.queue_music_rounded, size: 18), text: "Playlists"),
              Tab(icon: Icon(Icons.folder_rounded, size: 18), text: "Folders"),
              Tab(icon: Icon(Icons.insights_rounded, size: 18), text: "Insights"),
            ],
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: PlaylistManager.instance,
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildFavoritesTab(context),
              _buildPlaylistsTab(context),
              _buildFoldersTab(context),
              _buildInsightsTab(context),
            ],
          );
        },
      ),
    );
  }

  // --- FAVORITES TAB ---
  Widget _buildFavoritesTab(BuildContext context) {
    final favPaths = PlaylistManager.instance.favoritePaths.toList();
    final validFavs = widget.audioFiles
        .where((f) => favPaths.contains(f.path))
        .toList();

    if (validFavs.isEmpty) {
      return _buildEmptyTab(
        context,
        icon: Icons.favorite_border_rounded,
        title: "No Liked Songs Yet",
        desc: "Tap the heart icon ❤️ on any song to save it to your Favorites.",
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: validFavs.length,
      itemBuilder: (context, index) {
        final file = validFavs[index];
        final fileName = file.path.split(Platform.pathSeparator).last;
        return _buildSongTile(context, file.path, fileName);
      },
    );
  }

  // --- PLAYLISTS TAB ---
  Widget _buildPlaylistsTab(BuildContext context) {
    final playlistNames = PlaylistManager.instance.getPlaylistNames();
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final textCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);
    final activeCol = isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Create Playlist Button Card
          GestureDetector(
            onTap: _showCreatePlaylistDialog,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: activeCol.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: activeCol.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: activeCol, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    "Create New Playlist",
                    style: TextStyle(
                      color: activeCol,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (playlistNames.isEmpty)
            _buildEmptyTab(
              context,
              icon: Icons.playlist_add_rounded,
              title: "No Custom Playlists",
              desc: "Create custom playlists for workouts, study sessions, or moods.",
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: playlistNames.length,
              itemBuilder: (context, index) {
                final name = playlistNames[index];
                final songs = PlaylistManager.instance.getSongsInPlaylist(name);

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: activeCol.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.queue_music_rounded, color: activeCol, size: 22),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        color: textCol,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      "${songs.length} ${songs.length == 1 ? 'track' : 'tracks'}",
                      style: TextStyle(color: subTextCol, fontSize: 12),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: subTextCol),
                      onSelected: (val) {
                        if (val == 'delete') {
                          PlaylistManager.instance.deletePlaylist(name);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text("Delete Playlist", style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    children: [
                      if (songs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            "No songs in this playlist yet. Add songs from the Home tab.",
                            style: TextStyle(color: subTextCol, fontSize: 12),
                          ),
                        )
                      else
                        ...songs.map((songPath) {
                          final songName = songPath.split(Platform.pathSeparator).last;
                          return ListTile(
                            leading: ArtworkHelper.buildArtworkWidget(
                              songPath,
                              width: 36,
                              height: 36,
                              borderRadius: 6,
                            ),
                            title: Text(
                              songName,
                              style: TextStyle(color: textCol, fontSize: 13.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                              color: Colors.redAccent.withValues(alpha: 0.7),
                              onPressed: () {
                                PlaylistManager.instance.removeSongFromPlaylist(name, songPath);
                              },
                            ),
                            onTap: () => widget.playFilePath(songPath),
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- FOLDERS TAB ---
  Widget _buildFoldersTab(BuildContext context) {
    final paths = widget.audioFiles.map((f) => f.path as String).toList();
    final folderMap = PlaylistManager.groupSongsByFolder(paths);
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final textCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);
    final activeCol = isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary;

    if (folderMap.isEmpty) {
      return _buildEmptyTab(
        context,
        icon: Icons.folder_off_rounded,
        title: "No Folders Detected",
        desc: "No audio files were found across storage directories.",
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: folderMap.keys.length,
      itemBuilder: (context, index) {
        final folderName = folderMap.keys.elementAt(index);
        final songs = folderMap[folderName]!;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.folder_rounded, color: Color(0xFFF59E0B), size: 22),
            ),
            title: Text(
              folderName,
              style: TextStyle(
                color: textCol,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              "${songs.length} audio ${songs.length == 1 ? 'file' : 'files'}",
              style: TextStyle(color: subTextCol, fontSize: 12),
            ),
            children: songs.map((songPath) {
              final songName = songPath.split(Platform.pathSeparator).last;
              return ListTile(
                leading: ArtworkHelper.buildArtworkWidget(
                  songPath,
                  width: 36,
                  height: 36,
                  borderRadius: 6,
                ),
                title: Text(
                  songName,
                  style: TextStyle(color: textCol, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(Icons.play_arrow_rounded, color: activeCol),
                onTap: () => widget.playFilePath(songPath),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // --- INSIGHTS / POCKETO WRAPPED TAB ---
  Widget _buildInsightsTab(BuildContext context) {
    final manager = PlaylistManager.instance;
    final topSongs = manager.getTopPlayedSongs(limit: 5);
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final textCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);
    final activeCol = isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary;

    final totalMins = manager.totalListeningMinutes;
    final totalHrs = totalMins ~/ 60;
    final remMins = totalMins % 60;
    final activeHour = manager.mostActiveHour;
    final hourly = manager.hourlyActivity;
    final maxHourly =
        hourly.values.isEmpty ? 1 : hourly.values.reduce((a, b) => a > b ? a : b);

    String hourLabel(int h) {
      final period = h < 12 ? 'AM' : 'PM';
      final display = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$display$period';
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Wrapped Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                    : [const Color(0xFF6366F1), const Color(0xFF4338CA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: activeCol.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.headphones_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    const Text('Pocketo Wrapped',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('ALL TIME',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _wrappedStat(
                      label: 'Listening Time',
                      value: totalHrs > 0
                          ? '${totalHrs}h ${remMins}m'
                          : '${remMins}m',
                      icon: Icons.access_time_rounded,
                    ),
                    const SizedBox(width: 24),
                    _wrappedStat(
                      label: 'Total Tracks',
                      value: '${widget.audioFiles.length}',
                      icon: Icons.library_music_rounded,
                    ),
                    const SizedBox(width: 24),
                    _wrappedStat(
                      label: 'Total Plays',
                      value: '${manager.totalPlaysCount}',
                      icon: Icons.play_arrow_rounded,
                    ),
                  ],
                ),
                if (activeHour != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Peak listening hour: ${hourLabel(activeHour)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Hourly Activity Chart
          if (hourly.isNotEmpty) ...[
            Text(
              'Listening Activity by Hour',
              style: TextStyle(
                  color: textCol, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 80,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(24, (h) {
                        final count = hourly[h] ?? 0;
                        final frac =
                            maxHourly > 0 ? count / maxHourly : 0.0;
                        final isActive = h == activeHour;
                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 600),
                                  curve: Curves.easeOut,
                                  height: (frac * 64).clamp(3.0, 64.0),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? activeCol
                                        : activeCol.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('12AM',
                          style: TextStyle(color: subTextCol, fontSize: 10)),
                      Text('6AM',
                          style: TextStyle(color: subTextCol, fontSize: 10)),
                      Text('12PM',
                          style: TextStyle(color: subTextCol, fontSize: 10)),
                      Text('6PM',
                          style: TextStyle(color: subTextCol, fontSize: 10)),
                      Text('11PM',
                          style: TextStyle(color: subTextCol, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _statCard(
                  context,
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFF43F5E),
                  label: 'Liked Songs',
                  value: '${manager.favoritePaths.length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  context,
                  icon: Icons.queue_music_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  label: 'Playlists',
                  value: '${manager.getPlaylistNames().length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Top Played Header
          Text(
            'Most Played Tracks',
            style: TextStyle(
                color: textCol, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          if (topSongs.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Center(
                child: Text(
                  'Play your songs to build your listening stats!',
                  style: TextStyle(color: subTextCol, fontSize: 13),
                ),
              ),
            )
          else
            ...topSongs.asMap().entries.map((mapEntry) {
              final rank = mapEntry.key;
              final entry = mapEntry.value;
              final songName =
                  entry.key.split(Platform.pathSeparator).last;
              final maxPlays =
                  topSongs.first.value > 0 ? topSongs.first.value : 1;
              final fraction = entry.value / maxPlays;
              final rankColors = [
                const Color(0xFFFFD700),
                const Color(0xFFE2E8F0),
                const Color(0xFFCD7F32),
                activeCol,
                activeCol,
              ];

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Stack(
                        children: [
                          ArtworkHelper.buildArtworkWidget(
                            entry.key,
                            width: 44,
                            height: 44,
                            borderRadius: 8,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: rank < 3
                                    ? rankColors[rank]
                                    : activeCol,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: cardBg, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  '${rank + 1}',
                                  style: TextStyle(
                                    color: rank == 0
                                        ? Colors.black
                                        : Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        songName,
                        style: TextStyle(
                            color: textCol,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${entry.value} ${entry.value == 1 ? 'play' : 'plays'}',
                        style: TextStyle(
                            color: activeCol,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                      trailing: Icon(Icons.play_circle_fill_rounded,
                          color: activeCol, size: 28),
                      onTap: () => widget.playFilePath(entry.key),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          backgroundColor:
                              activeCol.withValues(alpha: 0.12),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(activeCol),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _wrappedStat(
      {required String label,
      required String value,
      required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final textCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  color: textCol, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: subTextCol, fontSize: 12)),
        ],
      ),
    );
  }


  Widget _buildSongTile(BuildContext context, String filePath, String fileName) {
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final textCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);
    final isFav = PlaylistManager.instance.isFavorite(filePath);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          leading: ArtworkHelper.buildArtworkWidget(
            filePath,
            width: 44,
            height: 44,
            borderRadius: 8,
          ),
          title: Text(
            fileName,
            style: TextStyle(color: textCol, fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text("Audio Track", style: TextStyle(color: subTextCol, fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFav ? const Color(0xFFF43F5E) : subTextCol,
                  size: 22,
                ),
                onPressed: () => PlaylistManager.instance.toggleFavorite(filePath),
              ),
              IconButton(
                icon: Icon(Icons.edit_note_rounded, color: subTextCol, size: 22),
                onPressed: () => TagEditorSheet.show(context, filePath),
              ),
            ],
          ),
          onTap: () => widget.playFilePath(filePath),
        ),
      ),
    );
  }

  Widget _buildEmptyTab(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final subTextCol = AppTheme.textSecondaryColor(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 54, color: subTextCol),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: subTextCol, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
