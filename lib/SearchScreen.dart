import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

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
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    List filteredFiles = widget.audioFiles
        .where((file) =>
            file.path.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Container(
          height: 40.0, // Decrease the height of the container
          decoration: BoxDecoration(
            color: Colors.deepPurple[200],
            borderRadius: BorderRadius.circular(30.0),
          ),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Search music...',
              hintStyle: TextStyle(color: Colors.white54),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.white54),
              contentPadding: EdgeInsets.symmetric(
                  vertical: 10.0, horizontal: 10.0), // Adjust padding if needed
            ),
          ),
        ),
      ),
      body: Container(
        color: const Color(0xFF0F0B1E),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 6.0),
          physics: const BouncingScrollPhysics(),
          itemCount: filteredFiles.length,
          itemBuilder: (context, index) {
            var file = filteredFiles[index];
            String title = file.path.split('/').last;
            int originalIndex = widget.audioFiles.indexOf(file);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
              decoration: BoxDecoration(
                color: const Color(0xFF180F33),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7B2CBF), Color(0xFFC77DFF)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white,
                    size: 20.0,
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  widget.playTrack(originalIndex);
                  Navigator.pop(context);
                },
                trailing: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFC77DFF).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFFC77DFF)),
                    onPressed: () {
                      widget.playTrack(originalIndex);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
