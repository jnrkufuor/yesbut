import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart' hide Text;
import 'package:provider/provider.dart';

import 'translations.dart';

/// Drop-in replacement for Flutter's [m.Text] that shows strings in the
/// app language. Screens import this instead of material's Text, so every
/// label in the app follows the language setting.
class Text extends StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
    this.semanticsLabel,
    this.translate = true,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
    this.semanticsLabel,
    this.translate = true,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  final String? semanticsLabel;
  /// False for brand words and names that must never change.
  final bool translate;

  InlineSpan _span(InlineSpan s, Translations t) {
    if (s is TextSpan) {
      return TextSpan(
        text: s.text == null ? null : t.tr(s.text!),
        style: s.style,
        recognizer: s.recognizer,
        semanticsLabel: s.semanticsLabel,
        children: s.children?.map((c) => _span(c, t)).toList(),
      );
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final t = translate ? context.watch<Translations?>() : null;
    if (textSpan != null) {
      return m.Text.rich(
        t == null ? textSpan! : _span(textSpan!, t),
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
        softWrap: softWrap,
        semanticsLabel: semanticsLabel,
      );
    }
    return m.Text(
      t == null ? data! : t.tr(data!),
      style: style,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel,
    );
  }
}

/// For strings that aren't shown through [Text] (hints, tooltips, toasts).
extension TrContext on BuildContext {
  String tr(String s) => watch<Translations?>()?.tr(s) ?? s;
}
