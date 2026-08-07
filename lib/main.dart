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
      title: 'Pocketo Play',
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
    )..repeat();

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
    bool hasPermission = false;

    if (await Permission.audio.isGranted ||
        await Permission.storage.isGranted ||
        await Permission.manageExternalStorage.isGranted) {
      hasPermission = true;
    } else {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.audio,
        Permission.storage,
      ].request();

      if ((statuses[Permission.audio]?.isGranted ?? false) ||
          (statuses[Permission.storage]?.isGranted ?? false)) {
        hasPermission = true;
      } else {
        if (await Permission.manageExternalStorage.request().isGranted) {
          hasPermission = true;
        }
      }
    }

    if (hasPermission) {
      audioFiles = await _fetchAudioFiles();
    } else {
      print("Storage/Audio permission denied.");
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
    Set<String> scannedPaths = {};

    List<String> directoriesToSearch = [
      '/storage/emulated/0',
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Audio',
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/WhatsApp/Media',
      '/storage/emulated/0/Telegram',
      '/storage/emulated/0/Bluetooth',
      '/storage/sdcard1',
      '/storage/sdcard1/Music',
      '/storage/sdcard1/Download',
    ];

    Directory? musicDir = await getExternalStorageDirectory();
    if (musicDir != null) {
      directoriesToSearch.add(musicDir.path);
    }

    for (final path in directoriesToSearch) {
      Directory dir = Directory(path);
      if (dir.existsSync() && !scannedPaths.contains(dir.path)) {
        _safeScanDirectory(dir, files, scannedPaths);
      }
    }

    return files;
  }

  void _safeScanDirectory(Directory dir, List<FileSystemEntity> results, Set<String> visitedDirs, {int depth = 0}) {
    if (depth > 6) return;
    if (!visitedDirs.add(dir.path)) return;

    try {
      final List<FileSystemEntity> entities = dir.listSync(recursive: false);
      for (final entity in entities) {
        final path = entity.path;
        final name = path.split(Platform.pathSeparator).last;
        if (name.startsWith('.')) continue;

        if (entity is File) {
          final lowerPath = path.toLowerCase();
          if (lowerPath.endsWith('.mp3') ||
              lowerPath.endsWith('.m4a') ||
              lowerPath.endsWith('.aac') ||
              lowerPath.endsWith('.wav') ||
              lowerPath.endsWith('.flac') ||
              lowerPath.endsWith('.ogg') ||
              lowerPath.endsWith('.opus')) {
            results.add(entity);
          }
        } else if (entity is Directory) {
          if (!path.endsWith('/Android/data') && !path.endsWith('/Android/obb')) {
            _safeScanDirectory(entity, results, visitedDirs, depth: depth + 1);
          }
        }
      }
    } catch (e) {
      print("Error scanning directory ${dir.path}: $e");
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
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            loading
                ? Lottie.asset(
                    'assets/music.json',
                    controller: _animationController,
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: Image.asset(
                      'assets/appicon.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
            const SizedBox(height: 24),
            const Text(
              'Pocketo Play',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your Personal Music Companion',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
