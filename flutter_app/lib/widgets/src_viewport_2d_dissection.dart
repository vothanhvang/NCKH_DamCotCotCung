// ============================================================================
// KHUNG NHÌN 2D ANSYS & PHẪU THUẬT MẶT CẮT NGANG TƯƠNG TÁC (SURGICAL PROBE)
// ============================================================================
// Cho phép người dùng:
//   • Xem mô phỏng 2D dọc trục cấu kiện (biến dạng, biểu đồ M(x), V(x)/N(x),
//     khe nứt kéo, đường trượt mặt cắt phẫu thuật x/L).
//   • Chạm/kéo trỏ chuột VÀO BẤT KỲ ĐIỂM NÀO (y, z) bên trong tiết diện ngang
//     để khảo sát trực tiếp ứng xử biến dạng ε_x, ứng suất σ_x, ứng suất tiếp
//     τ_xy, von Mises σ_vM, vùng giam giữ & trạng thái Nứt / Chảy dẻo / Vỡ nén!
//   • Xem đồng thời biểu đồ phân bố biến dạng phẳng ε(y) và ứng suất phi tuyến σ(y).
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/src_engine.dart';
import 'ansys_colorbar.dart';

class SrcViewport2DDissection extends StatefulWidget {
  final SrcAnalysisResult result;
  final ContourField field;
  final double probeXNorm;
  final bool darkMode;
  final AppLang lang;
  final ValueChanged<double> onProbeXChanged;

  const SrcViewport2DDissection({
    super.key,
    required this.result,
    required this.field,
    required this.probeXNorm,
    required this.darkMode,
    required this.lang,
    required this.onProbeXChanged,
  });

  @override
  State<SrcViewport2DDissection> createState() => _SrcViewport2DDissectionState();
}

class _SrcViewport2DDissectionState extends State<SrcViewport2DDissection> {
  double _probeYMm = 0.0;
  double _probeZMm = 0.0;

  @override
  Widget build(BuildContext context) {
    final res = widget.result;
    final l = widget.lang;
    final dark = widget.darkMode;
    final g = res.config.geometry;
    final yClamped = _probeYMm.clamp(-0.5 * g.hMm, 0.5 * g.hMm);
    final bMax = g.sectionType == 'SRC_T_SLAB_H' ? g.bfSlabMm : g.bMm;
    final zClamped = _probeZMm.clamp(-0.5 * bMax, 0.5 * bMax);

    final dis = SrcNonlinearEngine.dissectSection(res, widget.probeXNorm);
    final probe = SrcNonlinearEngine.probePoint(res, widget.probeXNorm, yClamped, zClamped);

    final cardBg = dark ? const Color(0xFF0F172A) : Colors.white;
    final border = dark ? const Color(0xFF263859) : const Color(0xFFCBD5E1);
    final fg = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;

        final longitudinalCard = Container(
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.linear_scale, size: 16, color: Color(0xFF06B6D4)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr(l, '1. Mô phỏng 2D Dọc Cấu kiện & Biểu đồ Nội lực (Chạm để dịch mặt cắt x/L)',
                          '1. 2D Longitudinal ANSYS View & Internal Forces (Tap to move cut plane x/L)'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
                    ),
                  ),
                  Text(
                    'x/L = ${widget.probeXNorm.toStringAsFixed(2)} (${dis.xMm.toStringAsFixed(0)} mm)',
                    style: const TextStyle(fontSize: 11, fontFamily: 'DejaVuSansMono', color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, c2) {
                    return GestureDetector(
                      onTapDown: (d) => _updateXFromTap(d.localPosition.dx, c2.maxWidth),
                      onHorizontalDragUpdate: (d) => _updateXFromTap(d.localPosition.dx, c2.maxWidth),
                      child: CustomPaint(
                        size: Size(c2.maxWidth, c2.maxHeight),
                        painter: _Longitudinal2DPainter(
                          result: res,
                          probeXNorm: widget.probeXNorm,
                          darkMode: dark,
                          lang: l,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );

        final sectionCard = Container(
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.biotech, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr(l, '2. Phẫu thuật Mặt cắt Ngang — Chạm điểm (y, z) bất kỳ để khảo sát',
                          '2. Surgical Cross-Section Dissector — Tap any (y, z) point to probe'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                flex: 6,
                child: Row(
                  children: [
                    // Bản đồ màu 2D các thớ trong mặt cắt ngang (tương tác chạm)
                    Expanded(
                      flex: 6,
                      child: LayoutBuilder(
                        builder: (ctx, cs) {
                          return GestureDetector(
                            onTapDown: (d) => _updateProbeYZ(d.localPosition, Size(cs.maxWidth, cs.maxHeight)),
                            onPanUpdate: (d) => _updateProbeYZ(d.localPosition, Size(cs.maxWidth, cs.maxHeight)),
                            child: CustomPaint(
                              size: Size(cs.maxWidth, cs.maxHeight),
                              painter: _SectionHeatmapPainter(
                                result: res,
                                dis: dis,
                                field: widget.field,
                                probeYMm: yClamped,
                                probeZMm: zClamped,
                                darkMode: dark,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Biểu đồ biến dạng ε(y) & ứng suất σ(y) dọc chiều cao tiết diện
                    Expanded(
                      flex: 4,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _StrainStressProfilePainter(
                          result: res,
                          dis: dis,
                          probeYMm: yClamped,
                          darkMode: dark,
                          lang: l,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Bảng đọc kết quả Khảo sát điểm (Probe Readout)
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF0A1224) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.my_location, size: 14, color: Color(0xFF06B6D4)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${tr(l, "ĐIỂM KHẢO SÁT", "PROBE POINT")} (x=${probe.xMm.toStringAsFixed(0)}, y=${probe.yMm.toStringAsFixed(1)}, z=${probe.zMm.toStringAsFixed(1)} mm) — ${l.isVi ? probe.materialVi : probe.materialEn}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l.isVi ? probe.zoneVi : probe.zoneEn}  •  ${tr(l, "Trạng thái", "State")}: ${l.isVi ? probe.stateVi : probe.stateEn}',
                      style: TextStyle(fontSize: 10.5, color: sub),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _metricChip('ε_x', '${(probe.epsX * 1000).toStringAsFixed(3)} ‰', const Color(0xFF38BDF8), dark),
                        _metricChip('σ_x', '${probe.sigmaXMpa.toStringAsFixed(2)} MPa', const Color(0xFFF59E0B), dark),
                        _metricChip('τ_xy', '${probe.tauXyMpa.toStringAsFixed(2)} MPa', const Color(0xFFA855F7), dark),
                        _metricChip('σ_vM', '${probe.sigmaVmMpa.toStringAsFixed(2)} MPa', const Color(0xFFEF4444), dark),
                        _metricChip('UR', '${(probe.utilRatio * 100).toStringAsFixed(1)} %',
                            probe.utilRatio > 1.0 ? const Color(0xFFEF4444) : const Color(0xFF10B981), dark),
                        _metricChip('x_NA', '${probe.xNaMm.toStringAsFixed(1)} mm', const Color(0xFF06B6D4), dark),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (wide) {
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(flex: 5, child: longitudinalCard),
                const SizedBox(width: 10),
                Expanded(flex: 5, child: sectionCard),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              SizedBox(height: 330, child: longitudinalCard),
              const SizedBox(height: 10),
              SizedBox(height: 440, child: sectionCard),
            ],
          ),
        );
      },
    );
  }

  void _updateXFromTap(double dx, double width) {
    final pad = 42.0;
    final norm = ((dx - pad) / math.max(1.0, width - 2 * pad)).clamp(0.02, 0.98);
    widget.onProbeXChanged(norm);
  }

  void _updateProbeYZ(Offset pos, Size sz) {
    final g = widget.result.config.geometry;
    final bDraw = g.sectionType == 'SRC_T_SLAB_H' ? g.bfSlabMm : g.bMm;
    final sc = math.min((sz.width - 36) / math.max(100.0, bDraw), (sz.height - 36) / math.max(100.0, g.hMm));
    final cx = sz.width * 0.5;
    final cy = sz.height * 0.5;
    setState(() {
      _probeZMm = ((pos.dx - cx) / sc).clamp(-0.5 * bDraw, 0.5 * bDraw);
      _probeYMm = ((cy - pos.dy) / sc).clamp(-0.5 * g.hMm, 0.5 * g.hMm);
    });
  }

  Widget _metricChip(String k, String v, Color accent, bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 10.5, fontFamily: 'DejaVuSansMono', color: dark ? Colors.white : const Color(0xFF0F172A)),
          children: [
            TextSpan(text: '$k: ', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
            TextSpan(text: v, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _Longitudinal2DPainter extends CustomPainter {
  final SrcAnalysisResult result;
  final double probeXNorm;
  final bool darkMode;
  final AppLang lang;
  const _Longitudinal2DPainter({required this.result, required this.probeXNorm, required this.darkMode, required this.lang});

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 42.0, padR = 24.0;
    final plotW = math.max(40.0, size.width - padL - padR);
    final L = result.config.lengthMm;
    final fg = darkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final grid = darkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    // Phần trên: Thân cấu kiện 2D biến dạng + Lõi thép H + Nứt kéo
    final topH = size.height * 0.46;
    final cyMem = topH * 0.52;
    final memH = math.min(topH * 0.54, 72.0);
    final maxD = result.profileDeflMm.fold<double>(0.1, (a, b) => math.max(a, b.abs()));
    final dAmp = math.min(22.0, topH * 0.18) / maxD;

    // Vẽ phân đoạn màu ứng suất dọc chiều dài
    final nP = result.profileXMm.length;
    final maxM = result.profileMKnm.fold<double>(1.0, (a, b) => math.max(a, b.abs()));
    for (int i = 0; i < nP - 1; i++) {
      final x1 = padL + (result.profileXMm[i] / L) * plotW;
      final x2 = padL + (result.profileXMm[i + 1] / L) * plotW;
      final y1 = cyMem - result.profileDeflMm[i] * dAmp;
      final y2 = cyMem - result.profileDeflMm[i + 1] * dAmp;
      final t = (result.profileMKnm[i].abs() / maxM).clamp(0.0, 1.0);
      final col = ansysRainbowColor(t).withValues(alpha: 0.45);
      final path = Path()
        ..moveTo(x1, y1 - 0.5 * memH)
        ..lineTo(x2, y2 - 0.5 * memH)
        ..lineTo(x2, y2 + 0.5 * memH)
        ..lineTo(x1, y1 + 0.5 * memH)
        ..close();
      canvas.drawPath(path, Paint()..color = col);
    }

    // Vẽ lõi thép hình H chạy bên trong
    final g = result.config.geometry;
    final hCorePx = memH * (g.haMm / g.hMm);
    final pCore = Path();
    for (int i = 0; i < nP; i++) {
      final x = padL + (result.profileXMm[i] / L) * plotW;
      final y = cyMem - result.profileDeflMm[i] * dAmp;
      if (i == 0) {
        pCore.moveTo(x, y - 0.5 * hCorePx);
      } else {
        pCore.lineTo(x, y - 0.5 * hCorePx);
      }
    }
    for (int i = nP - 1; i >= 0; i--) {
      final x = padL + (result.profileXMm[i] / L) * plotW;
      final y = cyMem - result.profileDeflMm[i] * dAmp;
      pCore.lineTo(x, y + 0.5 * hCorePx);
    }
    pCore.close();
    canvas.drawPath(pCore, Paint()..color = const Color(0x66EF4444));
    canvas.drawPath(pCore, Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.stroke..strokeWidth = 1.4);

    // Phần dưới: Biểu đồ Mô-men uốn M(x)
    final botTop = size.height * 0.54;
    final botH = size.height * 0.40;
    final baseY = botTop + botH * 0.16;
    canvas.drawLine(Offset(padL, baseY), Offset(padL + plotW, baseY), Paint()..color = grid..strokeWidth = 1.2);
    final mPath = Path()..moveTo(padL, baseY);
    for (int i = 0; i < nP; i++) {
      final x = padL + (result.profileXMm[i] / L) * plotW;
      final y = baseY + (result.profileMKnm[i].abs() / maxM) * (botH * 0.72);
      mPath.lineTo(x, y);
    }
    mPath.lineTo(padL + plotW, baseY);
    mPath.close();
    canvas.drawPath(mPath, Paint()..color = const Color(0xFF06B6D4).withValues(alpha: 0.22));
    canvas.drawPath(mPath, Paint()..color = const Color(0xFF06B6D4)..style = PaintingStyle.stroke..strokeWidth = 2.0);

    _drawTxt(
      canvas,
      Offset(padL, botTop - 4),
      '${tr(lang, "Biểu đồ Mô-men M_z(x)", "Bending Moment M_z(x)")} — Max = ${maxM.toStringAsFixed(1)} kN·m',
      fg,
      10,
    );

    // Đường cắt phẫu thuật kéo được tại x/L
    final xCut = padL + probeXNorm * plotW;
    canvas.drawLine(Offset(xCut, 8), Offset(xCut, size.height - 10), Paint()..color = const Color(0xFFF59E0B)..strokeWidth = 2.2);
    canvas.drawCircle(Offset(xCut, cyMem), 5.5, Paint()..color = const Color(0xFFF59E0B));
  }

  void _drawTxt(Canvas c, Offset pos, String s, Color col, double fs) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, pos);
  }

  @override
  bool shouldRepaint(covariant _Longitudinal2DPainter old) => true;
}

class _SectionHeatmapPainter extends CustomPainter {
  final SrcAnalysisResult result;
  final DissectionResult dis;
  final ContourField field;
  final double probeYMm, probeZMm;
  final bool darkMode;

  const _SectionHeatmapPainter({
    required this.result,
    required this.dis,
    required this.field,
    required this.probeYMm,
    required this.probeZMm,
    required this.darkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final g = result.config.geometry;
    final bDraw = g.sectionType == 'SRC_T_SLAB_H' ? g.bfSlabMm : g.bMm;
    final sc = math.min((size.width - 36) / math.max(100.0, bDraw), (size.height - 36) / math.max(100.0, g.hMm));
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;

    final spanSig = math.max(1.0, dis.sigMaxMpa - dis.sigMinMpa);
    final spanEps = math.max(1e-6, dis.epsMax - dis.epsMin);
    final maxVm = dis.fibers.fold<double>(1.0, (a, b) => math.max(a, b.sigmaVmMpa));

    final pFill = Paint()..style = PaintingStyle.fill;
    for (final df in dis.fibers) {
      final f = df.cell;
      final Color col;
      if (field == ContourField.confinementOrCrack) {
        if (f.kind.startsWith('steel')) {
          col = const Color(0xFFEF4444);
        } else if (f.kind == 'rebar') {
          col = const Color(0xFF10B981);
        } else if (df.stateEn.contains('Cracked')) {
          col = const Color(0xFFF43F5E);
        } else {
          col = switch (f.zone) {
            ConcreteZone.unconfined => const Color(0xFF64748B),
            ConcreteZone.partiallyConfined => const Color(0xFF38BDF8),
            ConcreteZone.highlyConfined => const Color(0xFFF59E0B),
          };
        }
      } else if (field == ContourField.strainEpsX) {
        col = ansysRainbowColor((df.epsX - dis.epsMin) / spanEps);
      } else if (field == ContourField.vonMises) {
        col = ansysRainbowColor(df.sigmaVmMpa / maxVm);
      } else {
        col = ansysRainbowColor((df.sigmaXMpa - dis.sigMinMpa) / spanSig);
      }
      pFill.color = col;
      final px = cx + f.zMm * sc;
      final py = cy - f.yMm * sc;
      if (f.kind == 'rebar') {
        canvas.drawCircle(Offset(px, py), math.max(3.5, 0.5 * f.dyMm * sc), pFill);
        canvas.drawCircle(Offset(px, py), math.max(3.5, 0.5 * f.dyMm * sc),
            Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.0);
      } else {
        final rect = Rect.fromCenter(center: Offset(px, py), width: math.max(2.0, f.dzMm * sc + 0.5), height: math.max(2.0, f.dyMm * sc + 0.5));
        canvas.drawRect(rect, pFill);
      }
    }

    // Đường biên bê tông & cốt đai
    final borderP = Paint()
      ..color = darkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (g.sectionType == 'COL_CIRC_H') {
      canvas.drawCircle(Offset(cx, cy), 0.5 * g.bMm * sc, borderP);
    } else {
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: g.bMm * sc, height: g.hMm * sc), borderP);
      if (g.sectionType == 'SRC_T_SLAB_H') {
        final hf = g.hfSlabMm * sc;
        canvas.drawRect(Rect.fromLTWH(cx - 0.5 * g.bfSlabMm * sc, cy - 0.5 * g.hMm * sc, g.bfSlabMm * sc, hf), borderP);
      }
    }

    // Đường trục trung hòa NA
    final yNaPx = cy - (0.5 * g.hMm - dis.xNaMm) * sc;
    canvas.drawLine(
      Offset(cx - 0.54 * bDraw * sc, yNaPx),
      Offset(cx + 0.54 * bDraw * sc, yNaPx),
      Paint()..color = Colors.white..strokeWidth = 1.8,
    );

    // Con trỏ khảo sát (Crosshair Probe) tại (y, z)
    final pPx = Offset(cx + probeZMm * sc, cy - probeYMm * sc);
    final cP = Paint()..color = const Color(0xFFFFFFFF)..strokeWidth = 1.6;
    canvas.drawLine(pPx - const Offset(10, 0), pPx + const Offset(10, 0), cP);
    canvas.drawLine(pPx - const Offset(0, 10), pPx + const Offset(0, 10), cP);
    canvas.drawCircle(pPx, 5.0, Paint()..color = const Color(0xFF06B6D4)..style = PaintingStyle.stroke..strokeWidth = 2.0);
  }

  @override
  bool shouldRepaint(covariant _SectionHeatmapPainter old) => true;
}

class _StrainStressProfilePainter extends CustomPainter {
  final SrcAnalysisResult result;
  final DissectionResult dis;
  final double probeYMm;
  final bool darkMode;
  final AppLang lang;

  const _StrainStressProfilePainter({
    required this.result,
    required this.dis,
    required this.probeYMm,
    required this.darkMode,
    required this.lang,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final g = result.config.geometry;
    final fg = darkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final axisP = Paint()..color = darkMode ? const Color(0xFF475569) : const Color(0xFF94A3B8)..strokeWidth = 1.0;

    final topY = 22.0;
    final botY = size.height - 16.0;
    final hPx = math.max(30.0, botY - topY);
    double yToPx(double yMm) => topY + (0.5 * g.hMm - yMm) / g.hMm * hPx;

    // Cột trái: Biến dạng ε(y); Cột phải: Ứng suất σ(y)
    final xEps0 = size.width * 0.27;
    final xSig0 = size.width * 0.74;
    final halfW = size.width * 0.21;
    canvas.drawLine(Offset(xEps0, topY), Offset(xEps0, botY), axisP);
    canvas.drawLine(Offset(xSig0, topY), Offset(xSig0, botY), axisP);

    final epsTop = dis.eps0 - 0.5 * g.hMm * dis.kappaZ;
    final epsBot = dis.eps0 + 0.5 * g.hMm * dis.kappaZ;
    final maxE = math.max(0.0005, math.max(epsTop.abs(), epsBot.abs()));
    final ePath = Path()
      ..moveTo(xEps0, topY)
      ..lineTo(xEps0 + (epsTop / maxE) * halfW, topY)
      ..lineTo(xEps0 + (epsBot / maxE) * halfW, botY)
      ..lineTo(xEps0, botY)
      ..close();
    canvas.drawPath(ePath, Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.28));
    canvas.drawLine(
      Offset(xEps0 + (epsTop / maxE) * halfW, topY),
      Offset(xEps0 + (epsBot / maxE) * halfW, botY),
      Paint()..color = const Color(0xFF38BDF8)..strokeWidth = 2.0,
    );

    // Ứng suất phi tuyến bê tông theo chiều cao
    final maxC = math.max(5.0, result.config.material.fcMpa * 1.1);
    final sPath = Path()..moveTo(xSig0, topY);
    for (int i = 0; i <= 24; i++) {
      final yMm = 0.5 * g.hMm - g.hMm * i / 24.0;
      final eps = dis.eps0 - yMm * dis.kappaZ;
      final r = SrcNonlinearEngine.concreteLaw(eps, result.config.material, ConcreteZone.partiallyConfined, result.conf, true);
      final sx = xSig0 + (r.sig / maxC).clamp(-1.1, 0.4) * halfW;
      sPath.lineTo(sx, yToPx(yMm));
    }
    sPath.lineTo(xSig0, botY);
    sPath.close();
    canvas.drawPath(sPath, Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.30));
    canvas.drawPath(sPath, Paint()..color = const Color(0xFFF59E0B)..style = PaintingStyle.stroke..strokeWidth = 1.8);

    // Vạch mức điểm đang khảo sát y
    final pyProbe = yToPx(probeYMm);
    canvas.drawLine(Offset(6, pyProbe), Offset(size.width - 6, pyProbe), Paint()..color = const Color(0xFF06B6D4)..strokeWidth = 1.2);

    void label(String s, double x) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: fg, fontSize: 9.5, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width * 0.5, 4));
    }

    label('ε(y) ‰', xEps0);
    label('σ_c(y) MPa', xSig0);
  }

  @override
  bool shouldRepaint(covariant _StrainStressProfilePainter old) => true;
}
