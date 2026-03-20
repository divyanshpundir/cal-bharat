// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

class WebPickedImage {
  const WebPickedImage({
    required this.dataUrl,
    required this.base64,
    required this.mimeType,
    required this.name,
  });

  final String dataUrl;
  final String base64;
  final String mimeType;
  final String name;
}

Future<WebPickedImage?> pickImageWithHtmlInput() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  input.style.display = 'none';
  html.document.body?.append(input);

  try {
    input.click();
    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return null;

    final file = files.first;
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoadEnd.first;

    final result = reader.result;
    if (result is! String || !result.startsWith('data:')) {
      throw Exception('Could not read image as data URL.');
    }

    // Example: data:image/png;base64,AAAA...
    final comma = result.indexOf(',');
    if (comma == -1) {
      throw Exception('Invalid data URL returned by browser.');
    }

    final meta = result.substring(0, comma); // data:image/png;base64
    final base64 = result.substring(comma + 1);

    final mime = _mimeFromDataUrlMeta(meta) ?? (file.type.isNotEmpty ? file.type : 'image/jpeg');
    return WebPickedImage(
      dataUrl: result,
      base64: base64,
      mimeType: mime,
      name: file.name,
    );
  } finally {
    input.remove();
  }
}

String? _mimeFromDataUrlMeta(String meta) {
  // meta: data:image/png;base64
  if (!meta.startsWith('data:')) return null;
  final withoutPrefix = meta.substring('data:'.length);
  final semi = withoutPrefix.indexOf(';');
  if (semi == -1) return null;
  final mime = withoutPrefix.substring(0, semi);
  return mime.isEmpty ? null : mime;
}

