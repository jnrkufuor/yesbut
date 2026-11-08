import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'ingestion/web_fetcher.dart';

/// A terms page you asked us to keep an eye on.
class WatchItem {
  final String url;
  final String title;
  final DateTime addedAt;
  final DateTime? lastChecked;
  final String? hash; // fingerprint of the page text last time
  final DateTime? pageDate; // "Last updated" the page showed last time
  final int? score; // score from the last full check
  final bool changed; // changed since you last looked
  final DateTime? changedAt;

  const WatchItem({
    required this.url,
    required this.title,
    required this.addedAt,
    this.lastChecked,
    this.hash,
    this.pageDate,
    this.score,
    this.changed = false,
    this.changedAt,
  });

  WatchItem copyWith({
    String? title,
    DateTime? lastChecked,
    String? hash,
    DateTime? pageDate,
    int? score,
    bool? changed,
    DateTime? changedAt,
  }) =>
      WatchItem(
        url: url,
        title: title ?? this.title,
        addedAt: addedAt,
        lastChecked: lastChecked ?? this.lastChecked,
        hash: hash ?? this.hash,
        pageDate: pageDate ?? this.pageDate,
        score: score ?? this.score,
        changed: changed ?? this.changed,
        changedAt: changedAt ?? this.changedAt,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'addedAt': addedAt.toIso8601String(),
        'lastChecked': lastChecked?.toIso8601String(),
        'hash': hash,
        'pageDate': pageDate?.toIso8601String(),
        'score': score,
        'changed': changed,
        'changedAt': changedAt?.toIso8601String(),
      };

  factory WatchItem.fromJson(Map<String, dynamic> j) => WatchItem(
        url: j['url'].toString(),
        title: (j['title'] ?? '').toString(),
        addedAt: DateTime.tryParse('${j['addedAt']}') ?? DateTime.now(),
        lastChecked: DateTime.tryParse('${j['lastChecked']}'),
        hash: j['hash']?.toString(),
        pageDate: DateTime.tryParse('${j['pageDate']}'),
        score: j['score'] is num ? (j['score'] as num).round() : null,
        changed: j['changed'] == true,
        changedAt: DateTime.tryParse('${j['changedAt']}'),
      );
}

/// Stores the watch list, re-checks pages (in the app and in the
/// background a couple of times a day) and sends a notification when one
/// changes.
class WatchService {
  static const _key = 'watchlist_v1';
  static const _task = 'yesbut-watch-check';
  static final _notes = FlutterLocalNotificationsPlugin();
  static bool _notesReady = false;

  // ------------------------------------------------------------ storage

  static Future<List<WatchItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((m) => WatchItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<WatchItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  // ------------------------------------------------------------ checking

  /// FNV-1a fingerprint of the page text (stable across app runs).
  static String fingerprint(String text) {
    final norm = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    var h = 0x811c9dc5;
    for (final c in norm.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return '${norm.length}-${h.toRadixString(16)}';
  }

  /// Re-fetches every watched page. Returns the updated list; items whose
  /// text or "last updated" date moved are marked [WatchItem.changed].
  static Future<(List<WatchItem>, List<WatchItem>)> checkAll(List<WatchItem> items) async {
    final out = <WatchItem>[];
    final newlyChanged = <WatchItem>[];
    for (final it in items) {
      try {
        final page = await WebFetcher().fetchWithRetry(it.url);
        final fp = fingerprint(page.text);
        final dateMoved = page.updated != null && it.pageDate != null && page.updated!.isAfter(it.pageDate!);
        final textMoved = it.hash != null && it.hash != fp;
        final now = DateTime.now();
        if ((textMoved || dateMoved) && !it.changed) {
          final c = it.copyWith(lastChecked: now, hash: fp, pageDate: page.updated, changed: true, changedAt: now);
          out.add(c);
          newlyChanged.add(c);
        } else {
          out.add(it.copyWith(lastChecked: now, hash: it.hash ?? fp, pageDate: page.updated ?? it.pageDate));
        }
      } catch (_) {
        out.add(it); // offline or blocked this time; try again later
      }
    }
    return (out, newlyChanged);
  }

  // ------------------------------------------------------------ notifications

  static Future<void> initNotifications() async {
    if (_notesReady) return;
    await _notes.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _notesReady = true;
  }

  static Future<void> askPermission() async {
    await initNotifications();
    await _notes
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> notifyChanged(List<WatchItem> changed) async {
    if (changed.isEmpty) return;
    await initNotifications();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'terms_changes',
        'Terms changes',
        channelDescription: 'When terms you watch are updated',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    final first = changed.first;
    await _notes.show(
      id: first.url.hashCode & 0x7fffffff,
      title: changed.length == 1 ? '${first.title} changed' : '${changed.length} terms you watch changed',
      body: changed.length == 1
          ? 'Their terms were updated. Open Yes,But to see what’s different.'
          : changed.map((c) => c.title).take(3).join(', '),
      notificationDetails: details,
    );
  }

  // ------------------------------------------------------------ background

  static Future<void> scheduleBackground() async {
    try {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _task,
        _task,
        frequency: const Duration(hours: 12),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {
      // Background checks are a bonus; the Live tab also checks when opened.
    }
  }
}

/// Runs in the background (no UI): re-check the watch list, notify on change.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    DartPluginRegistrant.ensureInitialized();
    try {
      final items = await WatchService.load();
      if (items.isEmpty) return true;
      final (updated, changed) = await WatchService.checkAll(items);
      await WatchService.save(updated);
      await WatchService.notifyChanged(changed);
    } catch (_) {}
    return true;
  });
}
