import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'dart:io';
import 'package:music/MainScreen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/play',
  );

  runApp(const MyApp());
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
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    startAppSetup();
  }

  Future<void> startAppSetup() async {
    await _waitForSplashTime();
    await _requestPermissionAndLoadFiles();
    navigateToMainScreenIfReady();
  }

  Future<void> _waitForSplashTime() async {
    await Future.delayed(const Duration(seconds: 4));
  }

  Future<void> _requestPermissionAndLoadFiles() async {
    if (await Permission.storage.isGranted || await Permission.storage.request().isGranted) {
      audioFiles = await _fetchAudioFiles();
    } else {
      print("Storage permission denied.");
    }
    setState(() {
      loading = false;
    });
  }

  void navigateToMainScreenIfReady() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainScreen(
          audioFiles: audioFiles.map((file) => file.path).toList(),
        ),
      ),
    );
  }

  Future<List<FileSystemEntity>> _fetchAudioFiles() async {
    List<FileSystemEntity> files = [];
    Directory? musicDir = await getExternalStorageDirectory();

    if (musicDir != null) {
      files.addAll(_getFilesFromDirectory(musicDir, '.mp3'));
    }

    const directoriesToSearch = [
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/DCIM',
      '/storage/sdcard1/Music',
      '/storage/sdcard1/Download',
      '/storage/sdcard1/DCIM'
    ];

    for (final path in directoriesToSearch) {
      Directory dir = Directory(path);
      if (dir.existsSync()) {
        files.addAll(_getFilesFromDirectory(dir, '.mp3'));
      }
    }

    return files;
  }

  List<FileSystemEntity> _getFilesFromDirectory(Directory dir, String extension) {
    try {
      return dir.listSync(recursive: true).where((file) => file.path.endsWith(extension)).toList();
    } catch (e) {
      print("Error accessing directory ${dir.path}: $e");
      return [];
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
                '',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
      ),
    );
  }
}
