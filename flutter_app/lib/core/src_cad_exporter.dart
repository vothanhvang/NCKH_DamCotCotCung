// ============================================================================
// MÔ-ĐUN XUẤT BẢN VẼ GIA CÔNG, CHẾ TẠO & THI CÔNG AUTOCAD (.DXF) VÀ PDF (.PDF)
// ============================================================================
// Chạy hoàn toàn ngoại tuyến trên Windows EXE, Android APK & GitHub Pages Web!
//   • AutoCAD .DXF chuẩn AC1009/R2000 đa lớp (10 LAYER chuyên nghiệp).
//   • Bản vẽ vector PDF khổ A3 ngang (420 × 297 mm) phông DejaVuSans Unicode
//     hỗ trợ đầy đủ Tiếng Việt có dấu / Tiếng Anh (tùy chọn).
// ============================================================================

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'i18n.dart';
import 'src_engine.dart';
import 'file_saver_stub.dart'
    if (dart.library.io) 'file_saver_io.dart'
    if (dart.library.js_interop) 'file_saver_web.dart';

class _DxfBuilder {
  final _sb = StringBuffer();

  static const _layers = [
    ('0_KHUNG_TEN', 7, 'CONTINUOUS'),
    ('1_NET_BAO_BT', 7, 'CONTINUOUS'),
    ('2_THEP_HINH_H', 1, 'CONTINUOUS'),
    ('3_COT_THEP_DOC', 3, 'CONTINUOUS'),
    ('4_COT_DAI', 4, 'CONTINUOUS'),
    ('5_DINH_NEO_STUD', 6, 'CONTINUOUS'),
    ('6_BAN_DE_LIEN_KET', 5, 'CONTINUOUS'),
    ('7_KICH_THUOC', 2, 'CONTINUOUS'),
    ('8_TIM_TRUC', 8, 'CENTER'),
    ('9_GHI_CHU', 7, 'CONTINUOUS'),
  ];

  void line(double x1, double y1, double x2, double y2, String layer) {
    _sb.write('0\nLINE\n8\n$layer\n10\n${x1.toStringAsFixed(3)}\n20\n${y1.toStringAsFixed(3)}\n30\n0.0\n'
        '11\n${x2.toStringAsFixed(3)}\n21\n${y2.toStringAsFixed(3)}\n31\n0.0\n');
  }

  void poly(List<(double, double)> pts, String layer, {bool closed = false}) {
    if (pts.length < 2) return;
    _sb.write('0\nLWPOLYLINE\n8\n$layer\n90\n${pts.length}\n70\n${closed ? 1 : 0}\n');
    for (final (x, y) in pts) {
      _sb.write('10\n${x.toStringAsFixed(3)}\n20\n${y.toStringAsFixed(3)}\n');
    }
  }

  void rect(double x, double y, double w, double h, String layer) {
    poly([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], layer, closed: true);
  }

  void circle(double cx, double cy, double r, String layer) {
    _sb.write('0\nCIRCLE\n8\n$layer\n10\n${cx.toStringAsFixed(3)}\n20\n${cy.toStringAsFixed(3)}\n30\n0.0\n40\n${r.toStringAsFixed(3)}\n');
  }

  void text(double x, double y, String s, double h, String layer, {int align = 0}) {
    final safe = s.replaceAll('\n', ' ').replaceAll('\r', ' ');
    if (align == 0) {
      _sb.write('0\nTEXT\n8\n$layer\n10\n${x.toStringAsFixed(3)}\n20\n${y.toStringAsFixed(3)}\n30\n0.0\n40\n${h.toStringAsFixed(2)}\n1\n$safe\n');
    } else {
      _sb.write('0\nTEXT\n8\n$layer\n10\n${x.toStringAsFixed(3)}\n20\n${y.toStringAsFixed(3)}\n30\n0.0\n40\n${h.toStringAsFixed(2)}\n1\n$safe\n72\n$align\n11\n${x.toStringAsFixed(3)}\n21\n${y.toStringAsFixed(3)}\n31\n0.0\n');
    }
  }

  void dimH(double x1, double x2, double yRef, double yDim, String lbl) {
    line(x1, yRef, x1, yDim + (yDim >= yRef ? 2.0 : -2.0), '7_KICH_THUOC');
    line(x2, yRef, x2, yDim + (yDim >= yRef ? 2.0 : -2.0), '7_KICH_THUOC');
    line(x1 - 2, yDim, x2 + 2, yDim, '7_KICH_THUOC');
    line(x1 - 1.5, yDim - 1.5, x1 + 1.5, yDim + 1.5, '7_KICH_THUOC');
    line(x2 - 1.5, yDim - 1.5, x2 + 1.5, yDim + 1.5, '7_KICH_THUOC');
    text(0.5 * (x1 + x2), yDim + 1.2, lbl, 3.0, '7_KICH_THUOC', align: 1);
  }

  void dimV(double xRef, double xDim, double y1, double y2, String lbl) {
    line(xRef, y1, xDim + (xDim >= xRef ? 2.0 : -2.0), y1, '7_KICH_THUOC');
    line(xRef, y2, xDim + (xDim >= xRef ? 2.0 : -2.0), y2, '7_KICH_THUOC');
    line(xDim, y1 - 2, xDim, y2 + 2, '7_KICH_THUOC');
    line(xDim - 1.5, y1 - 1.5, xDim + 1.5, y1 + 1.5, '7_KICH_THUOC');
    line(xDim - 1.5, y2 - 1.5, xDim + 1.5, y2 + 1.5, '7_KICH_THUOC');
    text(xDim + (xDim >= xRef ? 2.0 : -2.0), 0.5 * (y1 + y2) - 1.5, lbl, 3.0, '7_KICH_THUOC', align: xDim >= xRef ? 0 : 2);
  }

  String build() {
    final out = StringBuffer()
      ..write('0\nSECTION\n2\nHEADER\n9\n\$ACADVER\n1\nAC1009\n9\n\$INSUNITS\n70\n4\n0\nENDSEC\n')
      ..write('0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLTYPE\n70\n2\n'
          '0\nLTYPE\n2\nCONTINUOUS\n70\n0\n3\nSolid\n72\n65\n73\n0\n40\n0.0\n'
          '0\nLTYPE\n2\nCENTER\n70\n0\n3\nCenter\n72\n65\n73\n4\n40\n20.0\n49\n12.0\n49\n-3.0\n49\n2.0\n49\n-3.0\n'
          '0\nENDTAB\n')
      ..write('0\nTABLE\n2\nLAYER\n70\n${_layers.length}\n');
    for (final (n, col, lt) in _layers) {
      out.write('0\nLAYER\n2\n$n\n70\n0\n62\n$col\n6\n$lt\n');
    }
    out
      ..write('0\nENDTAB\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n')
      ..write(_sb.toString())
      ..write('0\nENDSEC\n0\nEOF\n');
    return out.toString();
  }
}

class SrcCadExporter {
  static void _drawSteelDxf(_DxfBuilder d, double cx, double cy, double sc, SectionGeometry g) {
    final yc = cy + g.coreOffsetYMm * sc;
    final ha = g.haMm * sc;
    final ba = g.baMm * sc;
    final tf = g.tfMm * sc;
    final tw = g.twMm * sc;
    if (g.sectionType == 'COL_RECT_CFST') {
      d.circle(cx, yc, 0.5 * ha, '2_THEP_HINH_H');
      d.circle(cx, yc, math.max(1.0, 0.5 * ha - tf), '2_THEP_HINH_H');
      return;
    }
    final h2 = 0.5 * ha, b2 = 0.5 * ba, tw2 = 0.5 * tw;
    d.poly([
      (cx - b2, yc - h2), (cx + b2, yc - h2), (cx + b2, yc - h2 + tf),
      (cx + tw2, yc - h2 + tf), (cx + tw2, yc + h2 - tf), (cx + b2, yc + h2 - tf),
      (cx + b2, yc + h2), (cx - b2, yc + h2), (cx - b2, yc + h2 - tf),
      (cx - tw2, yc + h2 - tf), (cx - tw2, yc - h2 + tf), (cx - b2, yc - h2 + tf),
    ], '2_THEP_HINH_H', closed: true);
    if (g.sectionType == 'COL_RECT_CROSS_H') {
      d.poly([
        (cx - h2, yc - b2), (cx - h2 + tf, yc - b2), (cx - h2 + tf, yc - tw2),
        (cx + h2 - tf, yc - tw2), (cx + h2 - tf, yc - b2), (cx + h2, yc - b2),
        (cx + h2, yc + b2), (cx + h2 - tf, yc + b2), (cx + h2 - tf, yc + tw2),
        (cx - h2 + tf, yc + tw2), (cx - h2 + tf, yc + b2), (cx - h2, yc + b2),
      ], '2_THEP_HINH_H', closed: true);
    }
  }

  /// Tạo chuỗi AutoCAD DXF hoàn chỉnh (khổ A3 ngang, 10 layer chuyên nghiệp)
  static String buildDxfString(SrcAnalysisResult res) {
    final cfg = res.config;
    final g = cfg.geometry;
    final isBeam = cfg.kind == MemberKind.beam;
    final d = _DxfBuilder();

    // Khung bản vẽ A3 & khung tên
    d.rect(0, 0, 420, 297, '0_KHUNG_TEN');
    d.rect(10, 8, 402, 281, '0_KHUNG_TEN');
    const tx = 247.0, ty = 8.0;
    d.rect(tx, ty, 165, 42, '0_KHUNG_TEN');
    d.line(tx, ty + 28, tx + 165, ty + 28, '0_KHUNG_TEN');
    d.line(tx, ty + 14, tx + 165, ty + 14, '0_KHUNG_TEN');
    d.line(tx + 115, ty, tx + 115, ty + 28, '0_KHUNG_TEN');
    d.text(tx + 4, ty + 33.5, 'NATIONAL SCIENTIFIC RESEARCH — SRC/CES STUDIO', 2.7, '9_GHI_CHU');
    d.text(
      tx + 4,
      ty + 19.5,
      isBeam
          ? 'SRC BEAM SHOP DRAWING L=${cfg.lengthMm.toStringAsFixed(0)}mm (${g.bMm.toStringAsFixed(0)}x${g.hMm.toStringAsFixed(0)})'
          : 'SRC COLUMN SHOP DRAWING H=${cfg.lengthMm.toStringAsFixed(0)}mm (${g.bMm.toStringAsFixed(0)}x${g.hMm.toStringAsFixed(0)})',
      2.6,
      '9_GHI_CHU',
    );
    d.text(tx + 4, ty + 5.5, 'Codes: EN 1994-1-1 / AISC 360-22 / JGJ 138 / TCVN', 2.3, '9_GHI_CHU');
    d.text(tx + 119, ty + 19.5, isBeam ? 'TAG: SRC-B1' : 'TAG: SRC-C1', 2.7, '9_GHI_CHU');
    d.text(tx + 119, ty + 5.5, 'A3 | UNIT: mm', 2.5, '9_GHI_CHU');

    if (isBeam) {
      const ex0 = 28.0, ey0 = 185.0;
      final scE = math.min(228.0 / math.max(1000.0, cfg.lengthMm), 50.0 / math.max(200.0, g.hMm));
      final elL = cfg.lengthMm * scE;
      final elH = g.hMm * scE;
      d.text(ex0, ey0 + elH + 14, '1. LONGITUDINAL ELEVATION — SRC BEAM (L=${cfg.lengthMm.toStringAsFixed(0)} mm)', 3.4, '9_GHI_CHU');
      d.rect(ex0, ey0, elL, elH, '1_NET_BAO_BT');
      if (g.sectionType == 'SRC_T_SLAB_H') {
        d.line(ex0, ey0 + elH - g.hfSlabMm * scE, ex0 + elL, ey0 + elH - g.hfSlabMm * scE, '1_NET_BAO_BT');
      }
      final ycE = ey0 + 0.5 * elH + g.coreOffsetYMm * scE;
      final haE = g.haMm * scE;
      final tfE = math.max(0.8, g.tfMm * scE);
      d.rect(ex0 - 2.5, ycE - 0.5 * haE, elL + 5.0, haE, '2_THEP_HINH_H');
      d.line(ex0 - 2.5, ycE - 0.5 * haE + tfE, ex0 + elL + 2.5, ycE - 0.5 * haE + tfE, '2_THEP_HINH_H');
      d.line(ex0 - 2.5, ycE + 0.5 * haE - tfE, ex0 + elL + 2.5, ycE + 0.5 * haE - tfE, '2_THEP_HINH_H');
      d.line(ex0 - 7, ycE, ex0 + elL + 7, ycE, '8_TIM_TRUC');

      final cE = (g.coverMm + g.stirrupDiaMm) * scE;
      d.poly([(ex0 + 2, ey0 + cE + 3), (ex0 + 2, ey0 + cE), (ex0 + elL - 2, ey0 + cE), (ex0 + elL - 2, ey0 + cE + 3)], '3_COT_THEP_DOC');
      d.poly([(ex0 + 2, ey0 + elH - cE - 3), (ex0 + 2, ey0 + elH - cE), (ex0 + elL - 2, ey0 + elH - cE), (ex0 + elL - 2, ey0 + elH - cE - 3)], '3_COT_THEP_DOC');

      double xp = 80.0;
      while (xp < cfg.lengthMm - 40.0) {
        final inEnd = xp <= 0.25 * cfg.lengthMm || xp >= 0.75 * cfg.lengthMm;
        d.line(ex0 + xp * scE, ey0 + cE, ex0 + xp * scE, ey0 + elH - cE, '4_COT_DAI');
        xp += inEnd ? g.stirrupSpacingEndMm : g.stirrupSpacingMm;
      }
      double stx = 120.0;
      final shE = math.max(2.2, cfg.studHeightMm * scE);
      while (stx < cfg.lengthMm - 80.0) {
        final sx = ex0 + stx * scE;
        d.line(sx, ycE + 0.5 * haE, sx, ycE + 0.5 * haE + shE, '5_DINH_NEO_STUD');
        d.line(sx - 1.0, ycE + 0.5 * haE + shE, sx + 1.0, ycE + 0.5 * haE + shE, '5_DINH_NEO_STUD');
        stx += math.max(100.0, cfg.studSpacingMm);
      }
      d.dimH(ex0, ex0 + elL, ey0, ey0 - 18, 'SPAN L = ${cfg.lengthMm.toStringAsFixed(0)} mm');
      d.dimV(ex0, ex0 - 10, ey0, ey0 + elH, 'h=${g.hMm.toStringAsFixed(0)}');

      // Mặt cắt 1-1
      const cxS = 335.0, cyS = 210.0;
      final scS = math.min(90.0 / math.max(300.0, g.sectionType == 'SRC_T_SLAB_H' ? g.bfSlabMm : g.bMm), 80.0 / math.max(250.0, g.hMm));
      final bS = g.bMm * scS, hS = g.hMm * scS, covS = g.coverMm * scS;
      d.text(cxS, cyS + 0.5 * hS + 14, '2. SECTION 1-1 (SCALE 1:${(1.0 / scS).toStringAsFixed(1)})', 3.4, '9_GHI_CHU', align: 1);
      if (g.sectionType == 'SRC_T_SLAB_H') {
        final bfS = g.bfSlabMm * scS, hfS = g.hfSlabMm * scS;
        d.poly([
          (cxS - 0.5 * bS, cyS - 0.5 * hS), (cxS + 0.5 * bS, cyS - 0.5 * hS),
          (cxS + 0.5 * bS, cyS + 0.5 * hS - hfS), (cxS + 0.5 * bfS, cyS + 0.5 * hS - hfS),
          (cxS + 0.5 * bfS, cyS + 0.5 * hS), (cxS - 0.5 * bfS, cyS + 0.5 * hS),
          (cxS - 0.5 * bfS, cyS + 0.5 * hS - hfS), (cxS - 0.5 * bS, cyS + 0.5 * hS - hfS),
        ], '1_NET_BAO_BT', closed: true);
      } else {
        d.rect(cxS - 0.5 * bS, cyS - 0.5 * hS, bS, hS, '1_NET_BAO_BT');
      }
      d.rect(cxS - 0.5 * bS + covS, cyS - 0.5 * hS + covS, bS - 2 * covS, hS - 2 * covS, '4_COT_DAI');
      _drawSteelDxf(d, cxS, cyS, scS, g);
      for (final rb in res.props.rebars) {
        d.circle(cxS + rb.zMm * scS, cyS + rb.yMm * scS, math.max(1.1, 0.5 * rb.diaMm * scS), '3_COT_THEP_DOC');
      }
      d.dimH(cxS - 0.5 * bS, cxS + 0.5 * bS, cyS - 0.5 * hS, cyS - 0.5 * hS - 10, 'b=${g.bMm.toStringAsFixed(0)}');
    } else {
      // Cột: Mặt đứng + Mặt cắt 1-1 + Bản đế chân cột
      final scE = math.min(190.0 / math.max(1500.0, cfg.lengthMm), 46.0 / math.max(200.0, g.bMm));
      final cw = g.bMm * scE, ch = cfg.lengthMm * scE;
      const cxE = 56.0, ey0 = 44.0;
      d.text(cxE, ey0 + ch + 13, '1. COLUMN ELEVATION (H=${cfg.lengthMm.toStringAsFixed(0)})', 3.3, '9_GHI_CHU', align: 1);
      d.rect(cxE - 0.5 * cw, ey0, cw, ch, '1_NET_BAO_BT');
      d.rect(cxE - 0.5 * g.haMm * scE, ey0, g.haMm * scE, ch, '2_THEP_HINH_H');
      d.rect(cxE - 0.5 * cw - 5, ey0 - 3.5, cw + 10, 3.5, '6_BAN_DE_LIEN_KET');
      double yp = 80.0;
      final covE = g.coverMm * scE;
      while (yp < cfg.lengthMm - 50.0) {
        final inEnd = yp <= 0.2 * cfg.lengthMm || yp >= 0.8 * cfg.lengthMm;
        d.line(cxE - 0.5 * cw + covE, ey0 + yp * scE, cxE + 0.5 * cw - covE, ey0 + yp * scE, '4_COT_DAI');
        yp += inEnd ? g.stirrupSpacingEndMm : g.stirrupSpacingMm;
      }
      d.dimV(cxE - 0.5 * cw, cxE - 0.5 * cw - 14, ey0, ey0 + ch, 'H=${cfg.lengthMm.toStringAsFixed(0)}');

      const cxS = 165.0, cyS = 210.0;
      final scS = math.min(76.0 / math.max(200.0, g.bMm), 76.0 / math.max(200.0, g.hMm));
      final bS = g.bMm * scS, hS = g.hMm * scS, covS = g.coverMm * scS;
      d.text(cxS, cyS + 0.5 * hS + 13, '2. SECTION 1-1', 3.4, '9_GHI_CHU', align: 1);
      if (g.sectionType == 'COL_CIRC_H') {
        d.circle(cxS, cyS, 0.5 * bS, '1_NET_BAO_BT');
        d.circle(cxS, cyS, 0.5 * bS - covS, '4_COT_DAI');
      } else {
        d.rect(cxS - 0.5 * bS, cyS - 0.5 * hS, bS, hS, '1_NET_BAO_BT');
        d.rect(cxS - 0.5 * bS + covS, cyS - 0.5 * hS + covS, bS - 2 * covS, hS - 2 * covS, '4_COT_DAI');
      }
      _drawSteelDxf(d, cxS, cyS, scS, g);
      for (final rb in res.props.rebars) {
        d.circle(cxS + rb.zMm * scS, cyS + rb.yMm * scS, math.max(1.1, 0.5 * rb.diaMm * scS), '3_COT_THEP_DOC');
      }
      d.dimH(cxS - 0.5 * bS, cxS + 0.5 * bS, cyS - 0.5 * hS, cyS - 0.5 * hS - 10, 'b=${g.bMm.toStringAsFixed(0)}');

      const cxB = 315.0, cyB = 210.0;
      final bpW = g.bMm + 120.0, bpH = g.hMm + 120.0;
      final scB = math.min(74.0 / bpW, 74.0 / bpH);
      final bwS = bpW * scB, bhS = bpH * scB;
      d.text(cxB, cyB + 0.5 * bhS + 13, '3. BASEPLATE PL30x${bpW.toStringAsFixed(0)}x${bpH.toStringAsFixed(0)}', 3.3, '9_GHI_CHU', align: 1);
      d.rect(cxB - 0.5 * bwS, cyB - 0.5 * bhS, bwS, bhS, '6_BAN_DE_LIEN_KET');
      _drawSteelDxf(d, cxB, cyB, scB, g);
      for (final (fx, fy) in const [(-0.38, -0.38), (0.0, -0.38), (0.38, -0.38), (0.38, 0.0), (0.38, 0.38), (0.0, 0.38), (-0.38, 0.38), (-0.38, 0.0)]) {
        d.circle(cxB + fx * bwS, cyB + fy * bhS, 1.8, '6_BAN_DE_LIEN_KET');
      }
    }

    // Bảng thống kê BOM
    final bx = isBeam ? 18.0 : 112.0;
    const by = 128.0, rh = 8.5;
    const cw = [18.0, 110.0, 34.0, 28.0, 28.0];
    final totW = cw.reduce((a, b) => a + b);
    d.text(bx, by + 6, 'BILL OF MATERIALS & FABRICATION SCHEDULE (BOM / BBS)', 3.2, '9_GHI_CHU');
    d.rect(bx, by - rh * (res.bom.length + 2), totW, rh * (res.bom.length + 2), '9_GHI_CHU');
    double cxT = bx;
    for (int i = 0; i < cw.length; i++) {
      d.text(cxT + 2, by - 6, const ['MARK', 'SPECIFICATION', 'GRADE', 'QTY', 'MASS (kg)'][i], 2.5, '9_GHI_CHU');
      cxT += cw[i];
    }
    d.line(bx, by - rh, bx + totW, by - rh, '9_GHI_CHU');
    double steelKg = 0;
    for (int idx = 0; idx < res.bom.length; idx++) {
      final it = res.bom[idx];
      if (it.mark != 'C-1') steelKg += it.weightKg;
      final ry = by - rh * (idx + 2);
      cxT = bx;
      final vals = [it.mark, it.descEn, it.grade, it.qtyEn, it.weightKg.toStringAsFixed(1)];
      for (int i = 0; i < cw.length; i++) {
        d.text(cxT + 2, ry + 2.5, vals[i], 2.3, '9_GHI_CHU');
        cxT += cw[i];
      }
      d.line(bx, ry, bx + totW, ry, '9_GHI_CHU');
    }
    d.text(bx + 2, by - rh * (res.bom.length + 2) + 2.5, 'TOTAL STEEL + REBAR + HARDWARE: ${steelKg.toStringAsFixed(1)} kg', 2.5, '9_GHI_CHU');
    return d.build();
  }

  static Future<String?> exportDxf(SrcAnalysisResult res) async {
    final dxfStr = buildDxfString(res);
    final bytes = Uint8List.fromList(utf8.encode(dxfStr));
    final tag = res.config.kind == MemberKind.beam ? 'DamCotCung_SRC' : 'CotCotCung_SRC';
    return saveBinaryFile('BanVe_ThiCong_$tag.dxf', bytes, 'application/dxf');
  }

  /// Xuất Bản vẽ Kỹ thuật Vector PDF khổ A3 ngang song ngữ VI / EN
  static Future<String?> exportDrawingPdf(SrcAnalysisResult res, AppLang lang) async {
    final fontReg = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final fontBold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    final doc = pw.Document();
    final cfg = res.config;
    final g = cfg.geometry;
    final isBeam = cfg.kind == MemberKind.beam;
    final vi = lang.isVi;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a3.landscape,
        margin: const pw.EdgeInsets.all(22),
        build: (ctx) {
          final steelKg = res.bom.where((b) => b.mark != 'C-1').fold<double>(0.0, (s, b) => s + b.weightKg);
          return pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey900, width: 1.5)),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      tr(lang, 'BẢN VẼ GIA CÔNG, CHẾ TẠO & THI CÔNG KẾT CẤU BÊ TÔNG CỐT CỨNG (SRC/CES)',
                          'FABRICATION & CONSTRUCTION SHOP DRAWING — COMPOSITE SRC/CES MEMBER'),
                      style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColor.fromHex('#0F3D6E')),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: res.overallPass ? PdfColor.fromHex('#059669') : PdfColor.fromHex('#DC2626'),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        res.overallPass ? tr(lang, 'ĐẠT / PASS', 'PASS') : tr(lang, 'CHƯA ĐẠT / FAIL', 'FAIL'),
                        style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                // Khung vẽ vector Mặt đứng & Mặt cắt ngang
                pw.Expanded(
                  flex: 6,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.7)),
                    child: pw.CustomPaint(
                      size: const PdfPoint(1080, 400),
                      painter: (canvas, size) {
                        _paintPdfEngineeringViews(canvas, size, res);
                      },
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                // Bảng thống kê BOM + Khung tên góc phải
                pw.Expanded(
                  flex: 4,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Expanded(
                        flex: 6,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              tr(lang, 'BẢNG THỐNG KÊ THÉP HÌNH, CỐT THÉP & VẬT LIỆU CHẾ TẠO (BOM / BBS)',
                                  'BILL OF MATERIALS & FABRICATION SCHEDULE (BOM / BBS)'),
                              style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColor.fromHex('#0F3D6E')),
                            ),
                            pw.SizedBox(height: 4),
                            pw.TableHelper.fromTextArray(
                              headerStyle: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
                              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F3D6E')),
                              cellStyle: pw.TextStyle(font: fontReg, fontSize: 7.8),
                              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                              headers: vi
                                  ? const ['SH', 'Hạng mục / Quy cách chế tạo', 'Mác VL', 'Số lượng', 'KL (kg)']
                                  : const ['Mark', 'Specification / Description', 'Grade', 'Qty', 'Mass (kg)'],
                              data: [
                                for (final b in res.bom)
                                  [b.mark, vi ? b.descVi : b.descEn, b.grade, vi ? b.qtyVi : b.qtyEn, b.weightKg.toStringAsFixed(1)],
                              ],
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              tr(lang, 'Tổng khối lượng thép chế tạo (Thép hình + Cốt thép + Phụ kiện): ${steelKg.toStringAsFixed(1)} kg (${(steelKg / 1000).toStringAsFixed(3)} tấn)',
                                  'Total Fabricated Steel Mass (Profile + Rebar + Hardware): ${steelKg.toStringAsFixed(1)} kg (${(steelKg / 1000).toStringAsFixed(3)} t)'),
                              style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColor.fromHex('#0F3D6E')),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        flex: 4,
                        child: pw.Container(
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#F8FAFC'),
                            border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.0),
                          ),
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Container(
                                width: double.infinity,
                                color: PdfColor.fromHex('#0F3D6E'),
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(
                                  tr(lang, 'KHUNG TÊN BẢN VẼ THI CÔNG — NCKH CẤP QUỐC GIA', 'CONSTRUCTION TITLE BLOCK — NATIONAL RESEARCH'),
                                  style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
                                ),
                              ),
                              pw.Text(cfg.name, style: pw.TextStyle(font: fontBold, fontSize: 9.5)),
                              pw.Text(
                                isBeam
                                    ? 'L = ${cfg.lengthMm.toStringAsFixed(0)} mm | b×h = ${g.bMm.toStringAsFixed(0)}×${g.hMm.toStringAsFixed(0)} mm | H${g.haMm.toStringAsFixed(0)}×${g.baMm.toStringAsFixed(0)}×${g.twMm.toStringAsFixed(1)}×${g.tfMm.toStringAsFixed(1)}'
                                    : 'H = ${cfg.lengthMm.toStringAsFixed(0)} mm | b×h = ${g.bMm.toStringAsFixed(0)}×${g.hMm.toStringAsFixed(0)} mm | ${g.sectionType}',
                                style: pw.TextStyle(font: fontReg, fontSize: 8),
                              ),
                              pw.Text(
                                '${cfg.material.concreteGrade} | ${cfg.material.steelGrade} | ${cfg.material.rebarGrade}',
                                style: pw.TextStyle(font: fontReg, fontSize: 8),
                              ),
                              pw.Text(
                                tr(lang, 'ĐH Bách Khoa - ĐHQG TP.HCM | GVHD: PGS.TS Ngô Cường | HVTH: Võ Thanh Vang (2670624)',
                                    'HCMUT - VNU-HCM | Advisor: Assoc. Prof. Dr. Ngo Cuong | Vo Thanh Vang (2670624)'),
                                style: pw.TextStyle(font: fontBold, fontSize: 7.0, color: PdfColor.fromHex('#1E3A8A')),
                              ),
                              pw.Text(
                                'EC4 (EN 1994-1-1) • ANSI/AISC 360-22 • JGJ 138 • TCVN 5574/5575',
                                style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColor.fromHex('#0F766E')),
                              ),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(isBeam ? 'TAG: SRC-B1' : 'TAG: SRC-C1', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                                  pw.Text('ISO A3 | UNIT: mm', style: pw.TextStyle(font: fontReg, fontSize: 8)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await doc.save();
    final tag = isBeam ? 'DamCotCung' : 'CotCotCung';
    return saveBinaryFile('BanVe_ThiCong_${tag}_${lang.code.toUpperCase()}.pdf', Uint8List.fromList(bytes), 'application/pdf');
  }

  static void _paintPdfEngineeringViews(PdfGraphics c, PdfPoint sz, SrcAnalysisResult res) {
    final cfg = res.config;
    final g = cfg.geometry;
    final isBeam = cfg.kind == MemberKind.beam;

    void drawSteelSection(double cx, double cy, double sc) {
      final yc = cy + g.coreOffsetYMm * sc;
      final ha = g.haMm * sc, ba = g.baMm * sc, tf = g.tfMm * sc, tw = g.twMm * sc;
      c.setFillColor(PdfColor.fromHex('#DC2626'));
      c.setStrokeColor(PdfColor.fromHex('#7F1D1D'));
      c.setLineWidth(0.7);
      if (g.sectionType == 'COL_RECT_CFST') {
        c.setLineWidth(math.max(1.8, tf));
        c.setStrokeColor(PdfColor.fromHex('#DC2626'));
        c.drawEllipse(cx, yc, 0.5 * ha - 0.5 * tf, 0.5 * ha - 0.5 * tf);
        c.strokePath();
        return;
      }
      c.drawRect(cx - 0.5 * ba, yc - 0.5 * ha, ba, tf);
      c.fillAndStrokePath();
      c.drawRect(cx - 0.5 * ba, yc + 0.5 * ha - tf, ba, tf);
      c.fillAndStrokePath();
      c.drawRect(cx - 0.5 * tw, yc - 0.5 * ha + tf, tw, ha - 2 * tf);
      c.fillAndStrokePath();
      if (g.sectionType == 'COL_RECT_CROSS_H') {
        c.drawRect(cx - 0.5 * ha, yc - 0.5 * ba, tf, ba);
        c.fillAndStrokePath();
        c.drawRect(cx + 0.5 * ha - tf, yc - 0.5 * ba, tf, ba);
        c.fillAndStrokePath();
        c.drawRect(cx - 0.5 * ha + tf, yc - 0.5 * tw, ha - 2 * tf, tw);
        c.fillAndStrokePath();
      }
    }

    if (isBeam) {
      // Mặt đứng dầm bên trái
      const ex = 40.0, ey = 110.0;
      final scE = math.min(540.0 / math.max(1000.0, cfg.lengthMm), 150.0 / math.max(200.0, g.hMm));
      final elL = cfg.lengthMm * scE, elH = g.hMm * scE;
      c.setFillColor(PdfColor.fromHex('#E2E8F0'));
      c.setStrokeColor(PdfColor.fromHex('#0F172A'));
      c.setLineWidth(1.2);
      c.drawRect(ex, ey, elL, elH);
      c.fillAndStrokePath();
      if (g.sectionType == 'SRC_T_SLAB_H') {
        c.setFillColor(PdfColor.fromHex('#CBD5E1'));
        c.drawRect(ex, ey + elH - g.hfSlabMm * scE, elL, g.hfSlabMm * scE);
        c.fillAndStrokePath();
      }
      final ycE = ey + 0.5 * elH + g.coreOffsetYMm * scE;
      final haE = g.haMm * scE;
      c.setFillColor(PdfColor.fromHex('#FCA5A5'));
      c.setStrokeColor(PdfColor.fromHex('#B91C1C'));
      c.drawRect(ex, ycE - 0.5 * haE, elL, haE);
      c.fillAndStrokePath();

      final covE = (g.coverMm + g.stirrupDiaMm) * scE;
      c.setStrokeColor(PdfColor.fromHex('#0284C7'));
      c.setLineWidth(0.7);
      double xp = 80.0;
      while (xp < cfg.lengthMm - 40.0) {
        final inEnd = xp <= 0.25 * cfg.lengthMm || xp >= 0.75 * cfg.lengthMm;
        c.moveTo(ex + xp * scE, ey + covE);
        c.lineTo(ex + xp * scE, ey + elH - covE);
        c.strokePath();
        xp += inEnd ? g.stirrupSpacingEndMm : g.stirrupSpacingMm;
      }
      c.setStrokeColor(PdfColor.fromHex('#15803D'));
      c.setLineWidth(1.8);
      c.moveTo(ex + 4, ey + covE);
      c.lineTo(ex + elL - 4, ey + covE);
      c.moveTo(ex + 4, ey + elH - covE);
      c.lineTo(ex + elL - 4, ey + elH - covE);
      c.strokePath();

      // Mặt cắt ngang 1-1 bên phải
      final cx = sz.x * 0.78, cy = sz.y * 0.52;
      final scS = math.min(280.0 / math.max(300.0, g.sectionType == 'SRC_T_SLAB_H' ? g.bfSlabMm : g.bMm), 230.0 / math.max(250.0, g.hMm));
      final bS = g.bMm * scS, hS = g.hMm * scS, covS = g.coverMm * scS;
      c.setFillColor(PdfColor.fromHex('#E2E8F0'));
      c.setStrokeColor(PdfColor.fromHex('#0F172A'));
      c.setLineWidth(1.2);
      c.drawRect(cx - 0.5 * bS, cy - 0.5 * hS, bS, hS);
      c.fillAndStrokePath();
      if (g.sectionType == 'SRC_T_SLAB_H') {
        final bfS = g.bfSlabMm * scS, hfS = g.hfSlabMm * scS;
        c.drawRect(cx - 0.5 * bfS, cy + 0.5 * hS - hfS, bfS, hfS);
        c.fillAndStrokePath();
      }
      c.setStrokeColor(PdfColor.fromHex('#0284C7'));
      c.drawRect(cx - 0.5 * bS + covS, cy - 0.5 * hS + covS, bS - 2 * covS, hS - 2 * covS);
      c.strokePath();
      drawSteelSection(cx, cy, scS);
      c.setFillColor(PdfColor.fromHex('#15803D'));
      for (final rb in res.props.rebars) {
        c.drawEllipse(cx + rb.zMm * scS, cy + rb.yMm * scS, math.max(2.6, 0.5 * rb.diaMm * scS), math.max(2.6, 0.5 * rb.diaMm * scS));
        c.fillPath();
      }
    } else {
      // Cột: Mặt đứng + Mặt cắt + Bản đế
      final scE = math.min(280.0 / math.max(1500.0, cfg.lengthMm), 90.0 / math.max(200.0, g.bMm));
      final cw = g.bMm * scE, ch = cfg.lengthMm * scE;
      const cxE = 140.0, ey = 55.0;
      c.setFillColor(PdfColor.fromHex('#E2E8F0'));
      c.setStrokeColor(PdfColor.fromHex('#0F172A'));
      c.drawRect(cxE - 0.5 * cw, ey, cw, ch);
      c.fillAndStrokePath();
      c.setFillColor(PdfColor.fromHex('#FCA5A5'));
      c.setStrokeColor(PdfColor.fromHex('#B91C1C'));
      c.drawRect(cxE - 0.5 * g.haMm * scE, ey, g.haMm * scE, ch);
      c.fillAndStrokePath();
      c.setFillColor(PdfColor.fromHex('#1E40AF'));
      c.drawRect(cxE - 0.5 * cw - 12, ey - 10, cw + 24, 10);
      c.fillAndStrokePath();

      // Mặt cắt 1-1
      final cxS = sz.x * 0.48, cyS = sz.y * 0.50;
      final scS = math.min(220.0 / math.max(200.0, g.bMm), 220.0 / math.max(200.0, g.hMm));
      final bS = g.bMm * scS, hS = g.hMm * scS, covS = g.coverMm * scS;
      c.setFillColor(PdfColor.fromHex('#E2E8F0'));
      c.setStrokeColor(PdfColor.fromHex('#0F172A'));
      if (g.sectionType == 'COL_CIRC_H') {
        c.drawEllipse(cxS, cyS, 0.5 * bS, 0.5 * bS);
        c.fillAndStrokePath();
        c.setStrokeColor(PdfColor.fromHex('#0284C7'));
        c.drawEllipse(cxS, cyS, 0.5 * bS - covS, 0.5 * bS - covS);
        c.strokePath();
      } else {
        c.drawRect(cxS - 0.5 * bS, cyS - 0.5 * hS, bS, hS);
        c.fillAndStrokePath();
        c.setStrokeColor(PdfColor.fromHex('#0284C7'));
        c.drawRect(cxS - 0.5 * bS + covS, cyS - 0.5 * hS + covS, bS - 2 * covS, hS - 2 * covS);
        c.strokePath();
      }
      drawSteelSection(cxS, cyS, scS);
      c.setFillColor(PdfColor.fromHex('#15803D'));
      for (final rb in res.props.rebars) {
        c.drawEllipse(cxS + rb.zMm * scS, cyS + rb.yMm * scS, math.max(2.6, 0.5 * rb.diaMm * scS), math.max(2.6, 0.5 * rb.diaMm * scS));
        c.fillPath();
      }

      // Bản đế chân cột
      final cxB = sz.x * 0.80, cyB = sz.y * 0.50;
      final bpW = g.bMm + 120.0, bpH = g.hMm + 120.0;
      final scB = math.min(210.0 / bpW, 210.0 / bpH);
      final bwS = bpW * scB, bhS = bpH * scB;
      c.setFillColor(PdfColor.fromHex('#DBEAFE'));
      c.setStrokeColor(PdfColor.fromHex('#1E40AF'));
      c.drawRect(cxB - 0.5 * bwS, cyB - 0.5 * bhS, bwS, bhS);
      c.fillAndStrokePath();
      drawSteelSection(cxB, cyB, scB);
      c.setFillColor(PdfColor.fromHex('#1E3A8A'));
      for (final (fx, fy) in const [(-0.38, -0.38), (0.0, -0.38), (0.38, -0.38), (0.38, 0.0), (0.38, 0.38), (0.0, 0.38), (-0.38, 0.38), (-0.38, 0.0)]) {
        c.drawEllipse(cxB + fx * bwS, cyB + fy * bhS, 4.2, 4.2);
        c.fillPath();
      }
    }
  }
}
