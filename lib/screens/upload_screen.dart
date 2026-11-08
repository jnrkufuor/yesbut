import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/loopy.dart';
import 'flows.dart';
import 'paste_screen.dart';

/// Blue sheet the Upload card grows into; the button opens the file picker.
class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

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
        onTap: () => Flows.upload(context),
      ),
      children: [
        HeroAction(
          color: GColors.blue,
          icon: 'upload',
          title: 'Pick a PDF or .txt',
          subtitle: 'From your files, Drive or downloads',
          onTap: () => Flows.upload(context),
        ),
        const SizedBox(height: 18),
        const InfoRow(icon: 'scan', text: 'Scanned paper? Use Scan it instead, it reads text from photos.'),
      ],
    );
  }
}
