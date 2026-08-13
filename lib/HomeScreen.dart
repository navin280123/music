import 'package:flutter/material.dart';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:music/ABLooperWidget.dart';
import 'package:music/AppTheme.dart';
import 'package:music/ArtworkHelper.dart';
import 'package:music/LyricsViewerSheet.dart';
import 'package:music/PlaylistManager.dart';
import 'package:music/TagEditorSheet.dart';

class HomeScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final AudioPlayer audioPlayer;
  final int? currentlyPlayingIndex;
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final Function() onPlay;
  final Function() onPause;
  final Function() onNext;
  final Function() onPrevious;
  final Function(int) playTrack;
  final Function(int) onTabTapped;
  final VoidCallback? onRescan;

  const HomeScreen({
    super.key,
    required this.audioFiles,
    required this.audioPlayer,
    required this.currentlyPlayingIndex,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.onPlay,
    required this.onPause,
    required this.onNext,
    required this.onPrevious,
    required this.playTrack,
    required this.onTabTapped,
    this.onRescan,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFilter = 'All';

  void _showAddToPlaylistDialog(String filePath) {
    final playlistNames = PlaylistManager.instance.getPlaylistNames();
    final isDark = AppTheme.isDark(context);

    if (playlistNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("No playlists yet. Create one in the Library tab!"),
          action: SnackBarAction(
            label: "Go to Library",
            onPressed: () => widget.onTabTapped(2),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E20) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add to Playlist",
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...playlistNames.map((name) {
                return ListTile(
                  leading: const Icon(Icons.playlist_add_rounded),
                  title: Text(name),
                  onTap: () {
                    PlaylistManager.instance.addSongToPlaylist(name, filePath);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Added to $name"),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final scaffoldBg = isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold;
    final activeCol = isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary;
    final cardBg = isDark ? const Color(0xFF242426) : const Color(0xFFF1F5F9);
    final textCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);

    if (widget.audioFiles.isEmpty) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Icon(
                    Icons.music_off_rounded,
                    size: 48,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "No Music Found",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "We couldn't find any audio files on your device. Make sure audio files are stored in Music, Downloads, or Internal Storage.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                if (widget.onRescan != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: widget.onRescan,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text("Scan For Music"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? const Color(0xFF2C2C2E) : AppTheme.lightPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: PlaylistManager.instance,
      builder: (context, _) {
        List filteredList = widget.audioFiles;
        if (_selectedFilter == 'Favorites') {
          filteredList = widget.audioFiles
              .where((f) => PlaylistManager.instance.isFavorite(f.path))
              .toList();
        }

        return Scaffold(
          backgroundColor: scaffoldBg,
          body: Column(
            children: [
              // Filter Chips
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip('All', "All Tracks (${widget.audioFiles.length})", activeCol, cardBg, textCol, subTextCol),
                      const SizedBox(width: 8),
                      _buildFilterChip('Favorites', "❤️ Favorites (${PlaylistManager.instance.favoritePaths.length})", activeCol, cardBg, textCol, subTextCol),
                    ],
                  ),
                ),
              ),

              // Song List
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Text(
                          _selectedFilter == 'Favorites'
                              ? "No favorites added yet"
                              : "No tracks found",
                          style: TextStyle(color: subTextCol),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20.0, top: 4.0),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final file = filteredList[index];
                          final actualIndex = widget.audioFiles.indexOf(file);
                          return _buildMusicTile(context, file, actualIndex);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
    String key,
    String label,
    Color activeCol,
    Color cardBg,
    Color textCol,
    Color subTextCol,
  ) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = key;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeCol : cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeCol : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : subTextCol,
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMusicTile(
      BuildContext context, FileSystemEntity file, int index) {
    final isDark = AppTheme.isDark(context);
    String fileName = file.path.split(Platform.pathSeparator).last;
    bool isPlayingCurrent =
        widget.currentlyPlayingIndex == index && widget.isPlaying;
    bool isCurrentSelected = widget.currentlyPlayingIndex == index;

    final selectedBg =
        isDark ? const Color(0xFF282828) : const Color(0xFFEEF2FF);
    final normalBg = AppTheme.cardBg(context);
    final selectedBorder =
        isDark ? Colors.white38 : AppTheme.lightPrimary.withValues(alpha: 0.5);
    final normalBorder = AppTheme.border(context);

    final titleColor = isCurrentSelected
        ? (isDark ? Colors.white : AppTheme.lightPrimary)
        : AppTheme.textPrimaryColor(context);
    final subtitleColor = AppTheme.textSecondaryColor(context);
    final isFav = PlaylistManager.instance.isFavorite(file.path);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: isCurrentSelected ? selectedBg : normalBg,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: isCurrentSelected ? selectedBorder : normalBorder,
          width: 1.0,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14.0),
        child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
        leading: ArtworkHelper.buildArtworkWidget(
          file.path,
          width: 48,
          height: 48,
          borderRadius: 8.0,
        ),
        title: Text(
          fileName,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isCurrentSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14.5,
            color: titleColor,
          ),
        ),
        subtitle: Text(
          "Audio Track",
          style: TextStyle(
            fontSize: 12.0,
            color: subtitleColor,
          ),
        ),
        onTap: () {
          widget.playTrack(index);
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Heart Favorite
            IconButton(
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? const Color(0xFFF43F5E) : subtitleColor,
                size: 22,
              ),
              onPressed: () {
                PlaylistManager.instance.toggleFavorite(file.path);
              },
            ),
            // Context Menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: subtitleColor, size: 20),
              onSelected: (val) {
                switch (val) {
                  case 'playlist':
                    _showAddToPlaylistDialog(file.path);
                    break;
                  case 'lyrics':
                    LyricsViewerSheet.show(context, file.path, widget.audioPlayer);
                    break;
                  case 'tags':
                    TagEditorSheet.show(context, file.path);
                    break;
                  case 'loop':
                    ABLooperSheet.show(context, widget.audioPlayer, widget.position);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add_rounded, size: 18),
                      SizedBox(width: 8),
                      Text("Add to Playlist"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'lyrics',
                  child: Row(
                    children: [
                      Icon(Icons.mic_external_on_rounded, size: 18),
                      SizedBox(width: 8),
                      Text("View Lyrics"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'tags',
                  child: Row(
                    children: [
                      Icon(Icons.edit_note_rounded, size: 18),
                      SizedBox(width: 8),
                      Text("Edit Tags"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'loop',
                  child: Row(
                    children: [
                      Icon(Icons.repeat_on_rounded, size: 18),
                      SizedBox(width: 8),
                      Text("A-B Looper"),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                isPlayingCurrent
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                color: isCurrentSelected
                    ? (isDark ? Colors.white : AppTheme.lightPrimary)
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
                size: 32.0,
              ),
              onPressed: () {
                if (isPlayingCurrent) {
                  widget.onPause();
                } else {
                  widget.playTrack(index);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}
}
