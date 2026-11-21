// Lưu & mở tệp kèm hộp thoại hệ điều hành chuẩn trên Windows (Win32) & Android (SAF)
import 'dart:io';
import 'package:flutter/services.dart';

const MethodChannel _fileDialogChannel = MethodChannel('src_ces.native/file_dialog');

Future<String?> saveBinaryFile(
  String fileName,
  Uint8List bytes,
  String mimeType,
) async {
  final dotIdx = fileName.lastIndexOf('.');
  final ext = (dotIdx >= 0 && dotIdx < fileName.length - 1)
      ? fileName.substring(dotIdx + 1).toLowerCase()
      : 'pdf';

  if (Platform.isWindows || Platform.isAndroid) {
    try {
      final chosen = await _fileDialogChannel.invokeMethod<String>('saveFile', {
        'fileName': fileName,
        'ext': ext,
        'mimeType': mimeType,
        'bytes': bytes,
      });
      return chosen;
    } on MissingPluginException {
      // Fallback khi chạy unit test không có native channel
    }
  }

  Directory targetDir;
  if (Platform.isWindows) {
    final home = Platform.environment['USERPROFILE'] ?? Directory.current.path;
    targetDir = Directory('$home\\Documents\\SRC_CES_NonlinearStudio');
  } else if (Platform.isAndroid) {
    targetDir = Directory('/storage/emulated/0/Download/SRC_CES_Studio');
  } else {
    targetDir = Directory.systemTemp;
  }
  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }
  final file = File('${targetDir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String?> openTextFile({String ext = 'json'}) async {
  if (Platform.isWindows || Platform.isAndroid) {
    try {
      return await _fileDialogChannel.invokeMethod<String>('openTextFile', {'ext': ext});
    } on MissingPluginException {
      return null;
    }
  }
  return null;
}
