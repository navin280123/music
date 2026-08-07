import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:music/HomeScreen.dart';
import 'package:music/PlayScreen.dart';
import 'package:music/ProfileScreen.dart';
import 'package:music/SearchScreen.dart';
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

    // Hide mini player on Play screen (index 1) since full player is active
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
        margin: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1F123F),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: const Color(0xFFC77DFF).withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFF7B2CBF).withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(20.0),
            onTap: () {
              _onTabTapped(1);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B2CBF), Color(0xFFC77DFF)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC77DFF).withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentSong,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11.0,
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
                      size: 22.0,
                    ),
                    onPressed: _previousTrack,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: const Color(0xFFC77DFF),
                      size: 32.0,
                    ),
                    onPressed: () => _isPlaying ? pause() : play(),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                      size: 22.0,
                    ),
                    onPressed: _nextTrack,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
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
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 4),
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF1D123A),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF7B2CBF).withValues(alpha: 0.25),
            blurRadius: 10,
            spreadRadius: -1,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
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
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 18.0 : 12.0,
                vertical: 8.0,
              ),
              decoration: isSelected
                  ? BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9D4EDD).withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    )
                  : const BoxDecoration(),
              child: Row(
                children: [
                  Icon(
                    item['icon'] as IconData,
                    color: isSelected ? Colors.white : Colors.white54,
                    size: isSelected ? 24 : 22,
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    Text(
                      item['label'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
      backgroundColor: const Color(0xFF0F0B1E),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF180E30),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B2CBF), Color(0xFFC77DFF)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7B2CBF).withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Pocketo Play",
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search_rounded, color: Colors.white),
                      onPressed: _openSearchScreen,
                      tooltip: 'Search Music',
                    ),
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
          ProfileScreen(
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
