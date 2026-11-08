import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';

import '../models/analysis.dart';
import '../services/catalog_repository.dart';
import '../services/ingestion/document_reader.dart';
import '../services/ingestion/web_fetcher.dart';
import '../services/ingestion/scanner.dart';
import '../services/incoming.dart';
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

  static Future<void> upload(BuildContext context, {bool sensitive = false}) async {
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
            sensitive: sensitive,
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
    bool sensitive = false,
  }) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AnalyzingScreen(
          load: () async => ContractInput(text: text, title: title, kind: kind, ref: ref, sensitive: sensitive),
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


/// Content shared into Yes,But from another app.
/// - Screenshots: read on the phone (OCR), all pages together.
/// - PDF / text files: text pulled out of the file.
/// - A link (or a message that's mostly a link): fetched and checked.
/// - Plain text: checked if it's long enough, otherwise opened in Paste.
Future<void> shareIn(BuildContext context, Incoming inc) async {
  final title = (inc.subject ?? '').trim();
  if (inc.files.isNotEmpty) {
    final images = <String>[], docs = <String>[];
    for (var i = 0; i < inc.files.length; i++) {
      final t = i < inc.types.length ? inc.types[i] : '';
      (t.startsWith('image/') || RegExp(r'\.(png|jpe?g|webp)$').hasMatch(inc.files[i]) ? images : docs).add(inc.files[i]);
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AnalyzingScreen(
        load: () async {
          final parts = <String>[];
          if (images.isNotEmpty) {
            final scanner = Scanner();
            try {
              for (final p in images) {
                parts.add(await scanner.readText(p));
              }
            } finally {
              await scanner.dispose();
            }
          }
          for (final p in docs) {
            parts.add(DocumentReader.extract(p, await File(p).readAsBytes()));
          }
          final text = parts.join('\n\n');
          if (text.trim().split(RegExp(r'\s+')).length < 20) {
            throw DocumentException('We couldn’t read enough text in what you shared. Try clearer screenshots, or copy the text instead.');
          }
          return ContractInput(
            text: text,
            title: title.isNotEmpty
                ? title
                : images.isNotEmpty
                    ? 'Shared screenshots (${images.length})'
                    : 'Shared document',
            kind: images.isNotEmpty ? SourceKind.scan : SourceKind.file,
          );
        },
      ),
    ));
    return;
  }
  final text = (inc.text ?? '').trim();
  if (text.isEmpty) return;
  final url = RegExp(r'https?://\S+').firstMatch(text)?.group(0);
  final words = text.split(RegExp(r'\s+')).length;
  if (url != null && words < 40) {
    await Flows.analyzeUrl(context, url);
  } else if (words >= 60) {
    await Flows.analyzeText(context, text: text, title: title.isNotEmpty ? title : 'Shared text', kind: SourceKind.paste);
  } else {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PasteScreen(initialText: text, initialTitle: title)));
  }
}
