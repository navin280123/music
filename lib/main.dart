import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'dart:io';
import 'package:music/AppSettings.dart';
import 'package:music/AppTheme.dart';
import 'package:music/MainScreen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppSettings.instance.loadSettings();

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
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Pocketo Play',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: AppSettings.instance.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
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
    await Future.delayed(const Duration(seconds: 3));
  }

  Future<void> _requestPermissionAndLoadFiles() async {
    bool hasPermission = false;

    // Android 13+: use READ_MEDIA_AUDIO; Android ≤12: use READ_EXTERNAL_STORAGE
    if (await Permission.audio.isGranted ||
        await Permission.storage.isGranted) {
      hasPermission = true;
    } else {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.audio,
        Permission.storage,
      ].request();

      if ((statuses[Permission.audio]?.isGranted ?? false) ||
          (statuses[Permission.storage]?.isGranted ?? false)) {
        hasPermission = true;
      }
    }

    if (hasPermission) {
      audioFiles = await scanAudioFilesOnDevice();
    } else {
      debugPrint("Storage/Audio permission denied.");
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  void navigateToMainScreenIfReady() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainScreen(
          audioFiles: audioFiles.map((file) => file.path).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white54 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
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
                    errorBuilder: (context, error, stackTrace) => ClipRRect(
                      borderRadius: BorderRadius.circular(20.0),
                      child: Image.asset(
                        'assets/appicon.png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(20.0),
                    child: Image.asset(
                      'assets/appicon.png',
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
            const SizedBox(height: 24),
            Text(
              'Pocketo Play',
              style: TextStyle(
                color: titleColor,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Personal Music Companion',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Global device scanner utility for audio files
Future<List<FileSystemEntity>> scanAudioFilesOnDevice() async {
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

  try {
    Directory? musicDir = await getExternalStorageDirectory();
    if (musicDir != null) {
      directoriesToSearch.add(musicDir.path);
    }
  } catch (e) {
    debugPrint("Error retrieving external storage directory: $e");
  }

  for (final path in directoriesToSearch) {
    Directory dir = Directory(path);
    if (dir.existsSync() && !scannedPaths.contains(dir.path)) {
      _safeScanDirectory(dir, files, scannedPaths);
    }
  }

  return files;
}

void _safeScanDirectory(
  Directory dir,
  List<FileSystemEntity> results,
  Set<String> visitedDirs, {
  int depth = 0,
}) {
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
    debugPrint("Error scanning directory ${dir.path}: $e");
  }
}
