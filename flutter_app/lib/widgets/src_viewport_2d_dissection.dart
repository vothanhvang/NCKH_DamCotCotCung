// ============================================================================
// KHUNG NHÌN 2D & PHẪU THUẬT MẶT CẮT NGANG — LỘT TẢ LIÊN KẾT CỐT CỨNG ↔ BTCT
// ============================================================================
// Cho phép người dùng:
//   • Xem mô phỏng 2D dọc trục cấu kiện với đầy đủ cấu tạo liên kết thực:
//     lõi thép hình H (cánh trên/dưới + bụng), cốt thép dọc, cốt đai (dày ở gối/đầu
//     cột), đinh neo chống cắt (Headed Studs), vết nứt kéo bê tông, mũi tên dòng
//     trượt tiếp xúc v_L / τ_b và biểu đồ kép M_z(x) + Lực trượt liên kết v_L(x).
//   • Phẫu thuật mặt cắt ngang tương tác tại x/L: chạm/kéo vào bất kỳ điểm (y, z)
//     nào để đọc ε_x, σ_x, τ_xy, σ_vM; đồng thời hiển thị rõ vòm giam giữ parabol
//     Chen–Lin (2006) trong khoang thép H, cốt đai + móc 135°, đinh neo, đường
//     cắt tách dọc cánh thép Weng (2002) và biểu đồ ứng suất kép σ_c(y) + σ_a(y).
//   • Theo dõi định lượng ứng xử liên kết Cốt cứng ↔ BTCT: thanh tỷ lệ chia tải
//     (Thép hình / Bê tông / Cốt thép), v_L, τ_b/τ_Rd, F_stud/P_Rd, s_slip, f_lh.
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
  bool _showConnectionOverlay = true;

  @override
  Widget build(BuildContext context) {
    final res = widget.result;
    final l = widget.lang;
    final dark = widget.darkMode;
    final g = res.config.geometry;
    final isBeam = res.config.kind == MemberKind.beam;
    final yClamped = _probeYMm.clamp(-0.5 * g.hMm, 0.5 * g.hMm);
    final bMax = g.sectionType == 'SRC_T_SLAB_H' ? g.bfSlabMm : g.bMm;
    final zClamped = _probeZMm.clamp(-0.5 * bMax, 0.5 * bMax);

    final dis = SrcNonlinearEngine.dissectSection(res, widget.probeXNorm);
    final probe = SrcNonlinearEngine.probePoint(res, widget.probeXNorm, yClamped, zClamped);

    final cardBg = dark ? const Color(0xFF0F172A) : Colors.white;
    final border = dark ? const Color(0xFF263859) : const Color(0xFFCBD5E1);
    final fg = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    final bondColor = dis.bondStatusLevel == 2
        ? const Color(0xFFEF4444)
        : (dis.bondStatusLevel == 1 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;

        // =====================================================================
        // KHỐI 1: MÔ PHỎNG 2D DỌC CẤU KIỆN & LIÊN KẾT THÉP HÌNH – BTCT
        // =====================================================================
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
                      tr(
                        l,
                        '1. Mô phỏng 2D Dọc Cấu kiện & Liên kết Thép hình – BTCT (Chạm để kéo x/L)',
                        '1. 2D Longitudinal Steel–RC Interaction View (Tap/drag cut plane x/L)',
                      ),
                      style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.bold, color: fg),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'x/L=${widget.probeXNorm.toStringAsFixed(2)} (${dis.xMm.toStringAsFixed(0)} mm)',
                    style: const TextStyle(fontSize: 10.6, fontFamily: 'DejaVuSansMono', color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // Chú giải cấu tạo liên kết dọc
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  _legendDot(const Color(0xFFEF4444), tr(l, 'Lõi thép hình H', 'Steel H-Core'), sub),
                  _legendDot(const Color(0xFF10B981), tr(l, 'Cốt thép dọc & Đai', 'Rebar & Stirrups'), sub),
                  _legendDot(const Color(0xFFF59E0B),
                      isBeam ? tr(l, 'Đinh neo & Lực trượt v_L', 'Shear Studs & Flow v_L') : tr(l, 'Vùng truyền lực l_V & Ma sát τ_b', 'Load Intro l_V & Bond τ_b'), sub),
                  _legendDot(const Color(0xFFF43F5E), tr(l, 'Vết nứt kéo BT', 'Concrete Cracks'), sub),
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
                          dis: dis,
                          probeXNorm: widget.probeXNorm,
                          darkMode: dark,
                          lang: l,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // BẢNG ĐỌC ỨNG XỬ LIÊN KẾT CỐT CỨNG ↔ BTCT TẠI MẶT CẮT x/L
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF0A1224) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: bondColor.withValues(alpha: 0.55)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link, size: 15, color: bondColor),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                tr(l, 'ỨNG XỬ LIÊN KẾT CỐT CỨNG ↔ BTCT (x/L=${widget.probeXNorm.toStringAsFixed(2)})',
                                    'STEEL CORE ↔ RC INTERFACE (x/L=${widget.probeXNorm.toStringAsFixed(2)})'),
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: bondColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: bondColor.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            l.isVi ? dis.bondStateVi : dis.bondStateEn,
                            style: TextStyle(fontSize: 9.2, fontWeight: FontWeight.bold, color: bondColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Thanh phân chia nội lực giữa Thép hình — Bê tông — Cốt thép thanh
                    Row(
                      children: [
                        Text(
                          isBeam ? tr(l, 'Chia tải M_z:', 'Moment Share:') : tr(l, 'Chia tải N:', 'Axial Share:'),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sub),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: SizedBox(
                              height: 12,
                              child: Row(
                                children: [
                                  if (dis.steelSharePct > 0.5)
                                    Expanded(
                                      flex: math.max(1, (dis.steelSharePct * 10).round()),
                                      child: Container(color: const Color(0xFFEF4444)),
                                    ),
                                  if (dis.concreteSharePct > 0.5)
                                    Expanded(
                                      flex: math.max(1, (dis.concreteSharePct * 10).round()),
                                      child: Container(color: const Color(0xFF38BDF8)),
                                    ),
                                  if (dis.rebarSharePct > 0.5)
                                    Expanded(
                                      flex: math.max(1, (dis.rebarSharePct * 10).round()),
                                      child: Container(color: const Color(0xFF10B981)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        Text(
                          '${tr(l, "Thép hình H", "Steel H")}: ${dis.steelSharePct.toStringAsFixed(1)}% (${isBeam ? "${dis.mzSteelKnm.toStringAsFixed(1)} kNm" : "${dis.nSteelKn.toStringAsFixed(0)} kN"})',
                          style: const TextStyle(fontSize: 9.8, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                        ),
                        Text(
                          '${tr(l, "Bê tông", "Concrete")}: ${dis.concreteSharePct.toStringAsFixed(1)}% (${isBeam ? "${dis.mzConcreteKnm.toStringAsFixed(1)} kNm" : "${dis.nConcreteKn.toStringAsFixed(0)} kN"})',
                          style: const TextStyle(fontSize: 9.8, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                        ),
                        Text(
                          '${tr(l, "Cốt thép", "Rebar")}: ${dis.rebarSharePct.toStringAsFixed(1)}% (${isBeam ? "${dis.mzRebarKnm.toStringAsFixed(1)} kNm" : "${dis.nRebarKn.toStringAsFixed(0)} kN"})',
                          style: const TextStyle(fontSize: 9.8, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _metricChip('v_L', '${dis.vInterfaceKnPerM.toStringAsFixed(1)} kN/m', const Color(0xFFF59E0B), dark),
                        _metricChip('τ_b / τ_Rd', '${dis.tauBondMpa.toStringAsFixed(2)} / ${dis.tauRdMpa.toStringAsFixed(2)} MPa',
                            dis.tauBondMpa > dis.tauRdMpa ? const Color(0xFFEF4444) : const Color(0xFF06B6D4), dark),
                        if (isBeam)
                          _metricChip('F_stud / P_Rd', '${dis.studForceKn.toStringAsFixed(1)} / ${res.studPRdKn.toStringAsFixed(1)} kN (${(dis.studUr * 100).toStringAsFixed(0)}%)',
                              dis.studUr > 0.85 ? const Color(0xFFEF4444) : const Color(0xFF10B981), dark)
                        else
                          _metricChip('f_lh / f_lp', '${res.conf.flH.toStringAsFixed(2)} / ${res.conf.flP.toStringAsFixed(2)} MPa', const Color(0xFFA855F7), dark),
                        _metricChip('s_slip', '${dis.slipMm.toStringAsFixed(3)} mm', const Color(0xFF38BDF8), dark),
                        if (isBeam)
                          _metricChip('Weng Split', 'UR=${(dis.splitUr * 100).toStringAsFixed(0)}%',
                              dis.splitUr > 0.85 ? const Color(0xFFEF4444) : const Color(0xFF10B981), dark),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        // =====================================================================
        // KHỐI 2: PHẪU THUẬT MẶT CẮT NGANG & TƯƠNG TÁC LIÊN KẾT + KHẢO SÁT ĐIỂM
        // =====================================================================
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
                      tr(l, '2. Phẫu thuật Mặt cắt & Vòm Giam giữ — Chạm điểm (y, z)',
                          '2. Cross-Section Dissection & Confinement — Tap any (y, z)'),
                      style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.bold, color: fg),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _showConnectionOverlay = !_showConnectionOverlay),
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: (_showConnectionOverlay ? const Color(0xFFF59E0B) : const Color(0xFF64748B)).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _showConnectionOverlay ? const Color(0xFFF59E0B) : border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.layers, size: 13, color: _showConnectionOverlay ? const Color(0xFFF59E0B) : sub),
                          const SizedBox(width: 4),
                          Text(
                            tr(l, 'Liên kết & Vòm', 'Bond & Arch'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _showConnectionOverlay ? const Color(0xFFF59E0B) : sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                flex: 6,
                child: Row(
                  children: [
                    // Bản đồ màu 2D các thớ + Lớp lột tả liên kết Cốt cứng ↔ BTCT (tương tác chạm)
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
                                showConnectionOverlay: _showConnectionOverlay,
                                darkMode: dark,
                                lang: l,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Biểu đồ biến dạng tương thích ε(y) & ứng suất liên hợp kép σ_c(y) + σ_a(y)
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
                            style: TextStyle(fontSize: 10.8, fontWeight: FontWeight.bold, color: fg),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${l.isVi ? probe.zoneVi : probe.zoneEn}  •  ${tr(l, "Trạng thái", "State")}: ${l.isVi ? probe.stateVi : probe.stateEn}',
                      style: TextStyle(fontSize: 10.2, color: sub),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
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
              SizedBox(height: 410, child: longitudinalCard),
              const SizedBox(height: 10),
              SizedBox(height: 455, child: sectionCard),
            ],
          ),
        );
      },
    );
  }

  Widget _legendDot(Color col, String txt, Color fg) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(txt, style: TextStyle(fontSize: 9.6, color: fg)),
      ],
    );
  }

  void _updateXFromTap(double dx, double width) {
    const pad = 42.0;
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 10.0, fontFamily: 'DejaVuSansMono', color: dark ? Colors.white : const Color(0xFF0F172A)),
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
  final DissectionResult dis;
  final double probeXNorm;
  final bool darkMode;
  final AppLang lang;

  const _Longitudinal2DPainter({
    required this.result,
    required this.dis,
    required this.probeXNorm,
    required this.darkMode,
    required this.lang,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 38.0, padR = 20.0;
    final plotW = math.max(40.0, size.width - padL - padR);
    final cfg = result.config;
    final g = cfg.geometry;
    final isBeam = cfg.kind == MemberKind.beam;
    final L = cfg.lengthMm;
    final fg = darkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final grid = darkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    // =========================================================================
    // PHẦN TRÊN: THÂN CẤU KIỆN 2D + CỐT ĐAI + CỐT THÉP + LÕI THÉP H + ĐINH NEO + DÒNG TRƯỢT v_L
    // =========================================================================
    final topH = size.height * 0.52;
    final cyMem = topH * 0.54;
    final memH = math.min(topH * 0.60, 88.0);
    final maxD = result.profileDeflMm.fold<double>(0.1, (a, b) => math.max(a, b.abs()));
    final dAmp = math.min(18.0, topH * 0.14) / maxD;

    final nP = result.profileXMm.length;
    final maxM = result.profileMKnm.fold<double>(1.0, (a, b) => math.max(a, b.abs()));
    final maxV = result.profileVKn.fold<double>(1.0, (a, b) => math.max(a, b.abs()));

    double yAtNorm(double xn) {
      final fIdx = xn.clamp(0.0, 1.0) * (nP - 1);
      final i0 = fIdx.floor().clamp(0, nP - 2);
      final t = fIdx - i0;
      final dMm = result.profileDeflMm[i0] * (1 - t) + result.profileDeflMm[i0 + 1] * t;
      return cyMem - dMm * dAmp;
    }

    double vAtNorm(double xn) {
      final fIdx = xn.clamp(0.0, 1.0) * (nP - 1);
      final i0 = fIdx.floor().clamp(0, nP - 2);
      final t = fIdx - i0;
      return result.profileVKn[i0] * (1 - t) + result.profileVKn[i0 + 1] * t;
    }

    // 1. Vẽ thân bê tông với bản đồ ứng suất dịu
    for (int i = 0; i < nP - 1; i++) {
      final x1 = padL + (result.profileXMm[i] / L) * plotW;
      final x2 = padL + (result.profileXMm[i + 1] / L) * plotW;
      final y1 = cyMem - result.profileDeflMm[i] * dAmp;
      final y2 = cyMem - result.profileDeflMm[i + 1] * dAmp;
      final t = (result.profileMKnm[i].abs() / maxM).clamp(0.0, 1.0);
      final col = ansysRainbowColor(t).withValues(alpha: darkMode ? 0.28 : 0.22);
      final path = Path()
        ..moveTo(x1, y1 - 0.5 * memH)
        ..lineTo(x2, y2 - 0.5 * memH)
        ..lineTo(x2, y2 + 0.5 * memH)
        ..lineTo(x1, y1 + 0.5 * memH)
        ..close();
      canvas.drawPath(path, Paint()..color = col);
    }

    // Đường biên bê tông trên/dưới
    final pConcTop = Path();
    final pConcBot = Path();
    for (int i = 0; i < nP; i++) {
      final x = padL + (result.profileXMm[i] / L) * plotW;
      final y = cyMem - result.profileDeflMm[i] * dAmp;
      if (i == 0) {
        pConcTop.moveTo(x, y - 0.5 * memH);
        pConcBot.moveTo(x, y + 0.5 * memH);
      } else {
        pConcTop.lineTo(x, y - 0.5 * memH);
        pConcBot.lineTo(x, y + 0.5 * memH);
      }
    }
    final concBorderP = Paint()
      ..color = darkMode ? const Color(0xFF94A3B8) : const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawPath(pConcTop, concBorderP);
    canvas.drawPath(pConcBot, concBorderP);

    // 2. Vẽ cốt đai ngang dọc cấu kiện (bố trí dày ở 2 đầu gối / đầu cột l_end = L/4)
    final stirP = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.65)
      ..strokeWidth = 1.05;
    final coverPx = memH * (g.coverMm / g.hMm).clamp(0.07, 0.16);
    double xPos = 80.0;
    while (xPos < L - 60.0) {
      final xn = xPos / L;
      final xPx = padL + xn * plotW;
      final yMid = yAtNorm(xn);
      canvas.drawLine(Offset(xPx, yMid - 0.5 * memH + coverPx), Offset(xPx, yMid + 0.5 * memH - coverPx), stirP);
      final inEnd = xPos < 0.25 * L || xPos > 0.75 * L;
      xPos += math.max(85.0, inEnd ? g.stirrupSpacingEndMm * 1.45 : g.stirrupSpacingMm * 1.45);
    }

    // 3. Vẽ thanh cốt thép dọc trên & dưới
    final rebarP = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final pRbTop = Path();
    final pRbBot = Path();
    for (int i = 0; i < nP; i++) {
      final x = padL + (result.profileXMm[i] / L) * plotW;
      final y = cyMem - result.profileDeflMm[i] * dAmp;
      if (i == 0) {
        pRbTop.moveTo(x, y - 0.5 * memH + coverPx);
        pRbBot.moveTo(x, y + 0.5 * memH - coverPx);
      } else {
        pRbTop.lineTo(x, y - 0.5 * memH + coverPx);
        pRbBot.lineTo(x, y + 0.5 * memH - coverPx);
      }
    }
    canvas.drawPath(pRbTop, rebarP);
    canvas.drawPath(pRbBot, rebarP);

    // 4. Vẽ lõi thép hình H (phân tách rõ bản bụng mờ + bản cánh trên/dưới đậm!)
    final hCorePx = memH * (g.haMm / g.hMm).clamp(0.25, 0.78);
    final tfPx = math.max(2.6, memH * (g.tfMm / g.hMm));
    final yOffPx = -memH * (g.coreOffsetYMm / g.hMm);

    final pWeb = Path();
    final pFlTop = Path();
    final pFlBot = Path();
    for (int i = 0; i < nP; i++) {
      final x = padL + (result.profileXMm[i] / L) * plotW;
      final yc = cyMem - result.profileDeflMm[i] * dAmp + yOffPx;
      if (i == 0) {
        pWeb.moveTo(x, yc - 0.5 * hCorePx);
        pFlTop.moveTo(x, yc - 0.5 * hCorePx);
        pFlBot.moveTo(x, yc + 0.5 * hCorePx - tfPx);
      } else {
        pWeb.lineTo(x, yc - 0.5 * hCorePx);
        pFlTop.lineTo(x, yc - 0.5 * hCorePx);
        pFlBot.lineTo(x, yc + 0.5 * hCorePx - tfPx);
      }
    }
    for (int i = nP - 1; i >= 0; i--) {
      final x = padL + (result.profileXMm[i] / L) * plotW;
      final yc = cyMem - result.profileDeflMm[i] * dAmp + yOffPx;
      pWeb.lineTo(x, yc + 0.5 * hCorePx);
      pFlTop.lineTo(x, yc - 0.5 * hCorePx + tfPx);
      pFlBot.lineTo(x, yc + 0.5 * hCorePx);
    }
    pWeb.close();
    pFlTop.close();
    pFlBot.close();

    canvas.drawPath(pWeb, Paint()..color = const Color(0x40EF4444));
    canvas.drawPath(pFlTop, Paint()..color = const Color(0xCCEF4444));
    canvas.drawPath(pFlBot, Paint()..color = const Color(0xCCEF4444));
    canvas.drawPath(pWeb, Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // 5. Vẽ ĐINH NEO CHỐNG CẮT (Dầm) hoặc VÙNG TRUYỀN LỰC ĐẦU CỘT l_V (Cột)
    if (isBeam) {
      final studH = math.max(5.5, math.min(11.0, memH * (cfg.studHeightMm / g.hMm) * 1.1));
      final nStudsDraw = (plotW / 24.0).clamp(8, 22).round();
      for (int s = 1; s < nStudsDraw; s++) {
        final xn = s / nStudsDraw;
        final xPx = padL + xn * plotW;
        final yTopFlange = yAtNorm(xn) + yOffPx - 0.5 * hCorePx;
        final vRat = (vAtNorm(xn).abs() / maxV).clamp(0.0, 1.0);
        final stCol = Color.lerp(const Color(0xFFFBBF24), const Color(0xFFFF3B30), vRat)!;
        final stP = Paint()..color = stCol..strokeWidth = 1.7;
        // Thân đinh neo hàn trên cánh thép + đầu mũ T
        canvas.drawLine(Offset(xPx, yTopFlange), Offset(xPx, yTopFlange - studH), stP);
        canvas.drawLine(Offset(xPx - 2.8, yTopFlange - studH), Offset(xPx + 2.8, yTopFlange - studH), stP..strokeWidth = 2.1);
      }
    } else {
      // Vùng truyền lực đầu cột l_V = min(2h, L/3) hai đầu cột (EN 1994-1-1 §6.7.4.2)
      final lIntroNorm = (math.min(2.0 * g.hMm, L / 3.0) / L).clamp(0.08, 0.34);
      final introPaint = Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.18);
      canvas.drawRect(Rect.fromLTWH(padL, cyMem - 0.5 * memH, lIntroNorm * plotW, memH), introPaint);
      canvas.drawRect(Rect.fromLTWH(padL + (1 - lIntroNorm) * plotW, cyMem - 0.5 * memH, lIntroNorm * plotW, memH), introPaint);
      _drawTxt(canvas, Offset(padL + 3, cyMem - 0.5 * memH - 12), 'l_V (EC4 §6.7.4)', const Color(0xFFF59E0B), 8.5);
    }

    // 6. Vẽ MŨI TÊN DÒNG TRƯỢT TIẾP XÚC τ_b / v_L dọc bề mặt cánh thép – bê tông
    final arrowP = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const nArr = 8;
    for (int k = 1; k <= nArr; k++) {
      final xn = (k - 0.5) / nArr;
      final vLoc = vAtNorm(xn);
      final strength = isBeam
          ? (vLoc.abs() / maxV).clamp(0.0, 1.0)
          : math.max((vLoc.abs() / maxV), math.max(0.0, 1.0 - math.min(xn, 1.0 - xn) / 0.28)).clamp(0.0, 1.0);
      if (strength < 0.14) continue;
      final dir = (xn < 0.5) ? 1.0 : -1.0;
      final xPx = padL + xn * plotW;
      final yIf = yAtNorm(xn) + yOffPx - 0.5 * hCorePx - 2.0;
      final len = 7.0 + 9.0 * strength;
      _drawArrow(canvas, Offset(xPx - dir * len * 0.5, yIf), Offset(xPx + dir * len * 0.5, yIf), arrowP);
      // Mũi tên ngược chiều phía bê tông lột tả ứng suất tiếp trượt đối kháng!
      _drawArrow(
        canvas,
        Offset(xPx + dir * len * 0.5, yIf - 4.5),
        Offset(xPx - dir * len * 0.5, yIf - 4.5),
        Paint()..color = const Color(0xFF38BDF8)..strokeWidth = 1.25,
      );
    }

    // 7. Vẽ vết nứt kéo bê tông tại vùng mô-men lớn (khi có nứt kéo)
    if (isBeam) {
      final crP = Paint()..color = const Color(0xFFF43F5E)..strokeWidth = 1.2;
      for (int c = 2; c <= 14; c++) {
        final xn = c / 16.0;
        final mRat = (result.profileMKnm[(xn * (nP - 1)).round().clamp(0, nP - 1)].abs() / maxM).clamp(0.0, 1.0);
        if (mRat < 0.35) continue;
        final xPx = padL + xn * plotW;
        final yBot = yAtNorm(xn) + 0.5 * memH;
        final crH = memH * 0.30 * mRat;
        final crPath = Path()
          ..moveTo(xPx, yBot)
          ..lineTo(xPx + 2.2, yBot - crH * 0.45)
          ..lineTo(xPx - 1.8, yBot - crH);
        canvas.drawPath(crPath, crP);
      }
    }

    // =========================================================================
    // PHẦN DƯỚI: BIỂU ĐỒ KÉP M_z(x) (CYAN) + DÒNG TRƯỢT LIÊN KẾT v_L(x) (AMBER)
    // =========================================================================
    final botTop = size.height * 0.59;
    final botH = size.height * 0.36;
    final baseY = botTop + botH * 0.16;
    canvas.drawLine(Offset(padL, baseY), Offset(padL + plotW, baseY), Paint()..color = grid..strokeWidth = 1.2);

    // Đường cong M_z(x)
    final mPath = Path()..moveTo(padL, baseY);
    for (int i = 0; i < nP; i++) {
      final x = padL + (result.profileXMm[i] / L) * plotW;
      final y = baseY + (result.profileMKnm[i].abs() / maxM) * (botH * 0.74);
      mPath.lineTo(x, y);
    }
    mPath.lineTo(padL + plotW, baseY);
    mPath.close();
    canvas.drawPath(mPath, Paint()..color = const Color(0xFF06B6D4).withValues(alpha: 0.18));
    canvas.drawPath(mPath, Paint()..color = const Color(0xFF06B6D4)..style = PaintingStyle.stroke..strokeWidth = 1.9);

    // Đường cong dòng trượt liên kết v_L(x) dọc chiều dài
    final vPath = Path();
    for (int i = 0; i < nP; i++) {
      final xn = result.profileXMm[i] / L;
      final x = padL + xn * plotW;
      final vNorm = isBeam
          ? (result.profileVKn[i].abs() / maxV)
          : math.max(result.profileVKn[i].abs() / maxV, math.max(0.0, 1.0 - math.min(xn, 1.0 - xn) / 0.28));
      final y = baseY + vNorm.clamp(0.0, 1.0) * (botH * 0.72);
      if (i == 0) {
        vPath.moveTo(x, y);
      } else {
        vPath.lineTo(x, y);
      }
    }
    canvas.drawPath(vPath, Paint()..color = const Color(0xFFF59E0B)..style = PaintingStyle.stroke..strokeWidth = 1.8);

    _drawTxt(
      canvas,
      Offset(padL, botTop - 6),
      'M_z(x) max=${maxM.toStringAsFixed(0)} kNm  |  ${tr(lang, "Trượt tiếp xúc v_L(x) tại x/L", "Interface flow v_L(x)")}=${dis.vInterfaceKnPerM.toStringAsFixed(0)} kN/m',
      fg,
      9.4,
    );

    // Đường cắt phẫu thuật kéo được tại x/L
    final xCut = padL + probeXNorm * plotW;
    canvas.drawLine(Offset(xCut, 4), Offset(xCut, size.height - 6), Paint()..color = const Color(0xFFF59E0B)..strokeWidth = 2.1);
    canvas.drawCircle(Offset(xCut, yAtNorm(probeXNorm)), 5.0, Paint()..color = const Color(0xFFF59E0B));
  }

  void _drawArrow(Canvas c, Offset a, Offset b, Paint p) {
    c.drawLine(a, b, p);
    final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
    const sz = 4.2;
    c.drawLine(b, b - Offset(sz * math.cos(ang - 0.55), sz * math.sin(ang - 0.55)), p);
    c.drawLine(b, b - Offset(sz * math.cos(ang + 0.55), sz * math.sin(ang + 0.55)), p);
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
  final bool showConnectionOverlay;
  final bool darkMode;
  final AppLang lang;

  const _SectionHeatmapPainter({
    required this.result,
    required this.dis,
    required this.field,
    required this.probeYMm,
    required this.probeZMm,
    required this.showConnectionOverlay,
    required this.darkMode,
    required this.lang,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = result.config;
    final g = cfg.geometry;
    final isBeam = cfg.kind == MemberKind.beam;
    final bDraw = g.sectionType == 'SRC_T_SLAB_H' ? g.bfSlabMm : g.bMm;
    final sc = math.min((size.width - 36) / math.max(100.0, bDraw), (size.height - 36) / math.max(100.0, g.hMm));
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;

    final spanSig = math.max(1.0, dis.sigMaxMpa - dis.sigMinMpa);
    final spanEps = math.max(1e-6, dis.epsMax - dis.epsMin);
    final maxVm = dis.fibers.fold<double>(1.0, (a, b) => math.max(a, b.sigmaVmMpa));

    Color colorFor(DissectedFiber df) {
      final f = df.cell;
      if (field == ContourField.confinementOrCrack) {
        if (f.kind.startsWith('steel')) {
          return const Color(0xFFEF4444);
        } else if (f.kind == 'rebar') {
          return const Color(0xFF10B981);
        } else if (df.stateEn.contains('Cracked')) {
          return const Color(0xFFF43F5E);
        } else {
          return switch (f.zone) {
            ConcreteZone.unconfined => const Color(0xFF64748B),
            ConcreteZone.partiallyConfined => const Color(0xFF38BDF8),
            ConcreteZone.highlyConfined => const Color(0xFFF59E0B),
          };
        }
      } else if (field == ContourField.strainEpsX) {
        return ansysRainbowColor((df.epsX - dis.epsMin) / spanEps);
      } else if (field == ContourField.vonMises) {
        return ansysRainbowColor(df.sigmaVmMpa / maxVm);
      } else {
        return ansysRainbowColor((df.sigmaXMpa - dis.sigMinMpa) / spanSig);
      }
    }

    // 1. Vẽ theo đúng thứ tự Z-order: Bê tông trước -> Lõi thép hình -> Cốt thép tròn (không bị che khuất!)
    final pFill = Paint()..style = PaintingStyle.fill;
    for (final pass in [0, 1, 2]) {
      for (final df in dis.fibers) {
        final f = df.cell;
        final kindOrder = f.kind == 'concrete' ? 0 : (f.kind.startsWith('steel') ? 1 : 2);
        if (kindOrder != pass) continue;
        pFill.color = colorFor(df);
        final px = cx + f.zMm * sc;
        final py = cy - f.yMm * sc;
        if (f.kind == 'rebar') {
          final r = math.max(3.8, 0.52 * f.dyMm * sc);
          canvas.drawCircle(Offset(px, py), r, pFill);
          canvas.drawCircle(Offset(px, py), r, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.1);
        } else {
          final rect = Rect.fromCenter(
            center: Offset(px, py),
            width: math.max(2.0, f.dzMm * sc + 0.4),
            height: math.max(2.0, f.dyMm * sc + 0.4),
          );
          canvas.drawRect(rect, pFill);
        }
      }
    }

    // 2. Đường biên bê tông ngoài
    final borderP = Paint()
      ..color = darkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    if (g.sectionType == 'COL_CIRC_H') {
      canvas.drawCircle(Offset(cx, cy), 0.5 * g.bMm * sc, borderP);
    } else {
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: g.bMm * sc, height: g.hMm * sc), borderP);
      if (g.sectionType == 'SRC_T_SLAB_H') {
        final hf = g.hfSlabMm * sc;
        canvas.drawRect(Rect.fromLTWH(cx - 0.5 * g.bfSlabMm * sc, cy - 0.5 * g.hMm * sc, g.bfSlabMm * sc, hf), borderP);
      }
    }

    // =========================================================================
    // 3. LỚP LỘT TẢ LIÊN KẾT CỐT CỨNG (THÉP HÌNH) ↔ BÊ TÔNG CỐT THÉP
    // =========================================================================
    if (showConnectionOverlay) {
      final yCorePx = cy - g.coreOffsetYMm * sc;
      final haPx = g.haMm * sc;
      final baPx = g.baMm * sc;
      final tfPx = math.max(2.5, g.tfMm * sc);
      final twPx = math.max(2.0, g.twMm * sc);

      // 3a. Khung cốt đai khép kín (giữ giam giữ Vùng 1 & neo cốt thép)
      final stirPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      if (g.sectionType == 'COL_CIRC_H') {
        canvas.drawCircle(Offset(cx, cy), math.max(10.0, (0.5 * g.bMm - g.coverMm) * sc), stirPaint);
      } else {
        final sw = (g.bMm - 2 * g.coverMm) * sc;
        final sh = (g.hMm - 2 * g.coverMm) * sc;
        final sRect = Rect.fromCenter(center: Offset(cx, cy), width: math.max(12, sw), height: math.max(12, sh));
        canvas.drawRRect(RRect.fromRectAndRadius(sRect, const Radius.circular(4)), stirPaint);
        // Móc 135° cốt đai góc trên trái
        canvas.drawLine(sRect.topLeft + const Offset(2, 2), sRect.topLeft + const Offset(9, 9), stirPaint);
      }

      // 3b. Đường viền tiếp xúc dính bám (Interface Bond Glow) quanh lõi thép hình!
      final bondGlow = Paint()
        ..color = dis.bondStatusLevel == 2
            ? const Color(0xFFFF3B30)
            : (dis.bondStatusLevel == 1 ? const Color(0xFFFBBF24) : const Color(0xFFFFFFFF))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      if (g.sectionType == 'COL_RECT_CFST') {
        canvas.drawCircle(Offset(cx, yCorePx), 0.5 * haPx, bondGlow);
        canvas.drawCircle(Offset(cx, yCorePx), math.max(4.0, 0.5 * haPx - twPx), bondGlow);
      } else {
        // Vẽ biên dạng chữ H phát sáng mặt tiếp xúc thép – bê tông
        final hOutline = Path()
          ..moveTo(cx - 0.5 * baPx, yCorePx - 0.5 * haPx)
          ..lineTo(cx + 0.5 * baPx, yCorePx - 0.5 * haPx)
          ..lineTo(cx + 0.5 * baPx, yCorePx - 0.5 * haPx + tfPx)
          ..lineTo(cx + 0.5 * twPx, yCorePx - 0.5 * haPx + tfPx)
          ..lineTo(cx + 0.5 * twPx, yCorePx + 0.5 * haPx - tfPx)
          ..lineTo(cx + 0.5 * baPx, yCorePx + 0.5 * haPx - tfPx)
          ..lineTo(cx + 0.5 * baPx, yCorePx + 0.5 * haPx)
          ..lineTo(cx - 0.5 * baPx, yCorePx + 0.5 * haPx)
          ..lineTo(cx - 0.5 * baPx, yCorePx + 0.5 * haPx - tfPx)
          ..lineTo(cx - 0.5 * twPx, yCorePx + 0.5 * haPx - tfPx)
          ..lineTo(cx - 0.5 * twPx, yCorePx - 0.5 * haPx + tfPx)
          ..lineTo(cx - 0.5 * baPx, yCorePx - 0.5 * haPx + tfPx)
          ..close();
        canvas.drawPath(hOutline, bondGlow);

        // 3c. Vòm giam giữ parabol Chen & Lin (2006) trong 2 khoang giữa cánh thép H!
        final archPaint = Paint()
          ..color = const Color(0xFFFDE047)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        final archFill = Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.14);
        final yTopIn = yCorePx - 0.5 * haPx + tfPx;
        final yBotIn = yCorePx + 0.5 * haPx - tfPx;
        final hwPx = math.max(4.0, yBotIn - yTopIn);
        final bow = math.min(0.28 * hwPx, 0.35 * (baPx - twPx));

        // Khoang phải (giữa bụng và mép phải cánh)
        final archR = Path()
          ..moveTo(cx + 0.5 * twPx, yTopIn)
          ..lineTo(cx + 0.5 * baPx, yTopIn)
          ..quadraticBezierTo(cx + 0.5 * baPx - bow, yCorePx, cx + 0.5 * baPx, yBotIn)
          ..lineTo(cx + 0.5 * twPx, yBotIn)
          ..close();
        canvas.drawPath(archR, archFill);
        canvas.drawPath(archR, archPaint);

        // Khoang trái
        final archL = Path()
          ..moveTo(cx - 0.5 * twPx, yTopIn)
          ..lineTo(cx - 0.5 * baPx, yTopIn)
          ..quadraticBezierTo(cx - 0.5 * baPx + bow, yCorePx, cx - 0.5 * baPx, yBotIn)
          ..lineTo(cx - 0.5 * twPx, yBotIn)
          ..close();
        canvas.drawPath(archL, archFill);
        canvas.drawPath(archL, archPaint);

        // Mũi tên áp lực giam giữ ngang f_lh hướng vào lõi bê tông
        final pArr = Paint()..color = const Color(0xFFFDE047)..strokeWidth = 1.4;
        _drawMiniArrow(canvas, Offset(cx + 0.5 * baPx + 7, yCorePx), Offset(cx + 0.5 * baPx - 2, yCorePx), pArr);
        _drawMiniArrow(canvas, Offset(cx - 0.5 * baPx - 7, yCorePx), Offset(cx - 0.5 * baPx + 2, yCorePx), pArr);

        // 3d. Đinh neo chống cắt (Headed Shear Stud) trên cánh trên thép H (cho Dầm SRC)
        if (isBeam) {
          final stH = math.max(8.0, math.min(20.0, cfg.studHeightMm * sc));
          final yTopFl = yCorePx - 0.5 * haPx;
          final stPaint = Paint()..color = const Color(0xFFF59E0B)..strokeWidth = 2.6;
          final nR = cfg.studRows.clamp(1, 2);
          final zOffsets = nR == 1 ? [0.0] : [-0.24 * baPx, 0.24 * baPx];
          for (final zo in zOffsets) {
            final sx = cx + zo;
            canvas.drawLine(Offset(sx, yTopFl), Offset(sx, yTopFl - stH), stPaint);
            canvas.drawLine(Offset(sx - 4.2, yTopFl - stH), Offset(sx + 4.2, yTopFl - stH), stPaint..strokeWidth = 3.0);
          }
          // Đường cảnh báo mặt cắt tách dọc Weng et al. (2002) ngang mép cánh thép dưới
          final splitP = Paint()
            ..color = dis.splitUr > 0.85 ? const Color(0xFFFF3B30) : const Color(0xFFF97316).withValues(alpha: 0.75)
            ..strokeWidth = 1.3;
          final ySplit = yCorePx + 0.5 * haPx;
          final xLeftEdge = cx - 0.5 * g.bMm * sc;
          final xRightEdge = cx + 0.5 * g.bMm * sc;
          _drawDashedLine(canvas, Offset(xLeftEdge, ySplit), Offset(cx - 0.5 * baPx, ySplit), splitP);
          _drawDashedLine(canvas, Offset(cx + 0.5 * baPx, ySplit), Offset(xRightEdge, ySplit), splitP);
        }
      }
    }

    // 4. Đường trục trung hòa NA
    final yNaPx = cy - (0.5 * g.hMm - dis.xNaMm) * sc;
    _drawDashedLine(
      canvas,
      Offset(cx - 0.54 * bDraw * sc, yNaPx),
      Offset(cx + 0.54 * bDraw * sc, yNaPx),
      Paint()..color = Colors.white..strokeWidth = 1.7,
    );

    // 5. Con trỏ khảo sát (Crosshair Probe) tại (y, z)
    final pPx = Offset(cx + probeZMm * sc, cy - probeYMm * sc);
    final cP = Paint()..color = const Color(0xFFFFFFFF)..strokeWidth = 1.6;
    canvas.drawLine(pPx - const Offset(10, 0), pPx + const Offset(10, 0), cP);
    canvas.drawLine(pPx - const Offset(0, 10), pPx + const Offset(0, 10), cP);
    canvas.drawCircle(pPx, 5.2, Paint()..color = const Color(0xFF06B6D4)..style = PaintingStyle.stroke..strokeWidth = 2.0);
  }

  void _drawMiniArrow(Canvas c, Offset a, Offset b, Paint p) {
    c.drawLine(a, b, p);
    final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
    const sz = 4.0;
    c.drawLine(b, b - Offset(sz * math.cos(ang - 0.6), sz * math.sin(ang - 0.6)), p);
    c.drawLine(b, b - Offset(sz * math.cos(ang + 0.6), sz * math.sin(ang + 0.6)), p);
  }

  void _drawDashedLine(Canvas c, Offset a, Offset b, Paint p) {
    final total = (b - a).distance;
    if (total < 1) return;
    final dir = (b - a) / total;
    double d = 0;
    while (d < total) {
      final d2 = math.min(total, d + 4.5);
      c.drawLine(a + dir * d, a + dir * d2, p);
      d += 8.0;
    }
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
    final m = result.config.material;
    final fg = darkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final axisP = Paint()..color = darkMode ? const Color(0xFF475569) : const Color(0xFF94A3B8)..strokeWidth = 1.0;

    const topY = 26.0;
    final botY = size.height - 18.0;
    final hPx = math.max(30.0, botY - topY);
    double yToPx(double yMm) => topY + (0.5 * g.hMm - yMm) / g.hMm * hPx;

    // Cột trái: Biến dạng tương thích ε(y) (Thép & BT làm việc đồng thời)
    // Cột phải: Ứng suất liên hợp KÉP σ_c(y) (Bê tông — Vàng) + σ_a(y) (Lõi Thép H — Đỏ)
    final xEps0 = size.width * 0.25;
    final xSig0 = size.width * 0.72;
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
    canvas.drawPath(ePath, Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.26));
    canvas.drawLine(
      Offset(xEps0 + (epsTop / maxE) * halfW, topY),
      Offset(xEps0 + (epsBot / maxE) * halfW, botY),
      Paint()..color = const Color(0xFF38BDF8)..strokeWidth = 2.0,
    );

    // Đánh dấu 2 điểm mép cánh thép H trên đường biến dạng (Chứng minh tương thích biến dạng ε_a = ε_c)
    final yStTop = g.coreOffsetYMm + 0.5 * g.haMm;
    final yStBot = g.coreOffsetYMm - 0.5 * g.haMm;
    for (final yFl in [yStTop, yStBot]) {
      final eFl = dis.eps0 - yFl * dis.kappaZ;
      final px = xEps0 + (eFl / maxE) * halfW;
      canvas.drawCircle(Offset(px, yToPx(yFl)), 3.2, Paint()..color = const Color(0xFFEF4444));
    }

    // 1. Ứng suất phi tuyến bê tông σ_c(y) (chuẩn hóa theo f'_c)
    final maxC = math.max(5.0, m.fcMpa * 1.15);
    final sPath = Path()..moveTo(xSig0, topY);
    for (int i = 0; i <= 24; i++) {
      final yMm = 0.5 * g.hMm - g.hMm * i / 24.0;
      final eps = dis.eps0 - yMm * dis.kappaZ;
      final r = SrcNonlinearEngine.concreteLaw(eps, m, ConcreteZone.partiallyConfined, result.conf, true);
      final sx = xSig0 + (r.sig / maxC).clamp(-1.1, 0.35) * halfW;
      sPath.lineTo(sx, yToPx(yMm));
    }
    sPath.lineTo(xSig0, botY);
    sPath.close();
    canvas.drawPath(sPath, Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.28));
    canvas.drawPath(sPath, Paint()..color = const Color(0xFFF59E0B)..style = PaintingStyle.stroke..strokeWidth = 1.6);

    // 2. Ứng suất lõi thép hình σ_a(y) (chuẩn hóa theo f_y để thấy rõ vùng làm việc của cánh/bụng thép H!)
    final maxS = math.max(50.0, m.fySteelMpa * 1.05);
    final aPath = Path()..moveTo(xSig0, yToPx(yStTop));
    for (int i = 0; i <= 14; i++) {
      final yMm = yStTop - g.haMm * i / 14.0;
      final eps = dis.eps0 - yMm * dis.kappaZ;
      final r = SrcNonlinearEngine.steelLaw(eps, m.esSteelMpa, m.fySteelMpa, m.hardeningSteel, true);
      final sx = xSig0 + (r.sig / maxS).clamp(-1.05, 1.05) * halfW;
      aPath.lineTo(sx, yToPx(yMm));
    }
    aPath.lineTo(xSig0, yToPx(yStBot));
    aPath.close();
    canvas.drawPath(aPath, Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.26));
    canvas.drawPath(aPath, Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.stroke..strokeWidth = 1.9);

    // Vạch mức điểm đang khảo sát y
    final pyProbe = yToPx(probeYMm);
    canvas.drawLine(Offset(4, pyProbe), Offset(size.width - 4, pyProbe), Paint()..color = const Color(0xFF06B6D4)..strokeWidth = 1.2);

    void label(String s, double x, double y, Color c, double fs) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: c, fontSize: fs, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((x - tp.width * 0.5).clamp(2.0, math.max(2.0, size.width - tp.width - 2)), y));
    }

    label('ε_a=ε_c (‰)', xEps0, 3, const Color(0xFF38BDF8), 8.8);
    label('σ_c & σ_a', xSig0, 3, const Color(0xFFF59E0B), 8.8);
    label(tr(lang, 'Vàng: BT | Đỏ: Thép H', 'Amber: RC | Red: Steel'), size.width * 0.5, size.height - 14, fg.withValues(alpha: 0.72), 8.2);
  }

  @override
  bool shouldRepaint(covariant _StrainStressProfilePainter old) => true;
}
