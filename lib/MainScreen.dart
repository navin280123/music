import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:music/AppSettings.dart';
import 'package:music/AppTheme.dart';
import 'package:music/ArtworkHelper.dart';
import 'package:music/HomeScreen.dart';
import 'package:music/LibraryScreen.dart';
import 'package:music/PlayScreen.dart';
import 'package:music/PlaylistManager.dart';
import 'package:music/SearchScreen.dart';
import 'package:music/SettingsScreen.dart';
import 'package:music/SleepTimerService.dart';
import 'package:music/WaveformVisualizer.dart';
import 'package:music/main.dart';
import 'package:path_provider/path_provider.dart';

class MainScreen extends StatefulWidget {
  final List<String> audioFiles;

  const MainScreen({super.key, required this.audioFiles});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int? _currentlyPlayingIndex;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isRepeat = false;
  bool _isMiniPlayerDismissed = false;
  List<String> _currentAudioFiles = [];
  List<AudioSource> audioSources = [];
  ConcatenatingAudioSource playlist = ConcatenatingAudioSource(children: []);
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _currentAudioFiles = List.from(widget.audioFiles);
    _setupAudioPlayer();
    _setupPlaylist();
    PlaylistManager.instance.init();
  }

  Future<void> _setupPlaylist() async {
    final artUri = await _loadAssetAsFileUri('assets/music.png');
    audioSources = _currentAudioFiles.map((filePath) {
      final index = _currentAudioFiles.indexOf(filePath);
      final metadata = _fetchMetadataFromPath(filePath);
      return AudioSource.uri(
        Uri.file(filePath),
        tag: MediaItem(
          id: '$index',
          album: metadata['album'] ?? "Unknown Album",
          title: metadata['title'] ?? "Unknown Title",
          artist: metadata['artist'] ?? "Unknown Artist",
          artUri: artUri,
        ),
      );
    }).toList();

    await playlist.clear();
    await playlist.addAll(audioSources);
  }

  void _setupAudioPlayer() {
    audioPlayer.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      }
    });

    audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    audioPlayer.playerStateStream.listen((playerState) {
      if (mounted) {
        setState(() {
          _isPlaying = playerState.playing;
        });
      }

      if (playerState.processingState == ProcessingState.completed) {
        debugPrint("Song completed");
        SleepTimerService.instance.onSongCompleted(audioPlayer);

        if (_isRepeat) {
          audioPlayer.seek(Duration.zero, index: _currentlyPlayingIndex);
          audioPlayer.play();
        } else if (AppSettings.instance.autoPlayNext) {
          _nextTrack();
        } else {
          audioPlayer.pause();
          audioPlayer.seek(Duration.zero);
        }
      }
    });

    audioPlayer.currentIndexStream.listen((index) {
      if (mounted) {
        setState(() {
          _currentlyPlayingIndex = index;
        });
      }
      if (index != null && index >= 0 && index < _currentAudioFiles.length) {
        PlaylistManager.instance.recordSongPlay(_currentAudioFiles[index]);
      }
    });
  }

  Future<void> playSong(int index) async {
    if (index < 0 || index >= _currentAudioFiles.length) return;

    try {
      if (mounted) {
        setState(() {
          _currentlyPlayingIndex = index;
          _isPlaying = true;
          _isMiniPlayerDismissed = false;
        });
      }

      await audioPlayer.setAudioSource(
        playlist,
        initialIndex: index,
        initialPosition: Duration.zero,
      );

      await audioPlayer.play();
    } catch (e) {
      debugPrint("Error playing song: $e");
    }
  }

  Future<void> playSongByPath(String path) async {
    final index = _currentAudioFiles.indexOf(path);
    if (index != -1) {
      await playSong(index);
    } else {
      // If song wasn't in playlist, append and play
      _currentAudioFiles.add(path);
      await _setupPlaylist();
      await playSong(_currentAudioFiles.length - 1);
    }
  }

  Future<Uri> _loadAssetAsFileUri(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file =
          await File('${tempDir.path}/temp_music_art.png').writeAsBytes(bytes);

      return file.uri;
    } catch (e) {
      debugPrint("Error loading asset: $e");
      return Uri();
    }
  }

  Future<void> play() async {
    if (_currentlyPlayingIndex != null) {
      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }
      await audioPlayer.play();
    } else if (_currentAudioFiles.isNotEmpty) {
      await playSong(0);
    }
  }

  Future<void> pause() async {
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
    await audioPlayer.pause();
  }

  Future<void> _nextTrack() async {
    if (_currentAudioFiles.isEmpty) return;
    int nextIndex = (_currentlyPlayingIndex ?? 0) + 1;
    if (nextIndex >= _currentAudioFiles.length) nextIndex = 0;
    await playSong(nextIndex);
  }

  Future<void> _previousTrack() async {
    if (_currentAudioFiles.isEmpty) return;
    int previousIndex = (_currentlyPlayingIndex ?? 0) - 1;
    if (previousIndex < 0) previousIndex = _currentAudioFiles.length - 1;
    await playSong(previousIndex);
  }

  void _toggleRepeat() {
    setState(() {
      _isRepeat = !_isRepeat;
    });
  }

  Map<String, String?> _fetchMetadataFromPath(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final title = fileName.split('.').first;
    return {
      'title': title,
      'album': "Pocketo Album",
      'artist': "Local Audio",
    };
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> rescanLibrary() async {
    try {
      final updatedFiles = await scanAudioFilesOnDevice();
      final filePaths = updatedFiles.map((f) => f.path).toList();

      if (mounted) {
        setState(() {
          _currentAudioFiles = filePaths;
        });
      }

      await _setupPlaylist();
    } catch (e) {
      debugPrint("Error rescanning library: $e");
    }
  }

  void _openSearchScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          audioFiles: _currentAudioFiles.map((path) => File(path)).toList(),
          audioPlayer: audioPlayer,
          playTrack: playSong,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    return duration.toString().split('.').first.padLeft(8, "0");
  }

  Widget _buildMiniPlayerBar() {
    if (_isMiniPlayerDismissed ||
        _currentlyPlayingIndex == null ||
        _currentlyPlayingIndex! < 0 ||
        _currentlyPlayingIndex! >= _currentAudioFiles.length) {
      return const SizedBox.shrink();
    }

    if (_currentIndex == 1) {
      return const SizedBox.shrink();
    }

    final isDark = AppTheme.isDark(context);
    final currentFilePath = _currentAudioFiles[_currentlyPlayingIndex!];
    final currentSong =
        currentFilePath.split(Platform.pathSeparator).last;
    final miniBg = AppTheme.miniPlayerBg(context);
    final borderCol = AppTheme.border(context);
    final titleCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);
    final iconCol = AppTheme.iconCol(context);
    final isFav = PlaylistManager.instance.isFavorite(currentFilePath);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          setState(() {
            _isMiniPlayerDismissed = true;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: miniBg,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: borderCol,
            width: 1,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(16.0),
            onTap: () {
              _onTabTapped(1);
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  ArtworkHelper.buildArtworkWidget(
                    currentFilePath,
                    width: 42,
                    height: 42,
                    borderRadius: 8,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentSong,
                          style: TextStyle(
                            color: titleCol,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2.0),
                        Row(
                          children: [
                            WaveformVisualizer(
                              isPlaying: _isPlaying,
                              barCount: 5,
                              height: 12,
                              barWidth: 2.5,
                              barColor: isDark
                                  ? const Color(0xFF818CF8)
                                  : AppTheme.lightPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
                              style: TextStyle(
                                color: subTextCol,
                                fontSize: 11.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? const Color(0xFFF43F5E) : subTextCol,
                      size: 20.0,
                    ),
                    onPressed: () {
                      PlaylistManager.instance.toggleFavorite(currentFilePath);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      color: iconCol,
                      size: 24.0,
                    ),
                    onPressed: _previousTrack,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: isDark ? Colors.white : AppTheme.lightPrimary,
                      size: 34.0,
                    ),
                    onPressed: () => _isPlaying ? pause() : play(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: iconCol,
                      size: 24.0,
                    ),
                    onPressed: _nextTrack,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: subTextCol,
                      size: 18.0,
                    ),
                    onPressed: () {
                      setState(() {
                        _isMiniPlayerDismissed = true;
                      });
                    },
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomBottomBar() {
    final isDark = AppTheme.isDark(context);
    final navBg = AppTheme.navBarBg(context);
    final borderCol = AppTheme.border(context);
    final selectedPillBg = AppTheme.navBarSelectedBg(context);
    final selectedTextCol = AppTheme.navBarSelectedText(context);
    final unselectedCol = AppTheme.textSecondaryColor(context);

    final navItems = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.play_arrow_rounded, 'label': 'Play'},
      {'icon': Icons.queue_music_rounded, 'label': 'Library'},
      {'icon': Icons.settings_rounded, 'label': 'Settings'},
    ];

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
      height: 60,
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: borderCol,
          width: 1,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(navItems.length, (index) {
          final isSelected = _currentIndex == index;
          final item = navItems[index];

          return GestureDetector(
            onTap: () => _onTabTapped(index),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 14.0 : 10.0,
                vertical: 8.0,
              ),
              decoration: isSelected
                  ? BoxDecoration(
                      color: selectedPillBg,
                      borderRadius: BorderRadius.circular(20),
                    )
                  : const BoxDecoration(),
              child: Row(
                children: [
                  Icon(
                    item['icon'] as IconData,
                    color: isSelected ? selectedTextCol : unselectedCol,
                    size: 20,
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        color: selectedTextCol,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final scaffoldBg = isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold;
    final headerBg = AppTheme.headerBg(context);
    final borderCol = AppTheme.border(context);
    final titleCol = AppTheme.textPrimaryColor(context);
    final iconCol = AppTheme.iconCol(context);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          decoration: BoxDecoration(
            color: headerBg,
            border: Border(
              bottom: BorderSide(
                color: borderCol,
                width: 1.0,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.asset(
                      'assets/appicon.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 32,
                        height: 32,
                        color: AppTheme.secondaryCardBg(context),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: titleCol,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Pocketo Play",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: titleCol,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.search_rounded, color: iconCol),
                    onPressed: _openSearchScreen,
                    tooltip: 'Search Music',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            audioFiles:
                _currentAudioFiles.map((path) => File(path)).toList(),
            audioPlayer: audioPlayer,
            currentlyPlayingIndex: _currentlyPlayingIndex,
            isPlaying: _isPlaying,
            onPlay: play,
            onPause: pause,
            duration: _duration,
            position: _position,
            onNext: _nextTrack,
            onPrevious: _previousTrack,
            playTrack: playSong,
            onTabTapped: _onTabTapped,
            onRescan: rescanLibrary,
          ),
          PlayScreen(
            audioFiles:
                _currentAudioFiles.map((path) => File(path)).toList(),
            audioPlayer: audioPlayer,
            currentlyPlayingIndex: _currentlyPlayingIndex,
            isPlaying: _isPlaying,
            onPlay: play,
            onPause: pause,
            duration: _duration,
            position: _position,
            onNext: _nextTrack,
            onPrevious: _previousTrack,
            playTrack: playSong,
            toggleRepeat: _toggleRepeat,
            isRepeat: _isRepeat,
          ),
          LibraryScreen(
            audioFiles:
                _currentAudioFiles.map((path) => File(path)).toList(),
            audioPlayer: audioPlayer,
            playTrack: playSong,
            playFilePath: playSongByPath,
          ),
          SettingsScreen(
            audioFiles:
                _currentAudioFiles.map((path) => File(path)).toList(),
            audioPlayer: audioPlayer,
            currentlyPlayingIndex: _currentlyPlayingIndex,
            isPlaying: _isPlaying,
            duration: _duration,
            position: _position,
            onPlay: play,
            onPause: pause,
            onNext: _nextTrack,
            onPrevious: _previousTrack,
            playTrack: playSong,
            onTabTapped: _onTabTapped,
            onRescan: rescanLibrary,
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniPlayerBar(),
          _buildCustomBottomBar(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}
