import 'package:flutter/material.dart';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:music/widgets/ab_looper_widget.dart';
import 'package:music/core/app_theme.dart';
import 'package:music/helpers/artwork_helper.dart';
import 'package:music/sheets/lyrics_viewer_sheet.dart';
import 'package:music/services/playlist_manager.dart';
import 'package:music/sheets/tag_editor_sheet.dart';

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
  // ── helpers ─────────────────────────────────────────────────────────────────

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  int _indexOfPath(String path) =>
      widget.audioFiles.indexWhere((f) => f.path == path);

  void _showAddToPlaylistDialog(String filePath) {
    final playlistNames = PlaylistManager.instance.getPlaylistNames();
    final isDark = AppTheme.isDark(context);

    if (playlistNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No playlists yet. Create one in the Library tab!'),
          action: SnackBarAction(
            label: 'Go to Library',
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
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to Playlist',
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...playlistNames.map((name) => ListTile(
                  leading: const Icon(Icons.playlist_add_rounded),
                  title: Text(name),
                  onTap: () {
                    PlaylistManager.instance.addSongToPlaylist(name, filePath);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Added to $name'),
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                )),
          ],
        ),
      ),
    );
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final scaffoldBg =
        isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold;
    final activeCol =
        isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary;

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
                  child: Icon(Icons.music_off_rounded,
                      size: 48,
                      color: AppTheme.textSecondaryColor(context)),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Music Found',
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
                    label: const Text('Scan For Music'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF2C2C2E)
                          : AppTheme.lightPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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
        // ── data ────────────────────────────────────────────────────────────

        // Most-played: top 6 that still exist in audioFiles
        final topEntries = PlaylistManager.instance
            .getTopPlayedSongs(limit: 20)
            .where((e) =>
                widget.audioFiles.any((f) => f.path == e.key))
            .take(6)
            .toList();

        // If not enough play data yet, fill with first songs
        List<dynamic> mostPlayed = topEntries
            .map((e) => widget.audioFiles.firstWhere((f) => f.path == e.key))
            .toList();
        if (mostPlayed.isEmpty) {
          mostPlayed = widget.audioFiles.take(6).toList();
        }

        // Recently played (paths that still exist)
        final recentPaths = PlaylistManager.instance.recentlyPlayed
            .where((p) => widget.audioFiles.any((f) => f.path == p))
            .take(10)
            .toList();
        final recentFiles = recentPaths
            .map((p) => widget.audioFiles.firstWhere((f) => f.path == p))
            .toList();

        // Recently added = last N files (order they were scanned, newest first)
        final recentlyAdded = widget.audioFiles.reversed.take(20).toList();

        return Scaffold(
          backgroundColor: scaffoldBg,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting,
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your Music',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Most Played ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'Most Played',
                  subtitle:
                      topEntries.isEmpty ? 'Start playing to rank songs' : null,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 192,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: mostPlayed.length,
                    itemBuilder: (context, i) {
                      final file = mostPlayed[i];
                      final idx = _indexOfPath(file.path as String);
                      final isActive = widget.currentlyPlayingIndex == idx;
                      final playCount = PlaylistManager.instance
                          .getSongPlayCount(file.path as String);
                      return _MostPlayedCard(
                        file: file,
                        index: idx,
                        rank: i + 1,
                        playCount: playCount,
                        isActive: isActive,
                        isPlaying: widget.isPlaying,
                        activeCol: activeCol,
                        onTap: () => widget.playTrack(idx),
                        onPause: widget.onPause,
                      );
                    },
                  ),
                ),
              ),

              // ── Recently Played ──────────────────────────────────────────
              if (recentFiles.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: _SectionHeader(
                    icon: Icons.history_rounded,
                    iconColor: Color(0xFF38BDF8),
                    title: 'Recently Played',
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 86,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: recentFiles.length,
                      itemBuilder: (context, i) {
                        final file = recentFiles[i];
                        final idx = _indexOfPath(file.path as String);
                        final isActive = widget.currentlyPlayingIndex == idx;
                        return _RecentChip(
                          file: file,
                          index: idx,
                          isActive: isActive,
                          activeCol: activeCol,
                          onTap: () => widget.playTrack(idx),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // ── Recently Added / All songs ───────────────────────────────
              SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: Icons.library_music_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Recently Added',
                  subtitle:
                      '${widget.audioFiles.length} track${widget.audioFiles.length == 1 ? '' : 's'}',
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final file = recentlyAdded[i];
                    final idx = _indexOfPath(file.path as String);
                    return _CompactSongTile(
                      file: file,
                      index: idx,
                      isCurrentSelected:
                          widget.currentlyPlayingIndex == idx,
                      isPlayingCurrent:
                          widget.currentlyPlayingIndex == idx &&
                              widget.isPlaying,
                      activeCol: activeCol,
                      onTap: () => widget.playTrack(idx),
                      onPlayPause: () {
                        if (widget.currentlyPlayingIndex == idx &&
                            widget.isPlaying) {
                          widget.onPause();
                        } else {
                          widget.playTrack(idx);
                        }
                      },
                      onFavToggle: () =>
                          PlaylistManager.instance.toggleFavorite(file.path),
                      onAddToPlaylist: () =>
                          _showAddToPlaylistDialog(file.path),
                      onLyrics: () => LyricsViewerSheet.show(
                          context, file.path, widget.audioPlayer),
                      onTags: () =>
                          TagEditorSheet.show(context, file.path),
                      onLoop: () => ABLooperSheet.show(
                          context, widget.audioPlayer, widget.position),
                    );
                  },
                  childCount: recentlyAdded.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(
              subtitle!,
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Most Played card — large album-art tile with rank & play count
// ─────────────────────────────────────────────────────────────────────────────

class _MostPlayedCard extends StatelessWidget {
  final dynamic file;
  final int index;
  final int rank;
  final int playCount;
  final bool isActive;
  final bool isPlaying;
  final Color activeCol;
  final VoidCallback onTap;
  final VoidCallback onPause;

  const _MostPlayedCard({
    required this.file,
    required this.index,
    required this.rank,
    required this.playCount,
    required this.isActive,
    required this.isPlaying,
    required this.activeCol,
    required this.onTap,
    required this.onPause,
  });

  String _displayName(String path) => path
      .split(Platform.pathSeparator)
      .last
      .replaceAll(
          RegExp(r'\.(mp3|flac|aac|m4a|wav|ogg|opus)$', caseSensitive: false),
          '');

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final name = _displayName(file.path as String);

    return GestureDetector(
      onTap: isActive && isPlaying ? onPause : onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12, bottom: 4, top: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? activeCol.withValues(alpha: 0.7)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06)),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? activeCol.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: isActive ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Album art
              ArtworkHelper.buildArtworkWidget(
                file.path as String,
                width: 140,
                height: 192,
                borderRadius: 0,
              ),
              // Gradient overlay
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
              // Rank badge (top-left)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? const Color(0xFFFFB300)
                        : rank == 2
                            ? const Color(0xFF9E9E9E)
                            : rank == 3
                                ? const Color(0xFFBF8C60)
                                : Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              // Play/Pause indicator (top-right)
              if (isActive)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: activeCol,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              // Title + play count (bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      if (playCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.play_arrow_rounded,
                                color: Colors.white60, size: 10),
                            const SizedBox(width: 2),
                            Text(
                              '$playCount play${playCount == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recently Played compact chip
// ─────────────────────────────────────────────────────────────────────────────

class _RecentChip extends StatelessWidget {
  final dynamic file;
  final int index;
  final bool isActive;
  final Color activeCol;
  final VoidCallback onTap;

  const _RecentChip({
    required this.file,
    required this.index,
    required this.isActive,
    required this.activeCol,
    required this.onTap,
  });

  String _displayName(String path) => path
      .split(Platform.pathSeparator)
      .last
      .replaceAll(
          RegExp(r'\.(mp3|flac|aac|m4a|wav|ogg|opus)$', caseSensitive: false),
          '');

  @override
  Widget build(BuildContext context) {
    final name = _displayName(file.path as String);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 210,
        margin: const EdgeInsets.only(right: 10, top: 2, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeCol.withValues(alpha: 0.12)
              : AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? activeCol.withValues(alpha: 0.45)
                : AppTheme.border(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ArtworkHelper.buildArtworkWidget(
                file.path as String,
                width: 46,
                height: 46,
                borderRadius: 8,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive
                          ? activeCol
                          : AppTheme.textPrimaryColor(context),
                      fontSize: 11.5,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.equalizer_rounded, color: activeCol, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact song tile for Recently Added list
// ─────────────────────────────────────────────────────────────────────────────

class _CompactSongTile extends StatelessWidget {
  final dynamic file;
  final int index;
  final bool isCurrentSelected;
  final bool isPlayingCurrent;
  final Color activeCol;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onFavToggle;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onLyrics;
  final VoidCallback onTags;
  final VoidCallback onLoop;

  const _CompactSongTile({
    required this.file,
    required this.index,
    required this.isCurrentSelected,
    required this.isPlayingCurrent,
    required this.activeCol,
    required this.onTap,
    required this.onPlayPause,
    required this.onFavToggle,
    required this.onAddToPlaylist,
    required this.onLyrics,
    required this.onTags,
    required this.onLoop,
  });

  String _displayName(String path) => path
      .split(Platform.pathSeparator)
      .last
      .replaceAll(
          RegExp(r'\.(mp3|flac|aac|m4a|wav|ogg|opus)$', caseSensitive: false),
          '');

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final name = _displayName(file.path as String);
    final isFav = PlaylistManager.instance.isFavorite(file.path as String);
    final subTextCol = AppTheme.textSecondaryColor(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 16),
      decoration: BoxDecoration(
        color: isCurrentSelected
            ? (isDark
                ? const Color(0xFF282828)
                : const Color(0xFFEEF2FF))
            : AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentSelected
              ? (isDark
                  ? Colors.white38
                  : AppTheme.lightPrimary.withValues(alpha: 0.5))
              : AppTheme.border(context),
          width: 1,
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
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
          onTap: onTap,
          leading: ArtworkHelper.buildArtworkWidget(
            file.path as String,
            width: 46,
            height: 46,
            borderRadius: 8,
          ),
          title: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight:
                  isCurrentSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13.5,
              color: isCurrentSelected
                  ? (isDark ? Colors.white : AppTheme.lightPrimary)
                  : AppTheme.textPrimaryColor(context),
            ),
          ),
          subtitle: Text(
            'Audio Track',
            style: TextStyle(fontSize: 11.5, color: subTextCol),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFav ? const Color(0xFFF43F5E) : subTextCol,
                  size: 20,
                ),
                onPressed: onFavToggle,
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: subTextCol, size: 20),
                onSelected: (val) {
                  switch (val) {
                    case 'playlist':
                      onAddToPlaylist();
                      break;
                    case 'lyrics':
                      onLyrics();
                      break;
                    case 'tags':
                      onTags();
                      break;
                    case 'loop':
                      onLoop();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'playlist',
                    child: Row(children: [
                      Icon(Icons.playlist_add_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Add to Playlist'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'lyrics',
                    child: Row(children: [
                      Icon(Icons.mic_external_on_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('View Lyrics'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'tags',
                    child: Row(children: [
                      Icon(Icons.edit_note_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Edit Tags'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'loop',
                    child: Row(children: [
                      Icon(Icons.repeat_on_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('A-B Looper'),
                    ]),
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
                  size: 30,
                ),
                onPressed: onPlayPause,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

