// ============================================================================
// PHÒNG THÍ NGHIỆM MÔ PHỎNG TƯƠNG TÁC CỐT CỨNG (THÉP HÌNH) ↔ BÊ TÔNG XUNG QUANH
// ============================================================================
// Lột tả trực quan, định lượng và động (0% → 100% tải cực hạn) 4 cơ chế vật lý:
//   1. Phóng đại cận cảnh vùng tiếp xúc dọc: Dính bám hóa học → Phá vỡ dính bám →
//      Kích hoạt đinh neo chống cắt (biến dạng chữ S, nêm ép bê tông, thanh chống
//      nén chéo 45°) → Trượt vi mô Δs → Hãm vết nứt kéo / Bong vỡ vỏ bảo vệ.
//   2. Phẫu thuật mặt cắt ngang tương tác: 3 vùng kiềm chế Chen–Lin (2006)
//      (Vỏ bảo vệ vs Cốt đai K_p vs Khoang vòm thép H K_h), áp lực giãn nở Poisson
//      vs phản lực kiềm chế f_l,h, đường cắt tách dọc cánh thép Weng (2002) và
//      so sánh song song 2 phía khe tiếp xúc (Phía Thép hình ↔ Phía Bê tông).
//   3. 3 Biểu đồ cơ học thời gian thực đồng bộ theo mức tải λ:
//      • Đường cong Dính bám – Trượt τ_b(s) & Đinh neo Ollgaard
//      • Đường cong Ứng suất – Biến dạng σ_c–ε_c của 3 vùng bê tông (3 chấm động!)
//      • Đường cong Chuyển dịch Chia tải Thép hình ↔ Bê tông từ 0% → 100% cực hạn!
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/src_engine.dart';

class SrcInterfaceInteractionLab extends StatefulWidget {
  final SrcAnalysisResult result;
  final double probeXNorm;
  final bool darkMode;
  final AppLang lang;
  final ValueChanged<double> onProbeXChanged;

  const SrcInterfaceInteractionLab({
    super.key,
    required this.result,
    required this.probeXNorm,
    required this.darkMode,
    required this.lang,
    required this.onProbeXChanged,
  });

  @override
  State<SrcInterfaceInteractionLab> createState() => _SrcInterfaceInteractionLabState();
}

class _SrcInterfaceInteractionLabState extends State<SrcInterfaceInteractionLab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  double _ultFrac = 0.55; // Mức tải hiện tại so với tải cực hạn [0.05..1.0]
  int _focusZone = 0; // 0: Đinh neo/Cánh trên, 1: Khoang lõi H, 2: Mép cánh Weng, 3: Vỏ vs Đai
  double? _customY;
  double? _customZ;

  // Cache đường cong chuyển dịch chia tải để không tính lại mỗi frame animation
  SrcAnalysisResult? _cachedRes;
  double _cachedX = -1;
  List<LoadRedistPoint> _redistCurve = const [];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 9))
      ..addListener(() {
        if (!mounted) return;
        setState(() {
          _ultFrac = 0.05 + 0.95 * _animCtrl.value;
        });
      });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggleAnim() {
    if (_animCtrl.isAnimating) {
      _animCtrl.stop();
      setState(() {});
    } else {
      _animCtrl.repeat(min: 0.0, max: 1.0);
      setState(() {});
    }
  }

  void _ensureCurve() {
    if (_cachedRes != widget.result || (_cachedX - widget.probeXNorm).abs() > 0.005) {
      _cachedRes = widget.result;
      _cachedX = widget.probeXNorm;
      _redistCurve = SrcNonlinearEngine.computeLoadRedistributionCurve(widget.result, widget.probeXNorm);
    }
  }

  (double yMm, double zMm) _getActiveProbeCoords() {
    if (_customY != null && _customZ != null) return (_customY!, _customZ!);
    final g = widget.result.config.geometry;
    return switch (_focusZone) {
      0 => (g.coreOffsetYMm + 0.5 * g.haMm, 0.0), // Mặt tiếp xúc cánh trên & đinh neo
      1 => (g.coreOffsetYMm, 0.25 * g.baMm), // Khoang kiềm chế mạnh giữa 2 cánh thép H
      2 => (g.coreOffsetYMm - 0.5 * g.haMm, 0.5 * g.baMm + 8.0), // Mép cánh dưới (cắt tách Weng)
      _ => (0.5 * g.hMm - 0.5 * g.coverMm, 0.0), // Vỏ bảo vệ ngoài cốt đai
    };
  }

  @override
  Widget build(BuildContext context) {
    _ensureCurve();
    final res = widget.result;
    final cfg = res.config;
    final g = cfg.geometry;
    final isBeam = cfg.kind == MemberKind.beam;
    final l = widget.lang;
    final dark = widget.darkMode;

    // Dùng vị trí x/L được chọn; nếu Dầm đang ở 0.50 (cắt V=0), hiển thị thêm gợi ý dịch về 0.15 để thấy lực trượt lớn nhất
    final dis = SrcNonlinearEngine.dissectSectionAtUltimateFrac(res, widget.probeXNorm, _ultFrac);
    final (pY, pZ) = _getActiveProbeCoords();

    // Khảo sát ĐỒNG THỜI 2 phía khe tiếp xúc (Phía Thép hình vs Phía Bê tông kề sát)
    final steelSampleY = (pY).clamp(g.coreOffsetYMm - 0.48 * g.haMm, g.coreOffsetYMm + 0.48 * g.haMm);
    final steelProbe = SrcNonlinearEngine.probePointOnDissection(res, dis, steelSampleY, 0.0);
    final concSampleY = _focusZone == 0
        ? (g.coreOffsetYMm + 0.5 * g.haMm + 12.0).clamp(-0.48 * g.hMm, 0.48 * g.hMm)
        : (_focusZone == 1 ? g.coreOffsetYMm : pY);
    final concSampleZ = _focusZone == 1 ? (0.30 * g.baMm) : (_focusZone == 2 ? (0.5 * g.baMm + 14.0).clamp(0.0, 0.48 * g.bMm) : pZ);
    final concProbe = SrcNonlinearEngine.probePointOnDissection(res, dis, concSampleY, concSampleZ);

    final cardBg = dark ? const Color(0xFF0F172A) : Colors.white;
    final subBg = dark ? const Color(0xFF081022) : const Color(0xFFF8FAFC);
    final border = dark ? const Color(0xFF263859) : const Color(0xFFCBD5E1);
    final fg = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    // Xác định 4 giai đoạn ứng xử tương tác theo mức tải & trạng thái vật lý
    final int stageIdx = _ultFrac < 0.25 ? 1 : (_ultFrac < 0.55 ? 2 : (_ultFrac < 0.85 ? 3 : 4));
    final stageColor = switch (stageIdx) {
      1 => const Color(0xFF10B981),
      2 => const Color(0xFF38BDF8),
      3 => const Color(0xFFF59E0B),
      _ => const Color(0xFFEF4444),
    };
    final stageTitle = switch (stageIdx) {
      1 => tr(l, 'GĐ1: Dính bám hóa học & Liên kết đàn hồi hoàn toàn (s ≈ 0)', 'Stage 1: Elastic Chemical Bond & Full Interaction'),
      2 => isBeam
          ? tr(l, 'GĐ2: Nứt kéo bê tông bị thép H hãm — Đinh neo chống cắt kích hoạt', 'Stage 2: Cracks Arrested by Steel — Shear Studs Activated')
          : tr(l, 'GĐ2: Tăng áp lực giãn nở ngang Poisson — Bắt đầu kiềm chế vòm thép H', 'Stage 2: Lateral Poisson Expansion — H-Core Confinement Starts'),
      3 => isBeam
          ? tr(l, 'GĐ3: Đinh neo biến dạng cắt & Nêm ép bê tông — Cánh thép bắt đầu chảy dẻo', 'Stage 3: Stud Shear Deformation & Concrete Bearing Cone — Steel Yielding')
          : tr(l, 'GĐ3: Kiềm chế 3 trục mạnh trong khoang H (K_h) — Vỏ ngoài tiệm cận vỡ nén', 'Stage 3: Strong Triaxial H-Core Confinement — Cover Near Peak'),
      _ => isBeam
          ? tr(l, 'GĐ4: Cực hạn — Dầm dẻo nhờ lõi thép H & Rủi ro cắt tách dọc cánh Weng', 'Stage 4: Ultimate — Plastic Hinge & Flange Splitting Check')
          : tr(l, 'GĐ4: Vỏ bê tông ngoài bong vỡ — Lõi kiềm chế mạnh khoang thép H vẫn giữ tải!', 'Stage 4: Outer Cover Spalls — Highly Confined H-Core Survives!'),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        // =====================================================================
        // THANH ĐIỀU KHIỂN MỨC TẢI ĐỘNG (0% → 100%) & MẶT CẮT x/L
        // =====================================================================
        final controlBar = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: stageColor.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Nút Play / Pause mô phỏng động
                  InkWell(
                    onTap: _toggleAnim,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _animCtrl.isAnimating
                              ? const [Color(0xFFEF4444), Color(0xFFF97316)]
                              : const [Color(0xFF06B6D4), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_animCtrl.isAnimating ? Icons.pause : Icons.play_arrow, size: 15, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            _animCtrl.isAnimating ? tr(l, 'Dừng', 'Pause') : tr(l, 'Chạy mô phỏng', 'Play Sim'),
                            style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 4 nút chọn nhanh 4 giai đoạn
                  for (final (lbl, val) in [
                    ('GĐ1 (15%)', 0.15),
                    ('GĐ2 (45%)', 0.45),
                    ('GĐ3 (75%)', 0.75),
                    ('GĐ4 (98%)', 0.98),
                  ])
                    _pillBtn(
                      lbl,
                      (_ultFrac - val).abs() < 0.08,
                      stageColor,
                      fg,
                      border,
                      () {
                        _animCtrl.stop();
                        setState(() => _ultFrac = val);
                      },
                    ),
                  // Chọn nhanh vị trí mặt cắt x/L (Gối nơi lực trượt lớn nhất vs Giữa nhịp)
                  Text(tr(l, 'Vị trí cắt:', 'Cut x/L:'), style: TextStyle(fontSize: 10.2, color: sub, fontWeight: FontWeight.bold)),
                  for (final (lbl, xv) in [
                    (isBeam ? tr(l, 'Gối 0.12', 'End 0.12') : tr(l, 'Đầu cột 0.10', 'End 0.10'), isBeam ? 0.12 : 0.10),
                    ('0.25', 0.25),
                    (tr(l, 'Giữa 0.50', 'Mid 0.50'), 0.50),
                  ])
                    _pillBtn(
                      lbl,
                      (widget.probeXNorm - xv).abs() < 0.05,
                      const Color(0xFF06B6D4),
                      fg,
                      border,
                      () => widget.onProbeXChanged(xv),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Text(
                    '${tr(l, "Mức tải", "Load")}: ${(_ultFrac * 100).toStringAsFixed(0)}% (${(res.ultimateLoadKn * _ultFrac).toStringAsFixed(0)} / ${res.ultimateLoadKn.toStringAsFixed(0)} kN)',
                    style: TextStyle(fontSize: 10.4, fontFamily: 'DejaVuSansMono', fontWeight: FontWeight.bold, color: stageColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: _ultFrac,
                        min: 0.05,
                        max: 1.0,
                        activeColor: stageColor,
                        inactiveColor: border,
                        onChanged: (v) {
                          _animCtrl.stop();
                          setState(() => _ultFrac = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: dark ? 0.14 : 0.09),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: stageColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: stageColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stageTitle,
                        style: TextStyle(fontSize: 10.8, fontWeight: FontWeight.bold, color: stageColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        // =====================================================================
        // CANVAS A: PHÓNG ĐẠI CẬN CẢNH CƠ CHẾ TIẾP XÚC DỌC THÉP HÌNH ↔ BÊ TÔNG
        // =====================================================================
        final microCutawayCard = Container(
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.zoom_in, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isBeam
                          ? tr(l, 'A. Phóng đại Vùng Tiếp xúc Dọc: Dính bám → Đinh neo → Nêm ép → Trượt Δs',
                              'A. Zoomed Longitudinal Interface: Bond → Stud Shear → Bearing Cone → Slip Δs')
                          : tr(l, 'A. Phóng đại Tương tác Dọc Cột: Nở hông Poisson ↔ Phản lực Kiềm chế & Ma sát',
                              'A. Zoomed Column Interaction: Poisson Expansion ↔ Confinement & Bond'),
                      style: TextStyle(fontSize: 11.4, fontWeight: FontWeight.bold, color: fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: wide ? 295 : 265,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _MicroInterfaceCutawayPainter(
                    result: res,
                    dis: dis,
                    ultFrac: _ultFrac,
                    stageIdx: stageIdx,
                    darkMode: dark,
                    lang: l,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Thanh chú giải định lượng tại khe tiếp xúc
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: subBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  children: [
                    _kvChip('v_L', '${dis.vInterfaceKnPerM.toStringAsFixed(1)} kN/m', const Color(0xFFF59E0B), dark),
                    _kvChip('τ_b / τ_Rd', '${dis.tauBondMpa.toStringAsFixed(2)} / ${dis.tauRdMpa.toStringAsFixed(2)} MPa',
                        dis.tauBondMpa > dis.tauRdMpa ? const Color(0xFFEF4444) : const Color(0xFF06B6D4), dark),
                    if (isBeam)
                      _kvChip('F_stud', '${dis.studForceKn.toStringAsFixed(1)} / ${res.studPRdKn.toStringAsFixed(1)} kN (${(dis.studUr * 100).toStringAsFixed(0)}%)',
                          dis.studUr > 0.85 ? const Color(0xFFEF4444) : const Color(0xFF10B981), dark)
                    else
                      _kvChip('f_lh / f_lp', '${(res.conf.flH * _ultFrac).toStringAsFixed(2)} / ${(res.conf.flP * _ultFrac).toStringAsFixed(2)} MPa',
                          const Color(0xFFA855F7), dark),
                    _kvChip('Δs (Slip)', '${dis.slipMm.toStringAsFixed(3)} mm', const Color(0xFF38BDF8), dark),
                    _kvChip(
                      tr(l, 'Tải thép H', 'Steel H'),
                      '${dis.steelSharePct.toStringAsFixed(1)}% | BT ${dis.concreteSharePct.toStringAsFixed(1)}%',
                      const Color(0xFFEF4444),
                      dark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        // =====================================================================
        // CANVAS B: PHẪU THUẬT MẶT CẮT NGANG — KIỀM CHẾ 3 VÙNG & SO SÁNH 2 PHÍA KHE
        // =====================================================================
        final sectionConfinementCard = Container(
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.hub_outlined, size: 16, color: Color(0xFF06B6D4)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr(l, 'B. Tương tác Mặt cắt Ngang: 3 Vùng Kiềm chế, Vòm Thép H & Tách Cánh',
                          'B. Cross-Section Mechanics: 3-Zone Confinement, H-Arching & Splitting'),
                      style: TextStyle(fontSize: 11.4, fontWeight: FontWeight.bold, color: fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // 4 nút nhảy nhanh đến 4 vùng tương tác trọng yếu
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  for (final (idx, lbl) in [
                    (0, isBeam ? tr(l, '1. Đinh neo / Cánh trên', '1. Stud / Top Flange') : tr(l, '1. Tiếp xúc Cánh thép', '1. Flange Contact')),
                    (1, tr(l, '2. Lõi kiềm chế H (K_h)', '2. H-Core Confined')),
                    (2, tr(l, '3. Mép cánh tách Weng', '3. Flange Splitting')),
                    (3, tr(l, '4. Vỏ ngoài vs Cốt đai', '4. Cover vs Stirrups')),
                  ])
                    _pillBtn(
                      lbl,
                      _focusZone == idx && _customY == null,
                      const Color(0xFFF59E0B),
                      fg,
                      border,
                      () => setState(() {
                        _focusZone = idx;
                        _customY = null;
                        _customZ = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: wide ? 225 : 215,
                child: LayoutBuilder(
                  builder: (ctx, cs) {
                    return GestureDetector(
                      onTapDown: (d) => _tapSection(d.localPosition, Size(cs.maxWidth, cs.maxHeight)),
                      onPanUpdate: (d) => _tapSection(d.localPosition, Size(cs.maxWidth, cs.maxHeight)),
                      child: CustomPaint(
                        size: Size(cs.maxWidth, cs.maxHeight),
                        painter: _ConfinementInterfaceSectionPainter(
                          result: res,
                          dis: dis,
                          ultFrac: _ultFrac,
                          focusZone: _focusZone,
                          probeYMm: pY,
                          probeZMm: pZ,
                          darkMode: dark,
                          lang: l,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              // SO SÁNH SONG SONG 2 PHÍA KHE TIẾP XÚC: THÉP HÌNH ↔ BÊ TÔNG KỀ SÁT
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: subBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.45)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(l, 'PHÍA LÕI THÉP HÌNH', 'STEEL CORE SIDE'),
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ε_a = ${(steelProbe.epsX * 1000).toStringAsFixed(2)} ‰  |  σ_a = ${steelProbe.sigmaXMpa.toStringAsFixed(1)} MPa',
                            style: TextStyle(fontSize: 9.6, fontFamily: 'DejaVuSansMono', color: fg, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'σ_vM = ${steelProbe.sigmaVmMpa.toStringAsFixed(1)} MPa (${(steelProbe.utilRatio * 100).toStringAsFixed(0)}% f_y)',
                            style: TextStyle(fontSize: 9.4, color: sub),
                          ),
                          Text(
                            l.isVi ? steelProbe.stateVi : steelProbe.stateEn,
                            style: TextStyle(fontSize: 9.2, color: const Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 52, color: border, margin: const EdgeInsets.symmetric(horizontal: 8)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(l, 'PHÍA BÊ TÔNG KỀ SÁT', 'ADJACENT CONCRETE'),
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ε_c = ${(concProbe.epsX * 1000).toStringAsFixed(2)} ‰  |  σ_c = ${concProbe.sigmaXMpa.toStringAsFixed(1)} MPa',
                            style: TextStyle(fontSize: 9.6, fontFamily: 'DejaVuSansMono', color: fg, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            l.isVi ? concProbe.zoneVi : concProbe.zoneEn,
                            style: TextStyle(fontSize: 9.2, color: sub),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            l.isVi ? concProbe.stateVi : concProbe.stateEn,
                            style: TextStyle(fontSize: 9.2, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        // =====================================================================
        // HÀNG DƯỚI: 3 BIỂU ĐỒ ĐỊNH LƯỢNG ĐỒNG BỘ THEO MỨC TẢI λ (0% → 100%)
        // =====================================================================
        final chart1 = _chartBox(
          title: tr(l, '1. Dính bám – Trượt (τ_b – s) & Đinh neo', '1. Bond–Slip (τ_b – s) & Stud Law'),
          accent: const Color(0xFFF59E0B),
          cardBg: cardBg,
          border: border,
          fg: fg,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BondSlipCurvePainter(result: res, dis: dis, darkMode: dark, lang: l),
          ),
        );

        final chart2 = _chartBox(
          title: tr(l, '2. Ứng xử 3 Vùng Bê tông (Vỏ vs Đai vs Lõi H)', '2. 3-Zone Concrete σ_c–ε_c (Cover vs Core)'),
          accent: const Color(0xFF38BDF8),
          cardBg: cardBg,
          border: border,
          fg: fg,
          child: CustomPaint(
            size: Size.infinite,
            painter: _ThreeZoneConstitutivePainter(result: res, dis: dis, darkMode: dark, lang: l),
          ),
        );

        final chart3 = _chartBox(
          title: tr(l, '3. Chuyển dịch Chia tải Thép H ↔ Bê tông (0→100%)', '3. Load Redistribution Steel H ↔ RC (0→100%)'),
          accent: const Color(0xFFEF4444),
          cardBg: cardBg,
          border: border,
          fg: fg,
          child: CustomPaint(
            size: Size.infinite,
            painter: _LoadRedistributionPainter(curve: _redistCurve, ultFrac: _ultFrac, darkMode: dark, lang: l),
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              controlBar,
              const SizedBox(height: 8),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 52, child: microCutawayCard),
                    const SizedBox(width: 8),
                    Expanded(flex: 48, child: sectionConfinementCard),
                  ],
                )
              else ...[
                microCutawayCard,
                const SizedBox(height: 8),
                sectionConfinementCard,
              ],
              const SizedBox(height: 8),
              if (wide)
                SizedBox(
                  height: 205,
                  child: Row(
                    children: [
                      Expanded(child: chart1),
                      const SizedBox(width: 8),
                      Expanded(child: chart2),
                      const SizedBox(width: 8),
                      Expanded(child: chart3),
                    ],
                  ),
                )
              else ...[
                SizedBox(height: 195, child: chart1),
                const SizedBox(height: 8),
                SizedBox(height: 195, child: chart2),
                const SizedBox(height: 8),
                SizedBox(height: 195, child: chart3),
              ],
            ],
          ),
        );
      },
    );
  }

  void _tapSection(Offset pos, Size sz) {
    final g = widget.result.config.geometry;
    final bDraw = g.sectionType == 'SRC_T_SLAB_H' ? g.bfSlabMm : g.bMm;
    final sc = math.min((sz.width - 42) / math.max(100.0, bDraw), (sz.height - 28) / math.max(100.0, g.hMm));
    final cx = sz.width * 0.5;
    final cy = sz.height * 0.5;
    setState(() {
      _customZ = ((pos.dx - cx) / sc).clamp(-0.5 * bDraw, 0.5 * bDraw);
      _customY = ((cy - pos.dy) / sc).clamp(-0.5 * g.hMm, 0.5 * g.hMm);
    });
  }

  Widget _pillBtn(String txt, bool active, Color accent, Color fg, Color border, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: active ? accent : border),
        ),
        child: Text(
          txt,
          style: TextStyle(fontSize: 9.8, fontWeight: FontWeight.bold, color: active ? accent : fg.withValues(alpha: 0.78)),
        ),
      ),
    );
  }

  Widget _kvChip(String k, String v, Color accent, bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 9.7, fontFamily: 'DejaVuSansMono', color: dark ? Colors.white : const Color(0xFF0F172A)),
          children: [
            TextSpan(text: '$k: ', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
            TextSpan(text: v, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _chartBox({
    required String title,
    required Color accent,
    required Color cardBg,
    required Color border,
    required Color fg,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(11), border: Border.all(color: border)),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 10.4, fontWeight: FontWeight.bold, color: fg), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ============================================================================
// PAINTER A: PHÓNG ĐẠI CẬN CẢNH VÙNG TIẾP XÚC DỌC THÉP HÌNH ↔ BÊ TÔNG
// ============================================================================
class _MicroInterfaceCutawayPainter extends CustomPainter {
  final SrcAnalysisResult result;
  final DissectionResult dis;
  final double ultFrac;
  final int stageIdx;
  final bool darkMode;
  final AppLang lang;

  const _MicroInterfaceCutawayPainter({
    required this.result,
    required this.dis,
    required this.ultFrac,
    required this.stageIdx,
    required this.darkMode,
    required this.lang,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isBeam = result.config.kind == MemberKind.beam;
    final bg = darkMode ? const Color(0xFF070E1D) : const Color(0xFFF1F5F9);
    final fg = darkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(9)), Paint()..color = bg);

    if (isBeam) {
      _paintBeamMicroInterface(canvas, size, fg);
    } else {
      _paintColumnMicroInterface(canvas, size, fg);
    }
  }

  void _paintBeamMicroInterface(Canvas canvas, Size size, Color fg) {
    final w = size.width;
    final h = size.height;
    const padX = 20.0;
    final x0 = padX, x1 = w - padX;
    final spanW = x1 - x0;

    // Bố trí cao độ hình học phóng đại cực kỳ rõ nét:
    final ySlabTop = h * 0.12;
    final yFlTop = h * 0.42; // Mặt tiếp xúc cánh trên thép H ↔ Bê tông (nơi có Đinh neo!)
    final tfH = h * 0.065;
    final yFlBot = h * 0.72; // Cánh dưới thép H
    final yConcBot = h * 0.89;

    // Độ trượt phóng đại thị giác Δs (rõ dần từ GĐ2 → GĐ4)
    final slipVisual = (dis.slipMm * 28.0 + (stageIdx >= 2 ? (ultFrac - 0.22) * 14.0 : 0.0)).clamp(0.0, 14.0);
    final bondBroken = dis.tauBondMpa > 0.30 || stageIdx >= 2;
    final steelYielding = stageIdx >= 3;

    // 1. Vùng bê tông bao quanh (bản sàn trên + sườn bê tông giữa + lớp bảo vệ dưới)
    final concTopColor = Color.lerp(
      darkMode ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
      const Color(0xFF0284C7),
      (ultFrac * 0.55).clamp(0.0, 0.55),
    )!;
    canvas.drawRect(Rect.fromLTRB(x0, ySlabTop, x1, yFlTop), Paint()..color = concTopColor.withValues(alpha: 0.72));
    canvas.drawRect(Rect.fromLTRB(x0, yFlTop, x1, yConcBot),
        Paint()..color = (darkMode ? const Color(0xFF17253B) : const Color(0xFFE2E8F0)).withValues(alpha: 0.65));

    // Vùng bê tông kiềm chế mạnh trong khoang giữa 2 cánh thép H (màu vàng ấm)
    canvas.drawRect(
      Rect.fromLTRB(x0 + 4, yFlTop + tfH, x1 - 4, yFlBot),
      Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.10 + 0.16 * ultFrac),
    );

    // 2. Cốt đai đứng bao quanh (vẽ mảnh phía sau, đổi màu xanh sáng khi chịu kéo kẹp nứt)
    final stirCol = Color.lerp(const Color(0xFF10B981), const Color(0xFF34D399), ultFrac)!;
    final stirP = Paint()..color = stirCol..strokeWidth = 2.0;
    for (int i = 0; i < 6; i++) {
      final xs = x0 + spanW * (0.08 + i * 0.168);
      canvas.drawLine(Offset(xs, ySlabTop + 10), Offset(xs, yConcBot - 10), stirP);
    }

    // Cốt thép dọc trên & dưới
    final rbP = Paint()..color = const Color(0xFF10B981)..strokeWidth = 3.2;
    canvas.drawLine(Offset(x0, ySlabTop + 10), Offset(x1, ySlabTop + 10), rbP);
    canvas.drawLine(Offset(x0, yConcBot - 10), Offset(x1, yConcBot - 10), rbP);

    // 3. LÕI THÉP HÌNH H (bản bụng + bản cánh trên & dưới — dịch chuyển nhẹ Δs để thấy trượt tương đối!)
    final stX0 = x0 + slipVisual * 0.5;
    final stX1 = x1 + slipVisual * 0.5;
    final webCol = steelYielding ? const Color(0xFFDC2626) : const Color(0xFFEF4444);
    canvas.drawRect(Rect.fromLTRB(stX0, yFlTop + tfH, stX1, yFlBot), Paint()..color = webCol.withValues(alpha: 0.30));
    canvas.drawRect(Rect.fromLTRB(stX0, yFlTop, stX1, yFlTop + tfH), Paint()..color = const Color(0xFFEF4444));
    canvas.drawRect(
      Rect.fromLTRB(stX0, yFlBot, stX1, yFlBot + tfH),
      Paint()..color = steelYielding ? const Color(0xFFFF006E) : const Color(0xFFEF4444),
    );

    // 4. LÒ XO DÍNH BÁM VI MÔ (Xanh nguyên vẹn ở GĐ1 → Đứt gãy màu đỏ từ GĐ2!)
    for (int k = 0; k < 18; k++) {
      final bx = x0 + spanW * (0.04 + k * 0.054);
      final bp = Paint()
        ..color = bondBroken ? const Color(0xFFFF4D4F).withValues(alpha: 0.65) : const Color(0xFF10B981)
        ..strokeWidth = 1.4;
      if (!bondBroken) {
        // Lò xo dính bám nguyên vẹn nối chặt cánh thép & bê tông
        final p = Path()
          ..moveTo(bx, yFlTop)
          ..lineTo(bx - 2.5, yFlTop - 3)
          ..lineTo(bx + 2.5, yFlTop - 6)
          ..lineTo(bx, yFlTop - 9);
        canvas.drawPath(p, bp..style = PaintingStyle.stroke);
      } else if (k % 2 == 0) {
        // Dấu đứt gãy dính bám hóa học + khe trượt vi mô
        canvas.drawLine(Offset(bx - 3, yFlTop - 2), Offset(bx + 3, yFlTop - 2), bp);
      }
    }

    // 5. 3 ĐINH NEO CHỐNG CẮT PHÓNG ĐẠI (Biến dạng chữ S + Nêm ép bê tông + Thanh chống nén 45°!)
    final studH = (yFlTop - ySlabTop) * 0.66;
    for (int s = 0; s < 3; s++) {
      final sxBase = stX0 + spanW * (0.18 + s * 0.30);
      final bend = (slipVisual * 0.72).clamp(0.0, 9.5);
      final sxHead = sxBase - bend; // Đầu đinh bị bê tông kéo ngược lại gây uốn cắt hình chữ S!

      // 5a. Nêm ép cục bộ bê tông (Concrete Bearing Cone σ_bear) ngay mặt trước chân đinh neo
      if (ultFrac > 0.12) {
        final coneW = 14.0 + 20.0 * ultFrac;
        final coneH = studH * 0.68;
        final conePath = Path()
          ..moveTo(sxBase - 3, yFlTop)
          ..lineTo(sxBase - 3 - coneW, yFlTop - coneH)
          ..lineTo(sxBase - 3 - coneW * 0.45, yFlTop - coneH * 1.12)
          ..lineTo(sxBase - 2, yFlTop - studH * 0.55)
          ..close();
        canvas.drawPath(
          conePath,
          Paint()..color = Color.lerp(const Color(0xFFFBBF24), const Color(0xFFFF3B30), ultFrac)!.withValues(alpha: 0.45 + 0.3 * ultFrac),
        );

        // 5b. Thanh chống nén chéo bê tông ~45° (Diagonal Concrete Compression Strut)
        final strutP = Paint()
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.45 + 0.4 * ultFrac)
          ..strokeWidth = 2.0;
        _drawArrow(
          canvas,
          Offset(sxBase - 4, yFlTop - 6),
          Offset(sxBase - 34 - 16 * ultFrac, ySlabTop + 14),
          strutP,
        );
      }

      // 5c. Thân đinh neo biến dạng cắt chữ S (Ollgaard shear-bending) + Mối hàn chân đinh + Mũ T
      final studPath = Path()
        ..moveTo(sxBase, yFlTop)
        ..cubicTo(
          sxBase, yFlTop - studH * 0.45,
          sxHead, yFlTop - studH * 0.55,
          sxHead, yFlTop - studH,
        );
      final studCol = Color.lerp(const Color(0xFFFDE047), const Color(0xFFFF5722), dis.studUr.clamp(0.0, 1.0))!;
      canvas.drawPath(studPath, Paint()..color = studCol..style = PaintingStyle.stroke..strokeWidth = 4.6..strokeCap = StrokeCap.round);
      // Mũ đinh neo (Head)
      canvas.drawLine(
        Offset(sxHead - 8, yFlTop - studH),
        Offset(sxHead + 8, yFlTop - studH),
        Paint()..color = studCol..strokeWidth = 4.2..strokeCap = StrokeCap.square,
      );
      // Mối hàn góc chân đinh
      canvas.drawCircle(Offset(sxBase, yFlTop), 3.6, Paint()..color = const Color(0xFFFFFFFF));
    }

    // 6. VẾT NỨT KÉO BÊ TÔNG DƯỚI (GĐ2 → GĐ4) BỊ CÁNH DƯỚI THÉP H & CỐT THÉP HÃM LẠI!
    if (stageIdx >= 2) {
      final crP = Paint()..color = const Color(0xFFFF2D55)..strokeWidth = 1.6 + 0.8 * ultFrac;
      final nCr = stageIdx == 2 ? 4 : (stageIdx == 3 ? 6 : 8);
      for (int c = 0; c < nCr; c++) {
        final cx = x0 + spanW * (0.10 + c * (0.80 / math.max(1, nCr - 1)));
        // Vết nứt chạy từ đáy lên tới cánh dưới thép H thì bị chặn/chia nhánh!
        final reach = (yConcBot - yFlBot) * (0.55 + 0.45 * ultFrac);
        final p = Path()
          ..moveTo(cx, yConcBot)
          ..lineTo(cx + 3.2, yConcBot - reach * 0.45)
          ..lineTo(cx - 2.4, yConcBot - reach * 0.85)
          ..lineTo(cx + 1.5, yConcBot - reach);
        canvas.drawPath(p, crP..style = PaintingStyle.stroke);
      }
    }

    // 7. MŨI TÊN CHUYỂN VỊ TRƯỢT TƯƠNG ĐỐI NGƯỢC CHIỀU (Bê tông sang trái ↔ Thép H sang phải)
    final arrowYTop = yFlTop - 13;
    _drawArrow(canvas, Offset(x0 + spanW * 0.62, arrowYTop), Offset(x0 + spanW * 0.36, arrowYTop),
        Paint()..color = const Color(0xFF38BDF8)..strokeWidth = 2.2);
    _drawArrow(canvas, Offset(stX0 + spanW * 0.36, yFlTop + tfH * 0.5), Offset(stX0 + spanW * 0.64, yFlTop + tfH * 0.5),
        Paint()..color = const Color(0xFFFFD700)..strokeWidth = 2.2);

    // 8. CHÚ THÍCH TRỰC QUAN NGAY TRÊN MÔ HÌNH
    _drawTag(canvas, Offset(x0 + 4, 5),
        tr(lang, '← Bê tông chịu nén & Thanh chống chéo 45°', '← Concrete Compression & 45° Strut'),
        const Color(0xFF38BDF8));
    _drawTag(canvas, Offset(x0 + spanW * 0.56, 5),
        '${tr(lang, "Nêm ép đinh neo", "Stud Bearing")}: F=${dis.studForceKn.toStringAsFixed(1)} kN',
        const Color(0xFFF59E0B));
    _drawTag(canvas, Offset(x0 + 6, yFlTop + tfH + 6),
        '${tr(lang, "Bụng thép H & Bê tông kiềm chế khoang H", "H-Web & Confined Core")}  |  Δs=${dis.slipMm.toStringAsFixed(3)} mm →',
        const Color(0xFFFDE047));
    _drawTag(canvas, Offset(x0 + 6, yConcBot + 4),
        stageIdx >= 2
            ? tr(lang, 'Vết nứt kéo bê tông bị cánh dưới thép H & cốt thép hãm lại', 'Flexural cracks arrested by steel bottom flange & rebar')
            : tr(lang, 'Bê tông vùng kéo chưa nứt — Làm việc đồng thời ε_a = ε_c', 'Uncracked tension zone — Full strain compatibility'),
        stageIdx >= 2 ? const Color(0xFFFF4D6D) : const Color(0xFF10B981));
  }

  void _paintColumnMicroInterface(Canvas canvas, Size size, Color fg) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final colW = math.min(w * 0.72, 310.0);
    final xL = cx - 0.5 * colW;
    final xR = cx + 0.5 * colW;
    final yT = h * 0.14;
    final yB = h * 0.86;

    final coverW = colW * 0.12;
    final stW = colW * 0.44;
    final stXL = cx - 0.5 * stW;
    final stXR = cx + 0.5 * stW;
    final flW = math.max(9.0, stW * 0.12);
    final spalling = stageIdx == 4 || dis.epsMin < -0.0032;

    // 1. Vỏ bảo vệ bê tông ngoài cùng (Vùng 0 — bong vỡ nứt tách ở GĐ4!)
    final covCol = spalling ? const Color(0xFFEF4444).withValues(alpha: 0.30) : (darkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1));
    canvas.drawRect(Rect.fromLTRB(xL, yT, xL + coverW, yB), Paint()..color = covCol);
    canvas.drawRect(Rect.fromLTRB(xR - coverW, yT, xR, yB), Paint()..color = covCol);

    // 2. Vùng 1 — Kiềm chế một phần trong cốt đai (Xanh dương)
    canvas.drawRect(
      Rect.fromLTRB(xL + coverW, yT, xR - coverW, yB),
      Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.18 + 0.15 * ultFrac),
    );

    // 3. Vùng 2 — Kiềm chế mạnh kẹp trong khoang thép hình H (Vàng kim rực theo mức tải!)
    canvas.drawRect(
      Rect.fromLTRB(stXL + flW, yT, stXR - flW, yB),
      Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.22 + 0.38 * ultFrac),
    );

    // 4. Lõi thép hình H (2 cánh đứng hai bên + bản bụng tâm)
    final steelCol = stageIdx >= 3 ? const Color(0xFFFF1744) : const Color(0xFFEF4444);
    canvas.drawRect(Rect.fromLTRB(stXL, yT, stXL + flW, yB), Paint()..color = steelCol);
    canvas.drawRect(Rect.fromLTRB(stXR - flW, yT, stXR, yB), Paint()..color = steelCol);
    canvas.drawLine(Offset(cx, yT), Offset(cx, yB), Paint()..color = steelCol.withValues(alpha: 0.6)..strokeWidth = 3.5);

    // 5. Cốt thép dọc & Cốt đai ngang bó chặt
    final rbP = Paint()..color = const Color(0xFF10B981)..strokeWidth = 2.6;
    canvas.drawLine(Offset(xL + coverW, yT), Offset(xL + coverW, yB), rbP);
    canvas.drawLine(Offset(xR - coverW, yT), Offset(xR - coverW, yB), rbP);
    for (int i = 0; i < 6; i++) {
      final ys = yT + (yB - yT) * (0.08 + i * 0.168);
      canvas.drawLine(Offset(xL + coverW, ys), Offset(xR - coverW, ys), Paint()..color = const Color(0xFF10B981)..strokeWidth = 2.0);
    }

    // 6. Mũi tên tải nén dọc trục N từ đỉnh cột + Ma sát truyền lực dọc τ_b hai bên cánh thép
    for (final ax in [xL + coverW * 1.5, cx, xR - coverW * 1.5]) {
      _drawArrow(canvas, Offset(ax, 6), Offset(ax, yT - 3), Paint()..color = const Color(0xFF38BDF8)..strokeWidth = 2.2);
    }
    // Mũi tên ma sát tiếp xúc dọc mặt cánh thép
    for (int j = 0; j < 3; j++) {
      final yy = yT + (yB - yT) * (0.20 + j * 0.28);
      _drawArrow(canvas, Offset(stXL - 5, yy - 10), Offset(stXL - 5, yy + 10), Paint()..color = const Color(0xFFF59E0B)..strokeWidth = 1.8);
      _drawArrow(canvas, Offset(stXR + 5, yy - 10), Offset(stXR + 5, yy + 10), Paint()..color = const Color(0xFFF59E0B)..strokeWidth = 1.8);
    }

    // 7. Mũi tên Nở hông Poisson (hướng ra ngoài) ↔ Phản lực Kiềm chế 3 trục f_l,h (ép ngược vào lõi!)
    final confLen = 10.0 + 14.0 * ultFrac;
    for (int r = 0; r < 3; r++) {
      final yy = yT + (yB - yT) * (0.25 + r * 0.25);
      // Cánh thép ép ngang ngược vào lõi bê tông (Vàng kim)
      _drawArrow(canvas, Offset(stXL + flW, yy), Offset(stXL + flW + confLen, yy), Paint()..color = const Color(0xFFFDE047)..strokeWidth = 2.2);
      _drawArrow(canvas, Offset(stXR - flW, yy), Offset(stXR - flW - confLen, yy), Paint()..color = const Color(0xFFFDE047)..strokeWidth = 2.2);
      // Cốt đai bó ngang từ ngoài vào (Xanh ngọc)
      _drawArrow(canvas, Offset(xL + coverW - 14, yy), Offset(xL + coverW - 1, yy), Paint()..color = const Color(0xFF10B981)..strokeWidth = 2.0);
      _drawArrow(canvas, Offset(xR - coverW + 14, yy), Offset(xR - coverW + 1, yy), Paint()..color = const Color(0xFF10B981)..strokeWidth = 2.0);
    }

    // 8. Hiệu ứng BONG VỠ LỚP VỎ BẢO VỆ (GĐ4) trong khi lõi trong vẫn nguyên vẹn!
    if (spalling) {
      final spP = Paint()..color = const Color(0xFFFF2D55)..style = PaintingStyle.stroke..strokeWidth = 1.8;
      for (final side in [-1.0, 1.0]) {
        final bx = side < 0 ? xL : xR;
        final flake = Path()
          ..moveTo(bx, yT + (yB - yT) * 0.25)
          ..lineTo(bx + side * 12, yT + (yB - yT) * 0.42)
          ..lineTo(bx + side * 6, yT + (yB - yT) * 0.58)
          ..lineTo(bx + side * 14, yT + (yB - yT) * 0.72)
          ..lineTo(bx, yT + (yB - yT) * 0.80);
        canvas.drawPath(flake, spP);
      }
    }

    // Chú thích trực quan
    _drawTag(canvas, Offset(8, 4), '↓ N=${(result.ultimateLoadKn * ultFrac).toStringAsFixed(0)} kN | τ_b=${dis.tauBondMpa.toStringAsFixed(2)} MPa', const Color(0xFF38BDF8));
    _drawTag(canvas, Offset(cx - 88, yB + 5),
        spalling
            ? tr(lang, 'Vỏ ngoài bong vỡ — Lõi thép H vẫn giữ K_h·f\'c!', 'Outer cover spalls — H-Core still carries K_h·f\'c!')
            : tr(lang, 'Cánh thép H & Cốt đai ép kiềm chế 3 trục (f_lh=${(result.conf.flH * ultFrac).toStringAsFixed(2)} MPa)', 'H-Flanges & Stirrups confine core (f_lh)'),
        spalling ? const Color(0xFFFF4D6D) : const Color(0xFFFDE047));
  }

  void _drawArrow(Canvas c, Offset a, Offset b, Paint p) {
    c.drawLine(a, b, p);
    final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
    const sz = 5.2;
    c.drawLine(b, b - Offset(sz * math.cos(ang - 0.55), sz * math.sin(ang - 0.55)), p);
    c.drawLine(b, b - Offset(sz * math.cos(ang + 0.55), sz * math.sin(ang + 0.55)), p);
  }

  void _drawTag(Canvas c, Offset pos, String s, Color col) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: 9.2, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, pos);
  }

  @override
  bool shouldRepaint(covariant _MicroInterfaceCutawayPainter old) => true;
}

// ============================================================================
// PAINTER B: MẶT CẮT NGANG 3 VÙNG KIỀM CHẾ, VÒM PARABOL & CẮT TÁCH CÁNH WENG
// ============================================================================
class _ConfinementInterfaceSectionPainter extends CustomPainter {
  final SrcAnalysisResult result;
  final DissectionResult dis;
  final double ultFrac;
  final int focusZone;
  final double probeYMm, probeZMm;
  final bool darkMode;
  final AppLang lang;

  const _ConfinementInterfaceSectionPainter({
    required this.result,
    required this.dis,
    required this.ultFrac,
    required this.focusZone,
    required this.probeYMm,
    required this.probeZMm,
    required this.darkMode,
    required this.lang,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = result.config;
    final g = cfg.geometry;
    final isBeam = cfg.kind == MemberKind.beam;
    final bDraw = g.sectionType == 'SRC_T_SLAB_H' ? g.bfSlabMm : g.bMm;
    final sc = math.min((size.width - 44) / math.max(100.0, bDraw), (size.height - 26) / math.max(100.0, g.hMm));
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;

    // 1. Vẽ từng thớ bê tông theo trạng thái thực tại mức tải λ (Vùng 0 / 1 / 2 + Nứt kéo + Bong vỡ!)
    final pFill = Paint()..style = PaintingStyle.fill;
    for (final pass in [0, 1, 2]) {
      for (final df in dis.fibers) {
        final f = df.cell;
        final ord = f.kind == 'concrete' ? 0 : (f.kind.startsWith('steel') ? 1 : 2);
        if (ord != pass) continue;

        final Color col;
        if (f.kind == 'concrete') {
          if (df.epsX < -0.0035 && f.zone == ConcreteZone.unconfined) {
            col = const Color(0xFF991B1B); // Vỏ bảo vệ đã bong vỡ nén!
          } else if (df.stateEn.contains('Cracked')) {
            col = const Color(0xFFF43F5E).withValues(alpha: 0.72); // Bê tông đã nứt kéo
          } else {
            col = switch (f.zone) {
              ConcreteZone.unconfined => darkMode ? const Color(0xFF475569) : const Color(0xFF94A3B8),
              ConcreteZone.partiallyConfined => const Color(0xFF0284C7).withValues(alpha: 0.55 + 0.35 * ultFrac),
              ConcreteZone.highlyConfined => Color.lerp(const Color(0xFFF59E0B), const Color(0xFFFDE047), ultFrac * 0.7)!,
            };
          }
        } else if (f.kind.startsWith('steel')) {
          final ur = (df.sigmaVmMpa / math.max(1.0, cfg.material.fySteelMpa)).clamp(0.0, 1.2);
          col = ur >= 0.98
              ? const Color(0xFFFF006E) // Thép hình đã chảy dẻo!
              : Color.lerp(const Color(0xFFEF4444), const Color(0xFFFF6B00), ur)!;
        } else {
          col = const Color(0xFF10B981);
        }

        pFill.color = col;
        final px = cx + f.zMm * sc;
        final py = cy - f.yMm * sc;
        if (f.kind == 'rebar') {
          final r = math.max(3.8, 0.54 * f.dyMm * sc);
          canvas.drawCircle(Offset(px, py), r, pFill);
          canvas.drawCircle(Offset(px, py), r, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.0);
        } else {
          canvas.drawRect(
            Rect.fromCenter(center: Offset(px, py), width: math.max(2.0, f.dzMm * sc + 0.4), height: math.max(2.0, f.dyMm * sc + 0.4)),
            pFill,
          );
        }
      }
    }

    // 2. Đường biên bê tông + Lồng cốt đai + Mũi tên kẹp cốt đai f_lp
    final borderP = Paint()
      ..color = darkMode ? Colors.white : const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (g.sectionType == 'COL_CIRC_H') {
      canvas.drawCircle(Offset(cx, cy), 0.5 * g.bMm * sc, borderP);
      canvas.drawCircle(Offset(cx, cy), math.max(8, (0.5 * g.bMm - g.coverMm) * sc),
          Paint()..color = const Color(0xFF10B981)..style = PaintingStyle.stroke..strokeWidth = 2.0);
    } else {
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: g.bMm * sc, height: g.hMm * sc), borderP);
      if (g.sectionType == 'SRC_T_SLAB_H') {
        canvas.drawRect(Rect.fromLTWH(cx - 0.5 * g.bfSlabMm * sc, cy - 0.5 * g.hMm * sc, g.bfSlabMm * sc, g.hfSlabMm * sc), borderP);
      }
      final sRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: math.max(12, (g.bMm - 2 * g.coverMm) * sc),
        height: math.max(12, (g.hMm - 2 * g.coverMm) * sc),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(sRect, const Radius.circular(4)),
        Paint()..color = const Color(0xFF10B981)..style = PaintingStyle.stroke..strokeWidth = 2.0,
      );
    }

    // 3. Vòm giam giữ parabol Chen–Lin + Mũi tên áp lực kiềm chế f_lh + Đinh neo + Nứt tách Weng
    final yCorePx = cy - g.coreOffsetYMm * sc;
    final haPx = g.haMm * sc;
    final baPx = g.baMm * sc;
    final tfPx = math.max(2.5, g.tfMm * sc);
    final twPx = math.max(2.0, g.twMm * sc);

    if (g.sectionType != 'COL_RECT_CFST') {
      final yTopIn = yCorePx - 0.5 * haPx + tfPx;
      final yBotIn = yCorePx + 0.5 * haPx - tfPx;
      final bow = math.min(0.28 * (yBotIn - yTopIn), 0.35 * (baPx - twPx));

      final archP = Paint()..color = const Color(0xFFFFF59D)..style = PaintingStyle.stroke..strokeWidth = 1.9;
      final archR = Path()
        ..moveTo(cx + 0.5 * baPx, yTopIn)
        ..quadraticBezierTo(cx + 0.5 * baPx - bow, yCorePx, cx + 0.5 * baPx, yBotIn);
      final archL = Path()
        ..moveTo(cx - 0.5 * baPx, yTopIn)
        ..quadraticBezierTo(cx - 0.5 * baPx + bow, yCorePx, cx - 0.5 * baPx, yBotIn);
      canvas.drawPath(archR, archP);
      canvas.drawPath(archL, archP);

      // Mũi tên phản lực kiềm chế f_lh ép từ 2 cánh & bụng thép H vào lõi bê tông
      final aLen = 6.0 + 7.0 * ultFrac;
      final fP = Paint()..color = const Color(0xFFFFF59D)..strokeWidth = 1.7;
      _arrow(canvas, Offset(cx + 0.5 * baPx + aLen, yCorePx), Offset(cx + 0.5 * baPx - 2, yCorePx), fP);
      _arrow(canvas, Offset(cx - 0.5 * baPx - aLen, yCorePx), Offset(cx - 0.5 * baPx + 2, yCorePx), fP);

      // Đinh neo chống cắt trên cánh trên thép H (cho Dầm SRC) + Vòng hào quang ép bê tông
      if (isBeam) {
        final stH = math.max(10.0, math.min(24.0, cfg.studHeightMm * sc));
        final yTopFl = yCorePx - 0.5 * haPx;
        final nR = cfg.studRows.clamp(1, 2);
        final zOffs = nR == 1 ? [0.0] : [-0.24 * baPx, 0.24 * baPx];
        for (final zo in zOffs) {
          final sx = cx + zo;
          canvas.drawCircle(Offset(sx, yTopFl - stH * 0.45), 6.0 + 5.0 * ultFrac,
              Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.25 + 0.25 * ultFrac));
          canvas.drawLine(Offset(sx, yTopFl), Offset(sx, yTopFl - stH), Paint()..color = const Color(0xFFFFD700)..strokeWidth = 3.0);
          canvas.drawLine(Offset(sx - 4.8, yTopFl - stH), Offset(sx + 4.8, yTopFl - stH), Paint()..color = const Color(0xFFFFD700)..strokeWidth = 3.2);
        }

        // Đường nứt tách dọc cánh thép Weng (2002) lan dần từ mép cánh ra vỏ ngoài theo mức tải
        final splitFrac = (dis.splitUr * 1.15).clamp(0.15, 1.0);
        final ySp = yCorePx + 0.5 * haPx;
        final xEdgeR = cx + 0.5 * g.bMm * sc;
        final xEdgeL = cx - 0.5 * g.bMm * sc;
        final spP = Paint()
          ..color = dis.splitUr > 0.75 ? const Color(0xFFFF2D55) : const Color(0xFFF97316)
          ..strokeWidth = 2.0;
        canvas.drawLine(Offset(cx + 0.5 * baPx, ySp), Offset(cx + 0.5 * baPx + (xEdgeR - (cx + 0.5 * baPx)) * splitFrac, ySp), spP);
        canvas.drawLine(Offset(cx - 0.5 * baPx, ySp), Offset(cx - 0.5 * baPx - ((cx - 0.5 * baPx) - xEdgeL) * splitFrac, ySp), spP);
      }
    }

    // 4. Vòng ngắm (Focus Target) tại điểm đang khảo sát (y, z)
    final pPx = Offset(cx + probeZMm * sc, cy - probeYMm * sc);
    canvas.drawCircle(pPx, 9.0, Paint()..color = const Color(0xFF06B6D4).withValues(alpha: 0.25));
    canvas.drawCircle(pPx, 5.5, Paint()..color = const Color(0xFFFFFFFF)..style = PaintingStyle.stroke..strokeWidth = 2.0);
    canvas.drawLine(pPx - const Offset(11, 0), pPx + const Offset(11, 0), Paint()..color = Colors.white..strokeWidth = 1.4);
    canvas.drawLine(pPx - const Offset(0, 11), pPx + const Offset(0, 11), Paint()..color = Colors.white..strokeWidth = 1.4);

    // Chú giải màu 3 vùng nhỏ gọn góc trái
    final leg = [
      (const Color(0xFFFDE047), tr(lang, 'Vùng 2: Lõi H (K_h)', 'Z2: H-Core')),
      (const Color(0xFF0284C7), tr(lang, 'Vùng 1: Đai (K_p)', 'Z1: Hoops')),
      (const Color(0xFF64748B), tr(lang, 'Vùng 0: Vỏ BT', 'Z0: Cover')),
      (const Color(0xFFF43F5E), tr(lang, 'Nứt / Bong vỡ', 'Crack/Spall')),
    ];
    for (int i = 0; i < leg.length; i++) {
      final y = 6.0 + i * 13.5;
      canvas.drawRect(Rect.fromLTWH(4, y + 2, 7, 7), Paint()..color = leg[i].$1);
      final tp = TextPainter(
        text: TextSpan(text: leg[i].$2, style: TextStyle(fontSize: 8.6, color: darkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155), fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(14, y));
    }
  }

  void _arrow(Canvas c, Offset a, Offset b, Paint p) {
    c.drawLine(a, b, p);
    final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
    const sz = 4.2;
    c.drawLine(b, b - Offset(sz * math.cos(ang - 0.55), sz * math.sin(ang - 0.55)), p);
    c.drawLine(b, b - Offset(sz * math.cos(ang + 0.55), sz * math.sin(ang + 0.55)), p);
  }

  @override
  bool shouldRepaint(covariant _ConfinementInterfaceSectionPainter old) => true;
}

// ============================================================================
// BIỂU ĐỒ 1: ĐƯỜNG CONG DÍNH BÁM – TRƯỢT τ_b(s) & ĐINH NEO OLLGAARD + CHẤM ĐỘNG
// ============================================================================
class _BondSlipCurvePainter extends CustomPainter {
  final SrcAnalysisResult result;
  final DissectionResult dis;
  final bool darkMode;
  final AppLang lang;

  const _BondSlipCurvePainter({required this.result, required this.dis, required this.darkMode, required this.lang});

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 36.0, padB = 22.0, padT = 12.0, padR = 10.0;
    final pw = math.max(30.0, size.width - padL - padR);
    final ph = math.max(30.0, size.height - padT - padB);
    final fg = darkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final grid = darkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + ph), Paint()..color = grid..strokeWidth = 1.2);
    canvas.drawLine(Offset(padL, padT + ph), Offset(padL + pw, padT + ph), Paint()..color = grid..strokeWidth = 1.2);

    final sMax = math.max(1.2, dis.slipMm * 1.45);
    final tauMax = math.max(dis.tauRdMpa * 2.4, dis.tauBondMpa * 1.35).clamp(0.8, 6.0);
    double xOf(double s) => padL + (s / sMax).clamp(0.0, 1.0) * pw;
    double yOf(double tau) => padT + ph - (tau / tauMax).clamp(0.0, 1.0) * ph;

    // Ngưỡng dính bám tự nhiên EC4 τ_Rd (đường ngang nét đứt)
    final yRd = yOf(dis.tauRdMpa);
    canvas.drawLine(Offset(padL, yRd), Offset(padL + pw, yRd), Paint()..color = const Color(0xFF06B6D4).withValues(alpha: 0.65)..strokeWidth = 1.1);

    // 1. Đường cong dính bám hóa học + ma sát thuần (không đinh neo — suy giảm sau đỉnh 0.05 mm)
    final bondPath = Path();
    for (int i = 0; i <= 40; i++) {
      final s = sMax * i / 40.0;
      final double tau = s <= 0.03
          ? dis.tauRdMpa * (s / 0.03)
          : dis.tauRdMpa * (0.45 + 0.55 * math.exp(-4.5 * (s - 0.03)));
      if (i == 0) {
        bondPath.moveTo(xOf(s), yOf(tau));
      } else {
        bondPath.lineTo(xOf(s), yOf(tau));
      }
    }
    canvas.drawPath(bondPath, Paint()..color = const Color(0xFF64748B)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // 2. Đường cong tổng hợp Có Đinh neo / Kiềm chế (Ollgaard: 1 − exp(−0.71 s)^0.4)
    final studPath = Path();
    final peakTot = math.max(dis.tauRdMpa * 1.9, dis.tauBondMpa * 1.15);
    for (int i = 0; i <= 40; i++) {
      final s = sMax * i / 40.0;
      final oll = math.pow(1.0 - math.exp(-3.2 * s), 0.42).toDouble();
      final tau = math.min(tauMax * 0.96, 0.35 * dis.tauRdMpa * math.min(1.0, s / 0.025) + peakTot * 0.85 * oll);
      if (i == 0) {
        studPath.moveTo(xOf(s), yOf(tau));
      } else {
        studPath.lineTo(xOf(s), yOf(tau));
      }
    }
    canvas.drawPath(studPath, Paint()..color = const Color(0xFFF59E0B)..style = PaintingStyle.stroke..strokeWidth = 2.1);

    // Chấm động vị trí làm việc hiện tại (s_slip, τ_b)
    final dot = Offset(xOf(dis.slipMm), yOf(dis.tauBondMpa));
    canvas.drawCircle(dot, 7.5, Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.28));
    canvas.drawCircle(dot, 4.2, Paint()..color = const Color(0xFFEF4444));
    canvas.drawCircle(dot, 4.2, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.1);

    _txt(canvas, Offset(padL + 3, yRd - 11), 'τ_Rd=${dis.tauRdMpa.toStringAsFixed(2)}', const Color(0xFF06B6D4), 8.2);
    _txt(canvas, Offset(padL + pw * 0.48, padT), 's=${dis.slipMm.toStringAsFixed(3)} mm', const Color(0xFFEF4444), 8.5);
    _txt(canvas, Offset(2, padT), 'τ(MPa)', fg, 8.2);
    _txt(canvas, Offset(padL + pw * 0.42, padT + ph + 5), tr(lang, 'Trượt s (mm)', 'Slip s (mm)'), fg, 8.2);
  }

  void _txt(Canvas c, Offset p, String s, Color col, double fs) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, p);
  }

  @override
  bool shouldRepaint(covariant _BondSlipCurvePainter old) => true;
}

// ============================================================================
// BIỂU ĐỒ 2: ĐƯỜNG CONG σ_c – ε_c CỦA 3 VÙNG KIỀM CHẾ + 3 CHẤM ĐỘNG!
// ============================================================================
class _ThreeZoneConstitutivePainter extends CustomPainter {
  final SrcAnalysisResult result;
  final DissectionResult dis;
  final bool darkMode;
  final AppLang lang;

  const _ThreeZoneConstitutivePainter({required this.result, required this.dis, required this.darkMode, required this.lang});

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 36.0, padB = 22.0, padT = 12.0, padR = 10.0;
    final pw = math.max(30.0, size.width - padL - padR);
    final ph = math.max(30.0, size.height - padT - padB);
    final fg = darkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final grid = darkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final m = result.config.material;
    final conf = result.conf;

    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + ph), Paint()..color = grid..strokeWidth = 1.2);
    canvas.drawLine(Offset(padL, padT + ph), Offset(padL + pw, padT + ph), Paint()..color = grid..strokeWidth = 1.2);

    const epsMax = 0.008; // 8 ‰ để thấy rõ vỏ bảo vệ sụp sau 3.5‰ trong khi lõi H vẫn dẻo!
    final sigMax = math.max(20.0, 0.85 * conf.etaHsc * m.fcMpa * conf.kh * 1.15);
    double xOf(double ePos) => padL + (ePos / epsMax).clamp(0.0, 1.0) * pw;
    double yOf(double sPos) => padT + ph - (sPos / sigMax).clamp(0.0, 1.0) * ph;

    final zones = [
      (ConcreteZone.unconfined, const Color(0xFF94A3B8), tr(lang, 'Vỏ', 'Cov')),
      (ConcreteZone.partiallyConfined, const Color(0xFF38BDF8), 'K_p'),
      (ConcreteZone.highlyConfined, const Color(0xFFFDE047), 'K_h'),
    ];

    final curEps = (-dis.epsMin).clamp(0.0, epsMax);
    // Đường đứng tại biến dạng nén thực hiện tại
    final xCur = xOf(curEps);
    canvas.drawLine(Offset(xCur, padT), Offset(xCur, padT + ph), Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.45)..strokeWidth = 1.2);

    for (final (z, col, _) in zones) {
      final path = Path();
      for (int i = 0; i <= 40; i++) {
        final e = epsMax * i / 40.0;
        final r = SrcNonlinearEngine.concreteLaw(-e, m, z, conf, true);
        final pt = Offset(xOf(e), yOf(-r.sig));
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = z == ConcreteZone.highlyConfined ? 2.2 : 1.6);

      // Chấm động tại đúng biến dạng nén thực curEps trên từng đường cong!
      final rc = SrcNonlinearEngine.concreteLaw(-curEps, m, z, conf, true);
      final dp = Offset(xCur, yOf(-rc.sig));
      canvas.drawCircle(dp, 3.8, Paint()..color = col);
      canvas.drawCircle(dp, 3.8, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }

    _txt(canvas, Offset(2, padT), 'σ_c', fg, 8.2);
    _txt(canvas, Offset(padL + pw * 0.35, padT + ph + 5), 'ε_c = ${(curEps * 1000).toStringAsFixed(2)} ‰', const Color(0xFFEF4444), 8.3);
    _txt(canvas, Offset(padL + 4, padT), 'K_h=${conf.kh.toStringAsFixed(2)}', const Color(0xFFFDE047), 8.2);
    _txt(canvas, Offset(padL + 58, padT), 'K_p=${conf.kp.toStringAsFixed(2)}', const Color(0xFF38BDF8), 8.2);
    _txt(canvas, Offset(padL + 112, padT), tr(lang, 'Vỏ', 'Cov'), const Color(0xFF94A3B8), 8.2);
  }

  void _txt(Canvas c, Offset p, String s, Color col, double fs) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, p);
  }

  @override
  bool shouldRepaint(covariant _ThreeZoneConstitutivePainter old) => true;
}

// ============================================================================
// BIỂU ĐỒ 3: CHUYỂN DỊCH CHIA TẢI THÉP HÌNH ↔ BÊ TÔNG THEO MỨC TẢI (0% → 100%)
// ============================================================================
class _LoadRedistributionPainter extends CustomPainter {
  final List<LoadRedistPoint> curve;
  final double ultFrac;
  final bool darkMode;
  final AppLang lang;

  const _LoadRedistributionPainter({required this.curve, required this.ultFrac, required this.darkMode, required this.lang});

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 32.0, padB = 22.0, padT = 14.0, padR = 10.0;
    final pw = math.max(30.0, size.width - padL - padR);
    final ph = math.max(30.0, size.height - padT - padB);
    final fg = darkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    if (curve.length < 2) return;

    double xOf(double uf) => padL + uf.clamp(0.0, 1.0) * pw;
    double yOf(double pct) => padT + ph - (pct / 100.0).clamp(0.0, 1.0) * ph;

    // 1. Dải xếp chồng: Dưới cùng = Thép hình H (Đỏ), Giữa = Bê tông (Xanh dương), Trên cùng = Cốt thép (Xanh lá)
    final pSteel = Path()..moveTo(xOf(curve.first.ultFrac), yOf(0));
    for (final pt in curve) {
      pSteel.lineTo(xOf(pt.ultFrac), yOf(pt.steelPct));
    }
    pSteel.lineTo(xOf(curve.last.ultFrac), yOf(0));
    pSteel.close();
    canvas.drawPath(pSteel, Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.42));

    final pConc = Path();
    for (int i = 0; i < curve.length; i++) {
      final pt = curve[i];
      if (i == 0) {
        pConc.moveTo(xOf(pt.ultFrac), yOf(pt.steelPct + pt.concretePct));
      } else {
        pConc.lineTo(xOf(pt.ultFrac), yOf(pt.steelPct + pt.concretePct));
      }
    }
    for (int i = curve.length - 1; i >= 0; i--) {
      final pt = curve[i];
      pConc.lineTo(xOf(pt.ultFrac), yOf(pt.steelPct));
    }
    pConc.close();
    canvas.drawPath(pConc, Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.36));

    final pReb = Path();
    for (int i = 0; i < curve.length; i++) {
      final pt = curve[i];
      if (i == 0) {
        pReb.moveTo(xOf(pt.ultFrac), yOf(100));
      } else {
        pReb.lineTo(xOf(pt.ultFrac), yOf(100));
      }
    }
    for (int i = curve.length - 1; i >= 0; i--) {
      final pt = curve[i];
      pReb.lineTo(xOf(pt.ultFrac), yOf(pt.steelPct + pt.concretePct));
    }
    pReb.close();
    canvas.drawPath(pReb, Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.38));

    // Đường biên sắc nét giữa Thép hình H và Bê tông
    final bLine = Path();
    for (int i = 0; i < curve.length; i++) {
      final pt = curve[i];
      if (i == 0) {
        bLine.moveTo(xOf(pt.ultFrac), yOf(pt.steelPct));
      } else {
        bLine.lineTo(xOf(pt.ultFrac), yOf(pt.steelPct));
      }
    }
    canvas.drawPath(bLine, Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.stroke..strokeWidth = 1.9);

    // Đường con trỏ mức tải hiện tại λ
    final xc = xOf(ultFrac);
    canvas.drawLine(Offset(xc, padT), Offset(xc, padT + ph), Paint()..color = const Color(0xFFFFD700)..strokeWidth = 2.0);

    _txt(canvas, Offset(2, padT), '100%', fg, 7.8);
    _txt(canvas, Offset(6, padT + ph - 8), '0%', fg, 7.8);
    _txt(canvas, Offset(padL + 4, padT + 1), tr(lang, 'Đỏ: Thép H | Xanh: BT | Lá: Thép thanh', 'Red: H-Steel | Blue: RC | Grn: Rebar'), fg, 7.9);
    _txt(canvas, Offset(padL + pw * 0.25, padT + ph + 5), '${tr(lang, "Mức tải λ", "Load λ")}: ${(ultFrac * 100).toStringAsFixed(0)}%', const Color(0xFFF59E0B), 8.2);
  }

  void _txt(Canvas c, Offset p, String s, Color col, double fs) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, p);
  }

  @override
  bool shouldRepaint(covariant _LoadRedistributionPainter old) => true;
}
