import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/loopy.dart';
import 'flows.dart';
import 'paste_screen.dart';

/// Blue sheet the Upload card grows into; the button opens the file picker.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _sensitive = false;

  @override
  Widget build(BuildContext context) {
    return InputScaffold(
      accent: GColors.blue,
      icon: Icons.upload_file_rounded,
      title: 'Got it saved ',
      titleSerif: 'somewhere?',
      subtitle: 'A PDF or text file from your phone. We read it right here.',
      bottom: BigButton(
        label: 'Choose a file',
        icon: Icons.arrow_forward_rounded,
        color: GColors.ink,
        onTap: () => Flows.upload(context, sensitive: _sensitive),
      ),
      children: [
        HeroAction(
          color: GColors.blue,
          icon: 'upload',
          title: 'Pick a PDF or .txt',
          subtitle: 'From your files, Drive or downloads',
          onTap: () => Flows.upload(context, sensitive: _sensitive),
        ),
        const SizedBox(height: 14),
        SensitiveToggle(value: _sensitive, onChanged: (v) => setState(() => _sensitive = v)),
        const SizedBox(height: 18),
        const InfoRow(icon: 'scan', text: 'Scanned paper? Use Scan it instead, it reads text from photos.'),
      ],
    );
  }
}
