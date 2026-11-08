import 'dart:io';

import 'package:flutter/material.dart';

import '../models/analysis.dart';
import '../services/ingestion/scanner.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return InputScaffold(
      accent: GColors.red,
      icon: Icons.document_scanner_rounded,
      title: 'Scan the contract',
      subtitle: 'Snap each page. Text is read right on your phone.',
      bottom: BigButton(
        label: _pages.isEmpty ? 'Add a page to start' : 'Check ${_pages.length} page${_pages.length == 1 ? '' : 's'}',
        icon: Icons.arrow_forward_rounded,
        color: GColors.white,
        onTap: _pages.isEmpty ? null : _analyze,
      ),
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.74,
          children: [
            for (var i = 0; i < _pages.length; i++)
              _PageThumb(
                index: i + 1,
                path: _pages[i].path,
                onRemove: () => setState(() => _pages.removeAt(i)),
              ),
            Pressable(
              onTap: _busy ? null : () => _add(),
              child: Container(
                decoration: BoxDecoration(
                  color: GColors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(GRadius.md),
                  border: Border.all(color: GColors.white.withValues(alpha: 0.5), width: 1),
                ),
                child: Center(
                  child: _busy
                      ? const HopDots(size: 9)
                      : const Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_a_photo_rounded, color: GColors.white, size: 30),
                          SizedBox(height: 8),
                          Text('Snap page',
                              style: TextStyle(color: GColors.white, fontWeight: FontWeight.w600)),
                        ]),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: _busy ? null : () => _add(gallery: true),
            icon: const Icon(Icons.photo_library_rounded, size: 18),
            label: const Text('Pick from photos instead'),
            style: TextButton.styleFrom(
              foregroundColor: GColors.white,
              textStyle: const TextStyle(fontFamily: AppTheme.font, fontWeight: FontWeight.w700),
            ),
          ),
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
