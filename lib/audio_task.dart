import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

  class AudioPlayerTask extends BackgroundAudioTask {
    final _player = AudioPlayer();

    @override
    Future<void> onStart(Map<String, dynamic>? params) async {
    final mediaItem = MediaItem(
      id: params!['id'],
      album: params['album'],
      title: params['title'],
      artist: params['artist'],
      duration: Duration(milliseconds: params['duration']),
    );
    AudioServiceBackground.setMediaItem(mediaItem);
    _player.play();
    _player.setUrl(params['url']);
    _player.play();
    _player.positionStream.listen((position) {
      AudioServiceBackground.setState(
      controls: [
        MediaControl.pause,
        MediaControl.stop,
      ],
      systemActions: [
        MediaAction.seek,
      ],
      playing: true,
      processingState: AudioProcessingState.ready,
      position: position,
      );
    });
    }

    @override
    Future<void> onPause() async {
    _player.pause();
    AudioServiceBackground.setState(
      controls: [
      MediaControl.play,
      MediaControl.stop,
      ],
      playing: false,
      processingState: AudioProcessingState.ready,
    );
    }

    @override
    Future<void> onStop() async {
    _player.stop();
    await _player.dispose();
    await super.onStop();
    }
  }