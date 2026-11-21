// ============================================================================
// XEM TRƯỚC BẢN VẼ GIA CÔNG CHẾ TẠO CAD & XUẤT AUTOCAD (.DXF) / PDF (.PDF)
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/src_cad_exporter.dart';
import '../core/src_engine.dart';

class SrcCadPreviewPanel extends StatefulWidget {
  final SrcAnalysisResult result;
  final bool darkMode;
  final AppLang lang;
  final ValueChanged<String> onStatusMessage;

  const SrcCadPreviewPanel({
    super.key,
    required this.result,
    required this.darkMode,
    required this.lang,
    required this.onStatusMessage,
  });

  @override
  State<SrcCadPreviewPanel> createState() => _SrcCadPreviewPanelState();
}

class _SrcCadPreviewPanelState extends State<SrcCadPreviewPanel> {
  bool _showSteel = true;
  bool _showRebar = true;
  bool _showStirrups = true;
  bool _showHardware = true;
  bool _blueprintStyle = true; // Nền xanh kỹ thuật CAD / nền trắng in ấn
  bool _exporting = false;

  Future<void> _exportDxf() async {
    setState(() => _exporting = true);
    try {
      final path = await SrcCadExporter.exportDxf(widget.result);
      if (path != null) {
        widget.onStatusMessage(tr(widget.lang, 'Đã xuất bản vẽ AutoCAD (.DXF): $path', 'Exported AutoCAD (.DXF): $path'));
      }
    } catch (e) {
      widget.onStatusMessage('DXF Export Error: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final path = await SrcCadExporter.exportDrawingPdf(widget.result, widget.lang);
      if (path != null) {
        widget.onStatusMessage(tr(widget.lang, 'Đã xuất bản vẽ kỹ thuật PDF A3: $path', 'Exported A3 Vector Drawing PDF: $path'));
      }
    } catch (e) {
      widget.onStatusMessage('PDF Drawing Error: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lang;
    final dark = widget.darkMode;
    final res = widget.result;
    final cardBg = dark ? const Color(0xFF0F172A) : Colors.white;
    final border = dark ? const Color(0xFF263859) : const Color(0xFFCBD5E1);
    final fg = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final steelKg = res.bom.where((b) => b.mark != 'C-1').fold<double>(0.0, (s, b) => s + b.weightKg);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thanh điều khiển Layer & Nút xuất AutoCAD DXF / PDF A3
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _exporting ? null : _exportDxf,
                  icon: const Icon(Icons.architecture, size: 16),
                  label: Text(tr(l, 'Xuất AutoCAD (.DXF 10 Layer)', 'Export AutoCAD (.DXF 10 Layers)')),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), foregroundColor: Colors.black),
                ),
                ElevatedButton.icon(
                  onPressed: _exporting ? null : _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: Text(tr(l, 'Xuất Bản vẽ PDF (A3 Ngang)', 'Export Shop Drawing PDF (A3)')),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.black),
                ),
                const SizedBox(width: 6),
                _layerChip(tr(l, 'Thép hình H', 'Steel Core'), const Color(0xFFEF4444), _showSteel, (v) => setState(() => _showSteel = v)),
                _layerChip(tr(l, 'Cốt thép dọc', 'Rebar'), const Color(0xFF22C55E), _showRebar, (v) => setState(() => _showRebar = v)),
                _layerChip(tr(l, 'Cốt đai', 'Stirrups'), const Color(0xFF38BDF8), _showStirrups, (v) => setState(() => _showStirrups = v)),
                _layerChip(
                  res.config.kind == MemberKind.beam ? tr(l, 'Đinh chống cắt', 'Shear Studs') : tr(l, 'Bản đế', 'Baseplate'),
                  const Color(0xFFE879F9),
                  _showHardware,
                  (v) => setState(() => _showHardware = v),
                ),
                _layerChip(tr(l, 'Nền CAD tối', 'CAD Dark'), const Color(0xFFF59E0B), _blueprintStyle, (v) => setState(() => _blueprintStyle = v)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Khung xem trước tờ bản vẽ A3 (Mặt đứng + Mặt cắt 1-1 + Chi tiết chế tạo)
          Container(
            height: 390,
            decoration: BoxDecoration(
              color: _blueprintStyle ? const Color(0xFF081326) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _blueprintStyle ? const Color(0xFF1E3A5F) : const Color(0xFF94A3B8), width: 1.5),
            ),
            child: CustomPaint(
              size: Size.infinite,
              painter: _CadSheetPainter(
                result: res,
                showSteel: _showSteel,
                showRebar: _showRebar,
                showStirrups: _showStirrups,
                showHardware: _showHardware,
                blueprint: _blueprintStyle,
                lang: l,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Bảng Thống Kê Vật Liệu Gia Công Chế Tạo (BOM / BBS)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr(l, 'BẢNG THỐNG KÊ THÉP HÌNH, CỐT THÉP & VẬT LIỆU THI CÔNG (BOM / BBS)',
                          'BILL OF MATERIALS & BAR BENDING SCHEDULE (BOM / BBS)'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                    ),
                    Text(
                      '${tr(l, "Tổng thép chế tạo", "Total Steel")}: ${steelKg.toStringAsFixed(1)} kg',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'DejaVuSansMono', color: fg),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 34,
                    dataRowMinHeight: 32,
                    dataRowMaxHeight: 38,
                    columns: [
                      DataColumn(label: Text(tr(l, 'Số hiệu', 'Mark'), style: TextStyle(fontWeight: FontWeight.bold, color: fg))),
                      DataColumn(label: Text(tr(l, 'Quy cách chế tạo', 'Specification'), style: TextStyle(fontWeight: FontWeight.bold, color: fg))),
                      DataColumn(label: Text(tr(l, 'Mác VL', 'Grade'), style: TextStyle(fontWeight: FontWeight.bold, color: fg))),
                      DataColumn(label: Text(tr(l, 'Số lượng', 'Qty'), style: TextStyle(fontWeight: FontWeight.bold, color: fg))),
                      DataColumn(label: Text(tr(l, 'Khối lượng (kg)', 'Mass (kg)'), style: TextStyle(fontWeight: FontWeight.bold, color: fg)), numeric: true),
                    ],
                    rows: [
                      for (final b in res.bom)
                        DataRow(cells: [
                          DataCell(Text(b.mark, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'DejaVuSansMono', color: Color(0xFF38BDF8)))),
                          DataCell(Text(l.isVi ? b.descVi : b.descEn, style: TextStyle(fontSize: 11.5, color: fg))),
                          DataCell(Text(b.grade, style: TextStyle(fontSize: 11, color: fg))),
                          DataCell(Text(l.isVi ? b.qtyVi : b.qtyEn, style: TextStyle(fontSize: 11, color: fg))),
                          DataCell(Text(b.weightKg.toStringAsFixed(1), style: TextStyle(fontFamily: 'DejaVuSansMono', fontWeight: FontWeight.bold, color: fg))),
                        ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _layerChip(String label, Color col, bool selected, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 10.8, color: selected ? col : null)),
      selected: selected,
      onSelected: onChanged,
      selectedColor: col.withValues(alpha: 0.20),
      checkmarkColor: col,
      side: BorderSide(color: selected ? col : const Color(0xFF475569)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _CadSheetPainter extends CustomPainter {
  final SrcAnalysisResult result;
  final bool showSteel, showRebar, showStirrups, showHardware, blueprint;
  final AppLang lang;

  const _CadSheetPainter({
    required this.result,
    required this.showSteel,
    required this.showRebar,
    required this.showStirrups,
    required this.showHardware,
    required this.blueprint,
    required this.lang,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = result.config;
    final g = cfg.geometry;
    final isBeam = cfg.kind == MemberKind.beam;
    final fg = blueprint ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final dimCol = blueprint ? const Color(0xFFFACC15) : const Color(0xFF334155);
    final concStroke = Paint()..color = fg..style = PaintingStyle.stroke..strokeWidth = 1.6;
    final concFill = Paint()..color = blueprint ? const Color(0x1894A3B8) : const Color(0x2894A3B8);

    // Viền bản vẽ kỹ thuật
    canvas.drawRect(Rect.fromLTWH(8, 8, size.width - 16, size.height - 16), Paint()..color = fg.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1.2);

    void drawSteelSection(double cx, double cy, double sc) {
      if (!showSteel) return;
      final yc = cy - g.coreOffsetYMm * sc;
      final ha = g.haMm * sc, ba = g.baMm * sc, tf = g.tfMm * sc, tw = g.twMm * sc;
      final pFill = Paint()..color = const Color(0xCCEF4444);
      final pStr = Paint()..color = const Color(0xFFFF6B6B)..style = PaintingStyle.stroke..strokeWidth = 1.2;
      if (g.sectionType == 'COL_RECT_CFST') {
        canvas.drawCircle(Offset(cx, yc), 0.5 * ha - 0.5 * tf, Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.stroke..strokeWidth = math.max(2.5, tf));
        return;
      }
      for (final r in [
        Rect.fromLTWH(cx - 0.5 * ba, yc - 0.5 * ha, ba, tf),
        Rect.fromLTWH(cx - 0.5 * ba, yc + 0.5 * ha - tf, ba, tf),
        Rect.fromLTWH(cx - 0.5 * tw, yc - 0.5 * ha + tf, tw, ha - 2 * tf),
      ]) {
        canvas.drawRect(r, pFill);
        canvas.drawRect(r, pStr);
      }
      if (g.sectionType == 'COL_RECT_CROSS_H') {
        for (final r in [
          Rect.fromLTWH(cx - 0.5 * ha, yc - 0.5 * ba, tf, ba),
          Rect.fromLTWH(cx + 0.5 * ha - tf, yc - 0.5 * ba, tf, ba),
          Rect.fromLTWH(cx - 0.5 * ha + tf, yc - 0.5 * tw, ha - 2 * tf, tw),
        ]) {
          canvas.drawRect(r, pFill);
          canvas.drawRect(r, pStr);
        }
      }
    }

    if (isBeam) {
      // 1. Mặt đứng dầm (62% bên trái)
      final leftW = size.width * 0.60;
      final scE = math.min((leftW - 60) / math.max(1000.0, cfg.lengthMm), (size.height * 0.45) / math.max(200.0, g.hMm));
      final elL = cfg.lengthMm * scE, elH = g.hMm * scE;
      const ex = 34.0;
      final ey = size.height * 0.52 - 0.5 * elH;

      _txt(canvas, Offset(ex, 18), tr(lang, '1. MẶT ĐỨNG DỌC DẦM SRC (L = ${cfg.lengthMm.toStringAsFixed(0)} mm)', '1. SRC BEAM ELEVATION (L = ${cfg.lengthMm.toStringAsFixed(0)} mm)'), fg, 11);
      final rectB = Rect.fromLTWH(ex, ey, elL, elH);
      canvas.drawRect(rectB, concFill);
      canvas.drawRect(rectB, concStroke);
      if (g.sectionType == 'SRC_T_SLAB_H') {
        canvas.drawLine(Offset(ex, ey + g.hfSlabMm * scE), Offset(ex + elL, ey + g.hfSlabMm * scE), concStroke);
      }
      if (showSteel) {
        final yc = ey + 0.5 * elH - g.coreOffsetYMm * scE;
        final haE = g.haMm * scE;
        canvas.drawRect(Rect.fromLTWH(ex, yc - 0.5 * haE, elL, haE), Paint()..color = const Color(0x44EF4444));
        canvas.drawRect(Rect.fromLTWH(ex, yc - 0.5 * haE, elL, haE), Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.stroke..strokeWidth = 1.4);
      }
      final covE = (g.coverMm + g.stirrupDiaMm) * scE;
      if (showStirrups) {
        final pSt = Paint()..color = const Color(0xFF38BDF8)..strokeWidth = 0.9;
        double xp = 80;
        while (xp < cfg.lengthMm - 40) {
          final inEnd = xp <= 0.25 * cfg.lengthMm || xp >= 0.75 * cfg.lengthMm;
          canvas.drawLine(Offset(ex + xp * scE, ey + covE), Offset(ex + xp * scE, ey + elH - covE), pSt);
          xp += inEnd ? g.stirrupSpacingEndMm : g.stirrupSpacingMm;
        }
      }
      if (showRebar) {
        final pRb = Paint()..color = const Color(0xFF22C55E)..strokeWidth = 2.2;
        canvas.drawLine(Offset(ex + 5, ey + covE), Offset(ex + elL - 5, ey + covE), pRb);
        canvas.drawLine(Offset(ex + 5, ey + elH - covE), Offset(ex + elL - 5, ey + elH - covE), pRb);
      }
      if (showHardware) {
        final yc = ey + 0.5 * elH - g.coreOffsetYMm * scE;
        final yTopFl = yc - 0.5 * g.haMm * scE;
        final sh = math.max(6.0, cfg.studHeightMm * scE);
        final pH = Paint()..color = const Color(0xFFE879F9)..strokeWidth = 1.5;
        double stx = 120;
        while (stx < cfg.lengthMm - 80) {
          final sx = ex + stx * scE;
          canvas.drawLine(Offset(sx, yTopFl), Offset(sx, yTopFl - sh), pH);
          canvas.drawLine(Offset(sx - 2.5, yTopFl - sh), Offset(sx + 2.5, yTopFl - sh), pH);
          stx += math.max(120, cfg.studSpacingMm);
        }
      }
      // Đường kích thước L
      canvas.drawLine(Offset(ex, ey + elH + 22), Offset(ex + elL, ey + elH + 22), Paint()..color = dimCol..strokeWidth = 1.0);
      _txt(canvas, Offset(ex + elL * 0.32, ey + elH + 26), 'L = ${cfg.lengthMm.toStringAsFixed(0)} mm | Đai @${g.stirrupSpacingEndMm.toStringAsFixed(0)}/${g.stirrupSpacingMm.toStringAsFixed(0)}', dimCol, 10);

      // 2. Mặt cắt ngang 1-1 (bên phải)
      final cxS = size.width * 0.80, cyS = size.height * 0.52;
      final bMax = g.sectionType == 'SRC_T_SLAB_H' ? g.bfSlabMm : g.bMm;
      final scS = math.min((size.width * 0.32) / math.max(250.0, bMax), (size.height * 0.62) / math.max(250.0, g.hMm));
      final bS = g.bMm * scS, hS = g.hMm * scS, covS = g.coverMm * scS;
      _txt(canvas, Offset(cxS - 52, 18), tr(lang, '2. MẶT CẮT NGANG 1–1', '2. CROSS-SECTION 1–1'), fg, 11);
      final rSec = Rect.fromCenter(center: Offset(cxS, cyS), width: bS, height: hS);
      canvas.drawRect(rSec, concFill);
      canvas.drawRect(rSec, concStroke);
      if (g.sectionType == 'SRC_T_SLAB_H') {
        final rSl = Rect.fromLTWH(cxS - 0.5 * g.bfSlabMm * scS, cyS - 0.5 * hS, g.bfSlabMm * scS, g.hfSlabMm * scS);
        canvas.drawRect(rSl, concFill);
        canvas.drawRect(rSl, concStroke);
      }
      if (showStirrups) {
        canvas.drawRect(Rect.fromCenter(center: Offset(cxS, cyS), width: bS - 2 * covS, height: hS - 2 * covS),
            Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      }
      drawSteelSection(cxS, cyS, scS);
      if (showRebar) {
        for (final rb in result.props.rebars) {
          canvas.drawCircle(Offset(cxS + rb.zMm * scS, cyS - rb.yMm * scS), math.max(3.2, 0.5 * rb.diaMm * scS), Paint()..color = const Color(0xFF22C55E));
        }
      }
      _txt(canvas, Offset(cxS - 55, cyS + 0.5 * hS + 12), 'b×h = ${g.bMm.toStringAsFixed(0)}×${g.hMm.toStringAsFixed(0)} mm', dimCol, 10);
    } else {
      // Cột: 3 hình (Mặt đứng | Mặt cắt 1-1 | Mặt bằng Bản đế)
      final scE = math.min((size.height * 0.72) / math.max(1500.0, cfg.lengthMm), 80.0 / math.max(200.0, g.bMm));
      final cw = g.bMm * scE, ch = cfg.lengthMm * scE;
      final cxE = size.width * 0.16, ey = size.height * 0.53 - 0.5 * ch;
      _txt(canvas, Offset(cxE - 46, 18), tr(lang, '1. MẶT ĐỨNG CỘT', '1. ELEVATION'), fg, 11);
      canvas.drawRect(Rect.fromLTWH(cxE - 0.5 * cw, ey, cw, ch), concFill);
      canvas.drawRect(Rect.fromLTWH(cxE - 0.5 * cw, ey, cw, ch), concStroke);
      if (showSteel) {
        canvas.drawRect(Rect.fromLTWH(cxE - 0.5 * g.haMm * scE, ey, g.haMm * scE, ch), Paint()..color = const Color(0x55EF4444));
        canvas.drawRect(Rect.fromLTWH(cxE - 0.5 * g.haMm * scE, ey, g.haMm * scE, ch), Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.stroke..strokeWidth = 1.4);
      }
      if (showHardware) {
        canvas.drawRect(Rect.fromLTWH(cxE - 0.5 * cw - 8, ey + ch, cw + 16, 8), Paint()..color = const Color(0xFFE879F9));
      }
      _txt(canvas, Offset(cxE - 38, ey + ch + 14), 'H = ${cfg.lengthMm.toStringAsFixed(0)} mm', dimCol, 10);

      // Mặt cắt 1-1
      final cxS = size.width * 0.48, cyS = size.height * 0.53;
      final scS = math.min((size.width * 0.25) / math.max(200.0, g.bMm), (size.height * 0.62) / math.max(200.0, g.hMm));
      final bS = g.bMm * scS, hS = g.hMm * scS, covS = g.coverMm * scS;
      _txt(canvas, Offset(cxS - 50, 18), tr(lang, '2. MẶT CẮT NGANG 1–1', '2. SECTION 1–1'), fg, 11);
      if (g.sectionType == 'COL_CIRC_H') {
        canvas.drawCircle(Offset(cxS, cyS), 0.5 * bS, concFill);
        canvas.drawCircle(Offset(cxS, cyS), 0.5 * bS, concStroke);
        if (showStirrups) canvas.drawCircle(Offset(cxS, cyS), 0.5 * bS - covS, Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      } else {
        final r = Rect.fromCenter(center: Offset(cxS, cyS), width: bS, height: hS);
        canvas.drawRect(r, concFill);
        canvas.drawRect(r, concStroke);
        if (showStirrups) {
          canvas.drawRect(Rect.fromCenter(center: Offset(cxS, cyS), width: bS - 2 * covS, height: hS - 2 * covS),
              Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.stroke..strokeWidth = 1.5);
        }
      }
      drawSteelSection(cxS, cyS, scS);
      if (showRebar) {
        for (final rb in result.props.rebars) {
          canvas.drawCircle(Offset(cxS + rb.zMm * scS, cyS - rb.yMm * scS), math.max(3.2, 0.5 * rb.diaMm * scS), Paint()..color = const Color(0xFF22C55E));
        }
      }
      _txt(canvas, Offset(cxS - 54, cyS + 0.5 * hS + 12), '${g.bMm.toStringAsFixed(0)}×${g.hMm.toStringAsFixed(0)} mm', dimCol, 10);

      // Bản đế chân cột
      final cxB = size.width * 0.80, cyB = size.height * 0.53;
      final bpW = g.bMm + 120.0, bpH = g.hMm + 120.0;
      final scB = math.min((size.width * 0.24) / bpW, (size.height * 0.60) / bpH);
      final bwS = bpW * scB, bhS = bpH * scB;
      _txt(canvas, Offset(cxB - 62, 18), tr(lang, '3. BẢN ĐẾ CHÂN CỘT', '3. BASEPLATE DETAIL'), fg, 11);
      if (showHardware) {
        final rb = Rect.fromCenter(center: Offset(cxB, cyB), width: bwS, height: bhS);
        canvas.drawRect(rb, Paint()..color = const Color(0x28E879F9));
        canvas.drawRect(rb, Paint()..color = const Color(0xFFE879F9)..style = PaintingStyle.stroke..strokeWidth = 1.6);
        for (final (fx, fy) in const [(-0.38, -0.38), (0.0, -0.38), (0.38, -0.38), (0.38, 0.0), (0.38, 0.38), (0.0, 0.38), (-0.38, 0.38), (-0.38, 0.0)]) {
          canvas.drawCircle(Offset(cxB + fx * bwS, cyB + fy * bhS), 4.0, Paint()..color = const Color(0xFFE879F9));
        }
      }
      drawSteelSection(cxB, cyB, scB);
      _txt(canvas, Offset(cxB - 62, cyB + 0.5 * bhS + 12), 'PL30×${bpW.toStringAsFixed(0)}×${bpH.toStringAsFixed(0)} (8×M24)', dimCol, 10);
    }
  }

  void _txt(Canvas c, Offset o, String s, Color col, double fs) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _CadSheetPainter old) => true;
}
