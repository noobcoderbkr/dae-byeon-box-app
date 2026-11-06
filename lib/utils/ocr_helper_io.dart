// lib/utils/ocr_helper_io.dart
// 네이티브(Android/iOS) 전용 OCR 구현 — Google ML Kit 사용.
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 이미지 파일에서 한국어 텍스트를 인식해 반환한다.
Future<String> recognizeKoreanText(String imagePath) async {
  final inputImage = InputImage.fromFilePath(imagePath);
  final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
  try {
    final recognized = await recognizer.processImage(inputImage);
    return recognized.text;
  } finally {
    await recognizer.close();
  }
}

/// 이 플랫폼에서 OCR(ML Kit) 사용 가능 여부.
const bool kOcrSupported = true;
