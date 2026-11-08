import 'dart:io';

import 'package:flutter/services.dart';

/// Something that arrived from outside the app: a home-screen widget tap
/// (open Scan, Paste…) or content shared from another app.
class Incoming {
  const Incoming({this.action, this.text, this.subject, this.files = const [], this.types = const []});
  final String? action; // widget: scan | upload | paste | link | history | home
  final String? text;
  final String? subject;
  final List<String> files;
  final List<String> types;

  bool get isShare => action == null;

  factory Incoming.fromMap(Map m) => m['kind'] == 'action'
      ? Incoming(action: m['action']?.toString())
      : Incoming(
          text: m['text']?.toString(),
          subject: m['subject']?.toString(),
          files: ((m['files'] as List?) ?? const []).map((e) => e.toString()).toList(),
          types: ((m['types'] as List?) ?? const []).map((e) => e.toString()).toList(),
        );
}

/// Bridge to the Android side (MainActivity.kt).
class IncomingService {
  static const _ch = MethodChannel('yesbut/incoming');

  /// Calls [onIncoming] for whatever opened the app, then for anything that
  /// arrives while it's open.
  static Future<void> listen(void Function(Incoming) onIncoming) async {
    if (!Platform.isAndroid) return;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'incoming' && call.arguments is Map) onIncoming(Incoming.fromMap(call.arguments as Map));
    });
    try {
      final first = await _ch.invokeMethod<Map>('initial');
      if (first != null) onIncoming(Incoming.fromMap(first));
    } catch (_) {}
  }

  /// Ask the home-screen widget to redraw (e.g. after a new check).
  static Future<void> refreshWidget() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('updateWidget');
    } catch (_) {}
  }
}
