// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_image.dart';

Future<PickedImage?> pickImageFromGallery() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  // Some browsers are more reliable when the element is attached to the DOM.
  input.style.display = 'none';
  html.document.body?.append(input);

  input.click();

  try {
    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return null;

    final file = files.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);

    await reader.onLoadEnd.first;
    final result = reader.result;
    if (result is! ByteBuffer) {
      throw Exception('Could not read image bytes from browser.');
    }

    final bytes = Uint8List.view(result);
    final mime = file.type.isNotEmpty ? file.type : 'image/jpeg';
    final name = file.name;
    return PickedImage(bytes: bytes, mimeType: mime, name: name);
  } finally {
    input.remove();
  }
}

