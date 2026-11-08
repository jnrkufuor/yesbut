import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';

import '../models/analysis.dart';
import '../services/ingestion/scanner.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/loopy.dart';
import 'flows.dart';
import 'paste_screen.dart';

class _Page {
  final String path;
  final String text;
  const _Page(this.path, this.text);
}

/// Multi-page scanner: snap each page, we OCR it on-device, then analyze
/// everything together.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _scanner = Scanner();
  final _pages = <_Page>[];
  bool _busy = false;
  bool _sensitive = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _add({bool gallery = false}) async {
    try {
      final img = await _scanner.capture(fromGallery: gallery);
      if (img == null) return;
      setState(() => _busy = true);
      final text = await _scanner.readText(img.path);
      if (!mounted) return;
      if (text.trim().length < 20) {
        showToast(context, 'Couldn\'t read text on that one. Try more light and hold steady.');
      } else {
        setState(() => _pages.add(_Page(img.path, text)));
      }
    } catch (e) {
      if (mounted) showToast(context, 'Camera trouble: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _analyze() {
    final text = _pages.map((p) => p.text).join('\n\n');
    Flows.analyzeText(
      context,
      text: text,
      title: 'Scanned contract (${_pages.length} page${_pages.length == 1 ? '' : 's'})',
      kind: SourceKind.scan,
      sensitive: _sensitive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _pages.length;
    return InputScaffold(
      accent: GColors.red,
      icon: Icons.document_scanner_rounded,
      title: 'Point at the ',
      titleSerif: 'paper',
      subtitle: 'One photo per page. The words are read right on your phone.',
      bottom: BigButton(
        label: n == 0 ? 'Add a page to start' : 'Check $n page${n == 1 ? '' : 's'}',
        icon: Icons.arrow_forward_rounded,
        color: GColors.ink,
        onTap: n == 0 ? null : _analyze,
      ),
      children: [
        HeroAction(
          color: GColors.red,
          icon: 'scan',
          title: n == 0 ? 'Snap a page' : 'Snap page ${n + 1}',
          subtitle: 'Hold steady, good light helps',
          busy: _busy,
          onTap: () => _add(),
        ),
        const SizedBox(height: 12),
        Center(child: OutlinePill(label: 'Pick from photos', icon: 'upload', onTap: _busy ? null : () => _add(gallery: true))),
        const SizedBox(height: 18),
        SensitiveToggle(
          value: _sensitive,
          suggest: _pages.any((p) => looksPersonal(p.text)),
          onChanged: (v) => setState(() => _sensitive = v),
        ),
        const SizedBox(height: 26),
        Row(children: [
          const Text('YOUR PAGES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.1, color: GColors.inkSoft)),
          const Spacer(),
          if (n > 0) Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GColors.inkSoft)),
        ]),
        const SizedBox(height: 10),
        if (n == 0)
          Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: GColors.line, width: 1),
            ),
            child: const Text('Pages you snap show up here', style: TextStyle(fontSize: 13, color: GColors.inkFaint)),
          )
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.74,
            children: [
              for (var i = 0; i < n; i++)
                _PageThumb(
                  index: i + 1,
                  path: _pages[i].path,
                  onRemove: () => setState(() => _pages.removeAt(i)),
                ),
            ],
          ),
      ],
    );
  }
}

class _PageThumb extends StatelessWidget {
  const _PageThumb({required this.index, required this.path, required this.onRemove});
  final int index;
  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(GRadius.md),
      child: Stack(fit: StackFit.expand, children: [
        DecoratedBox(decoration: BoxDecoration(border: Border.all(color: GColors.line))),
        Image.file(File(path), fit: BoxFit.cover),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: GColors.ink, borderRadius: BorderRadius.circular(99)),
            child: Text('$index',
                style: const TextStyle(color: GColors.white, fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: Pressable(
            onTap: onRemove,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(color: GColors.white, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 16, color: GColors.ink),
            ),
          ),
        ),
      ]),
    );
  }
}
