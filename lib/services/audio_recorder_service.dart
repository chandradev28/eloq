import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class AudioRecorderService {
  AudioRecorderService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<String> start() async {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/eloq-${const Uuid().v4()}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 128000,
      ),
      path: path,
    );
    return path;
  }

  Future<String?> stop() => _recorder.stop();

  Future<void> cancel() => _recorder.cancel();

  Future<Stream<Uint8List>> startPcmStream() {
    return _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      ),
    );
  }

  Future<bool> isRecording() => _recorder.isRecording();

  Future<Amplitude> getAmplitude() => _recorder.getAmplitude();

  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      _recorder.onAmplitudeChanged(interval);

  Future<void> dispose() => _recorder.dispose();
}

final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final service = AudioRecorderService();
  ref.onDispose(service.dispose);
  return service;
});
