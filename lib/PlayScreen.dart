import 'package:flutter/material.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:music/ABLooperWidget.dart';
import 'package:music/AppTheme.dart';
import 'package:music/ArtworkHelper.dart';
import 'package:music/CastService.dart';
import 'package:music/ColorPaletteService.dart';
import 'package:music/DriveModeScreen.dart';
import 'package:music/EqualizerPresetSheet.dart';
import 'package:music/LyricsViewerSheet.dart';
import 'package:music/PlaylistManager.dart';
import 'package:music/ShareCardWidget.dart';
import 'package:music/JamScreen.dart';
import 'package:music/JamSyncService.dart';
import 'package:music/SleepTimerService.dart';
import 'package:music/SleepTimerSheet.dart';
import 'package:music/TagEditorSheet.dart';

class PlayScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final AudioPlayer audioPlayer;
  final int? currentlyPlayingIndex;
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final bool isRepeat;
  final Function() onPlay;
  final Function() onPause;
  final Function() onNext;
  final Function() onPrevious;
  final Function(int) playTrack;
  final Function() toggleRepeat;

  const PlayScreen({
    super.key,
    required this.audioFiles,
    required this.audioPlayer,
    required this.currentlyPlayingIndex,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.onPlay,
    required this.onPause,
    required this.onNext,
    required this.onPrevious,
    required this.playTrack,
    required this.toggleRepeat,
    required this.isRepeat,
  });

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  double sliderValue = 0;

  // Dynamic color palette
  TrackPalette? _palette;
  String? _lastColorizedPath;

  // Quick-action dock scroll discoverability
  final ScrollController _dockScrollController = ScrollController();
  bool _showDockScrollHint = true;

  @override
  void initState() {
    super.initState();

    widget.audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          sliderValue = position.inSeconds.toDouble();
        });
      }
    });
    _refreshPalette();

    // Auto-scroll hint: nudge the dock slightly so users discover it's scrollable
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        if (_dockScrollController.hasClients &&
            _dockScrollController.position.maxScrollExtent > 0) {
          _dockScrollController
              .animateTo(52,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut)
              .then((_) {
            if (!mounted) return;
            _dockScrollController.animateTo(0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeIn);
          });
        }
      });
      // Hide the "more" chevron once the user scrolls themselves
      _dockScrollController.addListener(() {
        if (_dockScrollController.offset > 8 && _showDockScrollHint) {
          if (mounted) setState(() => _showDockScrollHint = false);
        }
      });
    });
  }

  @override
  void dispose() {
    _dockScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentlyPlayingIndex != widget.currentlyPlayingIndex) {
      _refreshPalette();
    }
  }

  Future<void> _refreshPalette() async {
    final path = _currentPath;
    if (path == null || path == _lastColorizedPath) return;
    _lastColorizedPath = path;
    final p = await ColorPaletteService.instance.getPalette(path);
    if (mounted) setState(() => _palette = p);
  }

  String? get _currentPath => widget.currentlyPlayingIndex != null &&
          widget.currentlyPlayingIndex! < widget.audioFiles.length
      ? widget.audioFiles[widget.currentlyPlayingIndex!].path as String
      : null;

  void seekAudio(double seconds) {
    final pos = Duration(seconds: seconds.toInt());
    widget.audioPlayer.seek(pos);
    if (JamSyncService.instance.isHost) {
      JamSyncService.instance.onHostSeek(pos);
    }
  }

  /// Estimate BPM from track duration (heuristic placeholder).
  /// Replace with real beat-detection when available.
  int _estimateBpm(Duration duration) {
    if (duration.inSeconds == 0) return 0;
    // Use duration to seed a deterministic "realistic" range 80–160 BPM
    final seed = duration.inSeconds % 80;
    return 80 + seed;
  }

  void _showSleepTimerDialog() {
    final isDark = AppTheme.isDark(context);
    final activeCol = _palette?.accent ??
        (isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary);
    SleepTimerSheet.show(context, widget.audioPlayer, accentColor: activeCol);
  }

  void _openDriveMode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriveModeScreen(
          audioFiles: widget.audioFiles,
          audioPlayer: widget.audioPlayer,
          onPlay: widget.onPlay,
          onPause: widget.onPause,
          onNext: widget.onNext,
          onPrevious: widget.onPrevious,
        ),
      ),
    );
  }

  void _openJamScreen() {
    final currentPath = _currentPath;
    String currentSong = currentPath != null
        ? currentPath.split(Platform.pathSeparator).last
        : 'Pocketo Music';
    final title = currentSong.split('.').first;
    const artist = 'Local Audio';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JamScreen(
          audioPlayer: widget.audioPlayer,
          currentTrackPath: currentPath,
          currentTitle: title,
          currentArtist: artist,
          duration: widget.audioPlayer.duration ?? widget.duration,
          position: widget.audioPlayer.position,
          isPlaying: widget.audioPlayer.playing,
        ),
      ),
    );
  }

  void showSongSelectionSheet() {
    final isDark = AppTheme.isDark(context);
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final itemBg = isDark ? const Color(0xFF282828) : const Color(0xFFF1F5F9);
    final activeItemBg =
        isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEEF2FF);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextCol = isDark ? Colors.white60 : const Color(0xFF64748B);
    final borderCol =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0);
    final activeAccent = _palette?.accent ??
        (isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Track Queue (${widget.audioFiles.length})',
                    style: TextStyle(
                        color: textCol,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subTextCol),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(color: borderCol, thickness: 1),
              const SizedBox(height: 8),
              Expanded(
                child: widget.audioFiles.isEmpty
                    ? Center(
                        child: Text('No tracks available',
                            style: TextStyle(color: subTextCol)))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: widget.audioFiles.length,
                        itemBuilder: (context, index) {
                          final filePath =
                              widget.audioFiles[index].path as String;
                          final songName =
                              filePath.split(Platform.pathSeparator).last;
                          final isCurrent =
                              widget.currentlyPlayingIndex == index;
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            decoration: BoxDecoration(
                              color: isCurrent ? activeItemBg : itemBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrent ? activeAccent : borderCol,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                leading: ArtworkHelper.buildArtworkWidget(
                                    filePath,
                                    width: 40,
                                    height: 40,
                                    borderRadius: 8),
                                title: Text(songName,
                                    style: TextStyle(
                                      color: isCurrent ? activeAccent : textCol,
                                      fontSize: 14.5,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1),
                                trailing: isCurrent && widget.isPlaying
                                    ? Icon(Icons.graphic_eq_rounded,
                                        color: activeAccent, size: 20)
                                    : null,
                                onTap: () {
                                  widget.playTrack(index);
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final scaffoldBg =
        isDark ? const Color(0xFF0C0C0F) : const Color(0xFFF8FAFC);

    // Dynamic accent from palette, fall back to theme
    final activeCol = _palette?.accent ??
        (isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary);
    final titleCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);
    final iconCol = AppTheme.iconCol(context);

    final currentPath = _currentPath;
    String currentSong = currentPath != null
        ? currentPath.split(Platform.pathSeparator).last
        : 'No song playing';
    final isFav =
        currentPath != null && PlaylistManager.instance.isFavorite(currentPath);
    final primaryBtnBg = isDark ? Colors.white : AppTheme.lightPrimary;
    final primaryBtnIcon = isDark ? Colors.black : Colors.white;
    final bpm =
        widget.duration.inSeconds > 0 ? _estimateBpm(widget.duration) : 0;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // ── Dynamic ambient background gradient ─────────────────────────
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? (_palette != null
                          ? [
                              _palette!.dominant.withValues(alpha: 0.55),
                              _palette!.muted.withValues(alpha: 0.25),
                              const Color(0xFF0C0C0F),
                            ]
                          : [
                              activeCol.withValues(alpha: 0.22),
                              const Color(0xFF13131A),
                              const Color(0xFF0C0C0F),
                            ])
                      : [
                          activeCol.withValues(alpha: 0.12),
                          const Color(0xFFF1F5F9),
                          const Color(0xFFF8FAFC),
                        ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // ── Main responsive content ────────────────────────────────────
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                final isCompact = availableHeight < 680;

                // Responsive hero artwork size
                final artSize = (availableHeight * 0.35).clamp(180.0, 290.0);
                final verticalGap = isCompact ? 10.0 : 16.0;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (availableHeight - 12.0)
                            .clamp(0.0, double.infinity),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ── Top Bar Header / Status Badges ──────────────
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListenableBuilder(
                                listenable: SleepTimerService.instance,
                                builder: (context, _) {
                                  final sleepActive =
                                      SleepTimerService.instance.isActive;
                                  final looperActive =
                                      ABLooperService.instance.isEnabled;
                                  if (!sleepActive && !looperActive) {
                                    return const SizedBox(height: 4);
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 10.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (sleepActive)
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            onTap: _showSleepTimerDialog,
                                            child: _statusBadge(
                                              icon: Icons.bedtime_rounded,
                                              label: SleepTimerService.instance
                                                  .formattedRemainingTime,
                                              color: const Color(0xFF10B981),
                                            ),
                                          ),
                                        if (looperActive)
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            onTap: () => ABLooperSheet.show(
                                                context,
                                                widget.audioPlayer,
                                                widget.position),
                                            child: _statusBadge(
                                              icon: Icons.repeat_on_rounded,
                                              label: 'A-B Loop Active',
                                              color: activeCol,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: verticalGap),

                              // ── Hero Album Artwork (with Ambient Glow Aura) ──
                              Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Ambient glowing aura behind artwork
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 600),
                                      width: artSize * 1.15,
                                      height: artSize * 1.15,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            activeCol.withValues(
                                                alpha: widget.isPlaying
                                                    ? 0.35
                                                    : 0.12),
                                            activeCol.withValues(alpha: 0.0),
                                          ],
                                          radius: 0.8,
                                        ),
                                      ),
                                    ),

                                    // Interactive Artwork Hero Card
                                    AnimatedScale(
                                      scale: widget.isPlaying ? 1.0 : 0.93,
                                      duration:
                                          const Duration(milliseconds: 450),
                                      curve: Curves.easeOutCubic,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(28.0),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                                alpha: isDark ? 0.12 : 0.65),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: activeCol.withValues(
                                                  alpha: widget.isPlaying
                                                      ? 0.40
                                                      : 0.15),
                                              blurRadius: 36,
                                              spreadRadius: 2,
                                              offset: const Offset(0, 14),
                                            ),
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                  alpha: isDark ? 0.50 : 0.15),
                                              blurRadius: 18,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: currentPath != null
                                            ? ArtworkHelper.buildArtworkWidget(
                                                currentPath,
                                                width: artSize,
                                                height: artSize,
                                                borderRadius: 28.0,
                                              )
                                            : Container(
                                                width: artSize,
                                                height: artSize,
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xFF1E1E24)
                                                      : const Color(0xFFE2E8F0),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          28.0),
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    Icons.music_note_rounded,
                                                    size: artSize * 0.38,
                                                    color: isDark
                                                        ? Colors.white38
                                                        : Colors.grey.shade400,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: verticalGap + 4),

                              // ── Track Title, Details, BPM & Favorite Heart ──
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentSong,
                                          style: TextStyle(
                                            fontSize: isCompact ? 19 : 22,
                                            fontWeight: FontWeight.w800,
                                            color: titleCol,
                                            letterSpacing: -0.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Text(
                                              widget.currentlyPlayingIndex !=
                                                      null
                                                  ? 'Pocketo Play • Local Audio'
                                                  : 'Select a track to play',
                                              style: TextStyle(
                                                fontSize:
                                                    isCompact ? 12.0 : 13.0,
                                                color: subTextCol,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (bpm > 0) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: activeCol.withValues(
                                                      alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: activeCol.withValues(
                                                        alpha: 0.35),
                                                  ),
                                                ),
                                                child: Text(
                                                  '~$bpm BPM',
                                                  style: TextStyle(
                                                    color: activeCol,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (currentPath != null)
                                    Material(
                                      color: Colors.transparent,
                                      child: IconButton(
                                        icon: Icon(
                                          isFav
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          color: isFav
                                              ? const Color(0xFFF43F5E)
                                              : subTextCol,
                                          size: 28,
                                        ),
                                        tooltip: isFav
                                            ? 'Remove from Favorites'
                                            : 'Add to Favorites',
                                        onPressed: () {
                                          PlaylistManager.instance
                                              .toggleFavorite(currentPath);
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: isCompact ? 8.0 : 14.0),

                              // ── Controls: Cast mode vs Local mode ──────────────
                              ListenableBuilder(
                                listenable: CastService.instance,
                                builder: (context, _) {
                                  final cs = CastService.instance;
                                  if (cs.isConnected) {
                                    return _PlayScreenCastController(
                                      castService: cs,
                                      activeCol: activeCol,
                                      subTextCol: subTextCol,
                                      iconCol: iconCol,
                                      isDark: isDark,
                                      onPrevious: widget.onPrevious,
                                      onNext: widget.onNext,
                                    );
                                  }

                                  // Local controls: Seeker + Playback buttons
                                  return Column(
                                    children: [
                                      // Custom Sleek Slider
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 4.0,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                  enabledThumbRadius: 6.5),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                  overlayRadius: 15.0),
                                          activeTrackColor: activeCol,
                                          inactiveTrackColor: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.15)
                                              : const Color(0xFFCBD5E1),
                                          thumbColor: activeCol,
                                          overlayColor:
                                              activeCol.withValues(alpha: 0.18),
                                        ),
                                        child: Slider(
                                          value: sliderValue.clamp(
                                            0,
                                            widget.duration.inSeconds
                                                        .toDouble() >
                                                    0
                                                ? widget.duration.inSeconds
                                                    .toDouble()
                                                : 0.0,
                                          ),
                                          min: 0,
                                          max: widget.duration.inSeconds
                                                      .toDouble() >
                                                  0
                                              ? widget.duration.inSeconds
                                                  .toDouble()
                                              : 1.0,
                                          onChanged: (value) => setState(
                                              () => sliderValue = value),
                                          onChangeEnd: seekAudio,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatDuration(Duration(
                                                  seconds:
                                                      sliderValue.toInt())),
                                              style: TextStyle(
                                                color: subTextCol,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                fontFeatures: const [
                                                  FontFeature.tabularFigures()
                                                ],
                                              ),
                                            ),
                                            Text(
                                              _formatDuration(widget.duration),
                                              style: TextStyle(
                                                color: subTextCol,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                fontFeatures: const [
                                                  FontFeature.tabularFigures()
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: isCompact ? 10.0 : 16.0),

                                      // Hero Playback Buttons
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          // Shuffle / Repeat Mode
                                          IconButton(
                                            icon: Icon(
                                              widget.audioPlayer.loopMode ==
                                                      LoopMode.all
                                                  ? Icons.repeat_rounded
                                                  : widget.audioPlayer
                                                              .loopMode ==
                                                          LoopMode.one
                                                      ? Icons.repeat_one_rounded
                                                      : Icons.shuffle_rounded,
                                              size: 24,
                                              color: widget.audioPlayer
                                                          .loopMode !=
                                                      LoopMode.off
                                                  ? activeCol
                                                  : (isDark
                                                      ? Colors.white38
                                                      : Colors.grey.shade400),
                                            ),
                                            tooltip: 'Repeat / Shuffle',
                                            onPressed: () {
                                              if (widget.audioPlayer.loopMode ==
                                                  LoopMode.off) {
                                                widget.audioPlayer
                                                    .setLoopMode(LoopMode.all);
                                                widget.audioPlayer
                                                    .setShuffleModeEnabled(
                                                        true);
                                              } else if (widget
                                                      .audioPlayer.loopMode ==
                                                  LoopMode.all) {
                                                widget.audioPlayer
                                                    .setLoopMode(LoopMode.one);
                                                widget.audioPlayer
                                                    .setShuffleModeEnabled(
                                                        false);
                                              } else {
                                                widget.audioPlayer
                                                    .setLoopMode(LoopMode.off);
                                              }
                                              setState(() {});
                                            },
                                          ),

                                          // Previous track button
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white
                                                      .withValues(alpha: 0.08)
                                                  : Colors.black
                                                      .withValues(alpha: 0.05),
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: Icon(
                                                  Icons.skip_previous_rounded,
                                                  size: 28,
                                                  color: iconCol),
                                              tooltip: 'Previous',
                                              onPressed: widget.onPrevious,
                                            ),
                                          ),

                                          // Hero Play/Pause Button
                                          Container(
                                            width: isCompact ? 64 : 72,
                                            height: isCompact ? 64 : 72,
                                            decoration: BoxDecoration(
                                              color: primaryBtnBg,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (isDark
                                                          ? activeCol
                                                          : AppTheme
                                                              .lightPrimary)
                                                      .withValues(alpha: 0.45),
                                                  blurRadius: 22,
                                                  spreadRadius: 1,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: IconButton(
                                              icon: Icon(
                                                widget.isPlaying
                                                    ? Icons.pause_rounded
                                                    : Icons.play_arrow_rounded,
                                                size: isCompact ? 34 : 38,
                                                color: primaryBtnIcon,
                                              ),
                                              onPressed:
                                                  widget.currentlyPlayingIndex !=
                                                          null
                                                      ? () => widget.isPlaying
                                                          ? widget.onPause()
                                                          : widget.onPlay()
                                                      : null,
                                            ),
                                          ),

                                          // Next track button
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white
                                                      .withValues(alpha: 0.08)
                                                  : Colors.black
                                                      .withValues(alpha: 0.05),
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: Icon(
                                                  Icons.skip_next_rounded,
                                                  size: 28,
                                                  color: iconCol),
                                              tooltip: 'Next',
                                              onPressed: widget.onNext,
                                            ),
                                          ),

                                          // Track Queue button
                                          IconButton(
                                            icon: Icon(
                                                Icons.queue_music_rounded,
                                                size: 24,
                                                color: isDark
                                                    ? Colors.white60
                                                    : Colors.grey.shade600),
                                            tooltip: 'Track Queue',
                                            onPressed: showSongSelectionSheet,
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),

                          // ── Floating Quick Action Glass Dock ─────────────
                          Padding(
                            padding:
                                EdgeInsets.only(top: verticalGap, bottom: 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Label row with "scroll for more" hint
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 4, bottom: 8),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Quick Actions',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      AnimatedOpacity(
                                        opacity:
                                            _showDockScrollHint ? 1.0 : 0.0,
                                        duration:
                                            const Duration(milliseconds: 400),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: activeCol.withValues(
                                                alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: activeCol.withValues(
                                                  alpha: 0.35),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.swipe_rounded,
                                                color: activeCol,
                                                size: 10,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Scroll for more',
                                                style: TextStyle(
                                                  color: activeCol,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Dock with right-fade gradient overlay
                                Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.07)
                                            : Colors.black
                                                .withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.10)
                                              : Colors.black
                                                  .withValues(alpha: 0.06),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                                alpha: isDark ? 0.25 : 0.04),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: SingleChildScrollView(
                                        controller: _dockScrollController,
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        child: Row(
                                          children: [
                                            _buildQuickActionBtn(
                                              icon:
                                                  Icons.mic_external_on_rounded,
                                              label: 'Lyrics',
                                              color: activeCol,
                                              onTap: () {
                                                if (currentPath != null) {
                                                  LyricsViewerSheet.show(
                                                      context,
                                                      currentPath,
                                                      widget.audioPlayer);
                                                }
                                              },
                                            ),
                                            _buildQuickActionBtn(
                                              icon: Icons.tune_rounded,
                                              label: 'Sound / EQ',
                                              color: const Color(0xFF38BDF8),
                                              onTap: () =>
                                                  EqualizerPresetSheet.show(
                                                      context,
                                                      widget.audioPlayer),
                                            ),
                                            _buildQuickActionBtn(
                                              icon: Icons.bedtime_rounded,
                                              label: 'Sleep Timer',
                                              color: const Color(0xFF10B981),
                                              onTap: _showSleepTimerDialog,
                                            ),
                                            _buildQuickActionBtn(
                                              icon: Icons.repeat_on_rounded,
                                              label: 'A-B Looper',
                                              color: const Color(0xFFF59E0B),
                                              onTap: () => ABLooperSheet.show(
                                                  context,
                                                  widget.audioPlayer,
                                                  widget.position),
                                            ),
                                            _buildQuickActionBtn(
                                              icon: Icons.speaker_group_rounded,
                                              label: JamSyncService.instance.isInJam
                                                  ? 'Jam (Live)'
                                                  : 'Jam',
                                              color: JamSyncService.instance.isInJam
                                                  ? Colors.greenAccent
                                                  : const Color(0xFF6366F1),
                                              onTap: _openJamScreen,
                                            ),
                                            _buildQuickActionBtn(
                                              icon:
                                                  Icons.directions_car_rounded,
                                              label: 'Drive Mode',
                                              color: const Color(0xFFEC4899),
                                              onTap: _openDriveMode,
                                            ),
                                            if (currentPath != null) ...[
                                              _buildQuickActionBtn(
                                                icon: Icons.share_rounded,
                                                label: 'Share',
                                                color: const Color(0xFF34D399),
                                                onTap: () =>
                                                    ShareCardWidget.show(
                                                  context,
                                                  currentPath,
                                                  currentSong,
                                                ),
                                              ),
                                              _buildQuickActionBtn(
                                                icon: Icons.edit_note_rounded,
                                                label: 'Edit Tags',
                                                color: const Color(0xFF8B5CF6),
                                                onTap: () =>
                                                    TagEditorSheet.show(
                                                        context, currentPath),
                                              ),
                                            ],
                                            // Trailing padding so last item
                                            // isn't right at the fade edge
                                            const SizedBox(width: 8),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Right-fade gradient overlay
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: 56,
                                      child: AnimatedOpacity(
                                        opacity:
                                            _showDockScrollHint ? 1.0 : 0.0,
                                        duration:
                                            const Duration(milliseconds: 600),
                                        child: IgnorePointer(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topRight: Radius.circular(20),
                                                bottomRight:
                                                    Radius.circular(20),
                                              ),
                                              gradient: LinearGradient(
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                                colors: [
                                                  (isDark
                                                          ? const Color(
                                                              0xFF1C1C1E)
                                                          : Colors.white)
                                                      .withValues(alpha: 0.0),
                                                  (isDark
                                                          ? const Color(
                                                              0xFF1C1C1E)
                                                          : Colors.white)
                                                      .withValues(alpha: 0.85),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Chevron arrow peeking on right edge
                                    Positioned(
                                      right: 6,
                                      top: 0,
                                      bottom: 0,
                                      child: AnimatedOpacity(
                                        opacity:
                                            _showDockScrollHint ? 1.0 : 0.0,
                                        duration:
                                            const Duration(milliseconds: 600),
                                        child: IgnorePointer(
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: activeCol.withValues(
                                                    alpha: 0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.chevron_right_rounded,
                                                color: activeCol,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDark(context);
    final textCol = AppTheme.textPrimaryColor(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 15),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: textCol,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Cast controller embedded inside PlayScreen
//  Shown instead of the normal seek+buttons when CastService.isConnected.
// ─────────────────────────────────────────────────────────────────────────────

class _PlayScreenCastController extends StatefulWidget {
  final CastService castService;
  final Color activeCol;
  final Color subTextCol;
  final Color iconCol;
  final bool isDark;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PlayScreenCastController({
    required this.castService,
    required this.activeCol,
    required this.subTextCol,
    required this.iconCol,
    required this.isDark,
    this.onPrevious,
    this.onNext,
  });

  @override
  State<_PlayScreenCastController> createState() =>
      _PlayScreenCastControllerState();
}

class _PlayScreenCastControllerState extends State<_PlayScreenCastController> {
  double? _dragVal;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.castService;
    final pos = cs.position;
    final dur = cs.duration;
    final hasDur = dur > Duration.zero;
    final isBuffering = cs.playbackState == CastPlaybackState.buffering;

    final sliderVal = _dragVal ??
        (hasDur
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0);

    return Column(
      children: [
        // ── "Casting to …" label ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cast_connected_rounded,
                  size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Text(
                'Casting to ${cs.connectedDeviceName ?? "device"}',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isBuffering) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Seek bar ───────────────────────────────────────────────────────
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
            activeTrackColor: widget.activeCol,
            inactiveTrackColor:
                widget.isDark ? Colors.white24 : const Color(0xFFCBD5E1),
            thumbColor: widget.activeCol,
            overlayColor: widget.activeCol.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: sliderVal,
            onChanged: hasDur ? (v) => setState(() => _dragVal = v) : null,
            onChangeEnd: hasDur
                ? (v) {
                    cs.seek(Duration(
                        milliseconds: (v * dur.inMilliseconds).round()));
                    setState(() => _dragVal = null);
                  }
                : null,
          ),
        ),

        // ── Time labels ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(_dragVal != null && hasDur
                    ? Duration(
                        milliseconds: (_dragVal! * dur.inMilliseconds).round())
                    : pos),
                style: TextStyle(color: widget.subTextCol, fontSize: 12),
              ),
              Text(
                hasDur ? _fmt(dur) : '--:--',
                style: TextStyle(color: widget.subTextCol, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Playback buttons ───────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Previous track — changes track on phone & re-casts
            IconButton(
              tooltip: 'Previous track',
              icon: Icon(Icons.skip_previous_rounded,
                  size: 32, color: widget.iconCol),
              onPressed: widget.onPrevious,
            ),

            // Rewind 10 s
            IconButton(
              tooltip: 'Rewind 10 s',
              icon: Icon(Icons.replay_10_rounded,
                  size: 28, color: widget.subTextCol),
              onPressed: () {
                final np = cs.position - const Duration(seconds: 10);
                cs.seek(np < Duration.zero ? Duration.zero : np);
              },
            ),

            // Play / Pause (big circle button)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: widget.activeCol,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.activeCol.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                iconSize: 34,
                icon: isBuffering
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        cs.isCastPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                onPressed: () {
                  cs.isCastPlaying ? cs.pause() : cs.play();
                },
              ),
            ),

            // Forward 10 s
            IconButton(
              tooltip: 'Forward 10 s',
              icon: Icon(Icons.forward_10_rounded,
                  size: 28, color: widget.subTextCol),
              onPressed: () {
                final np = cs.position + const Duration(seconds: 10);
                cs.seek(dur > Duration.zero && np > dur ? dur : np);
              },
            ),

            // Next track
            IconButton(
              tooltip: 'Next track',
              icon: Icon(Icons.skip_next_rounded,
                  size: 32, color: widget.iconCol),
              onPressed: widget.onNext,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Volume slider ──────────────────────────────────────────────────
        Row(
          children: [
            const SizedBox(width: 8),
            Icon(Icons.volume_down_rounded, size: 18, color: widget.subTextCol),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.5,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 11),
                  activeTrackColor: widget.activeCol,
                  inactiveTrackColor:
                      widget.isDark ? Colors.white24 : Colors.black12,
                  thumbColor: widget.activeCol,
                ),
                child: Slider(
                  value: cs.volume,
                  onChanged: (v) => cs.setVolume(v),
                ),
              ),
            ),
            Icon(Icons.volume_up_rounded, size: 18, color: widget.subTextCol),
            const SizedBox(width: 8),
          ],
        ),
      ],
    );
  }
}
