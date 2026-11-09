import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Little sounds and taps for moments worth noticing (results found, a check
/// finished). Both can be switched off in Settings › Accessibility.
class Fx {
  static bool sounds = true;
  static bool haptics = true;
  static final _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  static Future<void> _play(String name) async {
    if (!sounds) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$name.wav'), volume: 0.6);
    } catch (_) {}
  }

  /// Search came back with results.
  static void found() {
    _play('found');
    if (haptics) HapticFeedback.lightImpact();
  }

  /// A check finished and the result is opening.
  static void done() {
    _play('done');
    if (haptics) HapticFeedback.mediumImpact();
  }

  /// Small confirmation (switches, picks).
  static void tick() {
    if (haptics) HapticFeedback.selectionClick();
  }
}
