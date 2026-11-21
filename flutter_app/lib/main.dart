// ============================================================================
// ĐIỂM KHỞI CHẠY ỨNG DỤNG: SRC-CES NONLINEAR STUDIO (DẦM & CỘT BÊ TÔNG CỐT CỨNG)
// ============================================================================
// Đóng gói chạy độc lập đa nền tảng: Windows x64 (.exe), Android ARM64 (.apk
// tối ưu cho Xiaomi Pad 8 Pro & Xiaomi 13T Pro) và Web GitHub Pages!
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/studio_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SrcCesStudioApp());
}

class SrcCesStudioApp extends StatefulWidget {
  const SrcCesStudioApp({super.key});

  @override
  State<SrcCesStudioApp> createState() => _SrcCesStudioAppState();
}

class _SrcCesStudioAppState extends State<SrcCesStudioApp> {
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    final isWindowsDesktop = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    final darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF060B18),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF06B6D4),
        secondary: Color(0xFF10B981),
        surface: Color(0xFF0F172A),
      ),
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'DejaVuSans'),
    );

    final lightTheme = ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0F3D6E),
        secondary: Color(0xFF0F766E),
      ),
      textTheme: ThemeData.light().textTheme.apply(fontFamily: 'DejaVuSans'),
    );

    return MaterialApp(
      title: 'SRC–CES Nonlinear Studio — Phân tích Phi tuyến & Thiết kế Dầm Cột Cốt Cứng',
      debugShowCheckedModeBanner: false,
      theme: _darkMode ? darkTheme : lightTheme,
      // Bảo vệ chống crash UI Automation trên Flutter Windows engine
      builder: (context, child) => ExcludeSemantics(
        excluding: isWindowsDesktop,
        child: child ?? const SizedBox.shrink(),
      ),
      home: StudioHomeScreen(
        darkMode: _darkMode,
        onThemeChanged: (v) => setState(() => _darkMode = v),
      ),
    );
  }
}
