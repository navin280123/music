import 'package:flutter/material.dart';
import 'package:music/HomeScreen.dart';
import 'package:music/PlayScreen.dart';
import 'package:music/ProfileScreen.dart';

class MainScreen extends StatefulWidget {
  final List<dynamic>
      audioFiles; // List of audio files passed to the MainScreen
  MainScreen({super.key, required this.audioFiles});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late List<Widget> _pages;
  late List<dynamic> _filteredAudioFiles;

  @override
  void initState() {
    super.initState();
    _filteredAudioFiles = widget.audioFiles;
    _pages = [
      HomeScreen(
          audioFiles:
              _filteredAudioFiles), // Pass the audio files to HomeScreen
      const PlayScreen(),
      const ProfileScreen(),
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple, // Set app bar background color
        title: const Text(
          "Play Music",
          style: TextStyle(color: Colors.white), // Set text color
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ), // Display the selected tab's screen
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.deepPurple, // Set background color
        currentIndex: _currentIndex, // The currently selected tab
        onTap: _onTabTapped, // Handle tab tap
        selectedItemColor: Colors.white, // Set selected item color
        unselectedItemColor:
            const Color.fromARGB(255, 35, 35, 35), // Set unselected item color
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_fill),
            label: 'Play',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
