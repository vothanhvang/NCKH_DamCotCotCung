package vn.edu.hcmut.nckh.src_ces_studio

import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "src_ces.native/file_dialog"
    private val reqCreateDoc = 43091
    private val reqOpenDoc = 43092
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "openTextFile") {
                    if (pendingResult != null) {
                        result.error("BUSY", "File dialog already open.", null)
                        return@setMethodCallHandler
                    }
                    pendingResult = result
                    pendingBytes = null
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, reqOpenDoc)
                    return@setMethodCallHandler
                }
                if (call.method != "saveFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val fileName = call.argument<String>("fileName") ?: "SRC_CES_Output.pdf"
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null) {
                    result.error("BAD_ARGS", "Missing file bytes.", null)
                    return@setMethodCallHandler
                }
                if (pendingResult != null) {
                    result.error("BUSY", "Save dialog already open.", null)
                    return@setMethodCallHandler
                }
                pendingResult = result
                pendingBytes = bytes

                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mimeType
                    putExtra(Intent.EXTRA_TITLE, fileName)
                }
                @Suppress("DEPRECATION")
                startActivityForResult(intent, reqCreateDoc)
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == reqOpenDoc) {
            val res = pendingResult
            pendingResult = null
            pendingBytes = null
            if (res == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                res.success(null)
                return
            }
            try {
                val txt = contentResolver.openInputStream(data.data!!)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
                res.success(txt)
            } catch (e: Exception) {
                res.error("IO_ERROR", e.message ?: "Error reading file on Android", null)
            }
            return
        }
        if (requestCode != reqCreateDoc) return

        val res = pendingResult
        val bytes = pendingBytes
        pendingResult = null
        pendingBytes = null
        if (res == null) return

        if (resultCode != Activity.RESULT_OK || data?.data == null || bytes == null) {
            res.success(null)
            return
        }
        val uri = data.data!!
        try {
            contentResolver.openOutputStream(uri)?.use { out ->
                out.write(bytes)
                out.flush()
            } ?: throw IllegalStateException("Cannot open output stream.")

            var displayName = uri.lastPathSegment ?: uri.toString()
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && cursor.moveToFirst()) {
                    displayName = cursor.getString(idx)
                }
            }
            res.success(displayName)
        } catch (e: Exception) {
            res.error("IO_ERROR", e.message ?: "Error saving file on Android", null)
        }
    }
}
