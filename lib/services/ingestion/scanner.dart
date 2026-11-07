import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Captures pages with the camera (or gallery) and reads them on-device
/// with ML Kit text recognition. Nothing leaves the phone for this step.
class Scanner {
  final _picker = ImagePicker();
  TextRecognizer? _recognizer;

  Future<XFile?> capture({bool fromGallery = false}) => _picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 92,
        maxWidth: 2400,
      );

  Future<String> readText(String imagePath) async {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    final result =
        await _recognizer!.processImage(InputImage.fromFilePath(imagePath));
    // Join blocks with blank lines so sentences don't run together.
    return result.blocks.map((b) => b.text.replaceAll('\n', ' ')).join('\n\n');
  }

  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
