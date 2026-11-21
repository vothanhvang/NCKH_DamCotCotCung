// ============================================================================
// HỆ THỐNG ĐA NGÔN NGỮ SONG NGỮ TIẾNG VIỆT / TIẾNG ANH (VI / EN)
// ============================================================================

enum AppLang { vi, en }

extension AppLangExt on AppLang {
  String get code => this == AppLang.vi ? 'vi' : 'en';
  bool get isVi => this == AppLang.vi;
}

/// Chọn chuỗi hiển thị theo ngôn ngữ đang bật (Tiếng Việt / Tiếng Anh)
String tr(AppLang lang, String vi, String en) => lang == AppLang.vi ? vi : en;
