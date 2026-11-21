// ============================================================================
// BẢNG BIỂU ĐỒ PHI TUYẾN & KIỂM CHỨNG ĐA TIÊU CHUẨN (EC4 / AISC / JGJ / TCVN)
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/src_engine.dart';

class SrcChartsMultiCodePanel extends StatelessWidget {
  final SrcAnalysisResult result;
  final bool darkMode;
  final AppLang lang;

  const SrcChartsMultiCodePanel({
    super.key,
    required this.result,
    required this.darkMode,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final isBeam = result.config.kind == MemberKind.beam;
    final dark = darkMode;
    final l = lang;
    final cardBg = dark ? const Color(0xFF0F172A) : Colors.white;
    final border = dark ? const Color(0xFF263859) : const Color(0xFFCBD5E1);
    final fg = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Thẻ tóm tắt KPI + Đối chiếu thực nghiệm (nếu đang chọn preset benchmark)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _kpiCard(
                tr(l, 'Trạng thái tổng quát', 'Overall Verdict'),
                result.overallPass ? tr(l, 'ĐẠT (PASS)', 'PASS') : tr(l, 'CHƯA ĐẠT (FAIL)', 'FAIL'),
                result.overallPass ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                cardBg,
                border,
                fg,
              ),
              if (isBeam) ...[
                _kpiCard(
                  tr(l, 'Mô-men cực hạn FEM', 'FEM Ultimate M_u'),
                  '${result.ultimateMomentKnm.toStringAsFixed(1)} kN·m',
                  const Color(0xFF06B6D4),
                  cardBg,
                  border,
                  fg,
                ),
                _kpiCard(
                  tr(l, 'Độ võng NL / Giới hạn', 'NL Deflection / Limit'),
                  '${result.deflDesignMm.toStringAsFixed(2)} / ${result.deflLimitMm.toStringAsFixed(1)} mm',
                  result.deflDesignMm <= result.deflLimitMm ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  cardBg,
                  border,
                  fg,
                ),
                _kpiCard(
                  tr(l, 'Hệ số dẻo μ (δu/δy)', 'Ductility μ (δu/δy)'),
                  result.ductilityMu.toStringAsFixed(2),
                  const Color(0xFFA855F7),
                  cardBg,
                  border,
                  fg,
                ),
                _kpiCard(
                  tr(l, 'Cắt tách Weng (bf/bw)', 'Weng Splitting (bf/bw)'),
                  '${result.bfBwRatio.toStringAsFixed(2)} (${result.vSplitKn.toStringAsFixed(0)} kN)',
                  result.bfBwRatio >= 0.60 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                  cardBg,
                  border,
                  fg,
                ),
                _kpiCard(
                  tr(l, 'Đinh neo EC4 (§6.6.3)', 'Shear Studs (§6.6.3)'),
                  '${result.studsProvHalf} / ${result.studsReqHalf} (L/2)',
                  result.studsProvHalf >= result.studsReqHalf ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  cardBg,
                  border,
                  fg,
                ),
              ] else ...[
                _kpiCard(
                  tr(l, 'Tải phá hoại FEM (P–δ)', 'FEM Ultimate N_u (P–δ)'),
                  '${result.ultimateLoadKn.toStringAsFixed(0)} kN',
                  const Color(0xFF06B6D4),
                  cardBg,
                  border,
                  fg,
                ),
                _kpiCard(
                  tr(l, 'Độ mảnh & Uốn dọc EC4', 'EC4 Slenderness & χ'),
                  'λ̄=${result.ec4LambdaZ.toStringAsFixed(2)} | χ=${math.min(result.ec4ChiZ, result.ec4ChiY).toStringAsFixed(2)}',
                  const Color(0xFF38BDF8),
                  cardBg,
                  border,
                  fg,
                ),
                _kpiCard(
                  tr(l, 'Khuếch đại bậc 2 (P–δ)', '2nd-Order Amp (P–δ)'),
                  'k=${result.ec4KAmpZ.toStringAsFixed(2)} | M_II=${result.demandSecondary.toStringAsFixed(1)} kN·m',
                  const Color(0xFFF59E0B),
                  cardBg,
                  border,
                  fg,
                ),
                _kpiCard(
                  tr(l, 'Tỷ số đóng góp thép δ', 'Steel Ratio δ (EC4)'),
                  '${result.ec4DeltaSteel.toStringAsFixed(3)} (0.2–0.9)',
                  (result.ec4DeltaSteel >= 0.2 && result.ec4DeltaSteel <= 0.9) ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  cardBg,
                  border,
                  fg,
                ),
                _kpiCard(
                  tr(l, 'Giam giữ 3 vùng (Kp/Kh)', '3-Zone Confinement'),
                  'Kp=${result.conf.kp.toStringAsFixed(2)} | Kh=${result.conf.kh.toStringAsFixed(2)}',
                  const Color(0xFFA855F7),
                  cardBg,
                  border,
                  fg,
                ),
              ],
              if (result.config.expRefValue != null) ...[
                Builder(builder: (_) {
                  final exp = result.config.expRefValue!;
                  final fem = isBeam ? result.ultimateMomentKnm : result.ultimateLoadKn;
                  final errPct = ((fem - exp).abs() / exp * 100.0);
                  return _kpiCard(
                    result.config.expRefLabel ?? 'Experimental Benchmark',
                    'FEM/Exp = ${(fem / exp).toStringAsFixed(3)} (Δ=${errPct.toStringAsFixed(1)}%)',
                    errPct <= 15.0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    cardBg,
                    border,
                    fg,
                  );
                }),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // 2. Hai biểu đồ khoa học chính cạnh nhau (Responsive)
          LayoutBuilder(
            builder: (ctx, c) {
              final twoCol = c.maxWidth >= 780;
              final chart1 = _chartBox(
                title: isBeam
                    ? tr(l, 'Đường cong Tải trọng – Độ võng Phi tuyến (P – δ)', 'Nonlinear Load – Deflection Curve (P – δ)')
                    : tr(l, 'Biểu đồ Tương tác N – M (Thớ 2D & Đa giác dẻo EC4 A–E–C–D–B)', 'N – M Interaction Diagram (2D Fiber & EC4 Polygon)'),
                cardBg: cardBg,
                border: border,
                fg: fg,
                child: CustomPaint(
                  painter: isBeam
                      ? _LineChartPainter(
                          series: [
                            _ChartSeries(
                              tr(l, 'Phi tuyến Thớ 2D', 'Nonlinear Fiber'),
                              const Color(0xFF06B6D4),
                              [for (final h in result.history) Point2D(h.deflMm, h.loadKn)],
                            ),
                          ],
                          xLabel: 'δ (mm)',
                          yLabel: 'P (kN)',
                          hLineY: result.config.loadType == 'udl'
                              ? result.config.qUdlKnM * result.config.lengthMm / 1000.0
                              : result.config.pPointKn,
                          hLineLabel: tr(l, 'Tải thiết kế', 'Design Load'),
                          darkMode: dark,
                        )
                      : _NmInteractionPainter(result: result, darkMode: dark, lang: l),
                ),
              );

              final chart2 = _chartBox(
                title: isBeam
                    ? tr(l, 'Đường cong Mô-men – Độ cong (M – κ) & Ngưỡng EC4', 'Moment – Curvature (M – κ) & EC4 Plastic Capacity')
                    : tr(l, 'Đường cong Ổn định Bậc hai (N – Δ_mid) & Mô hình Giam giữ 3 vùng', 'Second-Order Buckling Curve (N – Δ_mid)'),
                cardBg: cardBg,
                border: border,
                fg: fg,
                child: CustomPaint(
                  painter: isBeam
                      ? _LineChartPainter(
                          series: [
                            _ChartSeries('M – κ (Fiber 2D)', const Color(0xFFF59E0B), result.mkCurve),
                          ],
                          xLabel: 'κ (1/m)',
                          yLabel: 'M (kN·m)',
                          hLineY: result.codeChecks.first.capacityPrimary,
                          hLineLabel: 'EC4 M_pl,Rd',
                          darkMode: dark,
                        )
                      : _LineChartPainter(
                          series: [
                            _ChartSeries(
                              tr(l, 'Đường cân bằng P–δ', 'P–δ Equilibrium'),
                              const Color(0xFF10B981),
                              [for (final h in result.history) Point2D(h.deflMm, h.loadKn)],
                            ),
                          ],
                          xLabel: 'Δ_mid (mm)',
                          yLabel: 'N (kN)',
                          hLineY: result.demandPrimary,
                          hLineLabel: 'N_Ed',
                          darkMode: dark,
                        ),
                ),
              );

              if (twoCol) {
                return Row(
                  children: [
                    Expanded(child: SizedBox(height: 310, child: chart1)),
                    const SizedBox(width: 12),
                    Expanded(child: SizedBox(height: 310, child: chart2)),
                  ],
                );
              }
              return Column(
                children: [
                  SizedBox(height: 290, child: chart1),
                  const SizedBox(height: 12),
                  SizedBox(height: 290, child: chart2),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // 3. Bảng so sánh đối chiếu 4 Hệ tiêu chuẩn Quốc tế + TCVN
          Container(
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(l, 'ĐỐI CHIẾU KIỂM TRA ĐA TIÊU CHUẨN QUỐC TẾ & VIỆT NAM', 'MULTI-CODE DESIGN VERIFICATION MATRIX'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF06B6D4)),
                ),
                const SizedBox(height: 8),
                for (final c in result.codeChecks) _codeRowTile(c, isBeam, dark, fg, sub, l),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value, Color accent, Color bg, Color border, Color fg) {
    return Container(
      width: 215,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10.2, color: fg.withValues(alpha: 0.72))),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, fontFamily: 'DejaVuSansMono', color: accent),
          ),
        ],
      ),
    );
  }

  Widget _chartBox({
    required String title,
    required Color cardBg,
    required Color border,
    required Color fg,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.bold, color: fg)),
          const SizedBox(height: 6),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _codeRowTile(CodeCheckRow c, bool isBeam, bool dark, Color fg, Color sub, AppLang l) {
    final barCol = c.urTotal <= 0.85
        ? const Color(0xFF10B981)
        : (c.urTotal <= 1.0 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0A1224) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: barCol.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(c.title, style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.bold, color: fg))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: barCol.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  'UR = ${(c.urTotal * 100).toStringAsFixed(1)}% • ${c.pass ? tr(l, "ĐẠT", "PASS") : tr(l, "CHƯA ĐẠT", "FAIL")}',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'DejaVuSansMono', color: barCol),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: c.urTotal.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: dark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(barCol),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isBeam
                ? 'M_Rd = ${c.capacityPrimary.toStringAsFixed(1)} kN·m (UR=${c.urPrimary.toStringAsFixed(2)})  |  V_Rd = ${c.capacitySecondary.toStringAsFixed(1)} kN (UR=${c.urSecondary.toStringAsFixed(2)})  |  ${c.extraNote}'
                : 'N_Rd = ${c.capacityPrimary.toStringAsFixed(0)} kN (UR=${c.urPrimary.toStringAsFixed(2)})  |  M_cap = ${c.capacitySecondary.toStringAsFixed(1)} kN·m  |  ${c.extraNote}',
            style: TextStyle(fontSize: 10.2, fontFamily: 'DejaVuSansMono', color: sub),
          ),
        ],
      ),
    );
  }
}

class _ChartSeries {
  final String name;
  final Color color;
  final List<Point2D> pts;
  const _ChartSeries(this.name, this.color, this.pts);
}

class _LineChartPainter extends CustomPainter {
  final List<_ChartSeries> series;
  final String xLabel, yLabel;
  final double? hLineY;
  final String? hLineLabel;
  final bool darkMode;

  const _LineChartPainter({
    required this.series,
    required this.xLabel,
    required this.yLabel,
    this.hLineY,
    this.hLineLabel,
    required this.darkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 48.0, padR = 14.0, padT = 16.0, padB = 30.0;
    final pw = math.max(20.0, size.width - padL - padR);
    final ph = math.max(20.0, size.height - padT - padB);
    final fg = darkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final gridCol = darkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    double maxX = 1.0, maxY = hLineY ?? 1.0;
    for (final s in series) {
      for (final p in s.pts) {
        maxX = math.max(maxX, p.x);
        maxY = math.max(maxY, p.y);
      }
    }
    maxX *= 1.08;
    maxY *= 1.12;

    double sx(double x) => padL + (x / maxX) * pw;
    double sy(double y) => padT + ph - (y / maxY) * ph;

    // Lưới & nhãn trục
    final gp = Paint()..color = gridCol..strokeWidth = 0.8;
    for (int i = 0; i <= 4; i++) {
      final yy = padT + ph * i / 4.0;
      canvas.drawLine(Offset(padL, yy), Offset(padL + pw, yy), gp);
      final valY = maxY * (1.0 - i / 4.0);
      _txt(canvas, Offset(2, yy - 6), valY >= 100 ? valY.toStringAsFixed(0) : valY.toStringAsFixed(1), fg, 8.8);
      final xx = padL + pw * i / 4.0;
      canvas.drawLine(Offset(xx, padT), Offset(xx, padT + ph), gp);
      final valX = maxX * i / 4.0;
      _txt(canvas, Offset(xx - 12, padT + ph + 4), valX >= 100 ? valX.toStringAsFixed(0) : valX.toStringAsFixed(1), fg, 8.8);
    }

    if (hLineY != null && hLineY! > 0) {
      final hy = sy(hLineY!);
      canvas.drawLine(Offset(padL, hy), Offset(padL + pw, hy), Paint()..color = const Color(0xFFEF4444)..strokeWidth = 1.3);
      if (hLineLabel != null) {
        _txt(canvas, Offset(padL + 6, hy - 13), '$hLineLabel (${hLineY!.toStringAsFixed(0)})', const Color(0xFFEF4444), 9.0);
      }
    }

    for (final s in series) {
      if (s.pts.length < 2) continue;
      final path = Path();
      for (int i = 0; i < s.pts.length; i++) {
        final o = Offset(sx(s.pts[i].x), sy(s.pts[i].y));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(path, Paint()..color = s.color..style = PaintingStyle.stroke..strokeWidth = 2.4);
      final lastPt = Offset(sx(s.pts.last.x), sy(s.pts.last.y));
      canvas.drawCircle(lastPt, 4.0, Paint()..color = s.color);
    }

    _txt(canvas, Offset(padL + pw - 42, padT + ph + 16), xLabel, fg, 9.2);
    _txt(canvas, Offset(4, 2), yLabel, fg, 9.2);
  }

  void _txt(Canvas c, Offset o, String s, Color col, double fs) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs, fontFamily: 'DejaVuSansMono')),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => true;
}

class _NmInteractionPainter extends CustomPainter {
  final SrcAnalysisResult result;
  final bool darkMode;
  final AppLang lang;
  const _NmInteractionPainter({required this.result, required this.darkMode, required this.lang});

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 52.0, padR = 16.0, padT = 16.0, padB = 30.0;
    final pw = math.max(20.0, size.width - padL - padR);
    final ph = math.max(20.0, size.height - padT - padB);
    final fg = darkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final grid = darkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    double maxM = math.max(50.0, result.demandSecondary * 1.2);
    double maxN = math.max(100.0, result.demandPrimary * 1.15);
    for (final p in [...result.nmNominalCurve, ...result.nmDesignCurve, ...result.ec4Polygon]) {
      maxM = math.max(maxM, p.x);
      maxN = math.max(maxN, p.y);
    }
    maxM *= 1.12;
    maxN *= 1.08;

    double sx(double m) => padL + (m / maxM) * pw;
    double sy(double n) => padT + ph - (n.clamp(0.0, maxN) / maxN) * ph;

    final gp = Paint()..color = grid..strokeWidth = 0.8;
    for (int i = 0; i <= 4; i++) {
      final yy = padT + ph * i / 4.0;
      canvas.drawLine(Offset(padL, yy), Offset(padL + pw, yy), gp);
      _txt(canvas, Offset(2, yy - 6), (maxN * (1 - i / 4.0)).toStringAsFixed(0), fg, 8.6);
      final xx = padL + pw * i / 4.0;
      canvas.drawLine(Offset(xx, padT), Offset(xx, padT + ph), gp);
      _txt(canvas, Offset(xx - 12, padT + ph + 4), (maxM * i / 4.0).toStringAsFixed(0), fg, 8.6);
    }

    void drawCurve(List<Point2D> pts, Color col, double w) {
      final valid = pts.where((p) => p.y >= -10).toList();
      if (valid.length < 2) return;
      final path = Path();
      for (int i = 0; i < valid.length; i++) {
        final o = Offset(sx(valid[i].x), sy(valid[i].y));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(path, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = w);
    }

    drawCurve(result.nmNominalCurve, const Color(0xFF64748B), 1.5);
    drawCurve(result.nmDesignCurve, const Color(0xFF06B6D4), 2.4);
    drawCurve(result.ec4Polygon, const Color(0xFFEF4444), 1.9);

    for (final p in result.ec4Polygon) {
      final o = Offset(sx(p.x), sy(p.y));
      canvas.drawCircle(o, 3.2, Paint()..color = const Color(0xFFEF4444));
      if (p.label.isNotEmpty) _txt(canvas, o + const Offset(4, -10), p.label, const Color(0xFFEF4444), 9.0);
    }

    // Điểm nội lực bậc 1 -> Mũi tên P-δ -> Điểm bậc 2
    final p1 = Offset(sx(result.demandFirstOrderM), sy(result.demandPrimary));
    final p2 = Offset(sx(result.demandSecondary), sy(result.demandPrimary));
    canvas.drawLine(p1, p2, Paint()..color = const Color(0xFFF59E0B)..strokeWidth = 2.2);
    canvas.drawCircle(p1, 5.0, Paint()..color = const Color(0xFF10B981));
    canvas.drawCircle(p2, 5.5, Paint()..color = const Color(0xFFF59E0B));

    _txt(canvas, Offset(padL + 6, padT + 2), '— Fiber Design  — EC4 A-E-C-D-B  ● M_I → M_II (P-δ)', fg, 8.6);
    _txt(canvas, Offset(padL + pw - 52, padT + ph + 16), 'M_z (kN·m)', fg, 9.0);
    _txt(canvas, Offset(4, 2), 'N (kN)', fg, 9.0);
  }

  void _txt(Canvas c, Offset o, String s, Color col, double fs) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs, fontFamily: 'DejaVuSansMono')),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _NmInteractionPainter old) => true;
}
