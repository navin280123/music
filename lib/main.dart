import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'dart:io';
import 'package:music/MainScreen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(), // Set SplashScreen as the home page
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool loading = true; // Flag to manage loading state
  List<FileSystemEntity> audioFiles = []; // List to store audio file paths
  bool filesLoaded = false; // Flag to track if audio files have been loaded
  bool minSplashTimeElapsed = false; // Flag for 4.5 seconds delay

  @override
  void initState() {
    super.initState();
    startTimers();
    requestPermissionAndLoadFiles();
  }

  void startTimers() {
    // Ensure the splash screen stays for at least 4.5 seconds
    Timer(const Duration(milliseconds: 4500), () {
      setState(() {
        minSplashTimeElapsed = true;
      });
      if (filesLoaded) {
        // If files are already loaded, navigate to the next screen
        navigateToMainScreen();
      }
    });
  }

  Future<void> requestPermissionAndLoadFiles() async {
    // Request permission to read external storage
    var status = await Permission.storage.request();

    if (status.isGranted) {
      // Fetch audio files
      List<FileSystemEntity> files = await _fetchAudioFiles();
      setState(() {
        audioFiles = files;
        filesLoaded = true; // Mark files as loaded
      });

      if (minSplashTimeElapsed) {
        // If the 4.5 sec timer is also complete, navigate to MainScreen
        navigateToMainScreen();
      }
    } else {
      // Handle permission denied scenario
      print("Storage permission denied");
      setState(() {
        loading = false; // Stop loading even if permission is denied
        filesLoaded = true;
      });
    }
  }

  void navigateToMainScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainScreen(audioFiles: audioFiles),
      ),
    );
  }

  // Function to fetch audio files from the storage
  Future<List<FileSystemEntity>> _fetchAudioFiles() async {
    List<FileSystemEntity> audioFiles = [];

    // Get the external storage directory
    Directory? musicDir = await getExternalStorageDirectory();
    if (musicDir != null) {
      // Scan for mp3 files in the directory
      audioFiles.addAll(_getFilesFromDirectory(musicDir, '.mp3'));
    }

    // Add additional common directories to search
    Directory musicDirectory = Directory('/storage/emulated/0/Music');
    if (musicDirectory.existsSync()) {
      audioFiles.addAll(_getFilesFromDirectory(musicDirectory, '.mp3'));
    }

    Directory downloadDirectory = Directory('/storage/emulated/0/Download');
    if (downloadDirectory.existsSync()) {
      audioFiles.addAll(_getFilesFromDirectory(downloadDirectory, '.mp3'));
    }

    return audioFiles;
  }

  // Helper function to get mp3 files from a directory
  List<FileSystemEntity> _getFilesFromDirectory(Directory dir, String extension) {
    List<FileSystemEntity> files = [];
    try {
      files = dir.listSync(recursive: true).where((file) {
        return file.path.endsWith(extension);
      }).toList();
    } catch (e) {
      print("Error while accessing directory: $e");
    }
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: loading
            ? Lottie.asset(
                'assets/music.json', // Lottie animation for loading
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              )
            : const Text(
                'Loading complete!',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
      ),
    );
  }
}
