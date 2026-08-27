import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NativeAudioPlaybackService {
  static const _channel = MethodChannel('app.eloq.eloq/native_audio');

  bool _available = true;
  bool _started = false;

  Future<bool> start({int sampleRate = 24000}) async {
    if (!_available) return false;
    if (_started) return true;
    try {
      await _channel.invokeMethod<void>('start', {'sampleRate': sampleRate});
      _started = true;
      return true;
    } on MissingPluginException {
      _available = false;
      return false;
    } on PlatformException {
      _started = false;
      return false;
    }
  }

  Future<bool> write(Uint8List bytes) async {
    if (bytes.isEmpty || !await start()) return false;
    try {
      await _channel.invokeMethod<void>('write', bytes);
      return true;
    } on PlatformException {
      _started = false;
      return false;
    }
  }

  Future<void> stop() async {
    if (!_available || !_started) return;
    _started = false;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // The platform player is optional outside Android.
    }
  }
}

final nativeAudioPlaybackServiceProvider =
    Provider<NativeAudioPlaybackService>((ref) {
  final service = NativeAudioPlaybackService();
  ref.onDispose(service.stop);
  return service;
});
