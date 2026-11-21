// ============================================================================
// BẢNG CƠ SỞ LÝ THUYẾT PHI TUYẾN, CÔNG THỨC ĐA TIÊU CHUẨN & MÃ NGUỒN PYTHON
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

    final formulas = [
      (
        title: tr(l, '1. Động học Mặt cắt Thớ 2D & Tích phân Tiếp tuyến', '1. 2D Fiber Section Kinematics & Tangent Stiffness'),
        eq: 'ε(y, z) = ε₀ − y·κ_z + z·κ_y   |   N = ∑ σᵢAᵢ ,   M_z = −∑ σᵢyᵢAᵢ ,   M_y = ∑ σᵢzᵢAᵢ\n[D_t] = ∑ E_t,i Aᵢ · [1, −yᵢ, zᵢ]ᵀ [1, −yᵢ, zᵢ]   (Kiểm chứng sai phân trung tâm: 3.25×10⁻¹³)',
        desc: tr(l, 'Tự động loại trừ diện tích thép hình và cốt thép khỏi ô bê tông (A_c + A_a + A_s = A_g), giải bằng tích phân Gauss-Legendre 3 điểm theo Rayleigh-Ritz & Full Newton-Raphson.',
            'Exact steel-area subtraction (A_c + A_a + A_s = A_g) integrated over 3-point Gauss-Legendre stations via Rayleigh-Ritz & Full Newton-Raphson.'),
        ref: 'CALFEM 3.4 • Spacone et al. (1996) • Huang & Liew (ASCCS 2018)',
      ),
      (
        title: tr(l, '2. Mô hình Vật liệu Bê tông 3 Vùng Giam giữ & HSC/VHSC', '2. 3-Zone Concrete Confinement & HSC/VHSC Brittleness'),
        eq: 'f_cc,p = K_p·(0.85·η_HSC·f\'_c)   |   f_cc,h = K_h·(0.85·η_HSC·f\'_c)\nη_HSC = 1.0 (f\'_c≤50) ;  1−(f\'_c−50)/200 (50<f\'_c≤90) ;  0.80 (f\'_c>90 MPa)',
        desc: tr(l, 'Chia bê tông thành 3 miền: Vùng 0 vỏ bảo vệ dễ bong vỡ, Vùng 1 giam giữ bởi cốt đai (K_p), và Vùng 2 giam giữ mạnh kẹp giữa hai cánh thép hình H hoặc trong ống CFST (K_h).',
            'Partitions concrete into Unconfined cover, Partially Confined (hoops K_p), and Highly Confined core between H-steel flanges / inside CFST tube (K_h).'),
        ref: 'Chen & Lin (2006) JCSR • El-Tawil & Deierlein (1999) • Lai, Liew & Xiong (2019) CBM 228',
      ),
      (
        title: tr(l, '3. Phi tuyến Hình học Cột (P–δ Corotational UL) & Đa giác EC4', '3. Column Geometric Nonlinearity (P–δ) & EC4 5-Point Polygon'),
        eq: '[K_t] = [K_m(E_t)] + [K_g(N)]   (với N < 0 làm mềm hóa cột khi chịu nén)\nN_b,Rd = χ·N_pl,Rd  |  k = β / (1 − N_Ed / N_cr,eff)  |  M_Ed ≤ α_M·μ_d·M_pl,Rd',
        desc: tr(l, 'Bắt chính xác hiệu ứng khuếch đại mô-men bậc hai P–δ cho cột nén đúng tâm (e=0 + khuyết tật e_imp = L/1000) và nén lệch tâm 1 phương / xiên 2 phương (§6.7.3.7).',
            'Captures second-order P–δ magnification for concentric (with initial imperfection L/1000), uniaxial, and biaxial eccentric columns.'),
        ref: 'EN 1994-1-1 §6.7 • ANSI/AISC 360-22 §I2.1, §I5 • SMARTCOCO EUR 28914 EN',
      ),
      (
        title: tr(l, '4. Chịu cắt, Tương tác M–V, Cắt tách dọc & Đinh neo Dầm SRC', '4. Beam Shear, M–V Interaction, Splitting & Headed Studs'),
        eq: 'V_Rd = V_Rd,a + V_Rd,s (SMARTCOCO)  |  ρ = (2V_Ed/V_Rd − 1)² (EC4 §6.2.2.4)\nP_Rd = min(0.8·f_u·πd²/4 , 0.29·α·d²·√(f_ck·E_cm)) / γ_V   (EC4 §6.6.3)',
        desc: tr(l, 'Đồng thời kiểm tra nguy cơ phá hoại cắt tách dọc cánh thép theo Weng et al. (2002) khi b_f/b_w ≥ 0.50–0.67 và đối chiếu 4 hệ tiêu chuẩn EC4 / AISC 360-22 / JGJ 138 / TCVN-SP266.',
            'Simultaneously checks Weng et al. (2002) longitudinal shear splitting along steel flanges and compares EC4, AISC 360-22, JGJ 138-2016, and TCVN/SP 266.'),
        ref: 'SMARTCOCO EUR 28914 EN (2018) • Weng, Yen & Jiang (2002) ASCE • JGJ 138-2016',
      ),
    ];

    final pyModules = [
      ('python_core/materials.py', tr(l, 'Mô-đun 1: Vật liệu phi tuyến 3 vùng giam giữ, HSC η (Lai-Liew 2019), thư viện B25–C110 & S235–Q690.', 'Module 1: 3-zone confinement concrete, HSC η factor, steel & rebar constitutive laws.')),
      ('python_core/section_fiber.py', tr(l, 'Mô-đun 2: Rời rạc hóa lưới thớ 2D (6 dạng tiết diện), vector hóa NumPy, đường cong M–κ & N–M.', 'Module 2: 2D fiber discretization (6 section shapes), NumPy vectorization, M–κ & N–M.')),
      ('python_core/beam_solver.py', tr(l, 'Mô-đun 3: Giải PTHH Dầm thớ 2D (Rayleigh-Ritz + Full NR 4 giai đoạn) & thiết kế 4 tiêu chuẩn.', 'Module 3: Nonlinear 2D Fiber Beam FEM + 4-code design verification & stud sizing.')),
      ('python_core/column_solver.py', tr(l, 'Mô-đun 4: Giải PTHH Cột phi tuyến vật liệu + hình học P–δ (đúng tâm / lệch tâm 1-2 phương).', 'Module 4: Material + Geometric P–δ Column FEM (concentric / uniaxial / biaxial).')),
      ('python_core/probe_dissection.py', tr(l, 'Mô-đun 5: Khảo sát điểm (x/L, y, z) & Phẫu thuật mặt cắt ngang / bổ dọc kiểu ANSYS.', 'Module 5: Arbitrary point probe (x/L, y, z) & ANSYS cross-section / longitudinal slicing.')),
      ('python_core/cad_exporter.py', tr(l, 'Mô-đun 6: Xuất bản vẽ gia công AutoCAD (.DXF 10 layer) & Vector PDF khổ A3 kèm BOM/BBS.', 'Module 6: 10-layer AutoCAD (.DXF) & A3 Vector PDF shop drawings + BOM/BBS.')),
      ('python_core/report_exporter.py', tr(l, 'Mô-đun 7: Xuất thuyết minh Word (.DOCX) & PDF (.PDF) song ngữ Tiếng Việt / Tiếng Anh.', 'Module 7: Bilingual (VI / EN) Word (.DOCX) & PDF (.PDF) calculation reports.')),
      ('python_core/benchmarks_verification.py', tr(l, 'Mô-đun 9: Kiểm chứng tự động 8 trụ cột khoa học (đạt 8/8 PASS, sai số giải tích 10⁻¹³).', 'Module 9: Automated 8-pillar verification (8/8 PASS, 1e-13 analytical exactness).')),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  Text(f.title, style: TextStyle(fontSize: 12.2, fontWeight: FontWeight.bold, color: fg)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF070E1F) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      f.eq,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'DejaVuSansMono',
                        fontWeight: FontWeight.bold,
                        color: dark ? const Color(0xFF7DD3FC) : const Color(0xFF0F3D6E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(f.desc, style: TextStyle(fontSize: 11.2, color: fg.withValues(alpha: 0.9), height: 1.4)),
                  const SizedBox(height: 4),
                  Text('Ref: ${f.ref}', style: TextStyle(fontSize: 10.2, fontStyle: FontStyle.italic, color: const Color(0xFF10B981))),
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
                              style: TextStyle(fontSize: 11.2, color: fg, height: 1.35),
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
