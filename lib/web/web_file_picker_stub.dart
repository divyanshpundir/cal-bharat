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
  throw UnsupportedError('HTML file input is only available on web.');
}

