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
      title: 'Upload a file',
      subtitle: 'A PDF or text file from your phone. We read it right here.',
      bottom: BigButton(
        label: 'Choose a file',
        icon: Icons.arrow_forward_rounded,
        color: GColors.white,
        onTap: () => Flows.upload(context),
      ),
      children: [
        Pressable(
          onTap: () => Flows.upload(context),
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              color: GColors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: GColors.white.withValues(alpha: 0.5), width: 1),
            ),
            child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              LoopyIcon('upload', size: 64, color: GColors.white, stroke: 1.6),
              SizedBox(height: 10),
              Text('Tap to pick a PDF or .txt', style: TextStyle(color: GColors.white, fontSize: 14)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Text('Scanned paper? Use Scan it instead, it reads text from photos.',
            style: TextStyle(color: GColors.white.withValues(alpha: 0.8), fontSize: 13, height: 1.45)),
      ],
    );
  }
}
