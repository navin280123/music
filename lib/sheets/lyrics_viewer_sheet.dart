import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/core/app_theme.dart';
import 'package:music/services/lyrics_service.dart';

class LyricsViewerSheet extends StatefulWidget {
  final String filePath;
  final AudioPlayer audioPlayer;

  const LyricsViewerSheet({
    super.key,
    required this.filePath,
    required this.audioPlayer,
  });

  static void show(BuildContext context, String filePath, AudioPlayer audioPlayer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LyricsViewerSheet(
        filePath: filePath,
        audioPlayer: audioPlayer,
      ),
    );
  }

  @override
  State<LyricsViewerSheet> createState() => _LyricsViewerSheetState();
}

class _LyricsViewerSheetState extends State<LyricsViewerSheet> {
  List<LyricLine> _lyrics = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  int _activeLyricIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
    widget.audioPlayer.positionStream.listen((pos) {
      if (!mounted || _lyrics.isEmpty) return;
      final newIndex = LyricsService.getActiveLyricIndex(_lyrics, pos);
      if (newIndex != _activeLyricIndex) {
        setState(() {
          _activeLyricIndex = newIndex;
        });
        _scrollToActiveLine();
      }
    });
  }

  Future<void> _loadLyrics() async {
    final result = await LyricsService.getLyricsForFile(widget.filePath);
    if (mounted) {
      setState(() {
        _lyrics = result;
        _isLoading = false;
      });
    }
  }

  void _scrollToActiveLine() {
    if (_activeLyricIndex >= 0 && _scrollController.hasClients) {
      const itemHeight = 48.0;
      final targetOffset = (_activeLyricIndex * itemHeight) - 120.0;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final fileName = widget.filePath.split(Platform.pathSeparator).last;
    final title = fileName.split('.').first;
    final sheetBg = isDark ? const Color(0xFF18181A) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final activeCol = isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary;
    final subTextCol = isDark ? Colors.white54 : const Color(0xFF64748B);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: activeCol.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.mic_external_on_rounded, color: activeCol, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textCol,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _lyrics.isNotEmpty ? "Synced Karaoke Lyrics" : "Lyrics",
                        style: TextStyle(color: subTextCol, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: subTextCol),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          // Lyrics Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _lyrics.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        itemCount: _lyrics.length,
                        itemBuilder: (context, index) {
                          final line = _lyrics[index];
                          final isActive = index == _activeLyricIndex;

                          return GestureDetector(
                            onTap: () {
                              widget.audioPlayer.seek(line.timestamp);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? activeCol.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                line.text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isActive ? 18.0 : 15.0,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                  color: isActive
                                      ? activeCol
                                      : textCol.withValues(alpha: 0.6),
                                  height: 1.4,
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

  Widget _buildEmptyState(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final subTextCol = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lyrics_outlined, size: 54, color: subTextCol),
            const SizedBox(height: 16),
            Text(
              "No Lyrics Found",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Place a .lrc file in the same folder with the same name as this song, or add embedded lyrics to the track.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: subTextCol, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
