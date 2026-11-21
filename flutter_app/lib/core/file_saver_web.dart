// Lưu & mở tệp (.docx, .pdf, .dxf, .csv, .json) trực tiếp trên trình duyệt Web (GitHub Pages)
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

@JS('showSaveFilePicker')
external JSPromise<JSObject> _showSaveFilePicker(JSObject options);

Future<String?> saveBinaryFile(
  String fileName,
  Uint8List bytes,
  String mimeType,
) async {
  if (web.window.hasProperty('showSaveFilePicker'.toJS).toDart) {
    try {
      final dotIdx = fileName.lastIndexOf('.');
      final ext = (dotIdx >= 0) ? fileName.substring(dotIdx).toLowerCase() : '.pdf';
      final desc = switch (ext) {
        '.docx' => 'Microsoft Word Document',
        '.pdf' => 'PDF Document',
        '.dxf' => 'AutoCAD DXF Drawing',
        '.csv' => 'CSV Table',
        '.json' => 'SRC-CES Project File',
        _ => 'File',
      };

      final acceptMap = JSObject();
      acceptMap.setProperty(mimeType.toJS, <JSString>[ext.toJS].toJS);
      final typeEntry = JSObject();
      typeEntry.setProperty('description'.toJS, desc.toJS);
      typeEntry.setProperty('accept'.toJS, acceptMap);

      final opts = JSObject();
      opts.setProperty('suggestedName'.toJS, fileName.toJS);
      opts.setProperty('types'.toJS, <JSObject>[typeEntry].toJS);

      final handle = await _showSaveFilePicker(opts).toDart;
      final writable = await handle.callMethod<JSPromise<JSObject>>('createWritable'.toJS).toDart;
      final blobParts = <web.BlobPart>[bytes.toJS].toJS;
      final blob = web.Blob(blobParts, web.BlobPropertyBag(type: mimeType));
      await writable.callMethod<JSPromise<JSAny?>>('write'.toJS, blob).toDart;
      await writable.callMethod<JSPromise<JSAny?>>('close'.toJS).toDart;

      final savedName = (handle.getProperty('name'.toJS) as JSString?)?.toDart ?? fileName;
      return savedName;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('AbortError') || msg.contains('aborted')) {
        return null;
      }
    }
  }

  final blobParts = <web.BlobPart>[bytes.toJS].toJS;
  final blob = web.Blob(blobParts, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return fileName;
}

Future<String?> openTextFile({String ext = 'json'}) async {
  final completer = Completer<String?>();
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = '.$ext,application/json,text/plain';
  input.style.display = 'none';
  web.document.body?.appendChild(input);

  void finish(String? val) {
    if (!completer.isCompleted) completer.complete(val);
    input.remove();
  }

  input.onchange = ((web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      finish(null);
      return;
    }
    final file = files.item(0);
    if (file == null) {
      finish(null);
      return;
    }
    final reader = web.FileReader();
    reader.onload = ((web.Event _) => finish((reader.result as JSString?)?.toDart)).toJS;
    reader.onerror = ((web.Event _) => finish(null)).toJS;
    reader.readAsText(file);
  }).toJS;

  input.oncancel = ((web.Event _) => finish(null)).toJS;
  input.click();
  return completer.future;
}
