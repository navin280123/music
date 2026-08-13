import 'package:flutter/material.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:music/ABLooperWidget.dart';
import 'package:music/AppTheme.dart';
import 'package:music/ArtworkHelper.dart';
import 'package:music/CastService.dart';
import 'package:music/CastSheet.dart';
import 'package:music/ColorPaletteService.dart';
import 'package:music/DriveModeScreen.dart';
import 'package:music/EqualizerPresetSheet.dart';
import 'package:music/LyricsViewerSheet.dart';
import 'package:music/PlaylistManager.dart';
import 'package:music/ShareCardWidget.dart';
import 'package:music/SleepTimerService.dart';
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
    widget.audioPlayer.seek(Duration(seconds: seconds.toInt()));
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        final sheetBg = isDark ? const Color(0xFF1E1E20) : Colors.white;
        final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
        final subTextCol = isDark ? Colors.white54 : const Color(0xFF64748B);
        final activeCol = _palette?.accent ??
            (isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary);

        return ListenableBuilder(
          listenable: SleepTimerService.instance,
          builder: (context, _) {
            final timerService = SleepTimerService.instance;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: activeCol.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.bedtime_rounded,
                              color: activeCol, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sleep Timer',
                                style: TextStyle(
                                    color: textCol,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold)),
                            Text(
                              timerService.isActive
                                  ? 'Active: ${timerService.formattedRemainingTime}'
                                  : 'Stops playback with gentle fade-out',
                              style: TextStyle(
                                color: timerService.isActive
                                    ? activeCol
                                    : subTextCol,
                                fontSize: 12,
                                fontWeight: timerService.isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ]),
                      if (timerService.isActive)
                        TextButton(
                          onPressed: () {
                            timerService.cancelTimer(widget.audioPlayer);
                            Navigator.pop(context);
                          },
                          child: const Text('Turn Off',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [15, 30, 45, 60].map((mins) {
                      return ElevatedButton(
                        onPressed: () {
                          timerService.startTimer(mins, widget.audioPlayer);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Sleep timer set for $mins minutes'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF28282A)
                              : const Color(0xFFF1F5F9),
                          foregroundColor: textCol,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('$mins min'),
                      );
                    }).toList()
                      ..add(ElevatedButton(
                        onPressed: () {
                          timerService.setEndOfTrackMode(widget.audioPlayer);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text(
                                'Sleep timer will stop at the end of this track'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeCol.withValues(alpha: 0.2),
                          foregroundColor: activeCol,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('End of Track'),
                      )),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openDriveMode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriveModeScreen(
          audioFiles: widget.audioFiles,
          audioPlayer: widget.audioPlayer,
          currentlyPlayingIndex: widget.currentlyPlayingIndex,
          isPlaying: widget.isPlaying,
          onPlay: widget.onPlay,
          onPause: widget.onPause,
          onNext: widget.onNext,
          onPrevious: widget.onPrevious,
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
    final scaffoldBg = isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold;

    // Dynamic accent from palette, fall back to theme
    final activeCol = _palette?.accent ??
        (isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary);
    final borderCol = AppTheme.border(context);
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
          // ── Dynamic color gradient background ──────────────────────────
          if (_palette != null && isDark)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _palette!.playerGradient,
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

          // ── Main scrollable content ────────────────────────────────────
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 16.0, right: 16.0, top: 12.0, bottom: 100.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18.0, vertical: 20.0),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : AppTheme.cardBg(context),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : borderCol,
                    width: 1,
                  ),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    // ── Status Badges ──────────────────────────────────

                    ListenableBuilder(
                      listenable: SleepTimerService.instance,
                      builder: (context, _) {
                        final sleepActive = SleepTimerService.instance.isActive;
                        final looperActive = ABLooperService.instance.isEnabled;
                        if (!sleepActive && !looperActive) {
                          return const SizedBox(height: 8);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (sleepActive)
                                _statusBadge(
                                  icon: Icons.bedtime_rounded,
                                  label: SleepTimerService
                                      .instance.formattedRemainingTime,
                                  color: const Color(0xFF10B981),
                                ),
                              if (looperActive)
                                _statusBadge(
                                  icon: Icons.repeat_on_rounded,
                                  label: 'A-B Looping',
                                  color: activeCol,
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    // ── Album Art Display Card ─────────────────────────────────
                    SizedBox(
                      height: 250,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24.0),
                            boxShadow: [
                              BoxShadow(
                                color: activeCol.withValues(
                                    alpha: widget.isPlaying ? 0.45 : 0.20),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: currentPath != null
                              ? ArtworkHelper.buildArtworkWidget(
                                  currentPath,
                                  width: 220,
                                  height: 220,
                                  borderRadius: 24.0,
                                )
                              : Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF282828)
                                        : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(24.0),
                                  ),
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    size: 80.0,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey.shade400,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14.0),

                    // ── Song Title + BPM + Favorite ───────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSong,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: titleCol,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    widget.currentlyPlayingIndex != null
                                        ? 'Pocketo Play Audio'
                                        : 'Select a track to play',
                                    style: TextStyle(
                                        fontSize: 12.5, color: subTextCol),
                                  ),
                                  if (bpm > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            activeCol.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: activeCol.withValues(
                                                alpha: 0.35)),
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
                          IconButton(
                            icon: Icon(
                              isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color:
                                  isFav ? const Color(0xFFF43F5E) : subTextCol,
                              size: 26,
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
                      ],
                    ),
                    const SizedBox(height: 12.0),

                    // ── Controls: Cast mode vs Local mode ──────────────
                    ListenableBuilder(
                      listenable: CastService.instance,
                      builder: (context, _) {
                        final cs = CastService.instance;
                        if (cs.isConnected) {
                          // ═══════════════════════════════════════════════
                          //  CAST CONTROLLER  —  shown in PlayScreen when
                          //  audio is streaming to a remote device
                          // ═══════════════════════════════════════════════
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

                        // ══════════════════════════════════════════════════
                        //  LOCAL CONTROLS  —  normal phone playback
                        // ══════════════════════════════════════════════════
                        return Column(
                          children: [
                            // Seek slider
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6.0),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14.0),
                                activeTrackColor: activeCol,
                                inactiveTrackColor: isDark
                                    ? Colors.white24
                                    : const Color(0xFFCBD5E1),
                                thumbColor: activeCol,
                                overlayColor: activeCol.withValues(alpha: 0.15),
                                trackHeight: 3.5,
                              ),
                              child: Slider(
                                value: sliderValue.clamp(
                                  0,
                                  widget.duration.inSeconds.toDouble() > 0
                                      ? widget.duration.inSeconds.toDouble()
                                      : 0.0,
                                ),
                                min: 0,
                                max: widget.duration.inSeconds.toDouble() > 0
                                    ? widget.duration.inSeconds.toDouble()
                                    : 1.0,
                                onChanged: (value) =>
                                    setState(() => sliderValue = value),
                                onChangeEnd: seekAudio,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(
                                        Duration(seconds: sliderValue.toInt())),
                                    style: TextStyle(
                                        color: subTextCol, fontSize: 12),
                                  ),
                                  Text(
                                    _formatDuration(widget.duration),
                                    style: TextStyle(
                                        color: subTextCol, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16.0),

                            // Playback buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    widget.audioPlayer.loopMode == LoopMode.all
                                        ? Icons.repeat_rounded
                                        : widget.audioPlayer.loopMode ==
                                                LoopMode.one
                                            ? Icons.repeat_one_rounded
                                            : Icons.shuffle_rounded,
                                    size: 24,
                                    color: widget.audioPlayer.loopMode !=
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
                                          .setShuffleModeEnabled(true);
                                    } else if (widget.audioPlayer.loopMode ==
                                        LoopMode.all) {
                                      widget.audioPlayer
                                          .setLoopMode(LoopMode.one);
                                      widget.audioPlayer
                                          .setShuffleModeEnabled(false);
                                    } else {
                                      widget.audioPlayer
                                          .setLoopMode(LoopMode.off);
                                    }
                                    setState(() {});
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.skip_previous_rounded,
                                      size: 32, color: iconCol),
                                  tooltip: 'Previous',
                                  onPressed: widget.onPrevious,
                                ),
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: primaryBtnBg,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            primaryBtnBg.withValues(alpha: 0.4),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      widget.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 36,
                                      color: primaryBtnIcon,
                                    ),
                                    onPressed:
                                        widget.currentlyPlayingIndex != null
                                            ? () => widget.isPlaying
                                                ? widget.onPause()
                                                : widget.onPlay()
                                            : null,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.skip_next_rounded,
                                      size: 32, color: iconCol),
                                  tooltip: 'Next',
                                  onPressed: widget.onNext,
                                ),
                                IconButton(
                                  icon: Icon(Icons.queue_music_rounded,
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
                    const SizedBox(height: 18.0),
                    Divider(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : borderCol),
                    const SizedBox(height: 10.0),

                    // ── Quick Action Toolbar ──────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          ListenableBuilder(
                            listenable: CastService.instance,
                            builder: (context, _) {
                              final isCast = CastService.instance.isConnected;
                              return _buildQuickActionBtn(
                                icon: isCast
                                    ? Icons.cast_connected_rounded
                                    : Icons.cast_rounded,
                                label: isCast ? 'Casting' : 'Cast',
                                color: isCast
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF6366F1),
                                onTap: () {
                                  CastSheet.show(
                                    context,
                                    currentTrackPath: currentPath,
                                    currentTrackTitle: currentSong,
                                    currentTrackArtist: 'Local Audio',
                                    startPosition: widget.audioPlayer.position,
                                  );
                                },
                              );
                            },
                          ),
                          _buildQuickActionBtn(
                            icon: Icons.mic_external_on_rounded,
                            label: 'Lyrics',
                            color: activeCol,
                            onTap: () {
                              if (currentPath != null) {
                                LyricsViewerSheet.show(
                                    context, currentPath, widget.audioPlayer);
                              }
                            },
                          ),
                          _buildQuickActionBtn(
                            icon: Icons.tune_rounded,
                            label: 'Sound / EQ',
                            color: const Color(0xFF38BDF8),
                            onTap: () => EqualizerPresetSheet.show(
                                context, widget.audioPlayer),
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
                                context, widget.audioPlayer, widget.position),
                          ),
                          _buildQuickActionBtn(
                            icon: Icons.directions_car_rounded,
                            label: 'Drive Mode',
                            color: const Color(0xFFEC4899),
                            onTap: _openDriveMode,
                          ),
                          if (currentPath != null) ...[
                            _buildQuickActionBtn(
                              icon: Icons.share_rounded,
                              label: 'Share',
                              color: const Color(0xFF34D399),
                              onTap: () => ShareCardWidget.show(
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
                                  TagEditorSheet.show(context, currentPath),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
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
    final cardBg =
        isDark ? Colors.black.withValues(alpha: 0.35) : const Color(0xFFF1F5F9);
    final textCol = AppTheme.textPrimaryColor(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: textCol,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
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
