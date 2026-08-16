import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/core/app_theme.dart';
import 'package:music/helpers/artwork_helper.dart';
import 'package:music/services/playlist_manager.dart';

class SearchScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final Function(int) playTrack;
  final AudioPlayer audioPlayer;

  const SearchScreen({
    super.key,
    required this.audioFiles,
    required this.audioPlayer,
    required this.playTrack,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final scaffoldBg = isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold;
    final headerBg = AppTheme.headerBg(context);
    final borderCol = AppTheme.border(context);
    final searchBoxBg = AppTheme.secondaryCardBg(context);
    final textCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);
    final cardBg = AppTheme.cardBg(context);

    List filteredFiles = widget.audioFiles
        .where((file) => file.path
            .split(Platform.pathSeparator)
            .last
            .toLowerCase()
            .contains(_searchQuery.trim().toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64.0),
        child: Container(
          decoration: BoxDecoration(
            color: headerBg,
            border: Border(
              bottom: BorderSide(
                color: borderCol,
                width: 1.0,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: textCol),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.asset(
                      'assets/appicon.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 32,
                        height: 32,
                        color: searchBoxBg,
                        child: Icon(
                          Icons.music_note_rounded,
                          color: textCol,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 42.0,
                      decoration: BoxDecoration(
                        color: searchBoxBg,
                        borderRadius: BorderRadius.circular(21.0),
                        border: Border.all(color: borderCol),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        style: TextStyle(color: textCol, fontSize: 14.0),
                        decoration: InputDecoration(
                          hintText: 'Search tracks, songs...',
                          hintStyle: TextStyle(
                            color: subTextCol,
                            fontSize: 14.0,
                          ),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: subTextCol,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: subTextCol,
                                    size: 18,
                                  ),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        color: scaffoldBg,
        child: Column(
          children: [
            if (_searchQuery.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 10.0),
                child: Row(
                  children: [
                    Text(
                      "Search Results",
                      style: TextStyle(
                        color: subTextCol,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF282828)
                            : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        "${filteredFiles.length} found",
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppTheme.lightPrimary,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _searchQuery.trim().isEmpty
                  ? _buildInitialState(context)
                  : filteredFiles.isEmpty
                      ? _buildNoResultsState(context)
                      : ListenableBuilder(
                          listenable: PlaylistManager.instance,
                          builder: (context, _) {
                            return ListView.builder(
                              padding: const EdgeInsets.only(
                                  bottom: 20.0, top: 4.0),
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredFiles.length,
                              itemBuilder: (context, index) {
                                var file = filteredFiles[index];
                                String title =
                                    file.path.split(Platform.pathSeparator).last;
                                int originalIndex =
                                    widget.audioFiles.indexOf(file);
                                final isFav = PlaylistManager.instance
                                    .isFavorite(file.path);

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4.0, horizontal: 16.0),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(14.0),
                                    border: Border.all(
                                      color: borderCol,
                                      width: 1,
                                    ),
                                    boxShadow: isDark
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.03),
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
                                          const EdgeInsets.symmetric(
                                              vertical: 4.0, horizontal: 12.0),
                                      leading: ArtworkHelper.buildArtworkWidget(
                                        file.path,
                                        width: 44,
                                        height: 44,
                                        borderRadius: 8.0,
                                      ),
                                      title: Text(
                                        title,
                                        style: TextStyle(
                                          color: textCol,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        "Tap to play track",
                                        style: TextStyle(
                                          fontSize: 12.0,
                                          color: subTextCol,
                                        ),
                                      ),
                                      onTap: () {
                                        widget.playTrack(originalIndex);
                                        Navigator.pop(context);
                                      },
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              isFav
                                                  ? Icons.favorite_rounded
                                                  : Icons
                                                      .favorite_border_rounded,
                                              color: isFav
                                                  ? const Color(0xFFF43F5E)
                                                  : subTextCol,
                                              size: 22.0,
                                            ),
                                            onPressed: () {
                                              PlaylistManager.instance
                                                  .toggleFavorite(file.path);
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.play_circle_fill_rounded,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppTheme.lightPrimary,
                                              size: 32.0,
                                            ),
                                            onPressed: () {
                                              widget.playTrack(originalIndex);
                                              Navigator.pop(context);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final textCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22.0),
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: borderCol),
            ),
            child: Icon(
              Icons.search_rounded,
              size: 44,
              color: isDark ? Colors.white54 : AppTheme.lightPrimary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "Search Your Library",
            style: TextStyle(
              color: textCol,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Type a song title or keyword above to filter tracks",
            style: TextStyle(
              color: subTextCol,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final textCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22.0),
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: borderCol),
            ),
            child: Icon(
              Icons.manage_search_rounded,
              size: 44,
              color: subTextCol,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "No Matching Songs",
            style: TextStyle(
              color: textCol,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "No audio files found for '$_searchQuery'. Try checking spelling or search another keyword.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subTextCol,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
