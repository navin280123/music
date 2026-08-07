import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/ArtworkHelper.dart';

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
  _SearchScreenState createState() => _SearchScreenState();
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
    List filteredFiles = widget.audioFiles
        .where((file) =>
            file.path.toLowerCase().contains(_searchQuery.trim().toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF181818),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFF282828),
                width: 1.0,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.asset(
                      'assets/appicon.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 30,
                        height: 30,
                        color: const Color(0xFF282828),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 40.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF282828),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        style: const TextStyle(color: Colors.white, fontSize: 14.0),
                        decoration: InputDecoration(
                          hintText: 'Search tracks, songs...',
                          hintStyle: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14.0,
                          ),
                          border: InputBorder.none,
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white54,
                                    size: 18,
                                  ),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
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
        color: const Color(0xFF121212),
        child: Column(
          children: [
            if (_searchQuery.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Row(
                  children: [
                    const Text(
                      "Search Results",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282828),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        "${filteredFiles.length} found",
                        style: const TextStyle(
                          color: Colors.white,
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
                  ? _buildInitialState()
                  : filteredFiles.isEmpty
                      ? _buildNoResultsState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20.0, top: 4.0),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredFiles.length,
                          itemBuilder: (context, index) {
                            var file = filteredFiles[index];
                            String title = file.path.split('/').last;
                            int originalIndex = widget.audioFiles.indexOf(file);

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4.0, horizontal: 16.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(
                                  color: const Color(0xFF2C2C2E),
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 4.0, horizontal: 12.0),
                                leading: ArtworkHelper.buildArtworkWidget(
                                  file.path,
                                  width: 44,
                                  height: 44,
                                  borderRadius: 8.0,
                                ),
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: const Text(
                                  "Tap to play track",
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    color: Colors.white54,
                                  ),
                                ),
                                onTap: () {
                                  widget.playTrack(originalIndex);
                                  Navigator.pop(context);
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.play_circle_fill_rounded,
                                      color: Colors.white, size: 32.0),
                                  onPressed: () {
                                    widget.playTrack(originalIndex);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 44,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "Search Your Library",
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Type a song title or keyword above to filter tracks",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.manage_search_rounded,
              size: 44,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "No Matching Songs",
            style: TextStyle(
              color: Colors.white,
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
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
