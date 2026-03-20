import 'package:image_picker/image_picker.dart';

import 'picked_image.dart';

final ImagePicker _picker = ImagePicker();

Future<PickedImage?> pickImageFromGallery() async {
  final image = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
  );
  if (image == null) return null;

  final bytes = await image.readAsBytes();
  final mimeType = _guessMimeType(image.name);
  return PickedImage(bytes: bytes, mimeType: mimeType, name: image.name);
}

String _guessMimeType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

