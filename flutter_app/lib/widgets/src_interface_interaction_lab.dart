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
  double _magFactor = 25.0; // Hệ số khuếch đại biến dạng / trượt / nứt [1..100]
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
                            style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Colors.white),
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
                  Text(tr(l, 'Vị trí cắt:', 'Cut x/L:'), style: TextStyle(fontSize: 12.0, color: sub, fontWeight: FontWeight.bold)),
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
              // Thanh trượt Mức tải + Thanh trượt Hệ số khuếch đại biến dạng / trượt
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: wide ? 420 : double.infinity,
                    child: Row(
                      children: [
                        Text(
                          '${tr(l, "Mức tải", "Load")}: ${(_ultFrac * 100).toStringAsFixed(0)}% (${(res.ultimateLoadKn * _ultFrac).toStringAsFixed(0)} kN)',
                          style: TextStyle(fontSize: 12.0, fontFamily: 'DejaVuSansMono', fontWeight: FontWeight.bold, color: stageColor),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
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
                  ),
                  SizedBox(
                    width: wide ? 440 : double.infinity,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.zoom_out_map, size: 14, color: Color(0xFFA855F7)),
                            const SizedBox(width: 4),
                            Text(
                              '${tr(l, "Khuếch đại", "Mag")}: ×${_magFactor.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12.0, fontFamily: 'DejaVuSansMono', fontWeight: FontWeight.bold, color: Color(0xFFA855F7)),
                            ),
                            SizedBox(
                              width: wide ? 150 : 128,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
                                ),
                                child: Slider(
                                  value: _magFactor,
                                  min: 1.0,
                                  max: 100.0,
                                  activeColor: const Color(0xFFA855F7),
                                  inactiveColor: border,
                                  onChanged: (v) => setState(() => _magFactor = v),
                                ),
                              ),
                            ),
                          ],
                        ),
                        for (final mv in [1.0, 25.0, 60.0, 100.0])
                          _pillBtn(
                            '×${mv.toInt()}',
                            (_magFactor - mv).abs() < 4.0,
                            const Color(0xFFA855F7),
                            fg,
                            border,
                            () => setState(() => _magFactor = mv),
                          ),
                      ],
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
                        style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: stageColor),
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
                      style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: wide ? 315 : 290,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _MicroInterfaceCutawayPainter(
                    result: res,
                    dis: dis,
                    ultFrac: _ultFrac,
                    magFactor: _magFactor,
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
                      style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: fg),
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
                height: wide ? 245 : 235,
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
                          magFactor: _magFactor,
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
                            style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ε_a = ${(steelProbe.epsX * 1000).toStringAsFixed(2)} ‰  |  σ_a = ${steelProbe.sigmaXMpa.toStringAsFixed(1)} MPa',
                            style: TextStyle(fontSize: 12.0, fontFamily: 'DejaVuSansMono', color: fg, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'σ_vM = ${steelProbe.sigmaVmMpa.toStringAsFixed(1)} MPa (${(steelProbe.utilRatio * 100).toStringAsFixed(0)}% f_y)',
                            style: TextStyle(fontSize: 12.0, color: sub),
                          ),
                          Text(
                            l.isVi ? steelProbe.stateVi : steelProbe.stateEn,
                            style: TextStyle(fontSize: 12.0, color: const Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 68, color: border, margin: const EdgeInsets.symmetric(horizontal: 8)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(l, 'PHÍA BÊ TÔNG KỀ SÁT', 'ADJACENT CONCRETE'),
                            style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ε_c = ${(concProbe.epsX * 1000).toStringAsFixed(2)} ‰  |  σ_c = ${concProbe.sigmaXMpa.toStringAsFixed(1)} MPa',
                            style: TextStyle(fontSize: 12.0, fontFamily: 'DejaVuSansMono', color: fg, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            l.isVi ? concProbe.zoneVi : concProbe.zoneEn,
                            style: TextStyle(fontSize: 12.0, color: sub),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            l.isVi ? concProbe.stateVi : concProbe.stateEn,
                            style: TextStyle(fontSize: 12.0, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
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
                  height: 235,
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
                SizedBox(height: 225, child: chart1),
                const SizedBox(height: 8),
                SizedBox(height: 225, child: chart2),
                const SizedBox(height: 8),
                SizedBox(height: 225, child: chart3),
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
          style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: active ? accent : fg.withValues(alpha: 0.78)),
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
          style: TextStyle(fontSize: 12.0, fontFamily: 'DejaVuSansMono', color: dark ? Colors.white : const Color(0xFF0F172A)),
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
                child: Text(title, style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: fg), overflow: TextOverflow.ellipsis),
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
  final double magFactor;
  final int stageIdx;
  final bool darkMode;
  final AppLang lang;

  const _MicroInterfaceCutawayPainter({
    required this.result,
    required this.dis,
    required this.ultFrac,
    required this.magFactor,
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

    // Nhãn hệ số khuếch đại góc trên phải (phục vụ chụp ảnh báo cáo NCKH)
    final magTxt = '${tr(lang, "Khuếch đại", "Scale")} ×${magFactor.toStringAsFixed(0)}';
    final tp = TextPainter(
      text: TextSpan(text: magTxt, style: const TextStyle(color: Color(0xFFD8B4FE), fontSize: 12.0, fontWeight: FontWeight.bold, fontFamily: 'DejaVuSansMono')),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - tp.width - 14, 4, tp.width + 10, tp.height + 5),
      const Radius.circular(5),
    );
    canvas.drawRRect(box, Paint()..color = const Color(0xFF581C87).withValues(alpha: 0.72));
    tp.paint(canvas, Offset(size.width - tp.width - 9, 6.5));
  }

  void _paintBeamMicroInterface(Canvas canvas, Size size, Color fg) {
    final w = size.width;
    final h = size.height;
    const padX = 24.0;
    final x0 = padX, x1 = w - padX;
    final spanW = x1 - x0;

    // Hệ số khuếch đại mượt từ ×1 (gần tỷ lệ thực) → ×100 (phóng đại cực rõ cơ chế trượt, uốn, nứt!)
    final magGain = (magFactor / 25.0).clamp(0.04, 4.0);
    final magNorm = ((magFactor - 1.0) / 99.0).clamp(0.0, 1.0);

    // Bố trí cao độ hình học phóng đại:
    final ySlabTop = h * 0.13;
    final yFlTop = h * 0.43; // Mặt tiếp xúc cánh trên thép H ↔ Bê tông (nơi có Đinh neo!)
    final tfH = h * 0.062;
    final yFlBot = h * 0.71; // Cánh dưới thép H
    final yConcBot = h * 0.87;

    // Độ võng uốn cong của phân đoạn dầm theo khuếch đại (parabol nhẹ giữa đoạn)
    final arcSag = (ultFrac * 7.5 * magGain).clamp(0.0, 17.0);
    double sagAt(double x) {
      final u = ((x - x0) / math.max(1.0, spanW) - 0.5) * 2.0; // -1..1
      return arcSag * (1.0 - u * u);
    }

    // Độ trượt phóng đại thị giác Δs (ở ×1 ~ 0.3px, ×25 ~ 10px, ×100 ~ 32px!)
    final baseSlip = dis.slipMm * 18.0 + (stageIdx >= 2 ? (ultFrac - 0.20) * 10.5 : ultFrac * 2.5);
    final slipVisual = (baseSlip * magGain).clamp(0.0, 32.0);
    final bondBroken = dis.tauBondMpa > 0.30 || stageIdx >= 2;
    final steelYielding = stageIdx >= 3;

    // Helper vẽ dải cong theo độ võng sagAt(x)
    Path curvedBand(double lx0, double lx1, double yt, double yb) {
      final p = Path();
      const n = 16;
      for (int i = 0; i <= n; i++) {
        final x = lx0 + (lx1 - lx0) * i / n;
        final dy = sagAt(x);
        if (i == 0) {
          p.moveTo(x, yt + dy);
        } else {
          p.lineTo(x, yt + dy);
        }
      }
      for (int i = n; i >= 0; i--) {
        final x = lx0 + (lx1 - lx0) * i / n;
        final dy = sagAt(x);
        p.lineTo(x, yb + dy);
      }
      p.close();
      return p;
    }

    // Bản sàn bê tông phía trên trượt tương đối sang trái (-0.45*slipVisual), thép H trượt sang phải (+0.55*slipVisual)
    final cTopX0 = x0 - slipVisual * 0.45;
    final cTopX1 = x1 - slipVisual * 0.45;
    final stX0 = x0 + slipVisual * 0.55;
    final stX1 = x1 + slipVisual * 0.55;

    // 1. Vùng bê tông bao quanh (bản sàn trên + sườn bê tông giữa + lớp bảo vệ dưới)
    final concTopColor = Color.lerp(
      darkMode ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
      const Color(0xFF0284C7),
      (ultFrac * 0.58).clamp(0.0, 0.58),
    )!;
    canvas.drawPath(curvedBand(cTopX0, cTopX1, ySlabTop, yFlTop), Paint()..color = concTopColor.withValues(alpha: 0.74));
    canvas.drawPath(curvedBand(x0, x1, yFlTop, yConcBot),
        Paint()..color = (darkMode ? const Color(0xFF17253B) : const Color(0xFFE2E8F0)).withValues(alpha: 0.65));

    // Vùng bê tông kiềm chế mạnh trong khoang giữa 2 cánh thép H (vàng ấm)
    canvas.drawPath(
      curvedBand(stX0 + 4, stX1 - 4, yFlTop + tfH, yFlBot),
      Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.12 + 0.18 * ultFrac),
    );

    // 2. Cốt đai đứng & Cốt thép dọc trên/dưới
    final stirCol = Color.lerp(const Color(0xFF10B981), const Color(0xFF34D399), ultFrac)!;
    final stirP = Paint()..color = stirCol..strokeWidth = 1.9;
    for (int i = 0; i < 6; i++) {
      final xs = x0 + spanW * (0.08 + i * 0.168);
      final dy = sagAt(xs);
      canvas.drawLine(Offset(xs - slipVisual * 0.25, ySlabTop + 9 + dy), Offset(xs, yConcBot - 9 + dy), stirP);
    }
    final rbP = Paint()..color = const Color(0xFF10B981)..style = PaintingStyle.stroke..strokeWidth = 3.0;
    final pRbTop = Path();
    final pRbBot = Path();
    for (int i = 0; i <= 16; i++) {
      final xt = cTopX0 + (cTopX1 - cTopX0) * i / 16;
      final xb = x0 + spanW * i / 16;
      if (i == 0) {
        pRbTop.moveTo(xt, ySlabTop + 9 + sagAt(xt));
        pRbBot.moveTo(xb, yConcBot - 9 + sagAt(xb));
      } else {
        pRbTop.lineTo(xt, ySlabTop + 9 + sagAt(xt));
        pRbBot.lineTo(xb, yConcBot - 9 + sagAt(xb));
      }
    }
    canvas.drawPath(pRbTop, rbP);
    canvas.drawPath(pRbBot, rbP);

    // 3. LÕI THÉP HÌNH H (bản bụng + bản cánh trên/dưới uốn cong & trượt tương đối sang phải!)
    final webCol = steelYielding ? const Color(0xFFDC2626) : const Color(0xFFEF4444);
    canvas.drawPath(curvedBand(stX0, stX1, yFlTop + tfH, yFlBot), Paint()..color = webCol.withValues(alpha: 0.32));
    canvas.drawPath(curvedBand(stX0, stX1, yFlTop, yFlTop + tfH), Paint()..color = const Color(0xFFEF4444));
    canvas.drawPath(
      curvedBand(stX0, stX1, yFlBot, yFlBot + tfH),
      Paint()..color = steelYielding ? const Color(0xFFFF006E) : const Color(0xFFEF4444),
    );

    // 3b. Đường thẳng đứng gốc (Trước khi trượt) ở mép trái để NHÌN THẤY NGAY BẬC TRƯỢT Δs!
    if (slipVisual > 2.0) {
      final refX = x0 + spanW * 0.04;
      _drawDashed(
        canvas,
        Offset(refX, ySlabTop),
        Offset(refX, yConcBot),
        Paint()..color = Colors.white.withValues(alpha: 0.55)..strokeWidth = 1.1,
      );
      // Vạch đánh dấu mép trượt của sàn BT (trái) và cánh thép H (phải)
      final yMark = yFlTop - 1.5 + sagAt(refX);
      canvas.drawLine(
        Offset(refX - slipVisual * 0.45, yMark - 7),
        Offset(refX + slipVisual * 0.55, yMark - 7),
        Paint()..color = const Color(0xFFD8B4FE)..strokeWidth = 2.0,
      );
    }

    // 4. LÒ XO DÍNH BÁM VI MÔ (Kéo xiên theo Δs ở GĐ1 → Đứt gãy tạo khe hở khi trượt!)
    for (int k = 0; k < 16; k++) {
      final bxTop = cTopX0 + (cTopX1 - cTopX0) * (0.05 + k * 0.06);
      final bxBot = stX0 + (stX1 - stX0) * (0.05 + k * 0.06);
      final dy = sagAt(bxBot);
      final bp = Paint()
        ..color = bondBroken ? const Color(0xFFFF4D4F).withValues(alpha: 0.72) : const Color(0xFF10B981)
        ..strokeWidth = 1.45;
      if (!bondBroken) {
        final p = Path()
          ..moveTo(bxBot, yFlTop + dy)
          ..lineTo((bxBot + bxTop) * 0.5 - 2.2, yFlTop - 3.5 + dy)
          ..lineTo((bxBot + bxTop) * 0.5 + 2.2, yFlTop - 7.0 + dy)
          ..lineTo(bxTop, yFlTop - 10.0 + dy);
        canvas.drawPath(p, bp..style = PaintingStyle.stroke);
      } else if (k % 2 == 0) {
        // Khe trượt đỏ dọc bề mặt tiếp xúc
        canvas.drawLine(Offset(bxTop - 2, yFlTop - 3 + dy), Offset(bxBot + 2, yFlTop - 1 + dy), bp);
      }
    }

    // 5. 3 ĐINH NEO CHỐNG CẮT PHÓNG ĐẠI (Biến dạng chữ S phóng đại theo magFactor + Nêm ép + Thanh chống 45°!)
    final studH = (yFlTop - ySlabTop) * 0.68;
    for (int s = 0; s < 3; s++) {
      final sxBase = stX0 + spanW * (0.20 + s * 0.29);
      final dy = sagAt(sxBase);
      final yBase = yFlTop + dy;
      final bend = (slipVisual * 0.78).clamp(0.0, 22.0);
      final sxHead = sxBase - bend; // Đầu đinh uốn cắt chữ S cực rõ khi tăng khuếch đại!

      // 5a. Nêm ép cục bộ bê tông (Concrete Bearing Cone σ_bear) phồng lớn theo khuếch đại
      if (ultFrac > 0.10) {
        final coneW = (12.0 + 18.0 * ultFrac) * (0.65 + 0.75 * magNorm);
        final coneH = studH * (0.58 + 0.25 * magNorm);
        final conePath = Path()
          ..moveTo(sxBase - 3, yBase)
          ..lineTo(sxBase - 3 - coneW, yBase - coneH)
          ..lineTo(sxBase - 3 - coneW * 0.42, yBase - coneH * 1.15)
          ..lineTo(sxBase - 2, yBase - studH * 0.55)
          ..close();
        canvas.drawPath(
          conePath,
          Paint()..color = Color.lerp(const Color(0xFFFBBF24), const Color(0xFFFF3B30), ultFrac)!.withValues(alpha: 0.42 + 0.35 * ultFrac),
        );

        // 5b. Thanh chống nén chéo bê tông ~45° (Diagonal Concrete Compression Strut)
        final strutLen = 28.0 + 18.0 * ultFrac + 14.0 * magNorm;
        final strutP = Paint()
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.50 + 0.40 * ultFrac)
          ..strokeWidth = 1.8 + 1.2 * magNorm;
        _drawArrow(
          canvas,
          Offset(sxBase - 4, yBase - 6),
          Offset(sxBase - strutLen, math.max(ySlabTop + 10 + dy, yBase - strutLen * 0.85)),
          strutP,
        );
      }

      // 5c. Thân đinh neo biến dạng cắt chữ S + Mối hàn chân đinh + Mũ T nghiêng theo góc trượt!
      final studPath = Path()
        ..moveTo(sxBase, yBase)
        ..cubicTo(
          sxBase, yBase - studH * 0.42,
          sxHead, yBase - studH * 0.58,
          sxHead, yBase - studH,
        );
      final studCol = Color.lerp(const Color(0xFFFDE047), const Color(0xFFFF5722), dis.studUr.clamp(0.0, 1.0))!;
      canvas.drawPath(studPath, Paint()..color = studCol..style = PaintingStyle.stroke..strokeWidth = 4.6..strokeCap = StrokeCap.round);
      final tilt = (bend * 0.14).clamp(0.0, 3.5);
      canvas.drawLine(
        Offset(sxHead - 8, yBase - studH - tilt),
        Offset(sxHead + 8, yBase - studH + tilt),
        Paint()..color = studCol..strokeWidth = 4.2..strokeCap = StrokeCap.square,
      );
      canvas.drawCircle(Offset(sxBase, yBase), 3.6, Paint()..color = const Color(0xFFFFFFFF));
    }

    // 6. VẾT NỨT KÉO BÊ TÔNG DƯỚI MỞ RỘNG THÀNH KHE CHỮ V THEO HỆ SỐ KHUẾCH ĐẠI (bị thép H hãm lại!)
    if (stageIdx >= 2) {
      final nCr = stageIdx == 2 ? 4 : (stageIdx == 3 ? 6 : 8);
      final crackHalfW = (0.7 + 2.8 * ultFrac * magGain).clamp(0.6, 5.2);
      for (int c = 0; c < nCr; c++) {
        final cx = x0 + spanW * (0.11 + c * (0.78 / math.max(1, nCr - 1)));
        final dy = sagAt(cx);
        final yBot = yConcBot + dy;
        final reach = (yConcBot - (yFlBot + tfH)) * (0.60 + 0.42 * ultFrac);
        final yTip = math.max(yFlBot + tfH + dy, yBot - reach);
        // Vẽ khe nứt hình chữ V mở rộng thực thụ (đỏ thẫm bên trong + viền sáng)
        final vCrack = Path()
          ..moveTo(cx - crackHalfW, yBot)
          ..lineTo(cx - crackHalfW * 0.45 + 1.5, yBot - (yBot - yTip) * 0.5)
          ..lineTo(cx, yTip)
          ..lineTo(cx + crackHalfW * 0.45 + 1.5, yBot - (yBot - yTip) * 0.5)
          ..lineTo(cx + crackHalfW, yBot)
          ..close();
        canvas.drawPath(vCrack, Paint()..color = const Color(0xFF4C0519));
        canvas.drawPath(vCrack, Paint()..color = const Color(0xFFFF2D55)..style = PaintingStyle.stroke..strokeWidth = 1.3);
      }
    }

    // 7. MŨI TÊN CHUYỂN VỊ TRƯỢT TƯƠNG ĐỐI NGƯỢC CHIỀU (tăng chiều dài theo magFactor)
    final arrSpan = (spanW * (0.18 + 0.14 * magNorm)).clamp(30.0, spanW * 0.34);
    final midX = x0 + spanW * 0.5;
    final dyMid = sagAt(midX);
    _drawArrow(canvas, Offset(midX + arrSpan * 0.5, yFlTop - 13 + dyMid), Offset(midX - arrSpan * 0.5, yFlTop - 13 + dyMid),
        Paint()..color = const Color(0xFF38BDF8)..strokeWidth = 2.2);
    _drawArrow(canvas, Offset(midX - arrSpan * 0.5, yFlTop + tfH * 0.5 + dyMid), Offset(midX + arrSpan * 0.5, yFlTop + tfH * 0.5 + dyMid),
        Paint()..color = const Color(0xFFFFD700)..strokeWidth = 2.2);

    // 8. CHÚ THÍCH TRỰC QUAN
    _drawTag(canvas, Offset(x0 + 2, 5),
        tr(lang, '← Bê tông nén & Thanh chống 45°', '← Concrete & 45° Strut'),
        const Color(0xFF38BDF8));
    _drawTag(canvas, Offset(x0 + 6, yFlTop + tfH + 5 + dyMid),
        '${tr(lang, "Trượt thực", "True slip")} Δs=${dis.slipMm.toStringAsFixed(3)} mm  |  F_stud=${dis.studForceKn.toStringAsFixed(1)} kN →',
        const Color(0xFFFDE047));
    _drawTag(canvas, Offset(x0 + 4, h - 14),
        stageIdx >= 2
            ? tr(lang, 'Vết nứt kéo chữ V bị cánh dưới thép H & cốt thép hãm lại', 'V-shaped flexural cracks arrested by steel flange & rebar')
            : tr(lang, 'Bê tông vùng kéo chưa nứt — Dính bám đàn hồi ε_a = ε_c', 'Uncracked tension zone — Elastic bond ε_a = ε_c'),
        stageIdx >= 2 ? const Color(0xFFFF4D6D) : const Color(0xFF10B981));
  }

  void _paintColumnMicroInterface(Canvas canvas, Size size, Color fg) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final colW = math.min(w * 0.66, 290.0);
    final xL = cx - 0.5 * colW;
    final xR = cx + 0.5 * colW;
    final yT0 = h * 0.13;
    final yB0 = h * 0.86;

    // Khuếch đại nén co ngắn dọc trục (ΔL) + phình ngang Poisson (bulge) theo magFactor!
    final magGain = (magFactor / 25.0).clamp(0.04, 4.0);
    final magNorm = ((magFactor - 1.0) / 99.0).clamp(0.0, 1.0);
    final shortenPx = (ultFrac * 7.5 * magGain).clamp(0.0, 20.0);
    final bulgePx = (ultFrac * 5.2 * magGain).clamp(0.0, 18.0);
    final yT = yT0 + shortenPx * 0.65;
    final yB = yB0 - shortenPx * 0.35;

    final coverW = colW * 0.12;
    final stW = colW * 0.44;
    final stXL = cx - 0.5 * stW;
    final stXR = cx + 0.5 * stW;
    final flW = math.max(9.0, stW * 0.12);
    final spalling = stageIdx == 4 || dis.epsMin < -0.0032;

    // Khung nét đứt hình dáng ban đầu trước khi nén (giúp thấy rõ sự co ngắn dọc trục & phình ngang!)
    if (shortenPx > 1.5 || bulgePx > 1.5) {
      _drawDashed(canvas, Offset(xL, yT0), Offset(xR, yT0), Paint()..color = Colors.white.withValues(alpha: 0.42)..strokeWidth = 1.0);
      _drawDashed(canvas, Offset(xL, yT0), Offset(xL, yB0), Paint()..color = Colors.white.withValues(alpha: 0.30)..strokeWidth = 1.0);
      _drawDashed(canvas, Offset(xR, yT0), Offset(xR, yB0), Paint()..color = Colors.white.withValues(alpha: 0.30)..strokeWidth = 1.0);
    }

    // Tạo đường biên phình ngang dạng đốt tre (Scalloped Poisson Bulging giữa các lớp cốt đai!)
    const nStir = 6;
    final stirYs = [for (int i = 0; i < nStir; i++) yT + (yB - yT) * (0.08 + i * 0.168)];
    double bulgeAtY(double y) {
      // Phình lớn nhất ở giữa 2 cốt đai, bị thắt lại ngay tại vị trí cốt đai!
      double minDist = 1e9;
      for (final sy in stirYs) {
        minDist = math.min(minDist, (y - sy).abs());
      }
      final halfGap = (yB - yT) * 0.084;
      final localScallop = (minDist / math.max(1.0, halfGap)).clamp(0.0, 1.0);
      final globalBarrel = math.sin(((y - yT) / math.max(1.0, yB - yT)).clamp(0.0, 1.0) * math.pi);
      return bulgePx * (0.35 * globalBarrel + 0.65 * localScallop * (0.5 + 0.5 * globalBarrel));
    }

    Path bulgedOuterPath(double baseXL, double baseXR, double bScale) {
      final p = Path();
      const n = 32;
      for (int i = 0; i <= n; i++) {
        final y = yT + (yB - yT) * i / n;
        final b = bulgeAtY(y) * bScale;
        if (i == 0) {
          p.moveTo(baseXL - b, y);
        } else {
          p.lineTo(baseXL - b, y);
        }
      }
      for (int i = n; i >= 0; i--) {
        final y = yT + (yB - yT) * i / n;
        final b = bulgeAtY(y) * bScale;
        p.lineTo(baseXR + b, y);
      }
      p.close();
      return p;
    }

    // 1. Vỏ bảo vệ bê tông ngoài cùng (phình mạnh nhất theo bulgePx — bong tách ở GĐ4!)
    final covCol = spalling ? const Color(0xFFEF4444).withValues(alpha: 0.34) : (darkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1));
    canvas.drawPath(bulgedOuterPath(xL, xR, 1.0), Paint()..color = covCol);

    // 2. Vùng 1 — Kiềm chế một phần trong cốt đai (phình ít hơn nhờ đai kẹp)
    canvas.drawPath(
      bulgedOuterPath(xL + coverW, xR - coverW, 0.42),
      Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.24 + 0.16 * ultFrac),
    );

    // 3. Vùng 2 — Kiềm chế mạnh kẹp trong khoang thép hình H (hầu như không phình, vàng kim rực!)
    canvas.drawRect(
      Rect.fromLTRB(stXL + flW, yT, stXR - flW, yB),
      Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.26 + 0.40 * ultFrac),
    );

    // 4. Lõi thép hình H (2 cánh đứng cực cứng + bản bụng tâm)
    final steelCol = stageIdx >= 3 ? const Color(0xFFFF1744) : const Color(0xFFEF4444);
    canvas.drawRect(Rect.fromLTRB(stXL, yT, stXL + flW, yB), Paint()..color = steelCol);
    canvas.drawRect(Rect.fromLTRB(stXR - flW, yT, stXR, yB), Paint()..color = steelCol);
    canvas.drawLine(Offset(cx, yT), Offset(cx, yB), Paint()..color = steelCol.withValues(alpha: 0.65)..strokeWidth = 3.5);

    // 5. Cốt thép dọc (hơi cong nhẹ giữa 2 đai theo biến dạng) & Cốt đai ngang bó chặt
    final rbP = Paint()..color = const Color(0xFF10B981)..style = PaintingStyle.stroke..strokeWidth = 2.6;
    final pRbL = Path(), pRbR = Path();
    for (int i = 0; i <= 24; i++) {
      final y = yT + (yB - yT) * i / 24;
      final b = bulgeAtY(y) * 0.35;
      if (i == 0) {
        pRbL.moveTo(xL + coverW - b, y);
        pRbR.moveTo(xR - coverW + b, y);
      } else {
        pRbL.lineTo(xL + coverW - b, y);
        pRbR.lineTo(xR - coverW + b, y);
      }
    }
    canvas.drawPath(pRbL, rbP);
    canvas.drawPath(pRbR, rbP);
    for (final ys in stirYs) {
      canvas.drawLine(Offset(xL + coverW, ys), Offset(xR - coverW, ys), Paint()..color = const Color(0xFF10B981)..strokeWidth = 2.2);
    }

    // 6. Mũi tên tải nén dọc trục N + Ma sát truyền lực dọc τ_b hai bên cánh thép
    for (final ax in [xL + coverW * 1.5, cx, xR - coverW * 1.5]) {
      _drawArrow(canvas, Offset(ax, 6), Offset(ax, yT - 2), Paint()..color = const Color(0xFF38BDF8)..strokeWidth = 2.2);
    }
    for (int j = 0; j < 3; j++) {
      final yy = yT + (yB - yT) * (0.20 + j * 0.28);
      final fLen = 8.0 + 7.0 * magNorm;
      _drawArrow(canvas, Offset(stXL - 5, yy - fLen), Offset(stXL - 5, yy + fLen), Paint()..color = const Color(0xFFF59E0B)..strokeWidth = 1.8);
      _drawArrow(canvas, Offset(stXR + 5, yy - fLen), Offset(stXR + 5, yy + fLen), Paint()..color = const Color(0xFFF59E0B)..strokeWidth = 1.8);
    }

    // 7. Mũi tên Phản lực Kiềm chế 3 trục f_l,h (vàng) & Kẹp cốt đai f_l,p (xanh) phóng đại theo magFactor!
    final confLen = (9.0 + 12.0 * ultFrac) * (0.7 + 0.65 * magNorm);
    for (int r = 0; r < 3; r++) {
      final yy = yT + (yB - yT) * (0.25 + r * 0.25);
      _drawArrow(canvas, Offset(stXL + flW, yy), Offset(stXL + flW + confLen, yy), Paint()..color = const Color(0xFFFDE047)..strokeWidth = 2.3);
      _drawArrow(canvas, Offset(stXR - flW, yy), Offset(stXR - flW - confLen, yy), Paint()..color = const Color(0xFFFDE047)..strokeWidth = 2.3);
      final hoLen = 12.0 + 10.0 * magNorm;
      _drawArrow(canvas, Offset(xL + coverW - hoLen, yy), Offset(xL + coverW - 1, yy), Paint()..color = const Color(0xFF10B981)..strokeWidth = 2.0);
      _drawArrow(canvas, Offset(xR - coverW + hoLen, yy), Offset(xR - coverW + 1, yy), Paint()..color = const Color(0xFF10B981)..strokeWidth = 2.0);
    }

    // 8. Hiệu ứng BONG VỠ & BUNG MẢNH VỎ BẢO VỆ RA NGOÀI (phóng đại rõ rệt theo magFactor ở GĐ3–4!)
    if (spalling || (stageIdx == 3 && magFactor >= 35)) {
      final spOut = (10.0 + 16.0 * magNorm) * (spalling ? 1.0 : 0.55);
      final spFill = Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.25);
      final spStroke = Paint()..color = const Color(0xFFFF2D55)..style = PaintingStyle.stroke..strokeWidth = 1.9;
      for (final side in [-1.0, 1.0]) {
        final bx = (side < 0 ? xL : xR) + side * bulgePx * 0.85;
        final flake = Path()
          ..moveTo(bx, yT + (yB - yT) * 0.22)
          ..lineTo(bx + side * spOut, yT + (yB - yT) * 0.40)
          ..lineTo(bx + side * (spOut * 0.55), yT + (yB - yT) * 0.56)
          ..lineTo(bx + side * (spOut * 1.15), yT + (yB - yT) * 0.72)
          ..lineTo(bx, yT + (yB - yT) * 0.82)
          ..close();
        canvas.drawPath(flake, spFill);
        canvas.drawPath(flake, spStroke);
      }
    }

    // Chú thích trực quan
    _drawTag(canvas, Offset(8, 4), '↓ N=${(result.ultimateLoadKn * ultFrac).toStringAsFixed(0)} kN | τ_b=${dis.tauBondMpa.toStringAsFixed(2)} MPa', const Color(0xFF38BDF8));
    _drawTag(canvas, Offset(8, h - 14),
        spalling
            ? tr(lang, 'Vỏ ngoài phình & bong vỡ — Lõi trong khoang thép H giữ vững K_h·f\'c!', 'Cover bulges & spalls — Confined H-Core holds K_h·f\'c!')
            : tr(lang, 'Nở hông Poisson giữa các cốt đai ↔ Cánh thép H ép kiềm chế 3 trục (f_lh=${(result.conf.flH * ultFrac).toStringAsFixed(2)} MPa)', 'Poisson bulging ↔ H-Flange triaxial confinement'),
        spalling ? const Color(0xFFFF4D6D) : const Color(0xFFFDE047));
  }

  void _drawDashed(Canvas c, Offset a, Offset b, Paint p) {
    final total = (b - a).distance;
    if (total < 1) return;
    final dir = (b - a) / total;
    double d = 0;
    while (d < total) {
      c.drawLine(a + dir * d, a + dir * math.min(total, d + 4.0), p);
      d += 7.5;
    }
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
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: 12.0, fontWeight: FontWeight.bold)),
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
  final double magFactor;
  final int focusZone;
  final double probeYMm, probeZMm;
  final bool darkMode;
  final AppLang lang;

  const _ConfinementInterfaceSectionPainter({
    required this.result,
    required this.dis,
    required this.ultFrac,
    required this.magFactor,
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
    final sc = math.min((size.width - 48) / math.max(100.0, bDraw), (size.height - 28) / math.max(100.0, g.hMm));
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final magNorm = ((magFactor - 1.0) / 99.0).clamp(0.0, 1.0);
    final latExpandPx = (!isBeam ? (ultFrac * 7.5 * magNorm) : (ultFrac * 3.0 * magNorm));

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
        // Khuếch đại nhẹ giãn nở ngang Poisson cho lớp bê tông vỏ ngoài!
        final expScale = (f.kind == 'concrete' && f.zone == ConcreteZone.unconfined) ? (1.0 + latExpandPx / math.max(40.0, 0.5 * g.bMm * sc)) : 1.0;
        final px = cx + f.zMm * sc * expScale;
        final py = cy - f.yMm * sc * expScale;
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

    // 2. Đường biên bê tông + Lồng cốt đai + Mũi tên kẹp cốt đai f_lp phóng đại theo magFactor
    final borderP = Paint()
      ..color = darkMode ? Colors.white : const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (g.sectionType == 'COL_CIRC_H') {
      canvas.drawCircle(Offset(cx, cy), 0.5 * g.bMm * sc + latExpandPx, borderP);
      canvas.drawCircle(Offset(cx, cy), math.max(8, (0.5 * g.bMm - g.coverMm) * sc),
          Paint()..color = const Color(0xFF10B981)..style = PaintingStyle.stroke..strokeWidth = 2.0);
    } else {
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: g.bMm * sc + 2 * latExpandPx, height: g.hMm * sc + 2 * latExpandPx), borderP);
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
      // Mũi tên kẹp góc của cốt đai khép kín (phóng đại theo magFactor!)
      final hLen = 7.0 + 11.0 * magNorm;
      final hP = Paint()..color = const Color(0xFF34D399)..strokeWidth = 1.6;
      _arrow(canvas, sRect.topLeft - Offset(hLen, hLen) * 0.65, sRect.topLeft + const Offset(2, 2), hP);
      _arrow(canvas, sRect.topRight + Offset(hLen, -hLen) * 0.65, sRect.topRight + const Offset(-2, 2), hP);
      _arrow(canvas, sRect.bottomLeft + Offset(-hLen, hLen) * 0.65, sRect.bottomLeft + const Offset(2, -2), hP);
      _arrow(canvas, sRect.bottomRight + Offset(hLen, hLen) * 0.65, sRect.bottomRight + const Offset(-2, -2), hP);
    }

    // 3. Vòm giam giữ parabol Chen–Lin + Mũi tên áp lực kiềm chế f_lh + Đinh neo + Nứt tách Weng chữ V
    final yCorePx = cy - g.coreOffsetYMm * sc;
    final haPx = g.haMm * sc;
    final baPx = g.baMm * sc;
    final tfPx = math.max(2.5, g.tfMm * sc);
    final twPx = math.max(2.0, g.twMm * sc);

    if (g.sectionType != 'COL_RECT_CFST') {
      final yTopIn = yCorePx - 0.5 * haPx + tfPx;
      final yBotIn = yCorePx + 0.5 * haPx - tfPx;
      final bow = math.min(0.28 * (yBotIn - yTopIn), 0.35 * (baPx - twPx));

      final archP = Paint()..color = const Color(0xFFFFF59D)..style = PaintingStyle.stroke..strokeWidth = 1.9 + 0.8 * magNorm;
      final archR = Path()
        ..moveTo(cx + 0.5 * baPx, yTopIn)
        ..quadraticBezierTo(cx + 0.5 * baPx - bow, yCorePx, cx + 0.5 * baPx, yBotIn);
      final archL = Path()
        ..moveTo(cx - 0.5 * baPx, yTopIn)
        ..quadraticBezierTo(cx - 0.5 * baPx + bow, yCorePx, cx - 0.5 * baPx, yBotIn);
      canvas.drawPath(archR, archP);
      canvas.drawPath(archL, archP);

      // Mũi tên phản lực kiềm chế f_lh ép từ 2 cánh & bụng thép H vào lõi bê tông (phóng đại theo magFactor!)
      final aLen = 7.0 + 8.0 * ultFrac + 12.0 * magNorm;
      final fP = Paint()..color = const Color(0xFFFFF59D)..strokeWidth = 1.8 + 0.8 * magNorm;
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
          canvas.drawCircle(Offset(sx, yTopFl - stH * 0.45), 6.0 + 5.0 * ultFrac + 5.0 * magNorm,
              Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.24 + 0.26 * ultFrac));
          canvas.drawLine(Offset(sx, yTopFl), Offset(sx, yTopFl - stH), Paint()..color = const Color(0xFFFFD700)..strokeWidth = 3.0);
          canvas.drawLine(Offset(sx - 4.8, yTopFl - stH), Offset(sx + 4.8, yTopFl - stH), Paint()..color = const Color(0xFFFFD700)..strokeWidth = 3.2);
        }

        // Vết nứt tách dọc cánh thép Weng (2002) mở thành khe hình chữ V phóng đại theo magFactor!
        final splitFrac = (dis.splitUr * (0.85 + 0.55 * magNorm)).clamp(0.18, 1.0);
        final spHalfH = (0.8 + 3.2 * magNorm * ultFrac).clamp(0.8, 4.5);
        final ySp = yCorePx + 0.5 * haPx;
        final xEdgeR = cx + 0.5 * g.bMm * sc + latExpandPx;
        final xEdgeL = cx - 0.5 * g.bMm * sc - latExpandPx;
        final spColor = dis.splitUr > 0.75 ? const Color(0xFFFF2D55) : const Color(0xFFF97316);
        final xTipR = cx + 0.5 * baPx + (xEdgeR - (cx + 0.5 * baPx)) * splitFrac;
        final xTipL = cx - 0.5 * baPx - ((cx - 0.5 * baPx) - xEdgeL) * splitFrac;

        final crR = Path()
          ..moveTo(cx + 0.5 * baPx, ySp - spHalfH)
          ..lineTo(xTipR, ySp)
          ..lineTo(cx + 0.5 * baPx, ySp + spHalfH)
          ..close();
        final crL = Path()
          ..moveTo(cx - 0.5 * baPx, ySp - spHalfH)
          ..lineTo(xTipL, ySp)
          ..lineTo(cx - 0.5 * baPx, ySp + spHalfH)
          ..close();
        canvas.drawPath(crR, Paint()..color = spColor.withValues(alpha: 0.85));
        canvas.drawPath(crL, Paint()..color = spColor.withValues(alpha: 0.85));
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
      final y = 4.0 + i * 17.5;
      canvas.drawRect(Rect.fromLTWH(4, y + 3, 8, 8), Paint()..color = leg[i].$1);
      final tp = TextPainter(
        text: TextSpan(text: leg[i].$2, style: TextStyle(fontSize: 12.0, color: darkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155), fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(16, y));
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
    const padL = 48.0, padB = 26.0, padT = 18.0, padR = 10.0;
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

    _txt(canvas, Offset(padL + 3, math.max(padT + 2, yRd - 15)), 'τ_Rd=${dis.tauRdMpa.toStringAsFixed(2)}', const Color(0xFF06B6D4), 12.0);
    _txt(canvas, Offset(padL + pw * 0.42, padT - 14), 's=${dis.slipMm.toStringAsFixed(3)} mm', const Color(0xFFEF4444), 12.0);
    _txt(canvas, Offset(2, padT), 'τ(MPa)', fg, 12.0);
    _txt(canvas, Offset(padL + pw * 0.32, padT + ph + 5), tr(lang, 'Trượt s (mm)', 'Slip s (mm)'), fg, 12.0);
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
    const padL = 48.0, padB = 26.0, padT = 18.0, padR = 10.0;
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

    _txt(canvas, Offset(4, padT), 'σ_c', fg, 12.0);
    _txt(canvas, Offset(padL + pw * 0.25, padT + ph + 5), 'ε_c = ${(curEps * 1000).toStringAsFixed(2)} ‰', const Color(0xFFEF4444), 12.0);
    _txt(canvas, Offset(padL + 2, padT - 15), 'Kh=${conf.kh.toStringAsFixed(2)}', const Color(0xFFFDE047), 12.0);
    _txt(canvas, Offset(padL + 72, padT - 15), 'Kp=${conf.kp.toStringAsFixed(2)}', const Color(0xFF38BDF8), 12.0);
    _txt(canvas, Offset(padL + 142, padT - 15), tr(lang, 'Vỏ', 'Cov'), const Color(0xFF94A3B8), 12.0);
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
    const padL = 44.0, padB = 26.0, padT = 18.0, padR = 10.0;
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

    _txt(canvas, Offset(2, padT), '100%', fg, 12.0);
    _txt(canvas, Offset(10, padT + ph - 12), '0%', fg, 12.0);
    _txt(canvas, Offset(padL + 2, padT - 15), tr(lang, 'Đỏ:Thép H | Xanh:BT | Lá:Thép', 'Red:Steel | Blue:RC | Grn:Reb'), fg, 12.0);
    _txt(canvas, Offset(padL + pw * 0.22, padT + ph + 5), '${tr(lang, "Mức tải λ", "Load λ")}: ${(ultFrac * 100).toStringAsFixed(0)}%', const Color(0xFFF59E0B), 12.0);
  }

  void _txt(Canvas c, Offset p, String s, Color col, double fs) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, p);
  }

  @override
  bool shouldRepaint(covariant _LoadRedistributionPainter old) => true;
}
