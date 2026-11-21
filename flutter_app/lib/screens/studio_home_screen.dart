// ============================================================================
// MÀN HÌNH CHÍNH ADAPTIVE: SRC-CES NONLINEAR STUDIO (DESKTOP / TABLET / PHONE / WEB)
// ============================================================================
// Tương thích hoàn hảo mọi độ phân giải:
//   • Windows PC màn hình rộng (>= 980px): Sidebar tham số trái cố định + Không gian 3D/2D rộng.
//   • Xiaomi Pad 8 Pro & Xiaomi 13T Pro (< 980px): Ngăn kéo Drawer tham số mượt mà,
//     tối ưu toàn bộ màn hình cho mô phỏng 3D xoay/zoom cảm ứng & phẫu thuật mặt cắt.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/src_cad_exporter.dart';
import '../core/src_engine.dart';
import '../core/src_report_exporter.dart';
import '../core/file_saver_stub.dart'
    if (dart.library.io) '../core/file_saver_io.dart'
    if (dart.library.js_interop) '../core/file_saver_web.dart';
import '../widgets/src_cad_preview_panel.dart';
import '../widgets/src_charts_multicode_panel.dart';
import '../widgets/src_theory_code_panel.dart';
import '../widgets/src_viewport_2d_dissection.dart';
import '../widgets/src_viewport_3d.dart';

class StudioHomeScreen extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onThemeChanged;

  const StudioHomeScreen({
    super.key,
    required this.darkMode,
    required this.onThemeChanged,
  });

  @override
  State<StudioHomeScreen> createState() => _StudioHomeScreenState();
}

class _StudioHomeScreenState extends State<StudioHomeScreen> with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabCtrl;

  AppLang _lang = AppLang.vi;
  SrcMemberConfig _beamCfg = SrcLibraries.beamPresets().first.cfg;
  SrcMemberConfig _colCfg = SrcLibraries.columnPresets().first.cfg;
  MemberKind _activeKind = MemberKind.beam;

  late SrcAnalysisResult _result;
  ContourField _contourField = ContourField.stressSigmaX;
  double _probeXNorm = 0.50;
  double _deformScale = 16.0;
  double _loadStepFrac = 1.0;
  bool _animating = false;
  Timer? _animTimer;
  String? _statusMsg;

  SrcMemberConfig get _cfg => _activeKind == MemberKind.beam ? _beamCfg : _colCfg;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _result = SrcNonlinearEngine.solve(_cfg);
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _applyConfig(SrcMemberConfig next) {
    setState(() {
      if (next.kind == MemberKind.beam) {
        _beamCfg = next;
        _activeKind = MemberKind.beam;
      } else {
        _colCfg = next;
        _activeKind = MemberKind.column;
      }
      _result = SrcNonlinearEngine.solve(next);
    });
  }

  void _switchMemberKind(MemberKind kind) {
    if (_activeKind == kind) return;
    setState(() {
      _activeKind = kind;
      _result = SrcNonlinearEngine.solve(_cfg);
    });
  }

  void _toggleAnimation() {
    if (_animating) {
      _animTimer?.cancel();
      setState(() {
        _animating = false;
        _loadStepFrac = 1.0;
      });
      return;
    }
    setState(() {
      _animating = true;
      _loadStepFrac = 0.05;
    });
    _animTimer = Timer.periodic(const Duration(milliseconds: 65), (_) {
      if (!mounted) return;
      setState(() {
        _loadStepFrac += 0.04;
        if (_loadStepFrac > 1.05) _loadStepFrac = 0.05;
      });
    });
  }

  void _showToast(String msg) {
    setState(() => _statusMsg = msg);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontSize: 12)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _handleExportAction(String action) async {
    try {
      String? saved;
      switch (action) {
        case 'docx_vi':
          saved = await SrcReportExporter.exportDocx(_result, AppLang.vi);
          break;
        case 'docx_en':
          saved = await SrcReportExporter.exportDocx(_result, AppLang.en);
          break;
        case 'pdf_vi':
          saved = await SrcReportExporter.exportPdf(_result, AppLang.vi);
          break;
        case 'pdf_en':
          saved = await SrcReportExporter.exportPdf(_result, AppLang.en);
          break;
        case 'dxf':
          saved = await SrcCadExporter.exportDxf(_result);
          break;
        case 'cad_pdf':
          saved = await SrcCadExporter.exportDrawingPdf(_result, _lang);
          break;
        case 'csv':
          saved = await SrcReportExporter.exportCsv(_result);
          break;
        case 'save_json':
          final bytes = Uint8List.fromList(utf8.encode(_cfg.toPrettyJson()));
          saved = await saveBinaryFile('DuAn_SRC_CES.json', bytes, 'application/json');
          break;
        case 'open_json':
          final txt = await openTextFile(ext: 'json');
          if (txt != null && txt.trim().isNotEmpty) {
            final loaded = SrcMemberConfig.fromJsonString(txt);
            _applyConfig(loaded);
            _showToast(tr(_lang, 'Đã nạp dự án thành công!', 'Project loaded successfully!'));
          }
          return;
      }
      if (saved != null) {
        _showToast(tr(_lang, 'Đã lưu thành công: $saved', 'Saved successfully: $saved'));
      }
    } catch (e) {
      _showToast('Export Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.darkMode;
    final l = _lang;
    final bg = dark ? const Color(0xFF060B18) : const Color(0xFFF1F5F9);
    final barBg = dark ? const Color(0xFF0B1325) : Colors.white;
    final border = dark ? const Color(0xFF1F3050) : const Color(0xFFCBD5E1);
    final fg = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final sidebarContent = _buildParameterSidebar(dark, l, fg, border);

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: bg,
          drawer: wide
              ? null
              : Drawer(
                  width: 330,
                  backgroundColor: barBg,
                  child: SafeArea(child: sidebarContent),
                ),
          body: SafeArea(
            child: Column(
              children: [
                // ===========================================================
                // BIỂU NGỮ HỌC THUẬT — TRƯỜNG ĐH BÁCH KHOA - ĐHQG TP.HCM
                // ===========================================================
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: wide ? 8 : 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: dark
                          ? const [Color(0xFF091A38), Color(0xFF10316B), Color(0xFF091A38)]
                          : const [Color(0xFF0B2C59), Color(0xFF16438E), Color(0xFF0B2C59)],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFFACC15).withValues(alpha: 0.72),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school, size: wide ? 20 : 17, color: const Color(0xFFFFD700)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          tr(
                            l,
                            'Trường Đại học Bách Khoa - Đại học Quốc Gia TP. Hồ Chí Minh - Giảng viên hướng dẫn: PGS.TS Ngô Cường - Học viên thực hiện: Võ Thanh Vang (2670624) - Email: vothanhvang@gmail.com',
                            'Ho Chi Minh City University of Technology (VNU-HCM) - Advisor: Assoc. Prof. Dr. Ngo Cuong - Student: Vo Thanh Vang (2670624) - Email: vothanhvang@gmail.com',
                          ),
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: wide ? 14.5 : 12.6,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFFD700),
                            height: 1.32,
                            letterSpacing: 0.15,
                            shadows: const [
                              Shadow(color: Color(0x99000000), offset: Offset(0, 1), blurRadius: 2.5),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ===========================================================
                // THANH TIÊU ĐỀ CHÍNH HIỆN ĐẠI (HEADER + MODE + EXPORT + VI/EN)
                // ===========================================================
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: barBg,
                    border: Border(bottom: BorderSide(color: border)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth - 24),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!wide)
                              IconButton(
                                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                                icon: const Icon(Icons.tune, color: Color(0xFF06B6D4)),
                                tooltip: tr(l, 'Mở bảng thông số thiết kế', 'Open Design Parameters'),
                                visualDensity: VisualDensity.compact,
                              ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF2563EB)]),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.view_in_ar, size: 18, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SRC–CES Nonlinear Studio',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: fg),
                                  ),
                                  Text(
                                    tr(l, 'NCKH Cấp Quốc Gia • Dầm & Cột Bê Tông Cốt Cứng', 'National Research • Composite SRC Beams & Columns'),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 9.8, color: fg.withValues(alpha: 0.68)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bộ chuyển nhanh Dầm Cốt Cứng / Cột Cốt Cứng
                      SegmentedButton<MemberKind>(
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          selectedBackgroundColor: const Color(0xFF06B6D4),
                          selectedForegroundColor: Colors.black,
                        ),
                        segments: [
                          ButtonSegment(
                            value: MemberKind.beam,
                            icon: const Icon(Icons.horizontal_rule, size: 15),
                            label: Text(tr(l, 'Dầm Cốt Cứng', 'SRC Beam'), style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.bold)),
                          ),
                          ButtonSegment(
                            value: MemberKind.column,
                            icon: const Icon(Icons.view_week, size: 15),
                            label: Text(tr(l, 'Cột Cốt Cứng', 'SRC Column'), style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        selected: {_activeKind},
                        onSelectionChanged: (s) => _switchMemberKind(s.first),
                      ),

                      // Cụm công cụ: Trường ANSYS, Hoạt hình, Xuất báo cáo Song ngữ / CAD, Ngôn ngữ VI/EN, Giao diện Sáng/Tối
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Chọn trường màu ANSYS
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: dark ? const Color(0xFF131F38) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<ContourField>(
                                value: _contourField,
                                isDense: true,
                                dropdownColor: dark ? const Color(0xFF0F172A) : Colors.white,
                                style: TextStyle(fontSize: 11, color: fg),
                                items: [
                                  DropdownMenuItem(value: ContourField.stressSigmaX, child: Text(tr(l, 'Trường σ_x (MPa)', 'Stress σ_x'))),
                                  DropdownMenuItem(value: ContourField.strainEpsX, child: Text(tr(l, 'Biến dạng ε_x (‰)', 'Strain ε_x'))),
                                  DropdownMenuItem(value: ContourField.vonMises, child: const Text('Von Mises σ_vM')),
                                  DropdownMenuItem(value: ContourField.momentOrAxial, child: Text(tr(l, 'Mô-men M_z', 'Moment M_z'))),
                                  DropdownMenuItem(value: ContourField.deflection, child: Text(tr(l, 'Chuyển vị δ', 'Deflection δ'))),
                                  DropdownMenuItem(value: ContourField.confinementOrCrack, child: Text(tr(l, '3 Vùng giam giữ', '3-Zone Conf.'))),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _contourField = v);
                                },
                              ),
                            ),
                          ),
                          // Nút phát hoạt hình tải trọng
                          IconButton.outlined(
                            onPressed: _toggleAnimation,
                            icon: Icon(_animating ? Icons.pause : Icons.play_arrow, size: 17, color: const Color(0xFF10B981)),
                            tooltip: tr(l, 'Hoạt hình gia tăng tải 0% → 100%', 'Animate Load Steps 0% → 100%'),
                            visualDensity: VisualDensity.compact,
                          ),
                          // Menu Xuất Word / PDF (VI & EN) / AutoCAD DXF / Bản vẽ PDF
                          PopupMenuButton<String>(
                            onSelected: _handleExportAction,
                            tooltip: tr(l, 'Xuất Thuyết minh & Bản vẽ CAD', 'Export Reports & CAD Drawings'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF10B981)]),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.download, size: 15, color: Colors.black),
                                  const SizedBox(width: 4),
                                  Text(
                                    tr(l, 'Xuất Báo cáo & CAD', 'Export Report & CAD'),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'docx_vi', child: Text('📝 ${tr(l, "Thuyết minh Word (.DOCX) — Tiếng Việt", "Word Report (.DOCX) — Vietnamese")}')),
                              PopupMenuItem(value: 'docx_en', child: Text('📝 ${tr(l, "Thuyết minh Word (.DOCX) — Tiếng Anh", "Word Report (.DOCX) — English")}')),
                              PopupMenuItem(value: 'pdf_vi', child: Text('📄 ${tr(l, "Thuyết minh PDF (.PDF) — Tiếng Việt", "PDF Report (.PDF) — Vietnamese")}')),
                              PopupMenuItem(value: 'pdf_en', child: Text('📄 ${tr(l, "Thuyết minh PDF (.PDF) — Tiếng Anh", "PDF Report (.PDF) — English")}')),
                              const PopupMenuDivider(),
                              PopupMenuItem(value: 'dxf', child: Text('📐 ${tr(l, "Bản vẽ Gia công AutoCAD (.DXF)", "AutoCAD Shop Drawing (.DXF)")}')),
                              PopupMenuItem(value: 'cad_pdf', child: Text('🗺️ ${tr(l, "Bản vẽ Thi công Vector PDF (A3)", "A3 Engineering Drawing (.PDF)")}')),
                              PopupMenuItem(value: 'csv', child: Text('📊 ${tr(l, "Xuất bảng dữ liệu phi tuyến (.CSV)", "Export Nonlinear Data (.CSV)")}')),
                              const PopupMenuDivider(),
                              PopupMenuItem(value: 'save_json', child: Text('💾 ${tr(l, "Lưu dự án (.JSON)", "Save Project (.JSON)")}')),
                              PopupMenuItem(value: 'open_json', child: Text('📂 ${tr(l, "Mở dự án (.JSON)", "Open Project (.JSON)")}')),
                            ],
                          ),
                          // Thông tin Tác giả
                          InkWell(
                            onTap: () => _showAuthorDialog(dark, fg, barBg, border),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.55)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_outline, size: 14, color: Color(0xFF06B6D4)),
                                  const SizedBox(width: 4),
                                  Text(
                                    tr(l, 'Tác giả', 'Author'),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Chuyển ngôn ngữ VI / EN
                          InkWell(
                            onTap: () => setState(() => _lang = _lang == AppLang.vi ? AppLang.en : AppLang.vi),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                _lang == AppLang.vi ? 'VI' : 'EN',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                              ),
                            ),
                          ),
                          // Sáng / Tối
                          IconButton(
                            onPressed: () => widget.onThemeChanged(!dark),
                            icon: Icon(dark ? Icons.light_mode : Icons.dark_mode, size: 18, color: const Color(0xFFF59E0B)),
                            visualDensity: VisualDensity.compact,
                            tooltip: tr(l, 'Đổi giao diện Sáng / Tối', 'Toggle Dark / Light Theme'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ===========================================================
                // PHẦN THÂN CHÍNH: SIDEBAR THAM SỐ (TRÁI) + 5 TAB KHÔNG GIAN LÀM VIỆC
                // ===========================================================
                Expanded(
                  child: Row(
                    children: [
                      if (wide)
                        Container(
                          width: 326,
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: border)),
                          ),
                          child: Material(color: barBg, child: sidebarContent),
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            // Thanh Tab chuyển đổi 5 không gian chuyên sâu
                            Container(
                              color: barBg,
                              child: TabBar(
                                controller: _tabCtrl,
                                isScrollable: !wide,
                                labelColor: const Color(0xFF06B6D4),
                                unselectedLabelColor: fg.withValues(alpha: 0.68),
                                indicatorColor: const Color(0xFF06B6D4),
                                labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                tabs: [
                                  Tab(icon: const Icon(Icons.view_in_ar, size: 16), text: tr(l, 'Mô phỏng 3D', '3D View')),
                                  Tab(icon: const Icon(Icons.biotech, size: 16), text: tr(l, '2D & Phẫu thuật', '2D & Dissection')),
                                  Tab(icon: const Icon(Icons.analytics_outlined, size: 16), text: tr(l, 'Biểu đồ & Tiêu chuẩn', 'Charts & Codes')),
                                  Tab(icon: const Icon(Icons.architecture, size: 16), text: tr(l, 'Bản vẽ CAD', 'CAD Drawing')),
                                  Tab(icon: const Icon(Icons.menu_book_outlined, size: 16), text: tr(l, 'Lý thuyết & Code', 'Theory & Code')),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: _tabCtrl,
                                physics: const NeverScrollableScrollPhysics(), // Tránh xung đột kéo xoay 3D trên tablet/phone!
                                children: [
                                  SrcViewport3D(
                                    result: _result,
                                    field: _contourField,
                                    probeXNorm: _probeXNorm,
                                    deformScale: _deformScale,
                                    loadStepFraction: _loadStepFrac,
                                    darkMode: dark,
                                    lang: l,
                                    onProbeXChanged: (v) => setState(() => _probeXNorm = v),
                                    onDeformScaleChanged: (v) => setState(() => _deformScale = v),
                                  ),
                                  SrcViewport2DDissection(
                                    result: _result,
                                    field: _contourField,
                                    probeXNorm: _probeXNorm,
                                    darkMode: dark,
                                    lang: l,
                                    onProbeXChanged: (v) => setState(() => _probeXNorm = v),
                                  ),
                                  SrcChartsMultiCodePanel(
                                    result: _result,
                                    darkMode: dark,
                                    lang: l,
                                  ),
                                  SrcCadPreviewPanel(
                                    result: _result,
                                    darkMode: dark,
                                    lang: l,
                                    onStatusMessage: _showToast,
                                  ),
                                  SrcTheoryCodePanel(
                                    darkMode: dark,
                                    lang: l,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Thanh trạng thái dưới cùng (Status Footer)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: barBg, border: Border(top: BorderSide(color: border))),
                  child: Row(
                    children: [
                      Icon(
                        _result.overallPass ? Icons.verified : Icons.warning_amber_rounded,
                        size: 14,
                        color: _result.overallPass ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _statusMsg ??
                              '${_cfg.name}  •  Ag=${_result.props.agMm2.toStringAsFixed(0)} mm²  •  ρa=${(_result.props.steelRatio * 100).toStringAsFixed(2)}%  •  ρs=${(_result.props.rebarRatio * 100).toStringAsFixed(2)}%  •  ${_result.fibers.length} ${tr(l, "thớ 2D", "2D fibers")}',
                          style: TextStyle(fontSize: 10.5, fontFamily: 'DejaVuSansMono', color: fg.withValues(alpha: 0.8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // BẢNG THAM SỐ THIẾT KẾ TRÁI (NHẬP SỐ TRỰC TIẾP + PRESETS + BENCHMARKS + RESET)
  // ===========================================================================
  Widget _buildParameterSidebar(bool dark, AppLang l, Color fg, Color border) {
    final c = _cfg;
    final g = c.geometry;
    final m = c.material;
    final isBeam = c.kind == MemberKind.beam;
    final presets = isBeam ? SrcLibraries.beamPresets() : SrcLibraries.columnPresets();

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        // 1. Preset chuẩn & Mẫu thí nghiệm kiểm chứng
        _secHeader(tr(l, '1. MẪU CHUẨN & THÍ NGHIỆM', '1. PRESETS & BENCHMARKS'), Icons.science_outlined),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF131F38) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: null,
              hint: Text(tr(l, 'Chọn mẫu chuẩn / Benchmark...', 'Select preset / Benchmark...'), style: TextStyle(fontSize: 11.2, color: fg)),
              dropdownColor: dark ? const Color(0xFF0F172A) : Colors.white,
              items: [
                for (final p in presets)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(l.isVi ? p.labelVi : p.labelEn, style: TextStyle(fontSize: 11, color: fg)),
                  ),
              ],
              onChanged: (id) {
                if (id == null) return;
                final picked = presets.firstWhere((e) => e.id == id);
                _applyConfig(picked.cfg);
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _applyConfig(presets.first.cfg),
                icon: const Icon(Icons.restart_alt, size: 15),
                label: Text(tr(l, 'Mặc định', 'Reset'), style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2. Hình học tiết diện & Lõi thép hình
        _secHeader(tr(l, '2. HÌNH HỌC & LÕI THÉP HÌNH', '2. SECTION & STEEL PROFILE'), Icons.straighten),
        const SizedBox(height: 6),
        _dropdownField<String>(
          label: tr(l, 'Dạng mặt cắt', 'Section Type'),
          value: g.sectionType,
          items: isBeam
              ? const [
                  ('SRC_T_SLAB_H', 'T-Slab + H-Profile (Chữ T bản sàn)'),
                  ('SRC_RECT_H', 'Rectangular + H-Profile (Chữ nhật)'),
                ]
              : const [
                  ('COL_RECT_H', 'Rect/Square + H-Profile (Lõi H)'),
                  ('COL_RECT_CROSS_H', 'Rect/Square + Cross-H (Chữ thập)'),
                  ('COL_CIRC_H', 'Circular + H-Profile (Cột tròn)'),
                  ('COL_RECT_CFST', 'Concrete-Encased CFST (Ống thép)'),
                ],
          onChanged: (v) => _applyConfig(c.copyWith(geometry: g.copyWith(sectionType: v), clearExpRef: true)),
          dark: dark,
          fg: fg,
          border: border,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _numField(
                label: isBeam ? 'L (mm)' : 'H (mm)',
                value: c.lengthMm,
                onSubmit: (v) => _applyConfig(c.copyWith(lengthMm: v.clamp(400, 24000), clearExpRef: true)),
                dark: dark,
                fg: fg,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _numField(
                label: 'b (mm)',
                value: g.bMm,
                onSubmit: (v) => _applyConfig(c.copyWith(geometry: g.copyWith(bMm: v.clamp(150, 2000)), clearExpRef: true)),
                dark: dark,
                fg: fg,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _numField(
                label: 'h (mm)',
                value: g.hMm,
                onSubmit: (v) => _applyConfig(c.copyWith(geometry: g.copyWith(hMm: v.clamp(150, 2500)), clearExpRef: true)),
                dark: dark,
                fg: fg,
              ),
            ),
          ],
        ),
        if (isBeam && g.sectionType == 'SRC_T_SLAB_H') ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _numField(
                  label: 'b_eff (mm)',
                  value: g.bfSlabMm,
                  onSubmit: (v) => _applyConfig(c.copyWith(geometry: g.copyWith(bfSlabMm: v.clamp(g.bMm, 4000)), clearExpRef: true)),
                  dark: dark,
                  fg: fg,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _numField(
                  label: 'h_f (mm)',
                  value: g.hfSlabMm,
                  onSubmit: (v) => _applyConfig(c.copyWith(geometry: g.copyWith(hfSlabMm: v.clamp(60, 0.45 * g.hMm)), clearExpRef: true)),
                  dark: dark,
                  fg: fg,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        // Chọn nhanh thép hình H chuẩn
        _dropdownField<String>(
          label: tr(l, 'Chọn nhanh thép hình chuẩn', 'Quick Steel Profile'),
          value: null,
          hint: 'H${g.haMm.toStringAsFixed(0)}×${g.baMm.toStringAsFixed(0)}×${g.twMm.toStringAsFixed(1)}×${g.tfMm.toStringAsFixed(1)}',
          items: [for (final k in SrcLibraries.steelProfiles.keys) (k, k)],
          onChanged: (k) {
            final p = SrcLibraries.steelProfiles[k]!;
            _applyConfig(c.copyWith(
              geometry: g.copyWith(haMm: p.ha, baMm: p.ba, twMm: p.tw, tfMm: p.tf),
              clearExpRef: true,
            ));
          },
          dark: dark,
          fg: fg,
          border: border,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _numField(label: 'ha', value: g.haMm, onSubmit: (v) => _applyConfig(c.copyWith(geometry: g.copyWith(haMm: v.clamp(80, g.hMm - 40)), clearExpRef: true)), dark: dark, fg: fg)),
            const SizedBox(width: 5),
            Expanded(child: _numField(label: 'ba', value: g.baMm, onSubmit: (v) => _applyConfig(c.copyWith(geometry: g.copyWith(baMm: v.clamp(60, g.bMm - 30)), clearExpRef: true)), dark: dark, fg: fg)),
            const SizedBox(width: 5),
            Expanded(child: _numField(label: 'tw', value: g.twMm, onSubmit: (v) => _applyConfig(c.copyWith(geometry: g.copyWith(twMm: v.clamp(4, 40)), clearExpRef: true)), dark: dark, fg: fg)),
            const SizedBox(width: 5),
            Expanded(child: _numField(label: 'tf', value: g.tfMm, onSubmit: (v) => _applyConfig(c.copyWith(geometry: g.copyWith(tfMm: v.clamp(5, 50)), clearExpRef: true)), dark: dark, fg: fg)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _numField(label: isBeam ? 'n_bot' : 'n_bars', value: g.nRebarBot.toDouble(), onSubmit: (v) => _applyConfig(c.copyWith(geometry: g.copyWith(nRebarBot: v.round().clamp(2, 24)), clearExpRef: true)), dark: dark, fg: fg)),
            const SizedBox(width: 5),
            Expanded(child: _numField(label: 'Ø_bar', value: g.rebarDiaBotMm, onSubmit: (v) => _applyConfig(c.copyWith(geometry: g.copyWith(rebarDiaBotMm: v.clamp(10, 40)), clearExpRef: true)), dark: dark, fg: fg)),
            const SizedBox(width: 5),
            Expanded(child: _numField(label: 's_đai', value: g.stirrupSpacingMm, onSubmit: (v) => _applyConfig(c.copyWith(geometry: g.copyWith(stirrupSpacingMm: v.clamp(50, 300)), clearExpRef: true)), dark: dark, fg: fg)),
          ],
        ),
        const SizedBox(height: 10),

        // 3. Vật liệu & Hiệu ứng giam giữ
        _secHeader(tr(l, '3. VẬT LIỆU & GIAM GIỮ 3 VÙNG', '3. MATERIALS & CONFINEMENT'), Icons.layers_outlined),
        const SizedBox(height: 6),
        _dropdownField<String>(
          label: tr(l, 'Cấp bền Bê tông', 'Concrete Grade'),
          value: SrcLibraries.concreteGrades.containsKey(m.concreteGrade) ? m.concreteGrade : null,
          hint: '${m.concreteGrade} (${m.fcMpa.toStringAsFixed(0)} MPa)',
          items: [for (final k in SrcLibraries.concreteGrades.keys) (k, k)],
          onChanged: (k) {
            final d = SrcLibraries.concreteGrades[k]!;
            _applyConfig(c.copyWith(material: m.copyWith(concreteGrade: k, fcMpa: d.fc, ecMpa: d.ec, fctMpa: d.fct), clearExpRef: true));
          },
          dark: dark,
          fg: fg,
          border: border,
        ),
        const SizedBox(height: 6),
        _dropdownField<String>(
          label: tr(l, 'Mác Thép hình cốt cứng', 'Structural Steel Grade'),
          value: SrcLibraries.steelGrades.containsKey(m.steelGrade) ? m.steelGrade : null,
          hint: '${m.steelGrade} (${m.fySteelMpa.toStringAsFixed(0)} MPa)',
          items: [for (final k in SrcLibraries.steelGrades.keys) (k, k)],
          onChanged: (k) {
            final d = SrcLibraries.steelGrades[k]!;
            _applyConfig(c.copyWith(material: m.copyWith(steelGrade: k, fySteelMpa: d.fy, fuSteelMpa: d.fu, esSteelMpa: d.es), clearExpRef: true));
          },
          dark: dark,
          fg: fg,
          border: border,
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(tr(l, 'Bật giam giữ 3 vùng (Chen & Lin)', '3-Zone Confinement (Chen & Lin)'), style: TextStyle(fontSize: 11.2, color: fg)),
          value: m.useConfinement,
          activeThumbColor: const Color(0xFF06B6D4),
          onChanged: (v) => _applyConfig(c.copyWith(material: m.copyWith(useConfinement: v))),
        ),
        const SizedBox(height: 6),

        // 4. Tải trọng & Liên kết (Dầm) hoặc Nén Đúng tâm / Lệch tâm (Cột)
        _secHeader(isBeam ? tr(l, '4. TẢI TRỌNG & LIÊN KẾT DẦM', '4. BEAM LOADS & SUPPORTS') : tr(l, '4. NÉN ĐÚNG TÂM / LỆCH TÂM', '4. AXIAL & ECCENTRIC LOADS'), Icons.arrow_downward),
        const SizedBox(height: 6),
        if (isBeam) ...[
          _dropdownField<String>(
            label: tr(l, 'Sơ đồ chất tải', 'Load Pattern'),
            value: c.loadType,
            items: [
              ('udl', tr(l, 'Phân bố đều q (kN/m)', 'Uniform UDL q (kN/m)')),
              ('3pt', tr(l, 'Uốn 3 điểm — Lực tập trung P', '3-Point Bending P')),
              ('4pt', tr(l, 'Uốn 4 điểm — Hai lực P/2', '4-Point Bending 2×P/2')),
              ('combined', tr(l, 'Kết hợp q + P tập trung', 'Combined UDL q + P')),
            ],
            onChanged: (v) => _applyConfig(c.copyWith(loadType: v, clearExpRef: true)),
            dark: dark,
            fg: fg,
            border: border,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (c.loadType == 'udl' || c.loadType == 'combined')
                Expanded(child: _numField(label: 'q (kN/m)', value: c.qUdlKnM, onSubmit: (v) => _applyConfig(c.copyWith(qUdlKnM: v.clamp(1, 1000))), dark: dark, fg: fg)),
              if (c.loadType == 'combined') const SizedBox(width: 6),
              if (c.loadType != 'udl')
                Expanded(child: _numField(label: 'P (kN)', value: c.pPointKn, onSubmit: (v) => _applyConfig(c.copyWith(pPointKn: v.clamp(5, 5000))), dark: dark, fg: fg)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _dropdownField<String>(
                  label: tr(l, 'Gối trái', 'Left Sup.'),
                  value: c.leftSupport,
                  items: const [('pin', 'Pin'), ('fixed', 'Fixed')],
                  onChanged: (v) => _applyConfig(c.copyWith(leftSupport: v)),
                  dark: dark,
                  fg: fg,
                  border: border,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _dropdownField<String>(
                  label: tr(l, 'Gối phải', 'Right Sup.'),
                  value: c.rightSupport,
                  items: const [('roller', 'Roller'), ('pin', 'Pin'), ('fixed', 'Fixed')],
                  onChanged: (v) => _applyConfig(c.copyWith(rightSupport: v)),
                  dark: dark,
                  fg: fg,
                  border: border,
                ),
              ),
            ],
          ),
        ] else ...[
          _dropdownField<String>(
            label: tr(l, 'Trạng thái chịu nén', 'Compression Mode'),
            value: c.loadingMode,
            items: [
              ('concentric', tr(l, 'Nén ĐÚNG TÂM (e = 0)', 'Concentric (e = 0)')),
              ('uniaxial', tr(l, 'Nén LỆCH TÂM 1 phương (N + Mz)', 'Uniaxial Eccentric (N + Mz)')),
              ('biaxial', tr(l, 'Nén LỆCH TÂM XIÊN 2 phương', 'Biaxial Eccentric (N + Mz + My)')),
            ],
            onChanged: (v) => _applyConfig(c.copyWith(loadingMode: v, clearExpRef: true)),
            dark: dark,
            fg: fg,
            border: border,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _numField(label: 'N_Ed (kN)', value: c.nEdKn, onSubmit: (v) => _applyConfig(c.copyWith(nEdKn: v.clamp(50, 50000))), dark: dark, fg: fg)),
              const SizedBox(width: 6),
              Expanded(child: _numField(label: 'k_eff', value: c.kEffZ, onSubmit: (v) => _applyConfig(c.copyWith(kEffZ: v.clamp(0.5, 2.5), kEffY: v.clamp(0.5, 2.5))), dark: dark, fg: fg)),
            ],
          ),
          if (c.loadingMode != 'concentric') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _numField(
                    label: c.useEccInput ? 'e_z (mm)' : 'M_z (kN·m)',
                    value: c.useEccInput ? c.ezMm : c.mzEdKnm,
                    onSubmit: (v) => _applyConfig(c.useEccInput ? c.copyWith(ezMm: v.clamp(0, 600)) : c.copyWith(mzEdKnm: v.clamp(0, 10000))),
                    dark: dark,
                    fg: fg,
                  ),
                ),
                if (c.loadingMode == 'biaxial') ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: _numField(
                      label: c.useEccInput ? 'e_y (mm)' : 'M_y (kN·m)',
                      value: c.useEccInput ? c.eyMm : c.myEdKnm,
                      onSubmit: (v) => _applyConfig(c.useEccInput ? c.copyWith(eyMm: v.clamp(0, 600)) : c.copyWith(myEdKnm: v.clamp(0, 10000))),
                      dark: dark,
                      fg: fg,
                    ),
                  ),
                ],
              ],
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(tr(l, 'Nhập theo độ lệch tâm e (mm)', 'Input via Eccentricity e (mm)'), style: TextStyle(fontSize: 11, color: fg)),
              value: c.useEccInput,
              activeThumbColor: const Color(0xFF06B6D4),
              onChanged: (v) => _applyConfig(c.copyWith(useEccInput: v)),
            ),
          ],
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  void _showAuthorDialog(bool dark, Color fg, Color cardBg, Color border) {
    final l = _lang;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border),
        ),
        title: Row(
          children: [
            const Icon(Icons.school, color: Color(0xFF06B6D4), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr(l, 'Thông tin Tác giả', 'Author Information'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: fg),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(l, 'Trường Đại học Bách Khoa - Đại học Quốc Gia TP. Hồ Chí Minh',
                  'Ho Chi Minh City University of Technology (VNU-HCM)'),
              style: const TextStyle(fontSize: 12.2, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(height: 6),
            Text(
              tr(l, 'Giảng viên hướng dẫn: PGS.TS Ngô Cường', 'Advisor: Assoc. Prof. Dr. Ngo Cuong'),
              style: TextStyle(fontSize: 12, color: fg),
            ),
            const Divider(height: 18),
            Text(
              tr(l, 'Tác giả / Học viên thực hiện:', 'Author / Researcher:'),
              style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 2),
            Text(
              'Võ Thanh Vang (2670624)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: fg),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 16, color: Color(0xFF06B6D4)),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    'Email: vothanhvang@gmail.com',
                    style: TextStyle(fontSize: 12.2, color: fg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    'Phone: 0973.993.494',
                    style: TextStyle(fontSize: 12.2, color: fg, fontFamily: 'DejaVuSansMono'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr(l, 'Đóng', 'Close'), style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _secHeader(String txt, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF06B6D4)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            txt,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4), letterSpacing: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T? value,
    String? hint,
    required List<(T, String)> items,
    required ValueChanged<T> onChanged,
    required bool dark,
    required Color fg,
    required Color border,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10.2, color: fg.withValues(alpha: 0.72))),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF131F38) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              isDense: true,
              value: value,
              hint: hint != null ? Text(hint, style: TextStyle(fontSize: 11, color: fg)) : null,
              dropdownColor: dark ? const Color(0xFF0F172A) : Colors.white,
              style: TextStyle(fontSize: 11, color: fg),
              items: [for (final (v, lbl) in items) DropdownMenuItem(value: v, child: Text(lbl, overflow: TextOverflow.ellipsis))],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _numField({
    required String label,
    required double value,
    required ValueChanged<double> onSubmit,
    required bool dark,
    required Color fg,
  }) {
    final text = value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return _NumericInputBox(
      key: ValueKey('$label-$text'),
      label: label,
      initialText: text,
      dark: dark,
      fg: fg,
      onCommit: onSubmit,
    );
  }
}

class _NumericInputBox extends StatefulWidget {
  final String label;
  final String initialText;
  final bool dark;
  final Color fg;
  final ValueChanged<double> onCommit;

  const _NumericInputBox({
    super.key,
    required this.label,
    required this.initialText,
    required this.dark,
    required this.fg,
    required this.onCommit,
  });

  @override
  State<_NumericInputBox> createState() => _NumericInputBoxState();
}

class _NumericInputBoxState extends State<_NumericInputBox> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialText);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  void _commit() {
    final parsed = double.tryParse(_ctrl.text.trim().replaceAll(',', '.'));
    if (parsed != null && parsed.isFinite) {
      widget.onCommit(parsed);
    } else {
      _ctrl.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: TextStyle(fontSize: 9.8, color: widget.fg.withValues(alpha: 0.72))),
        const SizedBox(height: 2),
        SizedBox(
          height: 30,
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 11.2, fontFamily: 'DejaVuSansMono', color: widget.fg),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              filled: true,
              fillColor: widget.dark ? const Color(0xFF131F38) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF334155))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF334155))),
            ),
            onSubmitted: (_) => _commit(),
          ),
        ),
      ],
    );
  }
}
