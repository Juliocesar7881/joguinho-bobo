import 'package:flutter/services.dart';

/// Best-effort playback contract for the short success sound.
abstract interface class SuccessAudioService {
  /// Plays the success sound and reports whether native playback started.
  ///
  /// Audio is nonessential feedback, so implementations must return `false`
  /// instead of allowing a platform availability error to affect gameplay.
  Future<bool> playSuccess();
}

/// Android-backed success audio exposed by LexiNexo's native activity.
final class NativeSuccessAudioService implements SuccessAudioService {
  NativeSuccessAudioService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.lexinexo.app/audio';
  static const playSuccessMethod = 'playSuccess';

  final MethodChannel _channel;

  @override
  Future<bool> playSuccess() async {
    try {
      return await _channel.invokeMethod<bool>(playSuccessMethod) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
