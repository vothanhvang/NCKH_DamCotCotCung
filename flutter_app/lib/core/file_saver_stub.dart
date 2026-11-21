import 'dart:typed_data';

Future<String?> saveBinaryFile(
  String fileName,
  Uint8List bytes,
  String mimeType,
) async {
  throw UnsupportedError('Platform not supported');
}

Future<String?> openTextFile({String ext = 'json'}) async {
  throw UnsupportedError('Platform not supported');
}
