import 'package:flutter/material.dart';

import '../models/analysis.dart';
import '../services/catalog_repository.dart';
import '../services/ingestion/document_reader.dart';
import '../services/ingestion/web_fetcher.dart';
import 'analyzing_screen.dart';
import 'link_screen.dart';
import 'paste_screen.dart';
import 'result_screen.dart';
import 'scan_screen.dart';
import 'search_screen.dart';

/// Central place for "start a check" navigation so every entry point
/// (home tiles, library, share intents later) behaves the same.
class Flows {
  static Future<void> paste(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const PasteScreen()));

  static Future<void> link(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const LinkScreen()));

  static Future<void> scan(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const ScanScreen()));

  static Future<void> upload(BuildContext context) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final doc = await DocumentReader().pickAndRead();
      if (doc == null) return;
      await nav.push(MaterialPageRoute(
        builder: (_) => AnalyzingScreen(
          load: () async => ContractInput(
            text: doc.text,
            title: doc.name.isEmpty ? 'Uploaded document' : doc.name,
            kind: SourceKind.file,
          ),
        ),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  static Future<void> analyzeText(
    BuildContext context, {
    required String text,
    required String title,
    required SourceKind kind,
    String? ref,
  }) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AnalyzingScreen(
          load: () async => ContractInput(text: text, title: title, kind: kind, ref: ref),
        ),
      ));

  static Future<void> analyzeUrl(BuildContext context, String url,
          {String? title, SourceKind kind = SourceKind.link, DateTime? pageDate}) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AnalyzingScreen(
          fetching: true,
          load: () async {
            // One quiet retry for pages that build themselves with scripts.
            final page = await WebFetcher().fetchWithRetry(url);
            return ContractInput(
              text: page.text,
              title: title ?? _cleanTitle(page.displayName),
              kind: kind,
              ref: kind == SourceKind.library ? url : page.url,
              pageDate: page.updated ?? pageDate,
            );
          },
        ),
      ));

  static Future<void> search(BuildContext context, {String? query}) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: query)));

  static Future<void> library(BuildContext context, CatalogItem item) =>
      analyzeUrl(context, item.url,
          title: '${item.name} · ${item.kind}', kind: SourceKind.library);

  static Future<void> open(BuildContext context, AnalysisResult r) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ResultScreen(result: r)));

  static String _cleanTitle(String t) {
    final parts = t.split(RegExp(r'\s[|\-–—]\s'));
    final s = parts.first.trim();
    return s.length > 60 ? '${s.substring(0, 57)}…' : s;
  }
}
