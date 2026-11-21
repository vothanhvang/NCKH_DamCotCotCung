// ============================================================================
// PHÒNG THÍ NGHIỆM MÔ PHỎNG TƯƠNG TÁC CỐT CỨNG (THÉP HÌNH) ↔ BÊ TÔNG XUNG QUANH
// TỪ ĐÀN HỒI → NỨT BÊ TÔNG → VƯỢT ĐÀN HỒI / PHI TUYẾN → CỰC HẠN → ĐỨT GÃY KẾT THÚC
// ============================================================================
// Lột tả trực quan, định lượng và động (0% → 100% đứt gãy, tự dừng khi đứt gãy)
// với Hệ số khuếch đại ×1 → ×100:
//   • GĐ1 (0–22%): Đàn hồi nguyên vẹn — Dính bám hóa học nguyên vẹn (s ≈ 0)
//   • GĐ2 (22–48%): Nứt kéo bê tông — Đứt dính bám, kích hoạt đinh neo & thanh chống 45°
//   • GĐ3 (48–72%): Vượt vùng đàn hồi → Phi tuyến chảy dẻo cốt thép & thép hình H
//   • GĐ4 (72–86%): Đỉnh cực hạn — Vỏ bảo vệ vỡ nén bong tách, lõi khoang H giữ tải K_h
//   • GĐ5 (86–100%): Nhánh suy giảm sau đỉnh → ĐỨT GÃY KẾT THÚC (đứt cốt thép/cánh
//     thép, đứt cắt đinh neo, vỡ vụn bê tông nén / oằn cốt thép + nứt cắt chéo cột)!
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
  double _progress = 0.55; // Tiến trình kéo/nén kiểm soát chuyển vị [0.02 .. 1.0 = Đứt gãy kết thúc]
  double _magFactor = 25.0; // Hệ số khuếch đại biến dạng / trượt / nứt [1..100]
  int _focusZone = 0; // 0: Đinh neo/Cánh trên, 1: Khoang lõi H, 2: Mép cánh Weng, 3: Vỏ vs Đai
  double? _customY;
  double? _customZ;

  // Cache đường cong chuyển dịch chia tải & đường cong phá hoại 5 giai đoạn
  SrcAnalysisResult? _cachedRes;
  double _cachedX = -1;
  List<LoadRedistPoint> _redistCurve = const [];
  List<FailurePathPoint> _failureCurve = const [];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 11))
      ..addListener(() {
        if (!mounted) return;
        setState(() {
          _progress = (0.02 + 0.98 * _animCtrl.value).clamp(0.02, 1.0);
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _progress = 1.0); // Dừng hẳn tại 100% Đứt gãy kết thúc!
        }
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
      // Nếu đã đứt gãy kết thúc (>= 99%) thì chạy lại từ đầu 0% → 100% Đứt gãy!
      final startNorm = _progress >= 0.985 ? 0.0 : ((_progress - 0.02) / 0.98).clamp(0.0, 0.99);
      _animCtrl.forward(from: startNorm);
      setState(() {});
    }
  }

  void _ensureCurves() {
    if (_cachedRes != widget.result || (_cachedX - widget.probeXNorm).abs() > 0.005) {
      _cachedRes = widget.result;
      _cachedX = widget.probeXNorm;
      _redistCurve = SrcNonlinearEngine.computeLoadRedistributionCurve(widget.result, widget.probeXNorm);
      _failureCurve = SrcNonlinearEngine.computeFailurePathCurve(widget.result);
    }
  }

  (double yMm, double zMm) _getActiveProbeCoords() {
    if (_customY != null && _customZ != null) return (_customY!, _customZ!);
    final g = widget.result.config.geometry;
    return switch (_focusZone) {
      0 => (g.coreOffsetYMm + 0.5 * g.haMm, 0.0),
      1 => (g.coreOffsetYMm, 0.25 * g.baMm),
      2 => (g.coreOffsetYMm - 0.5 * g.haMm, 0.5 * g.baMm + 8.0),
      _ => (0.5 * g.hMm - 0.5 * g.coverMm, 0.0),
    };
  }

  @override
  Widget build(BuildContext context) {
    _ensureCurves();
    final res = widget.result;
    final cfg = res.config;
    final g = cfg.geometry;
    final isBeam = cfg.kind == MemberKind.beam;
    final l = widget.lang;
    final dark = widget.darkMode;

    final dis = SrcNonlinearEngine.dissectSectionAtUltimateFrac(res, widget.probeXNorm, _progress);
    final fpNow = SrcNonlinearEngine.evaluateFailurePathPoint(res, _progress);
    final (pY, pZ) = _getActiveProbeCoords();

    // Khảo sát ĐỒNG THỜI 2 phía khe tiếp xúc (Phía Thép hình vs Phía Bê tông kề sát)
    final steelSampleY = pY.clamp(g.coreOffsetYMm - 0.48 * g.haMm, g.coreOffsetYMm + 0.48 * g.haMm);
    final steelProbe = SrcNonlinearEngine.probePointOnDissection(res, dis, steelSampleY, 0.0);
    final concSampleY = _focusZone == 0
        ? (g.coreOffsetYMm + 0.5 * g.haMm + 12.0).clamp(-0.48 * g.hMm, 0.48 * g.hMm)
        : (_focusZone == 1 ? g.coreOffsetYMm : pY);
    final concSampleZ = _focusZone == 1
        ? (0.30 * g.baMm)
        : (_focusZone == 2 ? (0.5 * g.baMm + 14.0).clamp(0.0, 0.48 * g.bMm) : pZ);
    final concProbe = SrcNonlinearEngine.probePointOnDissection(res, dis, concSampleY, concSampleZ);

    final cardBg = dark ? const Color(0xFF0F172A) : Colors.white;
    final subBg = dark ? const Color(0xFF081022) : const Color(0xFFF8FAFC);
    final border = dark ? const Color(0xFF263859) : const Color(0xFFCBD5E1);
    final fg = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    // 5 giai đoạn phá hoại đầy đủ (Đàn hồi → Nứt → Vượt đàn hồi/Phi tuyến → Cực hạn → Đứt gãy kết thúc)
    final int stageIdx = fpNow.stage;
    final bool isFractured = _progress >= 0.985;
    final stageColor = switch (stageIdx) {
      1 => const Color(0xFF10B981),
      2 => const Color(0xFF38BDF8),
      3 => const Color(0xFFF59E0B),
      4 => const Color(0xFFF97316),
      _ => const Color(0xFFEF4444),
    };
    final stageTitle = switch (stageIdx) {
      1 => tr(l, 'GĐ1 (Đàn hồi): Bê tông chưa nứt, thép đàn hồi, dính bám hóa học nguyên vẹn (s ≈ 0)',
          'Stage 1 (Elastic): Uncracked concrete, elastic steel, intact chemical bond'),
      2 => isBeam
          ? tr(l, 'GĐ2 (Nứt bê tông): Bê tông kéo vượt f_ct nứt chữ V — Đứt dính bám, kích hoạt đinh neo',
              'Stage 2 (Cracking): Tension cracks open — Debonding, shear studs activated')
          : tr(l, 'GĐ2 (Nứt vi mô): Tăng giãn nở ngang Poisson — Bắt đầu kiềm chế vòm thép H',
              'Stage 2 (Micro-cracking): Poisson expansion initiates H-core confinement'),
      3 => isBeam
          ? tr(l, 'GĐ3 (Vượt đàn hồi → Phi tuyến): Cốt thép & cánh thép H vượt f_y chảy dẻo, đinh neo uốn chữ S',
              'Stage 3 (Nonlinear Yielding): Rebar & H-flange yield past f_y, S-bending studs')
          : tr(l, 'GĐ3 (Vượt đàn hồi → Phi tuyến): Thép hình chảy dẻo, kiềm chế 3 trục K_h tăng mạnh',
              'Stage 3 (Nonlinear Plastic): Steel yields, strong triaxial confinement K_h'),
      4 => isBeam
          ? tr(l, 'GĐ4 (Cực hạn đỉnh tải): Đạt P_u — Vỏ bê tông nén vỡ bong tách, khớp dẻo mở rộng',
              'Stage 4 (Peak Ultimate): Peak P_u reached — Compression cover crushes, plastic hinge')
          : tr(l, 'GĐ4 (Cực hạn đỉnh tải): Đạt N_u — Vỏ bảo vệ ngoài bong vỡ, lõi thép H giữ tải K_h',
              'Stage 4 (Peak Ultimate): Peak N_u — Outer cover spalls while H-core holds K_h'),
      _ => isFractured
          ? (isBeam
              ? tr(l, '✕ GĐ5 (ĐỨT GÃY KẾT THÚC): Đứt cốt thép & cánh dưới thép H, cắt đứt đinh neo, vỡ nén hoàn toàn!',
                  '✕ Stage 5 (FRACTURE TERMINATED): Rebar & flange rupture, stud shear-off, concrete crush!')
              : tr(l, '✕ GĐ5 (ĐỨT GÃY KẾT THÚC): Bong toàn bộ vỏ, oằn cốt thép dọc & nứt cắt chéo 45° xuyên cột!',
                  '✕ Stage 5 (FRACTURE TERMINATED): Complete cover spall, rebar buckling & 45° shear collapse!'))
          : tr(l, 'GĐ5 (Nhánh suy giảm sau đỉnh → Đứt gãy): Tải tụt mạnh, trượt tăng vọt tiến tới đứt gãy!',
              'Stage 5 (Post-Peak Softening → Fracture): Load drops rapidly toward rupture!'),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        // =====================================================================
        // THANH ĐIỀU KHIỂN 5 GIAI ĐOẠN (KÉO ĐẾN ĐỨT GÃY KẾT THÚC) & KHUẾCH ĐẠI
        // =====================================================================
        final controlBar = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: stageColor.withValues(alpha: 0.65), width: isFractured ? 1.8 : 1.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Nút Play / Pause / Replay đến Đứt gãy kết thúc
                  InkWell(
                    onTap: _toggleAnim,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _animCtrl.isAnimating
                              ? const [Color(0xFFEF4444), Color(0xFFF97316)]
                              : (isFractured
                                  ? const [Color(0xFFDC2626), Color(0xFF991B1B)]
                                  : const [Color(0xFF06B6D4), Color(0xFF2563EB)]),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _animCtrl.isAnimating
                                ? Icons.pause
                                : (isFractured ? Icons.replay : Icons.play_arrow),
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _animCtrl.isAnimating
                                ? tr(l, 'Tạm dừng', 'Pause')
                                : (isFractured
                                    ? tr(l, 'Chạy lại từ đầu', 'Replay')
                                    : tr(l, 'Kéo đến Đứt gãy', 'Run to Fracture')),
                            style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 5 nút chọn nhanh 5 giai đoạn vật lý
                  for (final (lbl, val, col) in [
                    (tr(l, 'GĐ1 Đàn hồi', 'S1 Elastic'), 0.14, const Color(0xFF10B981)),
                    (tr(l, 'GĐ2 Nứt BT', 'S2 Crack'), 0.36, const Color(0xFF38BDF8)),
                    (tr(l, 'GĐ3 Phi tuyến', 'S3 Nonlinear'), 0.62, const Color(0xFFF59E0B)),
                    (tr(l, 'GĐ4 Cực hạn', 'S4 Peak'), 0.82, const Color(0xFFF97316)),
                    (tr(l, 'GĐ5 Đứt gãy', 'S5 Fracture'), 1.00, const Color(0xFFEF4444)),
                  ])
                    _pillBtn(
                      lbl,
                      stageIdx == SrcNonlinearEngine.failureStageOf(val),
                      col,
                      fg,
                      border,
                      () {
                        _animCtrl.stop();
                        setState(() => _progress = val);
                      },
                    ),
                  // Chọn nhanh vị trí cắt x/L
                  Text(tr(l, 'Cắt x/L:', 'Cut:'), style: TextStyle(fontSize: 12.0, color: sub, fontWeight: FontWeight.bold)),
                  for (final (lbl, xv) in [
                    (isBeam ? tr(l, 'Gối 0.12', 'End 0.12') : tr(l, 'Đầu 0.10', 'End 0.10'), isBeam ? 0.12 : 0.10),
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
              const SizedBox(height: 6),
              // Thanh trượt Tiến trình Kéo/Nén (0% → Đứt gãy) + Thanh trượt Hệ số Khuếch đại (×1 → ×100)
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: wide ? 450 : double.infinity,
                    child: Row(
                      children: [
                        Text(
                          '${tr(l, "Tiến trình", "Prog")}: ${(_progress * 100).toStringAsFixed(0)}% | ${fpNow.loadKn.toStringAsFixed(0)} kN',
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
                              value: _progress,
                              min: 0.02,
                              max: 1.0,
                              activeColor: stageColor,
                              inactiveColor: border,
                              onChanged: (v) {
                                _animCtrl.stop();
                                setState(() => _progress = v);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: wide ? 460 : double.infinity,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.zoom_out_map, size: 15, color: Color(0xFFA855F7)),
                            const SizedBox(width: 4),
                            Text(
                              '${tr(l, "Khuếch đại", "Mag")}: ×${_magFactor.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12.0, fontFamily: 'DejaVuSansMono', fontWeight: FontWeight.bold, color: Color(0xFFA855F7)),
                            ),
                            SizedBox(
                              width: wide ? 140 : 112,
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
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: dark ? (isFractured ? 0.25 : 0.15) : (isFractured ? 0.16 : 0.10)),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: stageColor.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Icon(isFractured ? Icons.dangerous_outlined : Icons.auto_awesome, size: 16, color: stageColor),
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
        // CANVAS A: PHÓNG ĐẠI CẬN CẢNH VÙNG TIẾP XÚC DỌC TỪ ĐÀN HỒI → ĐỨT GÃY
        // =====================================================================
        final microCutawayCard = Container(
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.zoom_in, size: 17, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isBeam
                          ? tr(l, 'A. Phóng đại Tương tác Dọc: Đàn hồi → Nứt → Chảy dẻo → Đứt gãy Kết thúc',
                              'A. Zoomed Longitudinal Mechanics: Elastic → Crack → Yield → Fracture')
                          : tr(l, 'A. Phóng đại Tương tác Dọc Cột: Nở hông → Kiềm chế H → Oằn & Đứt gãy Cắt',
                              'A. Zoomed Column Failure: Poisson Bulge → H-Confinement → Buckling & Fracture'),
                      style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: wide ? 320 : 295,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _MicroInterfaceCutawayPainter(
                    result: res,
                    dis: dis,
                    progress: _progress,
                    loadKn: fpNow.loadKn,
                    magFactor: _magFactor,
                    stageIdx: stageIdx,
                    darkMode: dark,
                    lang: l,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(color: subBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  children: [
                    _kvChip('v_L', '${dis.vInterfaceKnPerM.toStringAsFixed(1)} kN/m', const Color(0xFFF59E0B), dark),
                    _kvChip('τ_b / τ_Rd', '${dis.tauBondMpa.toStringAsFixed(2)} / ${dis.tauRdMpa.toStringAsFixed(2)} MPa',
                        dis.tauBondMpa > dis.tauRdMpa ? const Color(0xFFEF4444) : const Color(0xFF06B6D4), dark),
                    if (isBeam)
                      _kvChip('F_stud', '${dis.studForceKn.toStringAsFixed(1)} / ${res.studPRdKn.toStringAsFixed(1)} kN',
                          stageIdx >= 5 || dis.studUr > 0.85 ? const Color(0xFFEF4444) : const Color(0xFF10B981), dark)
                    else
                      _kvChip('f_lh / f_lp', '${(res.conf.flH * math.min(1.0, _progress / 0.84)).toStringAsFixed(2)} / ${(res.conf.flP * math.min(1.0, _progress / 0.84)).toStringAsFixed(2)} MPa',
                          const Color(0xFFA855F7), dark),
                    _kvChip('Δs', '${dis.slipMm.toStringAsFixed(3)} mm', const Color(0xFF38BDF8), dark),
                    _kvChip('δ', '${fpNow.dispMm.toStringAsFixed(1)} mm', stageColor, dark),
                  ],
                ),
              ),
            ],
          ),
        );

        // =====================================================================
        // CANVAS B: PHẪU THUẬT MẶT CẮT NGANG — 3 VÙNG KIỀM CHẾ & ĐỨT GÃY
        // =====================================================================
        final sectionConfinementCard = Container(
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.hub_outlined, size: 17, color: Color(0xFF06B6D4)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr(l, 'B. Mặt cắt Ngang: 3 Vùng Kiềm chế, Vòm Thép H & Phá hoại Cánh',
                          'B. Cross-Section: 3-Zone Confinement, H-Arching & Rupture'),
                      style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  for (final (idx, lbl) in [
                    (0, isBeam ? tr(l, '1. Đinh neo / Cánh trên', '1. Stud / Top Flange') : tr(l, '1. Tiếp xúc Cánh', '1. Flange Contact')),
                    (1, tr(l, '2. Lõi kiềm chế H', '2. H-Core Confined')),
                    (2, tr(l, '3. Mép cánh Weng', '3. Flange Splitting')),
                    (3, tr(l, '4. Vỏ vs Cốt đai', '4. Cover vs Hoops')),
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
                          progress: _progress,
                          stageIdx: stageIdx,
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: subBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: stageColor.withValues(alpha: 0.45)),
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
                            'ε_a=${(steelProbe.epsX * 1000).toStringAsFixed(2)}‰ | σ_a=${steelProbe.sigmaXMpa.toStringAsFixed(0)} MPa',
                            style: TextStyle(fontSize: 12.0, fontFamily: 'DejaVuSansMono', color: fg, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isFractured
                                ? tr(l, 'ĐỨT GÃY / MẤT ỔN ĐỊNH CỤC BỘ', 'RUPTURED / LOCAL BUCKLING')
                                : (l.isVi ? steelProbe.stateVi : steelProbe.stateEn),
                            style: TextStyle(fontSize: 12.0, color: isFractured ? const Color(0xFFEF4444) : const Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 64, color: border, margin: const EdgeInsets.symmetric(horizontal: 8)),
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
                            'ε_c=${(concProbe.epsX * 1000).toStringAsFixed(2)}‰ | σ_c=${concProbe.sigmaXMpa.toStringAsFixed(1)} MPa',
                            style: TextStyle(fontSize: 12.0, fontFamily: 'DejaVuSansMono', color: fg, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isFractured
                                ? tr(l, 'VỠ NÉN / NỨT XUYÊN ĐỨT GÃY', 'CRUSHED / FRACTURED')
                                : (l.isVi ? concProbe.stateVi : concProbe.stateEn),
                            style: TextStyle(fontSize: 12.0, color: isFractured ? const Color(0xFFEF4444) : const Color(0xFF10B981), fontWeight: FontWeight.w600),
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
        // 4 BIỂU ĐỒ CƠ HỌC ĐỒNG BỘ (LƯỚI 2×2 TRÊN DESKTOP — TẤT CẢ CỠ 12.0 px)
        // =====================================================================
        final chart0 = _chartBox(
          title: tr(l, '1. Đường cong Phá hoại 5 Giai đoạn (Đàn hồi → Nứt → Phi tuyến → Đứt gãy)',
              '1. 5-Stage Failure Curve (Elastic → Crack → Nonlinear → Fracture)'),
          accent: const Color(0xFFEF4444),
          cardBg: cardBg,
          border: border,
          fg: fg,
          child: CustomPaint(
            size: Size.infinite,
            painter: _FailurePath5StagePainter(curve: _failureCurve, nowPt: fpNow, isBeam: isBeam, darkMode: dark, lang: l),
          ),
        );

        final chart1 = _chartBox(
          title: tr(l, '2. Dính bám – Trượt (τ_b – s) đến Đứt cắt Đinh neo', '2. Bond–Slip (τ_b – s) to Stud Shear Fracture'),
          accent: const Color(0xFFF59E0B),
          cardBg: cardBg,
          border: border,
          fg: fg,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BondSlipCurvePainter(result: res, dis: dis, progress: _progress, darkMode: dark, lang: l),
          ),
        );

        final chart2 = _chartBox(
          title: tr(l, '3. Ứng xử 3 Vùng Bê tông σ_c–ε_c (Vỏ vs Đai vs Lõi H)', '3. 3-Zone Concrete σ_c–ε_c (Cover vs Core)'),
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
          title: tr(l, '4. Chuyển dịch Chia tải Thép H ↔ Bê tông (0% → Đứt gãy)', '4. Load Redistribution Steel H ↔ RC (0% → Fracture)'),
          accent: const Color(0xFF10B981),
          cardBg: cardBg,
          border: border,
          fg: fg,
          child: CustomPaint(
            size: Size.infinite,
            painter: _LoadRedistributionPainter(curve: _redistCurve, progress: _progress, darkMode: dark, lang: l),
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
              if (wide) ...[
                SizedBox(
                  height: 235,
                  child: Row(
                    children: [
                      Expanded(child: chart0),
                      const SizedBox(width: 8),
                      Expanded(child: chart1),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 235,
                  child: Row(
                    children: [
                      Expanded(child: chart2),
                      const SizedBox(width: 8),
                      Expanded(child: chart3),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(height: 230, child: chart0),
                const SizedBox(height: 8),
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
    final sc = math.min((sz.width - 44) / math.max(100.0, bDraw), (sz.height - 28) / math.max(100.0, g.hMm));
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
              Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: fg), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ============================================================================
// PAINTER A: PHÓNG ĐẠI CẬN CẢNH DỌC — TỪ ĐÀN HỒI → NỨT → PHI TUYẾN → ĐỨT GÃY!
// ============================================================================
class _MicroInterfaceCutawayPainter extends CustomPainter {
  final SrcAnalysisResult result;
  final DissectionResult dis;
  final double progress;
  final double loadKn;
  final double magFactor;
  final int stageIdx;
  final bool darkMode;
  final AppLang lang;

  const _MicroInterfaceCutawayPainter({
    required this.result,
    required this.dis,
    required this.progress,
    required this.loadKn,
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

    // Nhãn hệ số khuếch đại góc trên phải
    final magTxt = '${tr(lang, "Khuếch đại", "Scale")} ×${magFactor.toStringAsFixed(0)}';
    final tp = TextPainter(
      text: TextSpan(text: magTxt, style: const TextStyle(color: Color(0xFFD8B4FE), fontSize: 12.0, fontWeight: FontWeight.bold, fontFamily: 'DejaVuSansMono')),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - tp.width - 14, 4, tp.width + 10, tp.height + 4),
      const Radius.circular(5),
    );
    canvas.drawRRect(box, Paint()..color = const Color(0xFF581C87).withValues(alpha: 0.78));
    tp.paint(canvas, Offset(size.width - tp.width - 9, 6));

    // Dấu đóng mộc ĐỨT GÃY KẾT THÚC khi đạt 98.5%–100%
    if (progress >= 0.985) {
      final fTxt = tr(lang, '✕ ĐỨT GÃY KẾT THÚC', '✕ FRACTURE TERMINATED');
      final ftp = TextPainter(
        text: TextSpan(text: fTxt, style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      final fRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width * 0.5, 22), width: ftp.width + 18, height: ftp.height + 8),
        const Radius.circular(6),
      );
      canvas.drawRRect(fRect, Paint()..color = const Color(0xFFDC2626).withValues(alpha: 0.94));
      canvas.drawRRect(fRect, Paint()..color = const Color(0xFFFDE047)..style = PaintingStyle.stroke..strokeWidth = 1.6);
      ftp.paint(canvas, Offset(size.width * 0.5 - ftp.width * 0.5, 22 - ftp.height * 0.5));
    }
  }

  void _paintBeamMicroInterface(Canvas canvas, Size size, Color fg) {
    final w = size.width;
    final h = size.height;
    const padX = 24.0;
    final x0 = padX, x1 = w - padX;
    final spanW = x1 - x0;
    final midX = x0 + spanW * 0.5;

    final magGain = (magFactor / 25.0).clamp(0.04, 4.0);
    final magNorm = ((magFactor - 1.0) / 99.0).clamp(0.0, 1.0);
    final tFrac = progress > 0.86 ? ((progress - 0.86) / 0.14).clamp(0.0, 1.0) : 0.0;
    final isFracturing = tFrac > 0.05;

    final ySlabTop = h * 0.14;
    final yFlTop = h * 0.43;
    final tfH = h * 0.062;
    final yFlBot = h * 0.70;
    final yConcBot = h * 0.85;

    // Độ võng uốn cong (tăng vọt dạng khớp dẻo chữ V khi vào GĐ5 đứt gãy!)
    final arcSag = ((progress * 8.0 + tFrac * 10.0) * magGain).clamp(0.0, 24.0);
    double sagAt(double x) {
      final u = ((x - x0) / math.max(1.0, spanW) - 0.5) * 2.0; // -1..1
      final smooth = 1.0 - u * u;
      final hingeV = 1.0 - u.abs(); // Khớp dẻo gãy gập tại giữa!
      return arcSag * ((1.0 - tFrac) * smooth + tFrac * hingeV);
    }

    final baseSlip = dis.slipMm * 15.0 + (stageIdx >= 2 ? (progress - 0.20) * 11.0 : progress * 2.0) + tFrac * 10.0;
    final slipVisual = (baseSlip * magGain).clamp(0.0, 34.0);
    final bondBroken = dis.tauBondMpa > 0.30 || stageIdx >= 2;
    final steelYielding = stageIdx >= 3;

    Path curvedBand(double lx0, double lx1, double yt, double yb) {
      final p = Path();
      const n = 18;
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

    final cTopX0 = x0 - slipVisual * 0.45;
    final cTopX1 = x1 - slipVisual * 0.45;
    final stX0 = x0 + slipVisual * 0.55;
    final stX1 = x1 + slipVisual * 0.55;

    // 1. Vùng bê tông bao quanh
    final concTopColor = Color.lerp(
      darkMode ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
      stageIdx >= 4 ? const Color(0xFF991B1B) : const Color(0xFF0284C7),
      (progress * 0.65).clamp(0.0, 0.65),
    )!;
    canvas.drawPath(curvedBand(cTopX0, cTopX1, ySlabTop, yFlTop), Paint()..color = concTopColor.withValues(alpha: 0.74));
    canvas.drawPath(curvedBand(x0, x1, yFlTop, yConcBot),
        Paint()..color = (darkMode ? const Color(0xFF17253B) : const Color(0xFFE2E8F0)).withValues(alpha: 0.65));

    // Vùng bê tông kiềm chế mạnh trong khoang giữa 2 cánh thép H
    canvas.drawPath(
      curvedBand(stX0 + 4, stX1 - 4, yFlTop + tfH, yFlBot),
      Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.12 + 0.20 * progress),
    );

    // 2. Cốt đai đứng & Cốt thép dọc (đứt tách 2 đầu ở GĐ5!)
    final stirCol = Color.lerp(const Color(0xFF10B981), const Color(0xFF34D399), progress)!;
    for (int i = 0; i < 6; i++) {
      final xs = x0 + spanW * (0.08 + i * 0.168);
      final dy = sagAt(xs);
      canvas.drawLine(Offset(xs - slipVisual * 0.25, ySlabTop + 9 + dy), Offset(xs, yConcBot - 9 + dy),
          Paint()..color = stirCol..strokeWidth = 1.9);
    }

    final rbP = Paint()..color = const Color(0xFF10B981)..style = PaintingStyle.stroke..strokeWidth = 3.2;
    final pRbTop = Path();
    for (int i = 0; i <= 16; i++) {
      final xt = cTopX0 + (cTopX1 - cTopX0) * i / 16;
      if (i == 0) {
        pRbTop.moveTo(xt, ySlabTop + 9 + sagAt(xt));
      } else {
        pRbTop.lineTo(xt, ySlabTop + 9 + sagAt(xt));
      }
    }
    canvas.drawPath(pRbTop, rbP);

    // Cốt thép dọc chịu kéo phía dưới: ĐỨT TÁCH LÀM 2 ĐẦU Ở GĐ5!
    final snapGap = (tFrac * (10.0 + 14.0 * magNorm)).clamp(0.0, 26.0);
    if (snapGap > 2.5) {
      // Nửa trái & Nửa phải cốt thép kéo đứt rời
      final pL = Path(), pR = Path();
      for (int i = 0; i <= 8; i++) {
        final xl = x0 + (midX - snapGap * 0.5 - x0) * i / 8;
        final xr = (midX + snapGap * 0.5) + (x1 - (midX + snapGap * 0.5)) * i / 8;
        if (i == 0) {
          pL.moveTo(xl, yConcBot - 9 + sagAt(xl));
          pR.moveTo(xr, yConcBot - 9 + sagAt(xr));
        } else {
          pL.lineTo(xl, yConcBot - 9 + sagAt(xl));
          pR.lineTo(xr, yConcBot - 9 + sagAt(xr));
        }
      }
      canvas.drawPath(pL, Paint()..color = const Color(0xFFFF006E)..style = PaintingStyle.stroke..strokeWidth = 3.4);
      canvas.drawPath(pR, Paint()..color = const Color(0xFFFF006E)..style = PaintingStyle.stroke..strokeWidth = 3.4);
    } else {
      final pRbBot = Path();
      for (int i = 0; i <= 16; i++) {
        final xb = x0 + spanW * i / 16;
        if (i == 0) {
          pRbBot.moveTo(xb, yConcBot - 9 + sagAt(xb));
        } else {
          pRbBot.lineTo(xb, yConcBot - 9 + sagAt(xb));
        }
      }
      canvas.drawPath(pRbBot, steelYielding ? (Paint()..color = const Color(0xFFFF6B00)..style = PaintingStyle.stroke..strokeWidth = 3.2) : rbP);
    }

    // 3. LÕI THÉP HÌNH H (chảy dẻo GĐ3–4 → ĐỨT RÁCH CÁNH DƯỚI & BỤNG Ở GĐ5!)
    final webCol = steelYielding ? const Color(0xFFDC2626) : const Color(0xFFEF4444);
    canvas.drawPath(curvedBand(stX0, stX1, yFlTop + tfH, yFlBot), Paint()..color = webCol.withValues(alpha: 0.34));
    canvas.drawPath(curvedBand(stX0, stX1, yFlTop, yFlTop + tfH), Paint()..color = const Color(0xFFEF4444));
    if (snapGap > 3.5) {
      // Cánh dưới thép H bị kéo đứt làm 2 nửa!
      canvas.drawPath(curvedBand(stX0, midX - snapGap * 0.45, yFlBot, yFlBot + tfH), Paint()..color = const Color(0xFFFF006E));
      canvas.drawPath(curvedBand(midX + snapGap * 0.45, stX1, yFlBot, yFlBot + tfH), Paint()..color = const Color(0xFFFF006E));
    } else {
      canvas.drawPath(
        curvedBand(stX0, stX1, yFlBot, yFlBot + tfH),
        Paint()..color = steelYielding ? const Color(0xFFFF006E) : const Color(0xFFEF4444),
      );
    }

    // Đường gốc nét đứt trước khi trượt
    if (slipVisual > 2.0) {
      final refX = x0 + spanW * 0.04;
      _drawDashed(canvas, Offset(refX, ySlabTop), Offset(refX, yConcBot), Paint()..color = Colors.white.withValues(alpha: 0.55)..strokeWidth = 1.1);
    }

    // 4. Lò xo dính bám vi mô
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
        canvas.drawLine(Offset(bxTop - 2, yFlTop - 3 + dy), Offset(bxBot + 2, yFlTop - 1 + dy), bp);
      }
    }

    // 5. 3 ĐINH NEO CHỐNG CẮT (Biến dạng S → CẮT ĐỨT RỜI CHÂN ĐINH Ở GĐ5!)
    final studH = (yFlTop - ySlabTop) * 0.68;
    for (int s = 0; s < 3; s++) {
      final sxBase = stX0 + spanW * (0.20 + s * 0.29);
      final dy = sagAt(sxBase);
      final yBase = yFlTop + dy;
      final bend = (slipVisual * 0.78).clamp(0.0, 22.0);
      final studSheared = tFrac > 0.55;
      final shearShift = studSheared ? (tFrac - 0.55) * (16.0 + 14.0 * magNorm) : 0.0;
      final sxHead = sxBase - bend - shearShift;

      if (progress > 0.12) {
        final coneW = (12.0 + 18.0 * progress) * (0.65 + 0.75 * magNorm);
        final coneH = studH * (0.58 + 0.25 * magNorm);
        final conePath = Path()
          ..moveTo(sxBase - 3, yBase)
          ..lineTo(sxBase - 3 - coneW, yBase - coneH)
          ..lineTo(sxBase - 3 - coneW * 0.42, yBase - coneH * 1.15)
          ..lineTo(sxBase - 2, yBase - studH * 0.55)
          ..close();
        canvas.drawPath(
          conePath,
          Paint()..color = Color.lerp(const Color(0xFFFBBF24), const Color(0xFFFF2D55), progress)!.withValues(alpha: 0.44 + 0.35 * progress),
        );
        final strutLen = 26.0 + 18.0 * progress + 12.0 * magNorm;
        _drawArrow(
          canvas,
          Offset(sxBase - 4, yBase - 6),
          Offset(sxBase - strutLen, math.max(ySlabTop + 10 + dy, yBase - strutLen * 0.85)),
          Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.45 + 0.4 * progress)..strokeWidth = 1.8 + 1.0 * magNorm,
        );
      }

      final studCol = studSheared
          ? const Color(0xFFFF2D55)
          : Color.lerp(const Color(0xFFFDE047), const Color(0xFFFF5722), dis.studUr.clamp(0.0, 1.0))!;
      final yBreak = yBase - (studSheared ? 5.5 : 0.0);
      final studPath = Path()
        ..moveTo(sxBase - shearShift * 0.65, yBreak)
        ..cubicTo(
          sxBase - shearShift * 0.65, yBase - studH * 0.45,
          sxHead, yBase - studH * 0.58,
          sxHead, yBase - studH,
        );
      canvas.drawPath(studPath, Paint()..color = studCol..style = PaintingStyle.stroke..strokeWidth = 4.6..strokeCap = StrokeCap.round);
      final tilt = (bend * 0.14).clamp(0.0, 3.8);
      canvas.drawLine(Offset(sxHead - 8, yBase - studH - tilt), Offset(sxHead + 8, yBase - studH + tilt),
          Paint()..color = studCol..strokeWidth = 4.2..strokeCap = StrokeCap.square);
      // Chân đinh hàn còn lại trên cánh thép + tia cắt đứt màu trắng-đỏ nếu đã đứt!
      canvas.drawCircle(Offset(sxBase, yBase), 3.6, Paint()..color = studSheared ? const Color(0xFFFF2D55) : Colors.white);
      if (studSheared) {
        canvas.drawLine(Offset(sxBase - 6, yBase - 3), Offset(sxBase + 4, yBase - 3),
            Paint()..color = Colors.white..strokeWidth = 1.6);
      }
    }

    // 6. VẾT NỨT KÉO CHỮ V (GĐ2–4) → KHE ĐỨT GÃY CHÍNH XUYÊN BỤNG + VỠ VỤN BÊ TÔNG NÉN ĐỈNH (GĐ5)!
    if (stageIdx >= 2) {
      final nCr = stageIdx == 2 ? 4 : (stageIdx == 3 ? 6 : 8);
      final crackHalfW = (0.7 + 2.6 * progress * magGain).clamp(0.6, 5.4);
      for (int c = 0; c < nCr; c++) {
        final cx = x0 + spanW * (0.11 + c * (0.78 / math.max(1, nCr - 1)));
        final dy = sagAt(cx);
        final yBot = yConcBot + dy;
        final reach = (yConcBot - (yFlBot + tfH)) * (0.58 + 0.44 * math.min(1.0, progress / 0.84));
        final yTip = math.max(yFlBot + tfH + dy, yBot - reach);
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

    // 6b. KHE ĐỨT GÃY XUYÊN THÂN + TIA ĐỨT GÃY THÉP + MẢNH VỠ BÊ TÔNG NÉN ĐỈNH (GĐ5!)
    if (isFracturing) {
      final dyM = sagAt(midX);
      final gapHalf = (3.0 + tFrac * (7.0 + 7.0 * magNorm)).clamp(3.0, 16.0);
      final yFractTop = yFlTop + tfH + (yFlBot - yFlTop - tfH) * (1.0 - tFrac * 0.92) + dyM;
      final macroCrack = Path()
        ..moveTo(midX - gapHalf, yConcBot + dyM)
        ..lineTo(midX - gapHalf * 0.72, yFlBot + dyM)
        ..lineTo(midX - gapHalf * 0.35 + 3, (yFlBot + yFractTop) * 0.5)
        ..lineTo(midX, yFractTop)
        ..lineTo(midX + gapHalf * 0.35 + 3, (yFlBot + yFractTop) * 0.5)
        ..lineTo(midX + gapHalf * 0.72, yFlBot + dyM)
        ..lineTo(midX + gapHalf, yConcBot + dyM)
        ..close();
      canvas.drawPath(macroCrack, Paint()..color = const Color(0xFF2A0410));
      canvas.drawPath(macroCrack, Paint()..color = const Color(0xFFFFD700)..style = PaintingStyle.stroke..strokeWidth = 2.0);

      // Tia chớp sáng tại điểm đứt gãy cánh dưới thép H & cốt thép kéo
      for (final fy in [yFlBot + tfH * 0.5 + dyM, yConcBot - 9 + dyM]) {
        canvas.drawCircle(Offset(midX, fy), 6.0 + 5.0 * tFrac, Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.45));
        canvas.drawLine(Offset(midX - 7, fy - 5), Offset(midX + 7, fy + 5), Paint()..color = Colors.white..strokeWidth = 2.0);
        canvas.drawLine(Offset(midX - 7, fy + 5), Offset(midX + 7, fy - 5), Paint()..color = Colors.white..strokeWidth = 2.0);
      }

      // Mảnh vỡ nén bê tông vùng đỉnh dầm (Rubble shards)
      final rubbleP = Paint()..color = const Color(0xFFFF2D55)..style = PaintingStyle.fill;
      for (final dx in [-26.0, -10.0, 6.0, 22.0]) {
        final rx = midX + dx;
        final ry = ySlabTop + sagAt(rx) - tFrac * (4.0 + 8.0 * magNorm);
        final shard = Path()
          ..moveTo(rx - 6, ry + 7)
          ..lineTo(rx, ry - 4)
          ..lineTo(rx + 7, ry + 5)
          ..close();
        canvas.drawPath(shard, rubbleP);
      }
    }

    // 7. Chú thích rõ ràng (đồng nhất 12.0 px)
    _drawTag(canvas, Offset(x0 + 2, 5),
        isFracturing ? tr(lang, 'Vỡ nén bê tông đỉnh!', 'Top concrete crushed!') : tr(lang, '← Bê tông nén & Thanh chống 45°', '← Concrete & 45° Strut'),
        isFracturing ? const Color(0xFFFF4D6D) : const Color(0xFF38BDF8));
    _drawTag(canvas, Offset(x0 + 4, h - 18),
        isFracturing
            ? tr(lang, 'ĐỨT GÃY: Thép kéo & đinh neo đứt — Phá hoại kết thúc!', 'FRACTURE: Steel & studs ruptured — Failure terminated!')
            : (stageIdx >= 3
                ? tr(lang, 'Vượt đàn hồi → Phi tuyến: Thép H chảy dẻo, Δs=${dis.slipMm.toStringAsFixed(3)} mm', 'Nonlinear yielding: Steel yields, Δs=${dis.slipMm.toStringAsFixed(3)} mm')
                : tr(lang, 'Đàn hồi → Nứt BT: Δs=${dis.slipMm.toStringAsFixed(3)} mm | F_stud=${dis.studForceKn.toStringAsFixed(1)} kN', 'Elastic → Cracking: Δs=${dis.slipMm.toStringAsFixed(3)} mm')),
        isFracturing ? const Color(0xFFFFD700) : (stageIdx >= 2 ? const Color(0xFFFF6B81) : const Color(0xFF10B981)));
  }

  void _paintColumnMicroInterface(Canvas canvas, Size size, Color fg) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final colW = math.min(w * 0.64, 285.0);
    final xL = cx - 0.5 * colW;
    final xR = cx + 0.5 * colW;
    final yT0 = h * 0.14;
    final yB0 = h * 0.85;

    final magGain = (magFactor / 25.0).clamp(0.04, 4.0);
    final magNorm = ((magFactor - 1.0) / 99.0).clamp(0.0, 1.0);
    final tFrac = progress > 0.86 ? ((progress - 0.86) / 0.14).clamp(0.0, 1.0) : 0.0;
    final isFracturing = tFrac > 0.05;

    final shortenPx = ((progress * 7.5 + tFrac * 8.0) * magGain).clamp(0.0, 24.0);
    final bulgePx = ((progress * 5.2 + tFrac * 7.0) * magGain).clamp(0.0, 22.0);
    final yT = yT0 + shortenPx * 0.65;
    final yB = yB0 - shortenPx * 0.35;

    final coverW = colW * 0.12;
    final stW = colW * 0.44;
    final stXL = cx - 0.5 * stW;
    final stXR = cx + 0.5 * stW;
    final flW = math.max(9.0, stW * 0.12);
    final spalling = stageIdx >= 4 || dis.epsMin < -0.0032;

    if (shortenPx > 1.5 || bulgePx > 1.5) {
      _drawDashed(canvas, Offset(xL, yT0), Offset(xR, yT0), Paint()..color = Colors.white.withValues(alpha: 0.42)..strokeWidth = 1.0);
      _drawDashed(canvas, Offset(xL, yT0), Offset(xL, yB0), Paint()..color = Colors.white.withValues(alpha: 0.30)..strokeWidth = 1.0);
      _drawDashed(canvas, Offset(xR, yT0), Offset(xR, yB0), Paint()..color = Colors.white.withValues(alpha: 0.30)..strokeWidth = 1.0);
    }

    const nStir = 6;
    final stirYs = [for (int i = 0; i < nStir; i++) yT + (yB - yT) * (0.08 + i * 0.168)];
    double bulgeAtY(double y) {
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

    // 1–3. 3 vùng bê tông
    final covCol = spalling ? const Color(0xFFEF4444).withValues(alpha: 0.32) : (darkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1));
    canvas.drawPath(bulgedOuterPath(xL, xR, 1.0), Paint()..color = covCol);
    canvas.drawPath(bulgedOuterPath(xL + coverW, xR - coverW, 0.42),
        Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.24 + 0.16 * progress));
    canvas.drawRect(Rect.fromLTRB(stXL + flW, yT, stXR - flW, yB),
        Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.26 + 0.38 * progress));

    // 4. Lõi thép hình H (mất ổn định cục bộ nhẹ ở cánh khi đứt gãy GĐ5!)
    final steelCol = stageIdx >= 3 ? const Color(0xFFFF1744) : const Color(0xFFEF4444);
    final flBuckle = isFracturing ? tFrac * (4.0 + 6.0 * magNorm) : 0.0;
    final flPathL = Path()
      ..moveTo(stXL, yT)
      ..quadraticBezierTo(stXL - flBuckle, (yT + yB) * 0.5, stXL, yB)
      ..lineTo(stXL + flW, yB)
      ..quadraticBezierTo(stXL + flW - flBuckle, (yT + yB) * 0.5, stXL + flW, yT)
      ..close();
    final flPathR = Path()
      ..moveTo(stXR - flW, yT)
      ..quadraticBezierTo(stXR - flW + flBuckle, (yT + yB) * 0.5, stXR - flW, yB)
      ..lineTo(stXR, yB)
      ..quadraticBezierTo(stXR + flBuckle, (yT + yB) * 0.5, stXR, yT)
      ..close();
    canvas.drawPath(flPathL, Paint()..color = steelCol);
    canvas.drawPath(flPathR, Paint()..color = steelCol);
    canvas.drawLine(Offset(cx, yT), Offset(cx, yB), Paint()..color = steelCol.withValues(alpha: 0.65)..strokeWidth = 3.5);

    // 5. Cốt thép dọc (OẰN CONG VỒNG MẠNH RA NGOÀI GIỮA 2 CỐT ĐAI Ở GĐ5!) & Cốt đai
    final rbBuckleBoost = 0.35 + (isFracturing ? 1.45 * tFrac : 0.0);
    final rbP = Paint()..color = isFracturing ? const Color(0xFFFF006E) : const Color(0xFF10B981)..style = PaintingStyle.stroke..strokeWidth = 2.8;
    final pRbL = Path(), pRbR = Path();
    for (int i = 0; i <= 28; i++) {
      final y = yT + (yB - yT) * i / 28;
      final b = bulgeAtY(y) * rbBuckleBoost;
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
    for (int k = 0; k < stirYs.length; k++) {
      final ys = stirYs[k];
      final brokenMid = isFracturing && k == 2; // Cốt đai giữa bung đứt ở GĐ5!
      if (brokenMid) {
        canvas.drawLine(Offset(xL + coverW, ys), Offset(cx - 12, ys - 4), Paint()..color = const Color(0xFFFFD700)..strokeWidth = 2.2);
        canvas.drawLine(Offset(cx + 12, ys + 4), Offset(xR - coverW, ys), Paint()..color = const Color(0xFFFFD700)..strokeWidth = 2.2);
      } else {
        canvas.drawLine(Offset(xL + coverW, ys), Offset(xR - coverW, ys), Paint()..color = const Color(0xFF10B981)..strokeWidth = 2.2);
      }
    }

    // 6. Mũi tên tải nén N & Phản lực kiềm chế 3 trục
    for (final ax in [xL + coverW * 1.5, cx, xR - coverW * 1.5]) {
      _drawArrow(canvas, Offset(ax, 6), Offset(ax, yT - 2), Paint()..color = const Color(0xFF38BDF8)..strokeWidth = 2.2);
    }
    final confLen = (9.0 + 12.0 * progress) * (0.7 + 0.65 * magNorm);
    for (int r = 0; r < 3; r++) {
      final yy = yT + (yB - yT) * (0.25 + r * 0.25);
      _drawArrow(canvas, Offset(stXL + flW, yy), Offset(stXL + flW + confLen, yy), Paint()..color = const Color(0xFFFDE047)..strokeWidth = 2.3);
      _drawArrow(canvas, Offset(stXR - flW, yy), Offset(stXR - flW - confLen, yy), Paint()..color = const Color(0xFFFDE047)..strokeWidth = 2.3);
    }

    // 7. Bong vỏ bảo vệ (GĐ4) & VẾT NỨT CẮT CHÉO 45° XUYÊN CỘT PHÁ HOẠI KẾT THÚC (GĐ5!)
    if (spalling) {
      final spOut = (12.0 + 18.0 * magNorm) * (1.0 + 0.65 * tFrac);
      final spFill = Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.28);
      final spStroke = Paint()..color = const Color(0xFFFF2D55)..style = PaintingStyle.stroke..strokeWidth = 2.0;
      for (final side in [-1.0, 1.0]) {
        final bx = (side < 0 ? xL : xR) + side * bulgePx * 0.85;
        final flake = Path()
          ..moveTo(bx, yT + (yB - yT) * 0.20)
          ..lineTo(bx + side * spOut, yT + (yB - yT) * 0.38)
          ..lineTo(bx + side * (spOut * 0.52), yT + (yB - yT) * 0.56)
          ..lineTo(bx + side * (spOut * 1.18), yT + (yB - yT) * 0.72)
          ..lineTo(bx, yT + (yB - yT) * 0.82)
          ..close();
        canvas.drawPath(flake, spFill);
        canvas.drawPath(flake, spStroke);
      }
    }
    if (isFracturing) {
      // Dải đứt gãy cắt chéo 45° xé ngang toàn bộ lõi cột!
      final yMid = (yT + yB) * 0.5;
      final diag = Path()
        ..moveTo(xL - bulgePx, yMid - colW * 0.36)
        ..lineTo(cx - 10, yMid - 8)
        ..lineTo(cx + 12, yMid + 10)
        ..lineTo(xR + bulgePx, yMid + colW * 0.36);
      canvas.drawPath(diag, Paint()..color = const Color(0xFF2A0410)..style = PaintingStyle.stroke..strokeWidth = 6.0 + 4.0 * tFrac);
      canvas.drawPath(diag, Paint()..color = const Color(0xFFFFD700)..style = PaintingStyle.stroke..strokeWidth = 2.2);
    }

    _drawTag(canvas, Offset(8, 4), '↓ N=${loadKn.toStringAsFixed(0)} kN', const Color(0xFF38BDF8));
    _drawTag(canvas, Offset(8, h - 18),
        isFracturing
            ? tr(lang, 'ĐỨT GÃY: Oằn cốt thép dọc, bung đai & cắt chéo 45° xuyên cột!', 'FRACTURE: Rebar buckling, hoop rupture & 45° shear plane!')
            : (spalling
                ? tr(lang, 'Vỏ ngoài bong vỡ — Lõi thép H vẫn giữ tải K_h·f\'c!', 'Cover spalls — Confined H-Core holds K_h·f\'c!')
                : tr(lang, 'Nở hông Poisson ↔ Cánh thép H ép kiềm chế 3 trục', 'Poisson bulging ↔ H-Flange triaxial confinement')),
        isFracturing ? const Color(0xFFFFD700) : (spalling ? const Color(0xFFFF4D6D) : const Color(0xFFFDE047)));
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
// PAINTER B: MẶT CẮT NGANG 3 VÙNG KIỀM CHẾ, VÒM PARABOL & ĐỨT GÃY CÁNH
// ============================================================================
class _ConfinementInterfaceSectionPainter extends CustomPainter {
  final SrcAnalysisResult result;
  final DissectionResult dis;
  final double progress;
  final int stageIdx;
  final double magFactor;
  final int focusZone;
  final double probeYMm, probeZMm;
  final bool darkMode;
  final AppLang lang;

  const _ConfinementInterfaceSectionPainter({
    required this.result,
    required this.dis,
    required this.progress,
    required this.stageIdx,
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
    final tFrac = progress > 0.86 ? ((progress - 0.86) / 0.14).clamp(0.0, 1.0) : 0.0;
    final latExpandPx = (!isBeam ? (progress * 8.5 * magNorm) : (progress * 3.5 * magNorm));

    final pFill = Paint()..style = PaintingStyle.fill;
    for (final pass in [0, 1, 2]) {
      for (final df in dis.fibers) {
        final f = df.cell;
        final ord = f.kind == 'concrete' ? 0 : (f.kind.startsWith('steel') ? 1 : 2);
        if (ord != pass) continue;

        final Color col;
        if (f.kind == 'concrete') {
          if (df.epsX < -0.0035 && f.zone == ConcreteZone.unconfined) {
            col = const Color(0xFF7F1D1D); // Vỏ bảo vệ vỡ nén!
          } else if (df.epsX < -0.009) {
            col = const Color(0xFF991B1B); // Lõi bê tông suy giảm mạnh ở GĐ5!
          } else if (df.stateEn.contains('Cracked')) {
            col = const Color(0xFFF43F5E).withValues(alpha: 0.72);
          } else {
            col = switch (f.zone) {
              ConcreteZone.unconfined => darkMode ? const Color(0xFF475569) : const Color(0xFF94A3B8),
              ConcreteZone.partiallyConfined => const Color(0xFF0284C7).withValues(alpha: 0.55 + 0.35 * progress),
              ConcreteZone.highlyConfined => Color.lerp(const Color(0xFFF59E0B), const Color(0xFFFDE047), progress * 0.7)!,
            };
          }
        } else if (f.kind.startsWith('steel')) {
          final ur = (df.sigmaVmMpa / math.max(1.0, cfg.material.fySteelMpa)).clamp(0.0, 1.2);
          col = (tFrac > 0.45 && df.epsX > 0.005)
              ? const Color(0xFFFFFFFF) // Tia đứt cánh kéo ở GĐ5!
              : (ur >= 0.98
                  ? const Color(0xFFFF006E)
                  : Color.lerp(const Color(0xFFEF4444), const Color(0xFFFF6B00), ur)!);
        } else {
          col = (tFrac > 0.45 && df.epsX > 0.005) ? const Color(0xFFFFD700) : const Color(0xFF10B981);
        }

        pFill.color = col;
        final expScale = (f.kind == 'concrete' && f.zone == ConcreteZone.unconfined)
            ? (1.0 + latExpandPx / math.max(40.0, 0.5 * g.bMm * sc))
            : 1.0;
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
        Paint()..color = tFrac > 0.5 ? const Color(0xFFFFD700) : const Color(0xFF10B981)..style = PaintingStyle.stroke..strokeWidth = 2.0,
      );
      final hLen = 7.0 + 11.0 * magNorm;
      final hP = Paint()..color = const Color(0xFF34D399)..strokeWidth = 1.6;
      _arrow(canvas, sRect.topLeft - Offset(hLen, hLen) * 0.65, sRect.topLeft + const Offset(2, 2), hP);
      _arrow(canvas, sRect.topRight + Offset(hLen, -hLen) * 0.65, sRect.topRight + const Offset(-2, 2), hP);
      _arrow(canvas, sRect.bottomLeft + Offset(-hLen, hLen) * 0.65, sRect.bottomLeft + const Offset(2, -2), hP);
      _arrow(canvas, sRect.bottomRight + Offset(hLen, hLen) * 0.65, sRect.bottomRight + const Offset(-2, -2), hP);
    }

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

      final aLen = 7.0 + 8.0 * progress + 12.0 * magNorm;
      final fP = Paint()..color = const Color(0xFFFFF59D)..strokeWidth = 1.8 + 0.8 * magNorm;
      _arrow(canvas, Offset(cx + 0.5 * baPx + aLen, yCorePx), Offset(cx + 0.5 * baPx - 2, yCorePx), fP);
      _arrow(canvas, Offset(cx - 0.5 * baPx - aLen, yCorePx), Offset(cx - 0.5 * baPx + 2, yCorePx), fP);

      if (isBeam) {
        final stH = math.max(10.0, math.min(24.0, cfg.studHeightMm * sc));
        final yTopFl = yCorePx - 0.5 * haPx;
        final nR = cfg.studRows.clamp(1, 2);
        final zOffs = nR == 1 ? [0.0] : [-0.24 * baPx, 0.24 * baPx];
        for (final zo in zOffs) {
          final sx = cx + zo;
          canvas.drawCircle(Offset(sx, yTopFl - stH * 0.45), 6.0 + 5.0 * progress + 5.0 * magNorm,
              Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.24 + 0.26 * progress));
          canvas.drawLine(Offset(sx, yTopFl), Offset(sx, yTopFl - stH),
              Paint()..color = tFrac > 0.5 ? const Color(0xFFFF2D55) : const Color(0xFFFFD700)..strokeWidth = 3.0);
          canvas.drawLine(Offset(sx - 4.8, yTopFl - stH), Offset(sx + 4.8, yTopFl - stH),
              Paint()..color = tFrac > 0.5 ? const Color(0xFFFF2D55) : const Color(0xFFFFD700)..strokeWidth = 3.2);
        }

        // Vết nứt cắt tách Weng xé hoàn toàn ra mép ngoài ở GĐ5!
        final splitFrac = tFrac > 0.1 ? 1.0 : (dis.splitUr * (0.85 + 0.55 * magNorm)).clamp(0.18, 1.0);
        final spHalfH = (0.8 + 3.2 * magNorm * progress + 2.5 * tFrac).clamp(0.8, 6.0);
        final ySp = yCorePx + 0.5 * haPx;
        final xEdgeR = cx + 0.5 * g.bMm * sc + latExpandPx;
        final xEdgeL = cx - 0.5 * g.bMm * sc - latExpandPx;
        final spColor = stageIdx >= 4 ? const Color(0xFFFF2D55) : const Color(0xFFF97316);
        final xTipR = cx + 0.5 * baPx + (xEdgeR - (cx + 0.5 * baPx)) * splitFrac;
        final xTipL = cx - 0.5 * baPx - ((cx - 0.5 * baPx) - xEdgeL) * splitFrac;
        canvas.drawPath(
          Path()..moveTo(cx + 0.5 * baPx, ySp - spHalfH)..lineTo(xTipR, ySp)..lineTo(cx + 0.5 * baPx, ySp + spHalfH)..close(),
          Paint()..color = spColor.withValues(alpha: 0.88),
        );
        canvas.drawPath(
          Path()..moveTo(cx - 0.5 * baPx, ySp - spHalfH)..lineTo(xTipL, ySp)..lineTo(cx - 0.5 * baPx, ySp + spHalfH)..close(),
          Paint()..color = spColor.withValues(alpha: 0.88),
        );
      }
    }

    // Vòng ngắm Focus Target
    final pPx = Offset(cx + probeZMm * sc, cy - probeYMm * sc);
    canvas.drawCircle(pPx, 9.0, Paint()..color = const Color(0xFF06B6D4).withValues(alpha: 0.25));
    canvas.drawCircle(pPx, 5.5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0);
    canvas.drawLine(pPx - const Offset(11, 0), pPx + const Offset(11, 0), Paint()..color = Colors.white..strokeWidth = 1.4);
    canvas.drawLine(pPx - const Offset(0, 11), pPx + const Offset(0, 11), Paint()..color = Colors.white..strokeWidth = 1.4);

    final leg = [
      (const Color(0xFFFDE047), tr(lang, 'Vùng 2: Lõi H', 'Z2: H-Core')),
      (const Color(0xFF0284C7), tr(lang, 'Vùng 1: Đai', 'Z1: Hoops')),
      (const Color(0xFF64748B), tr(lang, 'Vùng 0: Vỏ', 'Z0: Cover')),
      (const Color(0xFFF43F5E), tr(lang, 'Nứt / Đứt', 'Crack/Fail')),
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
// BIỂU ĐỒ 1 (MỚI!): ĐƯỜNG CONG PHÁ HOẠI 5 GIAI ĐOẠN TỚI ĐỨT GÃY KẾT THÚC!
// ============================================================================
class _FailurePath5StagePainter extends CustomPainter {
  final List<FailurePathPoint> curve;
  final FailurePathPoint nowPt;
  final bool isBeam;
  final bool darkMode;
  final AppLang lang;

  const _FailurePath5StagePainter({
    required this.curve,
    required this.nowPt,
    required this.isBeam,
    required this.darkMode,
    required this.lang,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 50.0, padB = 26.0, padT = 18.0, padR = 14.0;
    final pw = math.max(30.0, size.width - padL - padR);
    final ph = math.max(30.0, size.height - padT - padB);
    final fg = darkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final grid = darkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    if (curve.length < 2) return;

    final maxDisp = math.max(1.0, curve.fold<double>(0.1, (a, b) => math.max(a, b.dispMm)) * 1.06);
    final maxLoad = math.max(10.0, curve.fold<double>(1.0, (a, b) => math.max(a, b.loadKn)) * 1.12);
    double xOf(double d) => padL + (d / maxDisp).clamp(0.0, 1.0) * pw;
    double yOf(double p) => padT + ph - (p / maxLoad).clamp(0.0, 1.0) * ph;

    // 1. Tô nền 5 vùng giai đoạn (Đàn hồi | Nứt | Phi tuyến | Cực hạn | Suy giảm & Đứt gãy)
    double dispAtProg(double pr) {
      final idx = (pr * (curve.length - 1)).round().clamp(0, curve.length - 1);
      return curve[idx].dispMm;
    }

    final bands = [
      (0.0, 0.22, const Color(0xFF10B981)),
      (0.22, 0.48, const Color(0xFF38BDF8)),
      (0.48, 0.72, const Color(0xFFF59E0B)),
      (0.72, 0.86, const Color(0xFFF97316)),
      (0.86, 1.00, const Color(0xFFEF4444)),
    ];
    for (final (p0, p1, col) in bands) {
      canvas.drawRect(
        Rect.fromLTRB(xOf(dispAtProg(p0)), padT, xOf(dispAtProg(p1)), padT + ph),
        Paint()..color = col.withValues(alpha: darkMode ? 0.11 : 0.08),
      );
    }

    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + ph), Paint()..color = grid..strokeWidth = 1.2);
    canvas.drawLine(Offset(padL, padT + ph), Offset(padL + pw, padT + ph), Paint()..color = grid..strokeWidth = 1.2);

    // 2. Đường toàn bộ quỹ đạo phá hoại (nét mờ dự báo) + đoạn đã kéo tới hiện tại (nét đậm rực)
    final fullPath = Path();
    final activePath = Path();
    bool activeStarted = false;
    for (int i = 0; i < curve.length; i++) {
      final pt = curve[i];
      final o = Offset(xOf(pt.dispMm), yOf(pt.loadKn));
      if (i == 0) {
        fullPath.moveTo(o.dx, o.dy);
      } else {
        fullPath.lineTo(o.dx, o.dy);
      }
      if (pt.progress <= nowPt.progress + 0.001) {
        if (!activeStarted) {
          activePath.moveTo(o.dx, o.dy);
          activeStarted = true;
        } else {
          activePath.lineTo(o.dx, o.dy);
        }
      }
    }
    final curOff = Offset(xOf(nowPt.dispMm), yOf(nowPt.loadKn));
    if (activeStarted) activePath.lineTo(curOff.dx, curOff.dy);

    canvas.drawPath(fullPath, Paint()..color = fg.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 1.6);
    canvas.drawPath(activePath, Paint()..color = const Color(0xFF06B6D4)..style = PaintingStyle.stroke..strokeWidth = 2.8);

    // 3. Dấu ✕ ĐỨT GÃY tại điểm cuối cùng của đường cong
    final endOff = Offset(xOf(curve.last.dispMm), yOf(curve.last.loadKn));
    final xP = Paint()..color = const Color(0xFFEF4444)..strokeWidth = 2.4;
    canvas.drawLine(endOff - const Offset(5, 5), endOff + const Offset(5, 5), xP);
    canvas.drawLine(endOff + const Offset(-5, 5), endOff + const Offset(5, -5), xP);

    // 4. Chấm sáng động tại trạng thái hiện tại
    canvas.drawCircle(curOff, 8.0, Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.32));
    canvas.drawCircle(curOff, 4.5, Paint()..color = nowPt.stage == 5 ? const Color(0xFFEF4444) : const Color(0xFFFFD700));
    canvas.drawCircle(curOff, 4.5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.2);

    _txt(canvas, Offset(2, padT), isBeam ? 'P(kN)' : 'N(kN)', fg);
    _txt(canvas, Offset(padL + 4, padT - 16), tr(lang, 'Đàn hồi→Nứt→Phi tuyến→Đứt ✕', 'Elast→Crack→Nonlin→Fail ✕'), const Color(0xFFF59E0B));
    _txt(canvas, Offset(padL + pw * 0.22, padT + ph + 5),
        '${isBeam ? "δ" : "Δ"}=${nowPt.dispMm.toStringAsFixed(1)} mm | ${nowPt.loadKn.toStringAsFixed(0)} kN', fg);
  }

  void _txt(Canvas c, Offset p, String s, Color col) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: col, fontSize: 12.0, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, p);
  }

  @override
  bool shouldRepaint(covariant _FailurePath5StagePainter old) => true;
}

// ============================================================================
// BIỂU ĐỒ 2: DÍNH BÁM – TRƯỢT τ_b(s) ĐẾN ĐỨT CẮT ĐINH NEO + CHẤM ĐỘNG
// ============================================================================
class _BondSlipCurvePainter extends CustomPainter {
  final SrcAnalysisResult result;
  final DissectionResult dis;
  final double progress;
  final bool darkMode;
  final AppLang lang;

  const _BondSlipCurvePainter({
    required this.result,
    required this.dis,
    required this.progress,
    required this.darkMode,
    required this.lang,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 48.0, padB = 26.0, padT = 18.0, padR = 10.0;
    final pw = math.max(30.0, size.width - padL - padR);
    final ph = math.max(30.0, size.height - padT - padB);
    final fg = darkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final grid = darkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + ph), Paint()..color = grid..strokeWidth = 1.2);
    canvas.drawLine(Offset(padL, padT + ph), Offset(padL + pw, padT + ph), Paint()..color = grid..strokeWidth = 1.2);

    final sMax = math.max(2.6, dis.slipMm * 1.25);
    final tauMax = math.max(dis.tauRdMpa * 2.4, dis.tauBondMpa * 1.45).clamp(0.8, 6.0);
    double xOf(double s) => padL + (s / sMax).clamp(0.0, 1.0) * pw;
    double yOf(double tau) => padT + ph - (tau / tauMax).clamp(0.0, 1.0) * ph;

    final yRd = yOf(dis.tauRdMpa);
    canvas.drawLine(Offset(padL, yRd), Offset(padL + pw, yRd), Paint()..color = const Color(0xFF06B6D4).withValues(alpha: 0.65)..strokeWidth = 1.1);

    // 1. Dính bám thuần không đinh neo
    final bondPath = Path();
    for (int i = 0; i <= 40; i++) {
      final s = sMax * i / 40.0;
      final double tau = s <= 0.03 ? dis.tauRdMpa * (s / 0.03) : dis.tauRdMpa * (0.40 + 0.60 * math.exp(-4.0 * (s - 0.03)));
      if (i == 0) {
        bondPath.moveTo(xOf(s), yOf(tau));
      } else {
        bondPath.lineTo(xOf(s), yOf(tau));
      }
    }
    canvas.drawPath(bondPath, Paint()..color = const Color(0xFF64748B)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // 2. Đường cong Ollgaard Có Đinh neo + Nhánh đứt cắt đinh neo sau s_u = 1.5 mm!
    final studPath = Path();
    final peakTot = math.max(dis.tauRdMpa * 1.9, dis.tauBondMpa * 1.2);
    for (int i = 0; i <= 48; i++) {
      final s = sMax * i / 48.0;
      final oll = math.pow(1.0 - math.exp(-2.8 * s), 0.42).toDouble();
      double tau = math.min(tauMax * 0.94, 0.35 * dis.tauRdMpa * math.min(1.0, s / 0.025) + peakTot * 0.85 * oll);
      if (s > 1.35) {
        // Suy giảm do đứt cắt đinh neo ở độ trượt lớn!
        tau *= math.max(0.18, 1.0 - 0.72 * ((s - 1.35) / math.max(0.6, sMax - 1.35)));
      }
      if (i == 0) {
        studPath.moveTo(xOf(s), yOf(tau));
      } else {
        studPath.lineTo(xOf(s), yOf(tau));
      }
    }
    canvas.drawPath(studPath, Paint()..color = const Color(0xFFF59E0B)..style = PaintingStyle.stroke..strokeWidth = 2.2);

    final dot = Offset(xOf(dis.slipMm), yOf(dis.tauBondMpa));
    canvas.drawCircle(dot, 7.5, Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.30));
    canvas.drawCircle(dot, 4.2, Paint()..color = const Color(0xFFEF4444));
    canvas.drawCircle(dot, 4.2, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.1);

    _txt(canvas, Offset(padL + 3, math.max(padT + 2, yRd - 15)), 'τ_Rd=${dis.tauRdMpa.toStringAsFixed(2)}', const Color(0xFF06B6D4));
    _txt(canvas, Offset(padL + pw * 0.36, padT - 15), 's=${dis.slipMm.toStringAsFixed(3)} mm', const Color(0xFFEF4444));
    _txt(canvas, Offset(2, padT), 'τ(MPa)', fg);
    _txt(canvas, Offset(padL + pw * 0.28, padT + ph + 5), tr(lang, 'Trượt s (mm)', 'Slip s (mm)'), fg);
  }

  void _txt(Canvas c, Offset p, String s, Color col) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: col, fontSize: 12.0, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, p);
  }

  @override
  bool shouldRepaint(covariant _BondSlipCurvePainter old) => true;
}

// ============================================================================
// BIỂU ĐỒ 3: ĐƯỜNG CONG σ_c – ε_c CỦA 3 VÙNG KIỀM CHẾ (TỚI 14‰ PHÁ HOẠI!)
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

    const epsMax = 0.014; // 14 ‰ để thấy hết GĐ5 vỡ vỏ → suy giảm lõi → đứt gãy!
    final sigMax = math.max(20.0, 0.85 * conf.etaHsc * m.fcMpa * conf.kh * 1.15);
    double xOf(double ePos) => padL + (ePos / epsMax).clamp(0.0, 1.0) * pw;
    double yOf(double sPos) => padT + ph - (sPos / sigMax).clamp(0.0, 1.0) * ph;

    final zones = [
      (ConcreteZone.unconfined, const Color(0xFF94A3B8)),
      (ConcreteZone.partiallyConfined, const Color(0xFF38BDF8)),
      (ConcreteZone.highlyConfined, const Color(0xFFFDE047)),
    ];

    final curEps = (-dis.epsMin).clamp(0.0, epsMax);
    final xCur = xOf(curEps);
    canvas.drawLine(Offset(xCur, padT), Offset(xCur, padT + ph), Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.48)..strokeWidth = 1.4);

    for (final (z, col) in zones) {
      final path = Path();
      for (int i = 0; i <= 48; i++) {
        final e = epsMax * i / 48.0;
        final r = SrcNonlinearEngine.concreteLaw(-e, m, z, conf, true);
        final pt = Offset(xOf(e), yOf(-r.sig));
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = z == ConcreteZone.highlyConfined ? 2.2 : 1.6);

      final rc = SrcNonlinearEngine.concreteLaw(-curEps, m, z, conf, true);
      final dp = Offset(xCur, yOf(-rc.sig));
      canvas.drawCircle(dp, 4.0, Paint()..color = col);
      canvas.drawCircle(dp, 4.0, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }

    _txt(canvas, Offset(4, padT), 'σ_c', fg);
    _txt(canvas, Offset(padL + pw * 0.25, padT + ph + 5), 'ε_c = ${(curEps * 1000).toStringAsFixed(2)} ‰', const Color(0xFFEF4444));
    _txt(canvas, Offset(padL + 2, padT - 15), 'Kh=${conf.kh.toStringAsFixed(2)}', const Color(0xFFFDE047));
    _txt(canvas, Offset(padL + 74, padT - 15), 'Kp=${conf.kp.toStringAsFixed(2)}', const Color(0xFF38BDF8));
    _txt(canvas, Offset(padL + 146, padT - 15), tr(lang, 'Vỏ', 'Cov'), const Color(0xFF94A3B8));
  }

  void _txt(Canvas c, Offset p, String s, Color col) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: col, fontSize: 12.0, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, p);
  }

  @override
  bool shouldRepaint(covariant _ThreeZoneConstitutivePainter old) => true;
}

// ============================================================================
// BIỂU ĐỒ 4: CHUYỂN DỊCH CHIA TẢI THÉP HÌNH ↔ BÊ TÔNG (0% → ĐỨT GÃY KẾT THÚC)
// ============================================================================
class _LoadRedistributionPainter extends CustomPainter {
  final List<LoadRedistPoint> curve;
  final double progress;
  final bool darkMode;
  final AppLang lang;

  const _LoadRedistributionPainter({required this.curve, required this.progress, required this.darkMode, required this.lang});

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 44.0, padB = 26.0, padT = 18.0, padR = 10.0;
    final pw = math.max(30.0, size.width - padL - padR);
    final ph = math.max(30.0, size.height - padT - padB);
    final fg = darkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    if (curve.length < 2) return;

    double xOf(double uf) => padL + uf.clamp(0.0, 1.0) * pw;
    double yOf(double pct) => padT + ph - (pct / 100.0).clamp(0.0, 1.0) * ph;

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

    final xc = xOf(progress);
    canvas.drawLine(Offset(xc, padT), Offset(xc, padT + ph), Paint()..color = const Color(0xFFFFD700)..strokeWidth = 2.0);

    _txt(canvas, Offset(2, padT), '100%', fg);
    _txt(canvas, Offset(10, padT + ph - 12), '0%', fg);
    _txt(canvas, Offset(padL + 2, padT - 15), tr(lang, 'Đỏ:Thép H | Xanh:BT | Lá:Thép', 'Red:Steel | Blue:RC | Grn:Reb'), fg);
    _txt(canvas, Offset(padL + pw * 0.16, padT + ph + 5), '${tr(lang, "Tiến trình", "Prog")}: ${(progress * 100).toStringAsFixed(0)}%', const Color(0xFFF59E0B));
  }

  void _txt(Canvas c, Offset p, String s, Color col) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: col, fontSize: 12.0, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, p);
  }

  @override
  bool shouldRepaint(covariant _LoadRedistributionPainter old) => true;
}
