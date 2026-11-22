// ============================================================================
// BẢNG CƠ SỞ LÝ THUYẾT PHI TUYẾN, CÔNG THỨC TOÁN HỌC ĐẦY ĐỦ DẤU CĂN & MÃ PYTHON
// ============================================================================
// Mọi dấu căn thức √(…) đều được dựng bằng nét vẽ vector toán học đầy đủ
// (gồm móc căn + nét xiên + thanh gạch ngang trên đỉnh phủ kín 100% biểu thức
// dưới dấu căn), kết hợp phân số chuẩn sách giáo khoa.
// ============================================================================

import 'package:flutter/material.dart';
import '../core/i18n.dart';

class SrcTheoryCodePanel extends StatelessWidget {
  final bool darkMode;
  final AppLang lang;

  const SrcTheoryCodePanel({
    super.key,
    required this.darkMode,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final dark = darkMode;
    final l = lang;
    final cardBg = dark ? const Color(0xFF0F172A) : Colors.white;
    final border = dark ? const Color(0xFF263859) : const Color(0xFFCBD5E1);
    final fg = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final eqColor = dark ? const Color(0xFF7DD3FC) : const Color(0xFF0F3D6E);
    final eqStyle = TextStyle(
      fontSize: 12.0,
      fontFamily: 'DejaVuSansMono',
      fontWeight: FontWeight.bold,
      color: eqColor,
      height: 1.3,
    );

    Widget mTxt(String s) => Text(s, style: eqStyle);

    Widget mLine(List<Widget> children) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            runSpacing: 4,
            children: children,
          ),
        );

    final formulas = [
      (
        title: tr(l, '1. Động học Mặt cắt Thớ 2D, Ma trận Tiếp tuyến & Ứng suất von Mises', '1. 2D Fiber Section Kinematics, Tangent Stiffness & von Mises'),
        eqWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            mLine([mTxt('ε(y, z) = ε₀ − y·κ_z + z·κ_y   |   N = ∑ σᵢAᵢ ,   M_z = −∑ σᵢyᵢAᵢ ,   M_y = ∑ σᵢzᵢAᵢ')]),
            mLine([mTxt('[D_t] = ∑ E_t,i Aᵢ · [1, −yᵢ, zᵢ]ᵀ [1, −yᵢ, zᵢ]   (Sai số sai phân trung tâm: 3.25×10⁻¹³)')]),
            mLine([
              mTxt('σ_vM = '),
              _MathSqrt(color: eqColor, child: mTxt('σ_x² + 3·τ_xy²')),
              mTxt('   (Tiêu chuẩn chảy dẻo lõi thép hình & cánh/bụng H)'),
            ]),
          ],
        ),
        desc: tr(l, 'Tự động loại trừ diện tích thép hình và cốt thép khỏi ô bê tông (A_c + A_a + A_s = A_g), giải bằng tích phân Gauss-Legendre 3 điểm theo Rayleigh-Ritz & Full Newton-Raphson.',
            'Exact steel-area subtraction (A_c + A_a + A_s = A_g) integrated over 3-point Gauss-Legendre stations via Rayleigh-Ritz & Full Newton-Raphson.'),
        ref: 'CALFEM 3.4 • Spacone et al. (1996) • Huang & Liew (ASCCS 2018)',
      ),
      (
        title: tr(l, '2. Mô hình Bê tông 3 Vùng Giam giữ (Mander / Chen–Lin) & HSC/VHSC', '2. 3-Zone Concrete Confinement (Mander / Chen–Lin) & HSC/VHSC'),
        eqWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            mLine([
              mTxt('K_p, K_h = −1.254 + 2.254·'),
              _MathSqrt(
                color: eqColor,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    mTxt('1 + 7.94·'),
                    _MathFrac(color: eqColor, num: mTxt('f_l'), den: mTxt("f'_c")),
                  ],
                ),
              ),
              mTxt(' − 2·'),
              _MathFrac(color: eqColor, num: mTxt('f_l'), den: mTxt("f'_c")),
            ]),
            mLine([
              mTxt("f_cc,p = K_p·(0.85·η_HSC·f'_c)   |   f_cc,h = K_h·(0.85·η_HSC·f'_c)"),
            ]),
            mLine([
              mTxt("η_HSC = 1.0 (f'_c ≤ 50) ;   1 − (f'_c − 50)/200 (50 < f'_c ≤ 90) ;   0.80 (f'_c > 90 MPa)"),
            ]),
          ],
        ),
        desc: tr(l, 'Chia bê tông thành 3 miền: Vùng 0 vỏ bảo vệ dễ bong vỡ, Vùng 1 giam giữ bởi cốt đai (áp lực f_l,p → K_p), và Vùng 2 giam giữ mạnh trong vòm parabol kẹp giữa hai cánh thép hình H / trong ống CFST (f_l,h → K_h).',
            'Partitions concrete into Unconfined cover, Partially Confined (hoops f_l,p → K_p), and Highly Confined parabolic arch between H-steel flanges / CFST tube (f_l,h → K_h).'),
        ref: 'Mander et al. (1988) • Chen & Lin (2006) JCSR • El-Tawil & Deierlein (1999) • Lai, Liew & Xiong (2019)',
      ),
      (
        title: tr(l, '3. Phi tuyến Hình học Cột (P–δ Corotational) & Ổn định Eurocode 4 §6.7', '3. Column Geometric Nonlinearity (P–δ) & Eurocode 4 §6.7 Buckling'),
        eqWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            mLine([
              mTxt('[K_t] = [K_m(E_t)] + [K_g(N)]   |   λ̄ = '),
              _MathSqrt(
                color: eqColor,
                child: _MathFrac(color: eqColor, num: mTxt('N_pl,Rk'), den: mTxt('N_cr')),
              ),
              mTxt('   |   χ = '),
              _MathFrac(
                color: eqColor,
                num: mTxt('1'),
                den: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    mTxt('Φ + '),
                    _MathSqrt(color: eqColor, child: mTxt('Φ² − λ̄²')),
                  ],
                ),
              ),
            ]),
            mLine([
              mTxt('N_b,Rd = χ·N_pl,Rd   |   k = '),
              _MathFrac(color: eqColor, num: mTxt('β'), den: mTxt('1 − N_Ed / N_cr,eff')),
              mTxt('   |   M_Ed,II = k·M_Ed,I ≤ α_M·μ_d·M_pl,Rd'),
            ]),
          ],
        ),
        desc: tr(l, 'Bắt chính xác hiệu ứng khuếch đại mô-men bậc hai P–δ cho cột nén đúng tâm (e=0 + khuyết tật e_imp = L/1000) và nén lệch tâm 1 phương / xiên 2 phương (§6.7.3.7).',
            'Captures second-order P–δ magnification for concentric (with initial imperfection L/1000), uniaxial, and biaxial eccentric columns.'),
        ref: 'EN 1994-1-1 §6.7 • ANSI/AISC 360-22 §I2.1, §I5 • SMARTCOCO EUR 28914 EN',
      ),
      (
        title: tr(l, '4. Chịu cắt, Đinh neo Chống cắt (EC4 §6.6.3) & Cắt tách dọc Weng (2002)', '4. Shear, Headed Shear Studs (EC4 §6.6.3) & Weng Splitting (2002)'),
        eqWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            mLine([
              mTxt('V_Rd,a = '),
              _MathFrac(
                color: eqColor,
                num: mTxt('A_v · f_yd'),
                den: _MathSqrt(color: eqColor, child: mTxt('3')),
              ),
              mTxt('   |   V_Rd = V_Rd,a + V_Rd,s   |   ρ = (2V_Ed / V_Rd − 1)²'),
            ]),
            mLine([
              mTxt('P_Rd = min( 0.8·f_u·πd²/4 ,  0.29·α·d²·'),
              _MathSqrt(color: eqColor, child: mTxt('f_ck · E_cm')),
              mTxt(' ) / γ_V   (EC4 §6.6.3)'),
            ]),
            mLine([
              mTxt('V_split = 0.35·'),
              _MathSqrt(color: eqColor, child: mTxt("f'_c")),
              mTxt('·b_net·d + A_sv·f_yv·d / s   (Weng et al. 2002)'),
            ]),
          ],
        ),
        desc: tr(l, 'Đồng thời kiểm tra tương tác uốn–cắt M–V, khả năng chịu cắt của đinh neo hàn trên cánh thép H, nguy cơ cắt tách dọc cánh thép khi b_f/b_w ≥ 0.50–0.67 và đối chiếu 4 hệ tiêu chuẩn EC4 / AISC 360-22 / JGJ 138 / TCVN-SP266.',
            'Simultaneously checks M–V interaction, headed stud capacity on H-steel flanges, Weng et al. (2002) longitudinal shear splitting, and 4 international codes.'),
        ref: 'EN 1994-1-1 §6.2 & §6.6 • SMARTCOCO EUR 28914 EN (2018) • Weng, Yen & Jiang (2002) ASCE',
      ),
      (
        title: tr(l, '5. Cơ chế Liên kết Cốt cứng (Thép hình) ↔ Bê tông Cốt thép (Dính bám & Trượt)', '5. Steel Core ↔ RC Composite Interface Mechanics (Bond, Studs & Slip)'),
        eqWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            mLine([
              mTxt('v_L(x) = '),
              _MathFrac(color: eqColor, num: mTxt('|V(x)| · α_a'), den: mTxt('z_lev')),
              mTxt(' + v_intro(x)   |   τ_b(x) = '),
              _MathFrac(color: eqColor, num: mTxt('v_L(x)'), den: mTxt('u_a')),
              mTxt(' ≤ τ_Rd,eff = τ_Rd,0 + 0.25·f_l,p'),
            ]),
            mLine([
              mTxt('F_stud(x) = '),
              _MathFrac(color: eqColor, num: mTxt('v_L(x) · s_stud'), den: mTxt('n_rows')),
              mTxt(' ≤ P_Rd   |   s_slip(x) = f(τ_b, F_stud, K_stud)'),
            ]),
          ],
        ),
        desc: tr(l, 'Mô tả định lượng sự truyền lực dọc mặt tiếp xúc giữa thép hình H và bê tông cốt thép: dính bám hóa học + ma sát tăng cường nhờ cốt đai (τ_Rd,eff), chốt đinh neo chống cắt (F_stud/P_Rd), vùng truyền lực đầu cột l_V = min(2h, L/3) và độ trượt tương đối s_slip.',
            'Quantifies steel–concrete composite transfer: natural bond + stirrup-enhanced friction (τ_Rd,eff), headed shear stud utilization (F_stud/P_Rd), column load-introduction length l_V = min(2h, L/3), and micro-slip s_slip.'),
        ref: 'EN 1994-1-1 §6.7.4.2 (Table 6.6) • Roeder et al. (1999) • Ollgaard Bond-Slip Model',
      ),
    ];

    final pyModules = [
      ('python_core/materials.py', tr(l, 'Mô-đun 1: Vật liệu phi tuyến 3 vùng giam giữ, HSC η (Lai-Liew 2019), thư viện B25–C110 & S235–Q690.', 'Module 1: 3-zone confinement concrete, HSC η factor, steel & rebar constitutive laws.')),
      ('python_core/section_fiber.py', tr(l, 'Mô-đun 2: Rời rạc hóa lưới thớ 2D (6 dạng tiết diện), vector hóa NumPy, đường cong M–κ & N–M.', 'Module 2: 2D fiber discretization (6 section shapes), NumPy vectorization, M–κ & N–M.')),
      ('python_core/beam_solver.py', tr(l, 'Mô-đun 3: Giải PTHH Dầm thớ 2D (Rayleigh-Ritz + Full NR 4 giai đoạn) & thiết kế 4 tiêu chuẩn.', 'Module 3: Nonlinear 2D Fiber Beam FEM + 4-code design verification & stud sizing.')),
      ('python_core/column_solver.py', tr(l, 'Mô-đun 4: Giải PTHH Cột phi tuyến vật liệu + hình học P–δ (đúng tâm / lệch tâm 1-2 phương).', 'Module 4: Material + Geometric P–δ Column FEM (concentric / uniaxial / biaxial).')),
      ('python_core/probe_dissection.py', tr(l, 'Mô-đun 5: Khảo sát điểm (x/L, y, z), Phẫu thuật mặt cắt & Ứng xử liên kết Thép hình – BTCT.', 'Module 5: Point probe (x/L, y, z), section dissection & Steel–RC bond/slip behavior.')),
      ('python_core/cad_exporter.py', tr(l, 'Mô-đun 6: Xuất bản vẽ gia công AutoCAD (.DXF 10 layer) & Vector PDF khổ A3 kèm BOM/BBS.', 'Module 6: 10-layer AutoCAD (.DXF) & A3 Vector PDF shop drawings + BOM/BBS.')),
      ('python_core/report_exporter.py', tr(l, 'Mô-đun 7: Xuất thuyết minh Word (.DOCX) & PDF (.PDF) song ngữ Tiếng Việt / Tiếng Anh.', 'Module 7: Bilingual (VI / EN) Word (.DOCX) & PDF (.PDF) calculation reports.')),
      ('python_core/benchmarks_verification.py', tr(l, 'Mô-đun 9: Kiểm chứng tự động 8 trụ cột khoa học (đạt 8/8 PASS, sai số giải tích 10⁻¹³).', 'Module 9: Automated 8-pillar verification (8/8 PASS, 1e-13 analytical exactness).')),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school, size: 17, color: Color(0xFF06B6D4)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tr(l, 'THÔNG TIN TÁC GIẢ & ĐƠN VỊ THỰC HIỆN', 'AUTHOR & INSTITUTIONAL INFORMATION'),
                        style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tr(l, 'Trường Đại học Bách Khoa - Đại học Quốc Gia TP. Hồ Chí Minh', 'Ho Chi Minh City University of Technology (VNU-HCM)'),
                  style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: fg),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(l, 'Giảng viên hướng dẫn: PGS.TS Ngô Hữu Cường', 'Advisor: Assoc. Prof. Dr. Ngo Huu Cuong'),
                  style: TextStyle(fontSize: 12.0, color: sub),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(l, 'Tác giả / Học viên thực hiện: Võ Thanh Vang (2670624)', 'Author / Student: Vo Thanh Vang (2670624)'),
                  style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: fg),
                ),
                const SizedBox(height: 2),
                Text(
                  'Email: vothanhvang@gmail.com   |   Phone: 0973.993.494',
                  style: TextStyle(fontSize: 12.0, fontFamily: 'DejaVuSansMono', color: dark ? const Color(0xFF38BDF8) : const Color(0xFF0F3D6E)),
                ),
              ],
            ),
          ),
          Text(
            tr(l, 'CƠ SỞ LÝ THUYẾT PHI TUYẾN & HỆ CÔNG THỨC ĐA TIÊU CHUẨN', 'NONLINEAR MECHANICS & MULTI-CODE FORMULATIONS'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
          ),
          const SizedBox(height: 8),
          for (final f in formulas)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.title, style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: fg)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF070E1F) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.4)),
                    ),
                    child: f.eqWidget,
                  ),
                  const SizedBox(height: 6),
                  Text(f.desc, style: TextStyle(fontSize: 12.0, color: fg.withValues(alpha: 0.9), height: 1.4)),
                  const SizedBox(height: 4),
                  Text('Ref: ${f.ref}', style: const TextStyle(fontSize: 12.0, fontStyle: FontStyle.italic, color: Color(0xFF10B981))),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            tr(l, 'KIẾN TRÚC LÕI TÍNH TOÁN PYTHON (CÓ CHÚ THÍCH TIẾNG VIỆT ĐẦY ĐỦ)', 'PYTHON CALCULATION CORE ARCHITECTURE (FULLY ANNOTATED)'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
            child: Column(
              children: [
                for (final (path, desc) in pyModules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.code, size: 15, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 12.0, color: fg, height: 1.35),
                              children: [
                                TextSpan(
                                  text: '$path  —  ',
                                  style: const TextStyle(fontFamily: 'DejaVuSansMono', fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                                ),
                                TextSpan(text: desc, style: TextStyle(color: sub)),
                              ],
                            ),
                          ),
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
  }
}

// ============================================================================
// WIDGET DẤU CĂN BẬC HAI TOÁN HỌC ĐẦY ĐỦ (VECTOR RADICAL + THANH GẠCH TRÊN ĐỈNH)
// ============================================================================
class _MathSqrt extends StatelessWidget {
  final Widget child;
  final Color color;

  const _MathSqrt({required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RadicalPainter(color: color),
      child: Padding(
        padding: const EdgeInsets.only(left: 13, top: 3.5, right: 4, bottom: 1),
        child: child,
      ),
    );
  }
}

class _RadicalPainter extends CustomPainter {
  final Color color;
  const _RadicalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter;

    final h = size.height;
    final w = size.width;
    const topY = 1.5;
    final path = Path()
      // Móc nhỏ bên trái của dấu căn
      ..moveTo(0.8, h * 0.56)
      ..lineTo(3.2, h * 0.48)
      // Nét chéo xuống đáy chữ V của dấu căn
      ..lineTo(6.2, h - 1.5)
      // Nét xiên dài đi lên đỉnh trái của thanh gạch ngang
      ..lineTo(11.2, topY)
      // Thanh gạch ngang (vinculum) phủ kín 100% biểu thức dưới dấu căn!
      ..lineTo(w - 1.0, topY)
      // Đầu khóa nhẹ bên phải (chuẩn dấu căn sách giáo khoa kỹ thuật)
      ..lineTo(w - 1.0, topY + 2.8);

    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _RadicalPainter old) => old.color != color;
}

// ============================================================================
// WIDGET PHÂN SỐ TOÁN HỌC CHUẨN (TỬ SỐ / GẠCH NGANG / MẪU SỐ)
// ============================================================================
class _MathFrac extends StatelessWidget {
  final Widget num;
  final Widget den;
  final Color color;

  const _MathFrac({required this.num, required this.den, required this.color});

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: num),
          Container(height: 1.25, color: color, margin: const EdgeInsets.symmetric(vertical: 1.5)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: den),
        ],
      ),
    );
  }
}
