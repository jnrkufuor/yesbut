import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PickedDocument {
  final String name;
  final String text;
  const PickedDocument(this.name, this.text);
}

class DocumentException implements Exception {
  final String message;
  DocumentException(this.message);
  @override
  String toString() => message;
}

/// Lets the user pick a PDF / text / HTML file and extracts its text.
class DocumentReader {
  static const extensions = ['pdf', 'txt', 'md', 'html', 'htm', 'rtf'];

  Future<PickedDocument?> pickAndRead() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) throw DocumentException('Couldn\'t open that file.');
    final text = extract(file.name, bytes);
    if (text.trim().split(RegExp(r'\s+')).length < 20) {
      throw DocumentException(
          'We couldn\'t find readable text in that file. If it\'s a photo or scanned PDF, use "Scan" instead.');
    }
    return PickedDocument(_prettyName(file.name), text);
  }

  static String extract(String name, Uint8List bytes) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        {
          final doc = PdfDocument(inputBytes: bytes);
          try {
            return PdfTextExtractor(doc).extractText();
          } finally {
            doc.dispose();
          }
        }
      case 'html':
      case 'htm':
        return html_parser.parse(_utf8(bytes)).body?.text ?? '';
      case 'rtf':
        return _utf8(bytes)
            .replaceAll(RegExp(r'\\par[d]?'), '\n')
            .replaceAll(RegExp(r'\{\\[^{}]*\}|\\[a-z]+-?\d* ?|[{}]'), '');
      default:
        return _utf8(bytes);
    }
  }

  static String _utf8(Uint8List b) {
    try {
      return utf8.decode(b);
    } catch (_) {
      return latin1.decode(b);
    }
  }

  static String _prettyName(String file) {
    final base = file.contains('.') ? file.substring(0, file.lastIndexOf('.')) : file;
    return base.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  }
}
