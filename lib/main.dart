import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'dart:io';
import 'package:music/MainScreen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Music',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  bool loading = true;
  List<FileSystemEntity> audioFiles = [];
  bool filesLoaded = false;
  bool minSplashTimeElapsed = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    startTimers();
    requestPermissionAndLoadFiles();
    

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // Smoothly loop the animation
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void startTimers() {
    Timer(const Duration(milliseconds: 4700), () {
      setState(() {
        minSplashTimeElapsed = true;
      });
      if (filesLoaded) {
        navigateToMainScreen();
      }
    });
  }

  Future<void> requestPermissionAndLoadFiles() async {
    var status = await Permission.storage.request();

    if (status.isGranted) {
      List<FileSystemEntity> files = await _fetchAudioFiles();
      setState(() {
        audioFiles = files;
        filesLoaded = true;
      });

      if (minSplashTimeElapsed) {
        navigateToMainScreen();
      }
    } else {
      print("Storage permission denied");
      setState(() {
        loading = false;
        filesLoaded = true;
      });
    }
  }

  void navigateToMainScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainScreen(audioFiles: audioFiles.map((file) => file.path).toList()),
      ),
    );
  }

  Future<List<FileSystemEntity>> _fetchAudioFiles() async {
    List<FileSystemEntity> audioFiles = [];
    Directory? musicDir = await getExternalStorageDirectory();
    if (musicDir != null) {
      audioFiles.addAll(_getFilesFromDirectory(musicDir, '.mp3'));
    }

    List<String> directoriesToSearch = [
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/DCIM',
      '/storage/sdcard1/Music',
      '/storage/sdcard1/Download',
      '/storage/sdcard1/DCIM'
    ];

    for (String path in directoriesToSearch) {
      Directory dir = Directory(path);
      if (dir.existsSync()) {
        audioFiles.addAll(_getFilesFromDirectory(dir, '.mp3'));
      }
    }

    return audioFiles;
  }

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
                'assets/music.json',
                controller: _animationController,
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
