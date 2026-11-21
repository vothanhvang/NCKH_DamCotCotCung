// ============================================================================
// KHUNG NHÌN MÔ PHỎNG 3D KIỂU ANSYS MECHANICAL — DẦM & CỘT BÊ TÔNG CỐT CỨNG
// ============================================================================
// Hỗ trợ đầy đủ thao tác tương tác 3D chuyên nghiệp:
//   • Xoay tự do 360° (kéo trái / 1 ngón) • Zoom (cuộn / chụm 2 ngón) • Pan (kéo phải / nút Pan)
//   • Cắt Phẫu thuật ngang 3D (Transverse Clipping Plane tại x/L) bóc tách để
//     soi trực tiếp toàn bộ lưới thớ ứng suất σ_x / biến dạng ε_x / trục trung hòa!
//   • Cắt Phẫu thuật bổ dọc 3D (Longitudinal Cutaway) chẻ dọc thân bê tông lộ rõ
//     lõi thép hình chữ H / chữ thập / ống CFST, cốt thép dọc, cốt đai & đinh neo!
//   • Chế độ X-Quang (bê tông bán trong suốt), thang màu cầu vồng ANSYS,
//     hệ số phóng đại biến dạng, phát hoạt hình gia tăng tải (0% → 100%).
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/src_engine.dart';
import 'ansys_colorbar.dart';

class _Vec3 {
  final double x, y, z;
  const _Vec3(this.x, this.y, this.z);
}

class _Cam3D {
  final double yaw, pitch, zoom;
  final Offset pan;
  final double spanMm;
  final Size viewport;
  final bool isVerticalColumn;

  const _Cam3D({
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.pan,
    required this.spanMm,
    required this.viewport,
    required this.isVerticalColumn,
  });

  ({Offset pt, double depth}) project(_Vec3 p) {
    // Chuẩn hóa về tâm 0
    final sx = p.x;
    final sy = p.y;
    final sz = p.z;
    // Xoay quanh trục đứng (Y màn hình) theo yaw, sau đó nghiêng theo pitch
    final cy = math.cos(yaw), sya = math.sin(yaw);
    final cp = math.cos(pitch), sp = math.sin(pitch);

    final rx = sx * cy + sz * sya;
    final rz1 = -sx * sya + sz * cy;
    final ry = sy * cp - rz1 * sp;
    final rz = sy * sp + rz1 * cp;

    final baseScale = math.min(viewport.width, viewport.height) / math.max(1200.0, spanMm * 1.15);
    final sc = baseScale * zoom;
    final persp = 1.0 / (1.0 + rz / math.max(3000.0, spanMm * 3.8));
    final cx = viewport.width * 0.5 + pan.dx + rx * sc * persp;
    final cyScreen = viewport.height * 0.52 + pan.dy - ry * sc * persp;
    return (pt: Offset(cx, cyScreen), depth: rz);
  }
}

class SrcViewport3D extends StatefulWidget {
  final SrcAnalysisResult result;
  final ContourField field;
  final double probeXNorm;
  final double deformScale;
  final double loadStepFraction;
  final bool darkMode;
  final AppLang lang;
  final ValueChanged<double> onProbeXChanged;
  final ValueChanged<double> onDeformScaleChanged;

  const SrcViewport3D({
    super.key,
    required this.result,
    required this.field,
    required this.probeXNorm,
    required this.deformScale,
    required this.loadStepFraction,
    required this.darkMode,
    required this.lang,
    required this.onProbeXChanged,
    required this.onDeformScaleChanged,
  });

  @override
  State<SrcViewport3D> createState() => _SrcViewport3DState();
}

class _SrcViewport3DState extends State<SrcViewport3D> {
  double _yaw = -0.52;
  double _pitch = 0.28;
  double _zoom = 1.08;
  Offset _pan = Offset.zero;
  double _baseZoom = 1.08;
  Offset _lastFocal = Offset.zero;
  bool _panMode = false;
  bool _rightBtn = false;
  bool _xRay = true;
  bool _clipTransverse = false; // Phẫu thuật cắt bỏ nửa trước sau mặt phẳng x/L
  bool _clipLongitudinal = false; // Phẫu thuật bổ dọc nửa tiết diện bê tông (z > 0)
  bool _showColorBar = true;
  bool _showRebarAndStirrups = true;

  void _setView(double y, double p) => setState(() {
        _yaw = y;
        _pitch = p;
      });

  void _resetView() => setState(() {
        _yaw = -0.52;
        _pitch = 0.28;
        _zoom = 1.08;
        _pan = Offset.zero;
      });

  ({String title, String unit, double minV, double maxV}) _fieldMeta() {
    final l = widget.lang;
    final dis = SrcNonlinearEngine.dissectSection(widget.result, widget.probeXNorm);
    switch (widget.field) {
      case ContourField.stressSigmaX:
        return (
          title: tr(l, 'Ứng suất pháp σ_x', 'Normal Stress σ_x'),
          unit: 'MPa',
          minV: math.min(-widget.result.config.material.fcMpa, dis.sigMinMpa),
          maxV: math.max(widget.result.config.material.fySteelMpa * 0.6, dis.sigMaxMpa),
        );
      case ContourField.strainEpsX:
        return (
          title: tr(l, 'Biến dạng dọc ε_x', 'Axial Strain ε_x'),
          unit: '‰',
          minV: math.min(-3.5, dis.epsMin * 1000.0),
          maxV: math.max(2.5, dis.epsMax * 1000.0),
        );
      case ContourField.vonMises:
        final mx = dis.fibers.fold<double>(10.0, (a, b) => math.max(a, b.sigmaVmMpa));
        return (title: 'Von Mises σ_vM', unit: 'MPa', minV: 0.0, maxV: mx);
      case ContourField.momentOrAxial:
        final mx = widget.result.profileMKnm.fold<double>(1.0, (a, b) => math.max(a, b.abs()));
        return (
          title: tr(l, 'Mô-men uốn M_z', 'Bending Moment M_z'),
          unit: 'kN·m',
          minV: 0.0,
          maxV: mx,
        );
      case ContourField.deflection:
        final mx = widget.result.profileDeflMm.fold<double>(0.5, (a, b) => math.max(a, b.abs()));
        return (title: tr(l, 'Chuyển vị δ', 'Displacement δ'), unit: 'mm', minV: 0.0, maxV: mx);
      case ContourField.confinementOrCrack:
        return (
          title: tr(l, 'Vùng giam giữ / Nứt', 'Confinement / Crack'),
          unit: 'Zone',
          minV: 0.0,
          maxV: 2.0,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.result;
    final l = widget.lang;
    final dark = widget.darkMode;
    final meta = _fieldMeta();
    final isCol = res.config.kind == MemberKind.column;
    final bgTop = dark ? const Color(0xFF060B18) : const Color(0xFFF1F5F9);
    final bgBot = dark ? const Color(0xFF0F1B33) : const Color(0xFFE2E8F0);
    final panelBg = dark ? const Color(0xCC0D162A) : const Color(0xE6FFFFFF);
    final borderCol = dark ? const Color(0xFF283B5E) : const Color(0xFFCBD5E1);
    final textCol = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sz = Size(constraints.maxWidth, constraints.maxHeight);
        final cam = _Cam3D(
          yaw: _yaw,
          pitch: _pitch,
          zoom: _zoom,
          pan: _pan,
          spanMm: res.config.lengthMm,
          viewport: sz,
          isVerticalColumn: isCol,
        );
        final disAtCut = SrcNonlinearEngine.dissectSection(res, widget.probeXNorm);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgTop, bgBot],
            ),
          ),
          child: Stack(
            children: [
              // Canvas tương tác 3D
              Listener(
                onPointerDown: (e) => _rightBtn = (e.buttons & kSecondaryMouseButton) != 0,
                onPointerUp: (_) => _rightBtn = false,
                onPointerSignal: (s) {
                  if (s is PointerScrollEvent) {
                    setState(() {
                      final factor = s.scrollDelta.dy > 0 ? 0.90 : 1.11;
                      _zoom = (_zoom * factor).clamp(0.45, 3.8);
                    });
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (d) {
                    _baseZoom = _zoom;
                    _lastFocal = d.localFocalPoint;
                  },
                  onScaleUpdate: (d) {
                    setState(() {
                      final delta = d.localFocalPoint - _lastFocal;
                      _lastFocal = d.localFocalPoint;
                      if (d.pointerCount >= 2) {
                        _zoom = (_baseZoom * d.scale).clamp(0.45, 3.8);
                        _pan += delta;
                      } else if (_panMode || _rightBtn) {
                        _pan += delta;
                      } else {
                        _yaw += delta.dx * 0.0085;
                        _pitch = (_pitch + delta.dy * 0.0075).clamp(-1.35, 1.35);
                      }
                    });
                  },
                  onTapUp: (details) {
                    // Nhấp vào thân dầm/cột để đặt nhanh mặt cắt phẫu thuật 3D
                    final tap = details.localPosition;
                    final L = res.config.lengthMm;
                    double bestT = widget.probeXNorm;
                    double bestDist = 36.0;
                    for (int i = 0; i <= 40; i++) {
                      final t = i / 40.0;
                      final p3 = isCol
                          ? _Vec3(0, (t - 0.5) * L, 0)
                          : _Vec3((t - 0.5) * L, 0, 0);
                      final proj = cam.project(p3).pt;
                      final dist = (proj - tap).distance;
                      if (dist < bestDist) {
                        bestDist = dist;
                        bestT = t;
                      }
                    }
                    if (bestDist < 36.0) widget.onProbeXChanged(bestT);
                  },
                  child: CustomPaint(
                    size: sz,
                    painter: _Src3DPainter(
                      result: res,
                      disAtCut: disAtCut,
                      cam: cam,
                      field: widget.field,
                      minV: meta.minV,
                      maxV: meta.maxV,
                      probeXNorm: widget.probeXNorm,
                      deformScale: widget.deformScale * widget.loadStepFraction,
                      xRay: _xRay,
                      clipTransverse: _clipTransverse,
                      clipLongitudinal: _clipLongitudinal,
                      showRebar: _showRebarAndStirrups,
                      darkMode: dark,
                      lang: l,
                    ),
                  ),
                ),
              ),

              // Thang màu ANSYS góc trên trái
              Positioned(
                top: 10,
                left: 10,
                child: _showColorBar
                    ? AnsysColorBar(
                        title: meta.title,
                        unit: meta.unit,
                        minVal: meta.minV,
                        maxVal: meta.maxV,
                        darkMode: dark,
                        onHide: () => setState(() => _showColorBar = false),
                      )
                    : ColorBarRestoreButton(
                        darkMode: dark,
                        onShow: () => setState(() => _showColorBar = true),
                      ),
              ),

              // Thanh công cụ Camera & Phẫu thuật 3D góc trên phải
              Positioned(
                top: 10,
                right: 10,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: math.min(540, constraints.maxWidth - 150)),
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    alignment: WrapAlignment.end,
                    children: [
                      _camBtn('ISO', () => _setView(-0.52, 0.28), panelBg, borderCol, textCol),
                      _camBtn(tr(l, 'Mặt đứng', 'Front'), () => _setView(0.0, 0.04), panelBg, borderCol, textCol),
                      _camBtn(tr(l, 'Mặt cắt', 'Section'), () => _setView(-1.54, 0.05), panelBg, borderCol, textCol),
                      _camBtn(tr(l, 'Bằng', 'Top'), () => _setView(0.0, 1.32), panelBg, borderCol, textCol),
                      _camBtn('Fit', _resetView, panelBg, borderCol, textCol),
                      _togglePill(
                        Icons.pan_tool_outlined,
                        'Pan',
                        _panMode,
                        () => setState(() => _panMode = !_panMode),
                        panelBg,
                        borderCol,
                        textCol,
                      ),
                      _togglePill(
                        Icons.blur_on,
                        tr(l, 'X-Quang', 'X-Ray'),
                        _xRay,
                        () => setState(() => _xRay = !_xRay),
                        panelBg,
                        borderCol,
                        textCol,
                      ),
                      _togglePill(
                        Icons.content_cut,
                        tr(l, 'Cắt ngang 3D', 'Slice x/L'),
                        _clipTransverse,
                        () => setState(() => _clipTransverse = !_clipTransverse),
                        panelBg,
                        borderCol,
                        textCol,
                        activeColor: const Color(0xFFF59E0B),
                      ),
                      _togglePill(
                        Icons.view_column_outlined,
                        tr(l, 'Bổ dọc 3D', 'Half-Cut'),
                        _clipLongitudinal,
                        () => setState(() => _clipLongitudinal = !_clipLongitudinal),
                        panelBg,
                        borderCol,
                        textCol,
                        activeColor: const Color(0xFFEC4899),
                      ),
                      _togglePill(
                        Icons.grid_on,
                        tr(l, 'Cốt thép', 'Rebar'),
                        _showRebarAndStirrups,
                        () => setState(() => _showRebarAndStirrups = !_showRebarAndStirrups),
                        panelBg,
                        borderCol,
                        textCol,
                      ),
                    ],
                  ),
                ),
              ),

              // Thanh điều khiển Mặt cắt phẫu thuật x/L & Hệ số phóng đại biến dạng dưới cùng
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: panelBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      // Slider Phẫu thuật x/L
                      SizedBox(
                        width: math.min(310, constraints.maxWidth - 44),
                        child: Row(
                          children: [
                            const Icon(Icons.medical_services_outlined, size: 15, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 6),
                            Text(
                              '${tr(l, "Phẫu thuật", "Cut")} x/L=${widget.probeXNorm.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: textCol),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: widget.probeXNorm,
                                  min: 0.02,
                                  max: 0.98,
                                  activeColor: const Color(0xFFF59E0B),
                                  onChanged: widget.onProbeXChanged,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Slider Phóng đại biến dạng
                      SizedBox(
                        width: math.min(220, constraints.maxWidth - 44),
                        child: Row(
                          children: [
                            const Icon(Icons.waves, size: 15, color: Color(0xFF06B6D4)),
                            const SizedBox(width: 5),
                            Text(
                              'Scale ×${widget.deformScale.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 12.0, color: textCol),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: widget.deformScale.clamp(0.0, 60.0),
                                  min: 0.0,
                                  max: 60.0,
                                  activeColor: const Color(0xFF06B6D4),
                                  onChanged: widget.onDeformScaleChanged,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tóm tắt nhanh tại mặt cắt đang phẫu thuật
                      Text(
                        'M=${disAtCut.mzKnm.toStringAsFixed(1)} kN·m | N=${disAtCut.nKn.toStringAsFixed(0)} kN | x_NA=${disAtCut.xNaMm.toStringAsFixed(0)} mm | σ=[${disAtCut.sigMinMpa.toStringAsFixed(0)}, ${disAtCut.sigMaxMpa.toStringAsFixed(0)}] MPa',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontFamily: 'DejaVuSansMono',
                          color: dark ? const Color(0xFF7DD3FC) : const Color(0xFF0F3D6E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _camBtn(String label, VoidCallback onTap, Color bg, Color border, Color fg) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: border)),
        child: Text(label, style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }

  Widget _togglePill(
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
    Color bg,
    Color border,
    Color fg, {
    Color activeColor = const Color(0xFF06B6D4),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.22) : bg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: active ? activeColor : border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? activeColor : fg.withValues(alpha: 0.75)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: active ? activeColor : fg)),
          ],
        ),
      ),
    );
  }
}

class _QuadFace {
  final List<Offset> pts;
  final double depth;
  final Color fill;
  final Color stroke;
  final double strokeW;
  const _QuadFace(this.pts, this.depth, this.fill, this.stroke, [this.strokeW = 0.7]);
}

class _Src3DPainter extends CustomPainter {
  final SrcAnalysisResult result;
  final DissectionResult disAtCut;
  final _Cam3D cam;
  final ContourField field;
  final double minV, maxV;
  final double probeXNorm, deformScale;
  final bool xRay, clipTransverse, clipLongitudinal, showRebar, darkMode;
  final AppLang lang;

  const _Src3DPainter({
    required this.result,
    required this.disAtCut,
    required this.cam,
    required this.field,
    required this.minV,
    required this.maxV,
    required this.probeXNorm,
    required this.deformScale,
    required this.xRay,
    required this.clipTransverse,
    required this.clipLongitudinal,
    required this.showRebar,
    required this.darkMode,
    required this.lang,
  });

  _Vec3 _toWorld(double sMm, double yMm, double zMm, double deflMm) {
    final L = result.config.lengthMm;
    final sCent = sMm - 0.5 * L;
    final dScaled = deflMm * deformScale;
    if (result.config.kind == MemberKind.column) {
      // Cột đứng dọc theo trục Y thế giới; độ võng ngang lệch theo trục X
      return _Vec3(yMm + dScaled, sCent, zMm);
    }
    // Dầm nằm ngang dọc trục X thế giới; độ võng theo trục Y
    return _Vec3(sCent, yMm + dScaled, zMm);
  }

  double _deflAt(double sMm) {
    final L = result.config.lengthMm;
    if (result.profileXMm.isEmpty) return 0.0;
    final target = sMm.clamp(0.0, L);
    for (int i = 0; i < result.profileXMm.length - 1; i++) {
      if (target >= result.profileXMm[i] && target <= result.profileXMm[i + 1]) {
        final w = (target - result.profileXMm[i]) / math.max(1e-6, result.profileXMm[i + 1] - result.profileXMm[i]);
        return result.profileDeflMm[i] + w * (result.profileDeflMm[i + 1] - result.profileDeflMm[i]);
      }
    }
    return 0.0;
  }

  Color _colorForVal(double v) {
    final t = ((v - minV) / math.max(1e-9, maxV - minV)).clamp(0.0, 1.0);
    return ansysRainbowColor(t);
  }

  Color _fiberColor(DissectedFiber df) {
    switch (field) {
      case ContourField.stressSigmaX:
        return _colorForVal(df.sigmaXMpa);
      case ContourField.strainEpsX:
        return _colorForVal(df.epsX * 1000.0);
      case ContourField.vonMises:
        return _colorForVal(df.sigmaVmMpa);
      case ContourField.confinementOrCrack:
        if (df.cell.kind.startsWith('steel')) return const Color(0xFFEF4444);
        if (df.cell.kind == 'rebar') return const Color(0xFF22C55E);
        if (df.stateEn.contains('Cracked')) return const Color(0xFFF43F5E);
        return switch (df.cell.zone) {
          ConcreteZone.unconfined => const Color(0xFF94A3B8),
          ConcreteZone.partiallyConfined => const Color(0xFF38BDF8),
          ConcreteZone.highlyConfined => const Color(0xFFF59E0B),
        };
      case ContourField.momentOrAxial:
      case ContourField.deflection:
        return _colorForVal(df.sigmaXMpa);
    }
  }

  void _addBox(
    List<_QuadFace> faces,
    double s1,
    double s2,
    double y1,
    double y2,
    double z1,
    double z2,
    Color baseCol,
    double alpha,
    Color edgeCol,
  ) {
    final d1 = _deflAt(s1);
    final d2 = _deflAt(s2);
    final corners = [
      cam.project(_toWorld(s1, y1, z1, d1)), // 0
      cam.project(_toWorld(s2, y1, z1, d2)), // 1
      cam.project(_toWorld(s2, y2, z1, d2)), // 2
      cam.project(_toWorld(s1, y2, z1, d1)), // 3
      cam.project(_toWorld(s1, y1, z2, d1)), // 4
      cam.project(_toWorld(s2, y1, z2, d2)), // 5
      cam.project(_toWorld(s2, y2, z2, d2)), // 6
      cam.project(_toWorld(s1, y2, z2, d1)), // 7
    ];
    const quads = [
      [0, 1, 2, 3, 0.86],
      [4, 5, 6, 7, 1.00],
      [3, 2, 6, 7, 1.08],
      [0, 1, 5, 4, 0.72],
      [0, 3, 7, 4, 0.92],
      [1, 2, 6, 5, 0.92],
    ];
    for (final q in quads) {
      final i0 = q[0] as int, i1 = q[1] as int, i2 = q[2] as int, i3 = q[3] as int;
      final shade = q[4] as double;
      final avgD = 0.25 * (corners[i0].depth + corners[i1].depth + corners[i2].depth + corners[i3].depth);
      final col = Color.fromARGB(
        (alpha * 255).round().clamp(0, 255),
        ((baseCol.r * 255) * shade).round().clamp(0, 255),
        ((baseCol.g * 255) * shade).round().clamp(0, 255),
        ((baseCol.b * 255) * shade).round().clamp(0, 255),
      );
      faces.add(_QuadFace(
        [corners[i0].pt, corners[i1].pt, corners[i2].pt, corners[i3].pt],
        avgD,
        col,
        edgeCol,
      ));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = result.config;
    final g = cfg.geometry;
    final L = cfg.lengthMm;
    final isCol = cfg.kind == MemberKind.column;
    final sCutMax = clipTransverse ? (probeXNorm * L).clamp(0.05 * L, L) : L;

    // 1. Lưới tọa độ sàn 3D nhẹ kiểu ANSYS
    _drawGrid(canvas, L, isCol);

    final faces = <_QuadFace>[];
    final concAlpha = xRay ? 0.24 : 0.88;
    final concEdge = darkMode ? const Color(0x5594A3B8) : const Color(0x77334155);
    const nSeg = 14;
    final zMaxConc = clipLongitudinal ? 0.0 : 0.5 * g.bMm;
    final zMaxSlab = clipLongitudinal ? 0.0 : 0.5 * g.bfSlabMm;

    // 2. Các phân đoạn khối bê tông & lõi thép hình dọc chiều dài cấu kiện
    for (int i = 0; i < nSeg; i++) {
      final s1 = L * i / nSeg;
      final s2 = L * (i + 1) / nSeg;
      if (s1 >= sCutMax - 1.0) break;
      final sEnd = math.min(s2, sCutMax);
      final sMid = 0.5 * (s1 + sEnd);
      final midDis = SrcNonlinearEngine.dissectSection(result, sMid / L);

      // Màu contour ANSYS đại diện cho phân đoạn bê tông
      final double segVal;
      switch (field) {
        case ContourField.deflection:
          segVal = _deflAt(sMid).abs();
          break;
        case ContourField.momentOrAxial:
          segVal = midDis.mzKnm.abs();
          break;
        case ContourField.strainEpsX:
          segVal = midDis.epsMin * 1000.0;
          break;
        case ContourField.vonMises:
          segVal = midDis.fibers.fold<double>(0, (a, b) => math.max(a, b.sigmaVmMpa));
          break;
        case ContourField.confinementOrCrack:
          segVal = midDis.fibers.any((f) => f.stateEn.contains('Cracked')) ? 2.0 : 0.5;
          break;
        case ContourField.stressSigmaX:
          segVal = midDis.sigMinMpa;
          break;
      }
      final segCol = _colorForVal(segVal);

      // Khối sườn bê tông chính
      if (g.sectionType == 'SRC_T_SLAB_H') {
        final ySlabBot = 0.5 * g.hMm - g.hfSlabMm;
        _addBox(faces, s1, sEnd, -0.5 * g.hMm, ySlabBot, -0.5 * g.bMm, zMaxConc, segCol, concAlpha, concEdge);
        _addBox(faces, s1, sEnd, ySlabBot, 0.5 * g.hMm, -0.5 * g.bfSlabMm, zMaxSlab, segCol, concAlpha * 0.9, concEdge);
      } else {
        _addBox(faces, s1, sEnd, -0.5 * g.hMm, 0.5 * g.hMm, -0.5 * g.bMm, zMaxConc, segCol, concAlpha, concEdge);
      }

      // Lõi thép hình chữ H bên trong (luôn hiển thị rõ màu ứng suất von Mises / σ_x!)
      final yc = g.coreOffsetYMm;
      final ha = g.haMm, ba = g.baMm, tf = g.tfMm, tw = g.twMm;
      final stTopStress = midDis.fibers
          .where((f) => f.cell.kind.startsWith('steel') && f.cell.yMm >= yc)
          .fold<double>(0, (a, b) => a.abs() > b.sigmaXMpa.abs() ? a : b.sigmaXMpa);
      final stBotStress = midDis.fibers
          .where((f) => f.cell.kind.startsWith('steel') && f.cell.yMm < yc)
          .fold<double>(0, (a, b) => a.abs() > b.sigmaXMpa.abs() ? a : b.sigmaXMpa);
      final cTopF = _colorForVal(stTopStress);
      final cBotF = _colorForVal(stBotStress);
      final cWeb = Color.lerp(cBotF, cTopF, 0.5)!;
      const stEdge = Color(0xAA0F172A);

      if (g.sectionType == 'COL_RECT_CFST') {
        _addBox(faces, s1, sEnd, yc - 0.5 * ha, yc + 0.5 * ha, -0.5 * ha, clipLongitudinal ? 0.0 : 0.5 * ha, cWeb, 0.72, stEdge);
      } else {
        _addBox(faces, s1, sEnd, yc - 0.5 * ha, yc - 0.5 * ha + tf, -0.5 * ba, 0.5 * ba, cBotF, 0.92, stEdge);
        _addBox(faces, s1, sEnd, yc + 0.5 * ha - tf, yc + 0.5 * ha, -0.5 * ba, 0.5 * ba, cTopF, 0.92, stEdge);
        _addBox(faces, s1, sEnd, yc - 0.5 * ha + tf, yc + 0.5 * ha - tf, -0.5 * tw, 0.5 * tw, cWeb, 0.90, stEdge);
        if (g.sectionType == 'COL_RECT_CROSS_H') {
          _addBox(faces, s1, sEnd, yc - 0.5 * ba, yc + 0.5 * ba, -0.5 * ha, -0.5 * ha + tf, cWeb, 0.88, stEdge);
          _addBox(faces, s1, sEnd, yc - 0.5 * ba, yc + 0.5 * ba, 0.5 * ha - tf, 0.5 * ha, cWeb, 0.88, stEdge);
        }
      }
    }

    // 3. MẶT CẮT PHẪU THUẬT 3D (EXPOSED SURGICAL CUT PLANE TẠI x/L) — Vẽ từng ô thớ 2D sống động!
    final sCut = probeXNorm * L;
    final dCut = _deflAt(sCut);
    for (final df in disAtCut.fibers) {
      final f = df.cell;
      final col = _fiberColor(df);
      final p0 = cam.project(_toWorld(sCut, f.yMm - 0.5 * f.dyMm, f.zMm - 0.5 * f.dzMm, dCut));
      final p1 = cam.project(_toWorld(sCut, f.yMm + 0.5 * f.dyMm, f.zMm - 0.5 * f.dzMm, dCut));
      final p2 = cam.project(_toWorld(sCut, f.yMm + 0.5 * f.dyMm, f.zMm + 0.5 * f.dzMm, dCut));
      final p3 = cam.project(_toWorld(sCut, f.yMm - 0.5 * f.dyMm, f.zMm + 0.5 * f.dzMm, dCut));
      final avgD = 0.25 * (p0.depth + p1.depth + p2.depth + p3.depth) - 2.0; // Nổi nhẹ lên mặt cắt
      faces.add(_QuadFace(
        [p0.pt, p1.pt, p2.pt, p3.pt],
        avgD,
        col.withValues(alpha: 0.95),
        const Color(0x330F172A),
        0.35,
      ));
    }

    // Sắp xếp Painter's Algorithm (từ xa tới gần)
    faces.sort((a, b) => b.depth.compareTo(a.depth));
    final fillP = Paint()..style = PaintingStyle.fill;
    final strokeP = Paint()..style = PaintingStyle.stroke;
    for (final face in faces) {
      final path = Path()
        ..moveTo(face.pts[0].dx, face.pts[0].dy)
        ..lineTo(face.pts[1].dx, face.pts[1].dy)
        ..lineTo(face.pts[2].dx, face.pts[2].dy)
        ..lineTo(face.pts[3].dx, face.pts[3].dy)
        ..close();
      fillP.color = face.fill;
      canvas.drawPath(path, fillP);
      if (face.strokeW > 0) {
        strokeP
          ..color = face.stroke
          ..strokeWidth = face.strokeW;
        canvas.drawPath(path, strokeP);
      }
    }

    // 4. Vẽ cốt thép dọc, cốt đai & đinh chống cắt 3D
    if (showRebar) {
      final rebarP = Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      for (final rb in result.props.rebars) {
        final path = Path();
        for (int i = 0; i <= 16; i++) {
          final s = sCutMax * i / 16.0;
          final pt = cam.project(_toWorld(s, rb.yMm, rb.zMm, _deflAt(s))).pt;
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        canvas.drawPath(path, rebarP);
      }

      // Cốt đai ngang 3D
      final stirP = Paint()
        ..color = const Color(0x9938BDF8)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      final cov = g.coverMm;
      final nStir = math.min(24, (sCutMax / math.max(120.0, g.stirrupSpacingMm)).floor());
      for (int i = 1; i < nStir; i++) {
        final s = sCutMax * i / nStir;
        final ds = _deflAt(s);
        final a = cam.project(_toWorld(s, -0.5 * g.hMm + cov, -0.5 * g.bMm + cov, ds)).pt;
        final b = cam.project(_toWorld(s, 0.5 * g.hMm - cov, -0.5 * g.bMm + cov, ds)).pt;
        final c = cam.project(_toWorld(s, 0.5 * g.hMm - cov, 0.5 * g.bMm - cov, ds)).pt;
        final d = cam.project(_toWorld(s, -0.5 * g.hMm + cov, 0.5 * g.bMm - cov, ds)).pt;
        canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy)
            ..lineTo(c.dx, c.dy)
            ..lineTo(d.dx, d.dy)
            ..close(),
          stirP,
        );
      }

      // Đinh neo chống cắt trên cánh trên thép H (cho Dầm)
      if (!isCol) {
        final studP = Paint()
          ..color = const Color(0xFFE879F9)
          ..strokeWidth = 2.0;
        final yFl = g.coreOffsetYMm + 0.5 * g.haMm;
        final nStud = math.min(20, (sCutMax / math.max(180.0, cfg.studSpacingMm)).floor());
        for (int i = 1; i < nStud; i++) {
          final s = sCutMax * i / nStud;
          final ds = _deflAt(s);
          for (final zOff in const [-0.26, 0.26]) {
            final pA = cam.project(_toWorld(s, yFl, zOff * g.baMm, ds)).pt;
            final pB = cam.project(_toWorld(s, yFl + cfg.studHeightMm, zOff * g.baMm, ds)).pt;
            canvas.drawLine(pA, pB, studP);
            canvas.drawCircle(pB, 2.2, Paint()..color = const Color(0xFFE879F9));
          }
        }
      }
    }

    // 5. Viền phát sáng mặt cắt phẫu thuật 3D & Đường trục trung hòa NA
    final ringP = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    final bDraw = g.sectionType == 'SRC_T_SLAB_H' ? g.bfSlabMm : g.bMm;
    final r0 = cam.project(_toWorld(sCut, -0.5 * g.hMm, -0.5 * bDraw, dCut)).pt;
    final r1 = cam.project(_toWorld(sCut, 0.5 * g.hMm, -0.5 * bDraw, dCut)).pt;
    final r2 = cam.project(_toWorld(sCut, 0.5 * g.hMm, 0.5 * bDraw, dCut)).pt;
    final r3 = cam.project(_toWorld(sCut, -0.5 * g.hMm, 0.5 * bDraw, dCut)).pt;
    canvas.drawPath(
      Path()
        ..moveTo(r0.dx, r0.dy)
        ..lineTo(r1.dx, r1.dy)
        ..lineTo(r2.dx, r2.dy)
        ..lineTo(r3.dx, r3.dy)
        ..close(),
      ringP,
    );
    final yNa = 0.5 * g.hMm - disAtCut.xNaMm;
    final na1 = cam.project(_toWorld(sCut, yNa, -0.55 * bDraw, dCut)).pt;
    final na2 = cam.project(_toWorld(sCut, yNa, 0.55 * bDraw, dCut)).pt;
    canvas.drawLine(na1, na2, Paint()..color = const Color(0xFFFFFFFF)..strokeWidth = 2.0);

    // 6. Vẽ mũi tên tải trọng 3D (UDL / 3pt / 4pt hoặc Nén lệch tâm cột!)
    _drawLoads3D(canvas, L, g, isCol);
  }

  void _drawGrid(Canvas canvas, double L, bool isCol) {
    final gp = Paint()
      ..color = darkMode ? const Color(0x2638BDF8) : const Color(0x26475569)
      ..strokeWidth = 0.8;
    final yFloor = isCol ? -0.5 * L : -0.5 * result.config.geometry.hMm - 280.0;
    final ext = L * 0.68;
    for (int i = -4; i <= 4; i++) {
      final t = ext * i / 4.0;
      final a = cam.project(_Vec3(-ext, yFloor, t)).pt;
      final b = cam.project(_Vec3(ext, yFloor, t)).pt;
      canvas.drawLine(a, b, gp);
      final c = cam.project(_Vec3(t, yFloor, -ext)).pt;
      final d = cam.project(_Vec3(t, yFloor, ext)).pt;
      canvas.drawLine(c, d, gp);
    }
  }

  void _drawLoads3D(Canvas canvas, double L, SectionGeometry g, bool isCol) {
    final p = Paint()
      ..color = const Color(0xFFF43F5E)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    void arrow(Offset from, Offset to) {
      canvas.drawLine(from, to, p);
      final dir = to - from;
      final len = dir.distance;
      if (len < 6) return;
      final u = dir / len;
      final perp = Offset(-u.dy, u.dx);
      final h1 = to - u * 9 + perp * 4.5;
      final h2 = to - u * 9 - perp * 4.5;
      canvas.drawLine(to, h1, p);
      canvas.drawLine(to, h2, p);
    }

    if (isCol) {
      // Mũi tên lực nén đúng tâm / lệch tâm ở đỉnh cột
      final ez = result.ezEffMm.clamp(-0.5 * g.hMm, 0.5 * g.hMm);
      final ey = result.eyEffMm.clamp(-0.5 * g.bMm, 0.5 * g.bMm);
      final top = cam.project(_Vec3(ez, 0.5 * L + 650, ey)).pt;
      final tip = cam.project(_Vec3(ez, 0.5 * L + 20, ey)).pt;
      arrow(top, tip);
      final tp = TextPainter(
        text: TextSpan(
          text: 'N=${result.demandPrimary.toStringAsFixed(0)} kN${ez > 0.5 ? " (e=${ez.toStringAsFixed(0)}mm)" : " (e=0)"}',
          style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 12.0, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, top + const Offset(6, -14));
    } else {
      final yTop = 0.5 * g.hMm;
      final lt = result.config.loadType;
      if (lt == 'udl' || lt == 'combined') {
        for (int i = 0; i <= 8; i++) {
          final s = L * i / 8.0;
          final ds = _deflAt(s);
          arrow(
            cam.project(_toWorld(s, yTop + 420, 0, ds)).pt,
            cam.project(_toWorld(s, yTop + 15, 0, ds)).pt,
          );
        }
      }
      if (lt == '3pt' || lt == 'combined') {
        final a = result.config.loadAMm.clamp(0.08 * L, 0.92 * L);
        final ds = _deflAt(a);
        arrow(cam.project(_toWorld(a, yTop + 620, 0, ds)).pt, cam.project(_toWorld(a, yTop + 15, 0, ds)).pt);
      } else if (lt == '4pt') {
        final a = result.config.loadAMm.clamp(0.08 * L, 0.48 * L);
        for (final pos in [a, L - a]) {
          final ds = _deflAt(pos);
          arrow(cam.project(_toWorld(pos, yTop + 620, 0, ds)).pt, cam.project(_toWorld(pos, yTop + 15, 0, ds)).pt);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Src3DPainter old) => true;
}
