import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class SleepTimerService extends ChangeNotifier {
  static final SleepTimerService _instance = SleepTimerService._internal();
  static SleepTimerService get instance => _instance;

  SleepTimerService._internal();

  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isActive = false;
  bool _isEndOfTrackMode = false;
  double _originalVolume = 1.0;

  int get remainingSeconds => _remainingSeconds;
  bool get isActive => _isActive;
  bool get isEndOfTrackMode => _isEndOfTrackMode;

  String get formattedRemainingTime {
    if (!_isActive) return "Off";
    if (_isEndOfTrackMode) return "End of Track";
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  /// Starts sleep timer with duration in minutes
  void startTimer(int minutes, AudioPlayer audioPlayer) {
    cancelTimer(audioPlayer);

    _remainingSeconds = minutes * 60;
    _isActive = true;
    _isEndOfTrackMode = false;
    _originalVolume = audioPlayer.volume > 0 ? audioPlayer.volume : 1.0;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _isActive = false;
        notifyListeners();
        await _stopPlaybackWithFade(audioPlayer);
      } else {
        _remainingSeconds--;
        // Fade out during last 20 seconds
        if (_remainingSeconds <= 20 && _remainingSeconds > 0) {
          final fadeFactor = _remainingSeconds / 20.0;
          await audioPlayer.setVolume(_originalVolume * fadeFactor);
        }
        notifyListeners();
      }
    });
  }

  /// Sets sleep timer to stop playback at the end of the current track
  void setEndOfTrackMode(AudioPlayer audioPlayer) {
    cancelTimer(audioPlayer);
    _isActive = true;
    _isEndOfTrackMode = true;
    notifyListeners();
  }

  /// Called when a song naturally finishes if end of track mode is active
  Future<void> onSongCompleted(AudioPlayer audioPlayer) async {
    if (_isEndOfTrackMode) {
      _isActive = false;
      _isEndOfTrackMode = false;
      notifyListeners();
      await audioPlayer.pause();
    }
  }

  /// Cancels any active sleep timer and restores volume
  void cancelTimer(AudioPlayer audioPlayer) {
    _timer?.cancel();
    _timer = null;
    _remainingSeconds = 0;
    _isActive = false;
    _isEndOfTrackMode = false;
    audioPlayer.setVolume(_originalVolume);
    notifyListeners();
  }

  Future<void> _stopPlaybackWithFade(AudioPlayer audioPlayer) async {
    try {
      await audioPlayer.pause();
      await audioPlayer.setVolume(_originalVolume);
    } catch (e) {
      debugPrint("Error pausing audio on sleep timer expiration: $e");
    }
  }
}
