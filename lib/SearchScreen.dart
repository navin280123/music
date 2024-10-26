
import 'package:audioplayers/audioplayers.dart' as audioPlayers;
import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final Function(int, String,bool,bool) onPlayOrPause;
  final audioPlayers.AudioPlayer audioPlayer;

  const SearchScreen({
    super.key,
    required this.audioFiles,
    required this.onPlayOrPause,
    required this.audioPlayer,
  });

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    List filteredFiles = widget.audioFiles
        .where((file) => file.path.toLowerCase().contains(_searchQuery.toLowerCase()))
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
              contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0), // Adjust padding if needed
            ),
          ),
        ),
      ),
      body: Container(
        color: Colors.deepPurple, // Add background color
        child: ListView.builder(
          itemCount: filteredFiles.length,
          itemBuilder: (context, index) {
        var file = filteredFiles[index];
        String title = file.path.split('/').last; // Extract the file name as title
        
        // Find the original index of this file in the main audioFiles list
        int originalIndex = widget.audioFiles.indexOf(file);

        return Card(
          color: Colors.deepPurple[400],
          margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
          child: ListTile(
            title: Text(
              title,
              style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
              overflow: TextOverflow.ellipsis, // Add this line to ensure single line display
            ),
            onTap: () {
              widget.onPlayOrPause(originalIndex, file.path,false,true);
              Navigator.pop(context);
            },
            trailing: IconButton(
              icon: const Icon(Icons.play_arrow, color: Color.fromARGB(255, 190, 152, 254)),
              onPressed: () {
          widget.onPlayOrPause(originalIndex, file.path,false,true);
          Navigator.pop(context);
              },
            ),
          ),
        );
          },
        ),
      ),
        );
  }
}
