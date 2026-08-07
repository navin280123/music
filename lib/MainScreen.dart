import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:music/HomeScreen.dart';
import 'package:music/PlayScreen.dart';
import 'package:music/SettingsScreen.dart';
import 'package:music/SearchScreen.dart';
import 'package:music/ArtworkHelper.dart';
import 'package:path_provider/path_provider.dart';

class MainScreen extends StatefulWidget {
  final List<String> audioFiles;

  MainScreen({super.key, required this.audioFiles});

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
  List<AudioSource> audioSources = [];
  ConcatenatingAudioSource playlist = ConcatenatingAudioSource(children: []);
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
    _setupPlaylist();
  }

  void _setupPlaylist() async {
    final artUri = await _loadAssetAsFileUri('assets/music.png');
    audioSources = widget.audioFiles.map((filePath) {
      final index = widget.audioFiles.indexOf(filePath);
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

    playlist.addAll(audioSources);
  }

  void _setupAudioPlayer() {
    // Listen to changes in audio duration
    audioPlayer.durationStream.listen((duration) {
      setState(() {
        _duration = duration ?? Duration.zero;
      });
    });

    // Listen to changes in audio position
    audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });

    // Listen to player state changes

    audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        print("Song completed");
        if (_isRepeat) {
          audioPlayer.seek(Duration.zero, index: _currentlyPlayingIndex);
          audioPlayer.play();
        } else {
          _nextTrack();
        }
      }
    });

    // Listen to changes in the current track index
    audioPlayer.currentIndexStream.listen((index) {
      setState(() {
        _currentlyPlayingIndex = index;
      });
    });
  }

  Future<void> playSong(int index) async {
    if (index < 0 || index >= widget.audioFiles.length) return;

    try {
      setState(() {
        _currentlyPlayingIndex = index;
        _isPlaying = true;
        _isMiniPlayerDismissed = false;
      });

      await audioPlayer.setAudioSource(
        playlist,
        initialIndex: index,
        initialPosition: Duration.zero,
      );

      await audioPlayer.play();
    } catch (e) {
      print("Error playing song: $e");
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
      print("Error loading asset: $e");
      return Uri();
    }
  }

  Future<void> play() async {
    if (_currentlyPlayingIndex != null) {
      setState(() {
        _isPlaying = true;
      });
      await audioPlayer.play();
    }
  }

  Future<void> pause() async {
    setState(() {
      _isPlaying = false;
    });
    await audioPlayer.pause();
  }

  Future<void> _nextTrack() async {
    int nextIndex = (_currentlyPlayingIndex ?? 0) + 1;
    if (nextIndex >= widget.audioFiles.length) nextIndex = 0;
    await playSong(nextIndex);
  }

  Future<void> _previousTrack() async {
    int previousIndex = (_currentlyPlayingIndex ?? 0) - 1;
    if (previousIndex < 0) previousIndex = widget.audioFiles.length - 1;
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
      'album': "Unknown Album",
      'artist': "Unknown Artist",
    };
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openSearchScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          audioFiles: widget.audioFiles.map((path) => File(path)).toList(),
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
        _currentlyPlayingIndex! >= widget.audioFiles.length) {
      return const SizedBox.shrink();
    }

    if (_currentIndex == 1) {
      return const SizedBox.shrink();
    }

    final currentFilePath = widget.audioFiles[_currentlyPlayingIndex!];
    final currentSong = currentFilePath.split(Platform.pathSeparator).last;

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
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: const Color(0xFF2C2C2E),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
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
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.skip_previous_rounded,
                      color: Colors.white,
                      size: 24.0,
                    ),
                    onPressed: _previousTrack,
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 34.0,
                    ),
                    onPressed: () => _isPlaying ? pause() : play(),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                      size: 24.0,
                    ),
                    onPressed: _nextTrack,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white38,
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
    final navItems = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.play_arrow_rounded, 'label': 'Play'},
      {'icon': Icons.settings_rounded, 'label': 'Settings'},
    ];

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF2C2C2E),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
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
                horizontal: isSelected ? 16.0 : 12.0,
                vertical: 8.0,
              ),
              decoration: isSelected
                  ? BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(20),
                    )
                  : const BoxDecoration(),
              child: Row(
                children: [
                  Icon(
                    item['icon'] as IconData,
                    color: isSelected ? Colors.white : Colors.white54,
                    size: 22,
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    Text(
                      item['label'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF181818),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFF282828),
                width: 1.0,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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
                        color: const Color(0xFF282828),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Pocketo Play",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: Colors.white70),
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
            audioFiles: widget.audioFiles.map((path) => File(path)).toList(),
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
          ),
          PlayScreen(
            audioFiles: widget.audioFiles.map((path) => File(path)).toList(),
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
          SettingsScreen(
            audioFiles: widget.audioFiles.map((path) => File(path)).toList(),
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
