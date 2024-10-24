import 'package:flutter/material.dart';
import 'package:music/HomeScreen.dart';
import 'package:music/PlayScreen.dart';
import 'package:music/ProfileScreen.dart';

class MainScreen extends StatefulWidget {
  final List<dynamic> audioFiles; // List of audio files passed to the MainScreen
  MainScreen({super.key, required this.audioFiles});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Create a list of pages, passing the audioFiles to the HomeScreen
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(audioFiles: widget.audioFiles), // Pass the audio files to HomeScreen
      const PlayScreen(),
      const ProfileScreen(),
    ];
  }

  // Handle tab change
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
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ), // Display the selected tab's screen
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.deepPurple, // Set background color
        currentIndex: _currentIndex, // The currently selected tab
        onTap: _onTabTapped, // Handle tab tap
        selectedItemColor: Colors.white, // Set selected item color
        unselectedItemColor: const Color.fromARGB(255, 35, 35, 35), // Set unselected item color
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
