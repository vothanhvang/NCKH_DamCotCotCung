# -*- coding: utf-8 -*-
"""
================================================================================
MÔ-ĐUN 7: XUẤT THUYẾT MINH TÍNH TOÁN CHUYÊN NGHIỆP WORD (.DOCX) & PDF (.PDF)
          SONG NGỮ TIẾNG VIỆT / TIẾNG ANH (TÙY CHỌN)
================================================================================
Chức năng khối:
  - Tạo thuyết minh tính toán chuẩn Báo cáo Nghiên cứu Khoa học Cấp Quốc gia
    bằng Tiếng Việt (`lang="vi"`) hoặc Tiếng Anh (`lang="en"`):
      1) Định dạng Microsoft Word (.DOCX) dùng `python-docx` trình bày chuyên
         nghiệp với bảng biểu tô màu, khung công thức, nhận xét vật lý, chèn
         trực tiếp biểu đồ chất lượng cao 300 DPI (Load–Deflection, M–κ / N–M
         Interaction, Phẫu thuật mặt cắt ngang ANSYS 2D).
      2) Định dạng PDF (.PDF) dùng `reportlab` + phông chữ Unicode đầy đủ dấu
         tiếng Việt, trình bày đẳng cấp học thuật sẵn sàng nộp báo cáo.
================================================================================
"""

from __future__ import annotations
from typing import Dict, List
import io
import os
import tempfile
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from .probe_dissection import dissect_section_2d
from .cad_exporter import compute_material_schedule, _register_unicode_fonts


def _render_analysis_chart_png(analysis: Dict[str, object], lang: str = "vi") -> bytes:
    """
    Vẽ hình tổng hợp 2 bảng biểu khoa học độ phân giải 260 DPI để nhúng trực tiếp
    vào thuyết minh Word (.docx) và PDF (.pdf):
      - Dầm: (Trái) Đường cong Tải trọng – Độ võng P–δ 4 giai đoạn; (Phải) Phẫu thuật mặt cắt ANSYS σ_x.
      - Cột: (Trái) Biểu đồ tương tác N–M (Fiber vs EC4 A–E + điểm thiết kế); (Phải) Phẫu thuật mặt cắt ANSYS σ_x.
    """
    plt.rcParams["font.sans-serif"] = ["DejaVu Sans", "Arial"]
    plt.rcParams["axes.unicode_minus"] = False

    fig, axes = plt.subplots(1, 2, figsize=(10.5, 4.3), dpi=240)
    is_beam = analysis["member_kind"] == "beam"
    checks = analysis["design_checks"]

    ax1 = axes[0]
    if is_beam:
        hist = analysis["history"]
        xs = [h["defl_mm"] for h in hist]
        ys = [h["load_kn"] for h in hist]
        ax1.plot(xs, ys, "-o", color="#0F3D6E", lw=2.2, ms=3.5, label=("Phi tuyến Thớ 2D (FEM)" if lang == "vi" else "Nonlinear 2D Fiber FEM"))
        ax1.axhline(analysis["total_load_design_kn"], color="#059669", ls="--", lw=1.4,
                    label=(f"Tải thiết kế = {analysis['total_load_design_kn']:.1f} kN" if lang == "vi" else f"Design Load = {analysis['total_load_design_kn']:.1f} kN"))
        ax1.set_xlabel("Độ võng giữa nhịp δ (mm)" if lang == "vi" else "Midspan Deflection δ (mm)", fontsize=9.5, fontweight="bold")
        ax1.set_ylabel("Tổng tải trọng P (kN)" if lang == "vi" else "Total Applied Load P (kN)", fontsize=9.5, fontweight="bold")
        ax1.set_title("Đường cong Tải trọng – Độ võng (P – δ)" if lang == "vi" else "Load – Deflection Response (P – δ)", fontsize=10.5, fontweight="bold", color="#0F3D6E")
    else:
        nm_des = analysis["nm_z_design"]
        nm_nom = analysis["nm_z_nominal"]
        poly = checks["codes"]["EC4"]["polygon_z"]["points"]
        ax1.plot(nm_nom["m_knm"], nm_nom["n_kn"], "--", color="#64748B", lw=1.4, label=("Thớ 2D Danh định" if lang == "vi" else "Fiber Nominal"))
        ax1.plot(nm_des["m_knm"], nm_des["n_kn"], "-", color="#0F3D6E", lw=2.2, label=("Thớ 2D Thiết kế" if lang == "vi" else "Fiber Design"))
        ax1.plot([p["m_knm"] for p in poly], [p["n_kn"] for p in poly], "-s", color="#DC2626", lw=1.7, ms=4.5, label="EC4 A–E–C–D–B")
        ax1.scatter([checks["mz_1_knm"]], [checks["n_ed_kn"]], color="#059669", s=55, zorder=6, label="1st Order (M_I)")
        ax1.scatter([checks["codes"]["EC4"]["mz_ed_2_knm"]], [checks["n_ed_kn"]], color="#F59E0B", marker="^", s=75, zorder=7, label="2nd Order (M_II, P-δ)")
        ax1.set_xlabel("Mô-men uốn M_z (kN·m)" if lang == "vi" else "Bending Moment M_z (kN·m)", fontsize=9.5, fontweight="bold")
        ax1.set_ylabel("Lực nén dọc trục N (kN)" if lang == "vi" else "Axial Compression N (kN)", fontsize=9.5, fontweight="bold")
        ax1.set_title("Biểu đồ Tương tác N – M (Thớ 2D & EC4)" if lang == "vi" else "N – M Interaction Diagram (Fiber & EC4)", fontsize=10.5, fontweight="bold", color="#0F3D6E")
    ax1.grid(True, ls=":", alpha=0.6)
    ax1.legend(fontsize=7.6, loc="best")

    # Hình 2: Phẫu thuật mặt cắt ngang kiểu ANSYS tại giữa nhịp/chiều cao (x/L = 0.5)
    from matplotlib.patches import Rectangle, Circle
    from matplotlib.collections import PatchCollection
    from matplotlib.colors import Normalize

    ax2 = axes[1]
    dis = dissect_section_2d(analysis, x_norm=0.5)
    norm = Normalize(vmin=dis["sigma_min_mpa"], vmax=dis["sigma_max_mpa"])
    conc_f = [f for f in dis["fibers"] if f["kind"] == "concrete"]
    steel_f = [f for f in dis["fibers"] if f["kind"].startswith("steel")]
    rebar_f = [f for f in dis["fibers"] if f["kind"] == "rebar"]

    pc_conc = PatchCollection(
        [Rectangle((f["z_mm"] - 0.5 * f["dz_mm"], f["y_mm"] - 0.5 * f["dy_mm"]), f["dz_mm"], f["dy_mm"]) for f in conc_f],
        cmap="jet", norm=norm, edgecolor="none", zorder=1,
    )
    pc_conc.set_array(np.array([f["sigma_mpa"] for f in conc_f]))
    ax2.add_collection(pc_conc)

    if steel_f:
        pc_st = PatchCollection(
            [Rectangle((f["z_mm"] - 0.5 * f["dz_mm"], f["y_mm"] - 0.5 * f["dy_mm"]), f["dz_mm"], f["dy_mm"]) for f in steel_f],
            cmap="jet", norm=norm, edgecolor="#0F172A", linewidth=0.35, zorder=3,
        )
        pc_st.set_array(np.array([f["sigma_mpa"] for f in steel_f]))
        ax2.add_collection(pc_st)

    if rebar_f:
        pc_rb = PatchCollection(
            [Circle((f["z_mm"], f["y_mm"]), radius=max(0.55 * f["dz_mm"], 9.0)) for f in rebar_f],
            cmap="jet", norm=norm, edgecolor="#0F172A", linewidth=0.65, zorder=5,
        )
        pc_rb.set_array(np.array([f["sigma_mpa"] for f in rebar_f]))
        ax2.add_collection(pc_rb)

    ax2.autoscale_view()
    cb = plt.colorbar(pc_conc, ax=ax2, pad=0.03, fraction=0.046)
    cb.set_label("σ_x (MPa)", fontsize=8.5)
    y_na = 0.5 * analysis["config"].geometry.h_mm - dis["x_na_mm"]
    ax2.axhline(y_na, color="#0F172A", ls="--", lw=1.2, zorder=6, label=f"NA (x_NA={dis['x_na_mm']:.1f} mm)")
    ax2.set_aspect("equal", adjustable="box")
    ax2.set_xlabel("z (mm)", fontsize=9)
    ax2.set_ylabel("y (mm)", fontsize=9)
    ax2.set_title("Phẫu thuật Mặt cắt x/L=0.5 (ANSYS)" if lang == "vi" else "Cross-Section Dissection x/L=0.5", fontsize=10.0, fontweight="bold", color="#0F3D6E")
    ax2.legend(fontsize=7.6, loc="lower right")
    ax2.grid(True, ls=":", alpha=0.35)

    plt.tight_layout()
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=240)
    plt.close(fig)
    return buf.getvalue()


def _build_report_sections_data(analysis: Dict[str, object], lang: str = "vi") -> Dict[str, object]:
    """Chuẩn bị toàn bộ dữ liệu có cấu trúc song ngữ VI/EN cho cả Word và PDF."""
    is_beam = analysis["member_kind"] == "beam"
    cfg = analysis["config"]
    g = cfg.geometry
    m = cfg.material
    props = analysis["props"]
    conf = analysis["conf"]
    checks = analysis["design_checks"]
    vi = (lang == "vi")

    title = (
        ("THUYẾT MINH TÍNH TOÁN & THIẾT KẾ PHI TUYẾN DẦM BÊ TÔNG CỐT CỨNG (SRC / CES)" if is_beam
         else "THUYẾT MINH TÍNH TOÁN & THIẾT KẾ PHI TUYẾN CỘT BÊ TÔNG CỐT CỨNG (SRC / CES)")
        if vi else
        ("NONLINEAR ANALYSIS & MULTI-CODE DESIGN REPORT — SRC COMPOSITE BEAM" if is_beam
         else "NONLINEAR ANALYSIS & MULTI-CODE DESIGN REPORT — SRC COMPOSITE COLUMN")
    )
    subtitle = (
        "Báo cáo Nghiên cứu Khoa học Cấp Quốc gia — Đối chiếu Eurocode 4, ANSI/AISC 360-22, JGJ 138-2016, TCVN/SP 266 & SMARTCOCO"
        if vi else
        "National Scientific Research Report — Multi-Code Verification (EC4, ANSI/AISC 360-22, JGJ 138-2016, TCVN/SP 266 & SMARTCOCO)"
    )

    param_rows = [
        (["Cấu kiện / Tên bài toán" if vi else "Member / Case Name", cfg.name]),
        (["Loại tiết diện" if vi else "Section Type", g.section_type]),
        (["Kích thước bê tông b × h (mm)" if vi else "Concrete Dimensions b × h (mm)",
          f"{g.b_mm:.0f} × {g.h_mm:.0f}" + (f" (Bản sàn {g.bf_slab_mm:.0f}×{g.hf_slab_mm:.0f})" if g.section_type == "SRC_T_SLAB_H" else "")]),
        (["Chiều dài nhịp / chiều cao L (mm)" if vi else "Span / Height L (mm)", f"{cfg.span_mm if is_beam else cfg.height_mm:.0f}"]),
        (["Lõi thép hình cốt cứng (mm)" if vi else "Encased Steel Profile (mm)", f"H{g.ha_mm:.0f}×{g.ba_mm:.0f}×{g.tw_mm:.1f}×{g.tf_mm:.1f} (A_a = {props.aa_mm2:.0f} mm², ρ_a = {props.steel_ratio*100:.2f}%)"]),
        (["Cốt thép dọc & Cốt đai" if vi else "Rebar & Transverse Stirrups",
          f"{len(props.rebar_coords)} {'thanh' if vi else 'bars'} (A_s = {props.as_mm2:.0f} mm², ρ_s = {props.rebar_ratio*100:.2f}%) | {'Đai' if vi else 'Stirrups'} Ø{g.stirrup_dia_mm:.0f} @{g.stirrup_spacing_end_mm:.0f}/{g.stirrup_spacing_mm:.0f}"]),
        (["Bê tông (3 vùng giam giữ)" if vi else "Concrete (3-Zone Confinement)", f"{m.concrete_grade}: f'c = {m.fc_mpa:.1f} MPa, E_c = {m.ec_mpa:.0f} MPa | K_p = {conf.kp:.2f}, K_h = {conf.kh:.2f}, η_HSC = {conf.eta_hsc:.2f}"]),
        (["Thép hình & Cốt thép" if vi else "Steel Profile & Rebar Grade", f"{m.steel_grade} (f_y={m.fy_steel_mpa:.0f} MPa, E_a={m.es_steel_mpa:.0f}) | {m.rebar_grade} (f_yr={m.fy_rebar_mpa:.0f} MPa)"]),
    ]

    if is_beam:
        c_ec4 = checks["codes"]["EC4"]
        c_aisc = checks["codes"]["AISC"]
        c_jgj = checks["codes"]["JGJ138"]
        c_tcvn = checks["codes"]["TCVN_SP266"]
        det = checks["detailing"]
        code_headers = (
            ["Tiêu chuẩn", "M_Rd (kN·m)", "V_Rd (kN)", "Tỷ số M_Ed/M_Rd", "Tỷ số V_Ed/V_Rd", "Kết luận"]
            if vi else
            ["Design Standard", "M_Rd (kN·m)", "V_Rd (kN)", "M_Ed / M_Rd", "V_Ed / V_Rd", "Verdict"]
        )
        ok_str = "ĐẠT" if vi else "PASS"
        ng_str = "KHÔNG ĐẠT" if vi else "FAIL"
        code_rows = [
            ["Eurocode 4 (EN 1994-1-1) + SMARTCOCO", f"{c_ec4['m_rd_mv_knm']:.1f}", f"{c_ec4['v_rd_kn']:.1f}", f"{c_ec4['ur_m']:.3f}", f"{c_ec4['ur_v']:.3f}", ok_str if c_ec4["pass"] else ng_str],
            ["ANSI/AISC 360-22 (Ch. I - LRFD)", f"{c_aisc['m_rd_knm']:.1f}", f"{c_aisc['v_rd_kn']:.1f}", f"{c_aisc['ur_m']:.3f}", f"{c_aisc['ur_v']:.3f}", ok_str if c_aisc["pass"] else ng_str],
            ["JGJ 138-2016 (China Ch. 5)", f"{c_jgj['m_rd_knm']:.1f}", f"{c_jgj['v_rd_kn']:.1f}", f"{c_jgj['ur_m']:.3f}", f"{c_jgj['ur_v']:.3f}", ok_str if c_jgj["pass"] else ng_str],
            ["TCVN 5574/5575 + SP 266", f"{c_tcvn['m_rd_knm']:.1f}", f"{c_tcvn['v_rd_kn']:.1f}", f"{c_tcvn['ur_m']:.3f}", f"{c_tcvn['ur_v']:.3f}", ok_str if c_tcvn["pass"] else ng_str],
            ["PTHH Thớ 2D Phi tuyến (Cực hạn danh định)" if vi else "Nonlinear 2D Fiber FEM (Nominal Ultimate)",
             f"{analysis['m_ultimate_fem_knm']:.1f}", "-", f"{checks['m_ed_knm']/max(1.0, analysis['m_ultimate_fem_knm']):.3f}", "-",
             f"μ = {analysis['ductility_mu']:.2f}"],
        ]
        summary_bullets = [
            (f"Mô-men thiết kế M_Ed = {checks['m_ed_knm']:.1f} kN·m; Lực cắt V_Ed = {checks['v_ed_kn']:.1f} kN; Độ võng phi tuyến δ_NL = {analysis['max_defl_design_mm']:.2f} mm (tuyến tính δ_L = {analysis['max_defl_linear_mm']:.2f} mm; giới hạn L/{cfg.deflection_limit_ratio:.0f} = {checks['delta_limit_mm']:.2f} mm)."
             if vi else
             f"Design moment M_Ed = {checks['m_ed_knm']:.1f} kN·m; Design shear V_Ed = {checks['v_ed_kn']:.1f} kN; Nonlinear deflection δ_NL = {analysis['max_defl_design_mm']:.2f} mm (linear δ_L = {analysis['max_defl_linear_mm']:.2f} mm; SLS limit = {checks['delta_limit_mm']:.2f} mm)."),
            (f"Sức chịu tải cực hạn PTHH Thớ 2D: P_u = {analysis['p_ultimate_kn']:.1f} kN, M_u = {analysis['m_ultimate_fem_knm']:.1f} kN·m, độ võng cực hạn δ_u = {analysis['defl_ultimate_mm']:.2f} mm, hệ số dẻo μ = {analysis['ductility_mu']:.2f}."
             if vi else
             f"Nonlinear 2D Fiber FEM ultimate capacity: P_u = {analysis['p_ultimate_kn']:.1f} kN, M_u = {analysis['m_ultimate_fem_knm']:.1f} kN·m, ultimate deflection δ_u = {analysis['defl_ultimate_mm']:.2f} mm, ductility μ = {analysis['ductility_mu']:.2f}."),
            (f"Kiểm tra cắt tách dọc Weng et al. (2002): b_f/b_w = {det['bf_bw_ratio']:.2f}, V_split = {det['v_split_kn']:.1f} kN (UR = {det['ur_split']:.2f}) — Mức rủi ro: {det['splitting_risk']}."
             if vi else
             f"Weng et al. (2002) longitudinal shear-splitting check: b_f/b_w = {det['bf_bw_ratio']:.2f}, V_split = {det['v_split_kn']:.1f} kN (UR = {det['ur_split']:.2f})."),
            (f"Kiểm tra đinh chống cắt EN 1994-1-1 §6.6.3: P_Rd = {det['stud_p_rd_kn']:.1f} kN/đinh, yêu cầu {det['studs_req_half']} đinh/nửa nhịp, bố trí {det['studs_prov_half']} đinh (UR = {det['ur_studs']:.2f})."
             if vi else
             f"Headed shear studs EN 1994-1-1 §6.6.3: P_Rd = {det['stud_p_rd_kn']:.1f} kN/stud, required {det['studs_req_half']} studs/half-span, provided {det['studs_prov_half']} studs (UR = {det['ur_studs']:.2f})."),
        ]
    else:
        c_ec4 = checks["codes"]["EC4"]
        c_aisc = checks["codes"]["AISC"]
        c_jgj = checks["codes"]["JGJ138"]
        c_lai = checks["codes"]["LAI_LIEW_2019"]
        c_tcvn = checks["codes"]["TCVN_SP266"]
        code_headers = (
            ["Tiêu chuẩn / Phương pháp", "N_Rd / φP_n (kN)", "Độ mảnh / Hệ số", "Hệ số sử dụng UR", "Kết luận"]
            if vi else
            ["Standard / Method", "N_Rd / φP_n (kN)", "Slenderness / Factor", "Utilization UR", "Verdict"]
        )
        ok_str = "ĐẠT" if vi else "PASS"
        ng_str = "KHÔNG ĐẠT" if vi else "FAIL"
        code_rows = [
            ["Eurocode 4 (EN 1994-1-1 §6.7)", f"N_b,Rd = {c_ec4['n_b_rd_kn']:.1f}", f"λ̄_z={c_ec4['lambda_z']:.2f}, χ_z={c_ec4['chi_z']:.2f}, k={c_ec4['k_amp_z']:.2f}", f"{c_ec4['ur_total']:.3f}", ok_str if c_ec4["pass"] else ng_str],
            ["ANSI/AISC 360-22 (§I2.1 & §I5)", f"φP_n = {c_aisc['phi_pn_kn']:.1f}", f"C1={c_aisc['c1_factor']:.2f}, B1={c_aisc['b1_z']:.2f}", f"{c_aisc['ur_total']:.3f}", ok_str if c_aisc["pass"] else ng_str],
            ["JGJ 138-2016 (China Ch. 6)", f"N_Rd = {c_jgj['n_rd_kn']:.1f}", f"φ = {c_jgj['phi_stability']:.3f}", f"{c_jgj['ur_n']:.3f}", ok_str if c_jgj["pass"] else ng_str],
            ["TCVN 5574/5575 + SP 266", f"N_Rd = {c_tcvn['n_rd_kn']:.1f}", f"χ_min = {min(c_ec4['chi_z'], c_ec4['chi_y']):.2f}", f"{c_tcvn['ur_n']:.3f}", ok_str if c_tcvn["pass"] else ng_str],
            ["Lai, Liew & Xiong (2019) HSC", f"N_ana2 = {c_lai['n_ana2_eta_kn']:.1f}", f"η_HSC = {c_lai['eta_hsc']:.2f}", f"{checks['n_ed_kn']/max(1.0, c_lai['n_ana2_eta_kn']):.3f}", "Tham chiếu danh định" if vi else "Nominal Ref."],
            ["PTHH Thớ 2D + P–δ (Cực hạn FEM)" if vi else "Nonlinear Fiber + P–δ FEM (Ultimate)",
             f"N_u = {analysis['n_ultimate_fem_kn']:.1f}", f"M_II/M_I = {analysis['p_delta_amp_fem']:.2f}", f"{checks['n_ed_kn']/max(1.0, analysis['n_ultimate_fem_kn']):.3f}", ok_str if analysis["reached_design_load"] else ("MẤT ỔN ĐỊNH" if vi else "BUCKLED")],
        ]
        summary_bullets = [
            (f"Nội lực thiết kế: N_Ed = {checks['n_ed_kn']:.1f} kN, M_z,I = {checks['mz_1_knm']:.1f} kN·m (e_z = {checks['ez_mm']:.1f} mm), M_y,I = {checks['my_1_knm']:.1f} kN·m (e_y = {checks['ey_mm']:.1f} mm); Mô-men bậc hai EC4 M_z,II = {c_ec4['mz_ed_2_knm']:.1f} kN·m."
             if vi else
             f"Design demand: N_Ed = {checks['n_ed_kn']:.1f} kN, M_z,I = {checks['mz_1_knm']:.1f} kN·m (e_z = {checks['ez_mm']:.1f} mm), M_y,I = {checks['my_1_knm']:.1f} kN·m; EC4 2nd-order M_z,II = {c_ec4['mz_ed_2_knm']:.1f} kN·m."),
            (f"Tỷ số đóng góp thép hình δ = {c_ec4['delta_steel']:.3f} (quy định EC4: 0.20 ≤ δ ≤ 0.90); Độ mảnh quy ước λ̄_z = {c_ec4['lambda_z']:.3f}, λ̄_y = {c_ec4['lambda_y']:.3f} (≤ 2.0)."
             if vi else
             f"Steel contribution ratio δ = {c_ec4['delta_steel']:.3f} (EC4 range 0.20–0.90); Relative slenderness λ̄_z = {c_ec4['lambda_z']:.3f}, λ̄_y = {c_ec4['lambda_y']:.3f} (≤ 2.0)."),
            (f"Phân tích phi tuyến P–δ (Corotational + 3 vùng giam giữ K_p={conf.kp:.2f}, K_h={conf.kh:.2f}): Tải phá hoại cực hạn N_u,FEM = {analysis['n_ultimate_fem_kn']:.1f} kN; Chuyển vị ngang giữa cột tại tải thiết kế Δ_mid = {analysis['lat_defl_design_mm']:.2f} mm."
             if vi else
             f"Nonlinear P–δ Fiber FEM (3-zone confinement K_p={conf.kp:.2f}, K_h={conf.kh:.2f}): Ultimate load N_u,FEM = {analysis['n_ultimate_fem_kn']:.1f} kN; Mid-height lateral deflection at design load Δ_mid = {analysis['lat_defl_design_mm']:.2f} mm."),
        ]

    refs = [
        "[1] EN 1994-1-1:2004 (Eurocode 4) — Design of composite steel and concrete structures: General rules and rules for buildings (§6.2, §6.6, §6.7).",
        "[2] European Commission RFCS SMARTCOCO (EUR 28914 EN, 2018) — Smart Composite Components: Concrete Structures Reinforced by Steel Profiles.",
        "[3] ANSI/AISC 360-22 — Specification for Structural Steel Buildings, Chapter I: Design of Composite Members (§I2, §I3, §I4, §I5).",
        "[4] JGJ 138-2016 — Code for Design of Composite Structures (China, Chapters 5 & 6).",
        "[5] TCVN 5574:2018, TCVN 5575:2024, TCVN 11823-6:2017 & SP 266.1325800.2016.",
        "[6] Lai, B., Liew, J.Y.R., & Xiong, M. (2019). Experimental study on high strength concrete encased steel composite short columns. Construction & Building Materials, 228, 116640.",
        "[7] Huang, Z., Liew, J.Y.R. et al. (2018). Experimental behaviour of VHSC-encased steel composite columns under axial compression and end moment. ASCCS 2018.",
        "[8] Chen, C.C. & Lin, N.J. (2006). Analytical model for predicting axial capacity and behavior of concrete encased steel composite stub columns. JCSR, 62(5), 424–433.",
        "[9] Weng, C.C., Yen, S.I., & Jiang, M.H. (2002). Experimental study on shear splitting failure of full-scale composite concrete encased steel beams. ASCE JSE.",
    ]

    return {
        "title": title,
        "subtitle": subtitle,
        "param_rows": param_rows,
        "code_headers": code_headers,
        "code_rows": code_rows,
        "summary_bullets": summary_bullets,
        "bom": compute_material_schedule(analysis, lang=lang),
        "refs": refs,
        "overall_pass": checks["overall_pass"],
    }


def _export_docx_generic(analysis: Dict[str, object], out_path: str, lang: str = "vi") -> str:
    """Tạo tệp thuyết minh Microsoft Word (.DOCX) chuẩn học thuật song ngữ VI / EN."""
    from docx import Document
    from docx.shared import Inches, Pt, RGBColor
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.oxml import OxmlElement, parse_xml
    from docx.oxml.ns import nsdecls

    data = _build_report_sections_data(analysis, lang=lang)
    vi = (lang == "vi")
    doc = Document()

    # Thiết lập phông chữ Times New Roman toàn văn bản
    normal_style = doc.styles["Normal"]
    normal_style.font.name = "Times New Roman"
    normal_style.font.size = Pt(11)

    def _shade_cell(cell, hex_color: str) -> None:
        shading = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{hex_color}"/>')
        cell._tc.get_or_add_tcPr().append(shading)

    def _add_heading(text: str) -> None:
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(10)
        p.paragraph_format.space_after = Pt(4)
        r = p.add_run(text)
        r.bold = True
        r.font.size = Pt(12.5)
        r.font.color.rgb = RGBColor(0x0F, 0x3D, 0x6E)

    # Tiêu đề báo cáo
    p_top = doc.add_paragraph()
    p_top.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_top = p_top.add_run(data["title"])
    r_top.bold = True
    r_top.font.size = Pt(15)
    r_top.font.color.rgb = RGBColor(0x0F, 0x3D, 0x6E)

    p_sub = doc.add_paragraph()
    p_sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_sub = p_sub.add_run(data["subtitle"])
    r_sub.italic = True
    r_sub.font.size = Pt(10.5)
    r_sub.font.color.rgb = RGBColor(0x33, 0x41, 0x55)

    # 1. Thông số đầu vào
    _add_heading("1. THÔNG SỐ HÌNH HỌC, VẬT LIỆU & TẢI TRỌNG" if vi else "1. GEOMETRY, MATERIAL & LOADING PARAMETERS")
    t1 = doc.add_table(rows=1, cols=2)
    t1.style = "Table Grid"
    hdr1 = ["Thông số" if vi else "Parameter", "Giá trị thiết kế" if vi else "Design Value"]
    for i, h in enumerate(hdr1):
        t1.rows[0].cells[i].text = h
        _shade_cell(t1.rows[0].cells[i], "0F3D6E")
        for run in t1.rows[0].cells[i].paragraphs[0].runs:
            run.bold = True
            run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
    for idx, (k, v) in enumerate(data["param_rows"]):
        row = t1.add_row().cells
        row[0].text = k
        row[1].text = v
        if idx % 2:
            _shade_cell(row[0], "F1F5F9")
            _shade_cell(row[1], "F1F5F9")

    # 2. So sánh kết quả đa tiêu chuẩn & PTHH phi tuyến
    _add_heading("2. KẾT QUẢ PHÂN TÍCH PHI TUYẾN & KIỂM TRA ĐA TIÊU CHUẨN" if vi else "2. NONLINEAR FEM & MULTI-CODE VERIFICATION RESULTS")
    t2 = doc.add_table(rows=1, cols=len(data["code_headers"]))
    t2.style = "Table Grid"
    for i, h in enumerate(data["code_headers"]):
        t2.rows[0].cells[i].text = h
        _shade_cell(t2.rows[0].cells[i], "0F3D6E")
        for run in t2.rows[0].cells[i].paragraphs[0].runs:
            run.bold = True
            run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
    for idx, r_vals in enumerate(data["code_rows"]):
        row = t2.add_row().cells
        for i, val in enumerate(r_vals):
            row[i].text = str(val)
            if idx % 2:
                _shade_cell(row[i], "F8FAFC")

    # 3. Nhận xét & Bản chất vật lý
    _add_heading("3. NHẬN XÉT KHOA HỌC & KẾT LUẬN AN TOÀN" if vi else "3. ENGINEERING ASSESSMENT & SAFETY VERDICT")
    for b in data["summary_bullets"]:
        p = doc.add_paragraph(b, style="List Bullet")
        p.paragraph_format.space_after = Pt(3)

    verdict_p = doc.add_paragraph()
    rv = verdict_p.add_run(
        ("KẾT LUẬN TỔNG QUÁT: TIẾT DIỆN ĐẠT YÊU CẦU CHỊU LỰC & SỬ DỤNG (PASS)" if data["overall_pass"]
         else "KẾT LUẬN TỔNG QUÁT: TIẾT DIỆN CHƯA ĐẠT — CẦN TĂNG KÍCH THƯỚC HOẶC LÕI THÉP (FAIL)")
        if vi else
        ("OVERALL VERDICT: SECTION SATISFIES STRENGTH & SERVICEABILITY REQUIREMENTS (PASS)" if data["overall_pass"]
         else "OVERALL VERDICT: SECTION FAILS — INCREASE STEEL CORE OR DIMENSIONS (FAIL)")
    )
    rv.bold = True
    rv.font.size = Pt(11.5)
    rv.font.color.rgb = RGBColor(0x05, 0x96, 0x69) if data["overall_pass"] else RGBColor(0xDC, 0x26, 0x26)

    # 4. Biểu đồ kết quả & Phẫu thuật mặt cắt ANSYS
    _add_heading("4. BIỂU ĐỒ ĐÁP ỨNG PHI TUYẾN & PHẪU THUẬT MẶT CẮT NGANG (ANSYS)" if vi else "4. NONLINEAR RESPONSE & CROSS-SECTION DISSECTION (ANSYS)")
    png_bytes = _render_analysis_chart_png(analysis, lang=lang)
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        tmp.write(png_bytes)
        tmp_path = tmp.name
    try:
        doc.add_picture(tmp_path, width=Inches(6.3))
        doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

    # 5. Bảng thống kê vật liệu chế tạo (BOM / BBS)
    _add_heading("5. BẢNG THỐNG KÊ THÉP HÌNH, CỐT THÉP & BÊ TÔNG THI CÔNG" if vi else "5. BILL OF MATERIALS & FABRICATION SCHEDULE")
    t3 = doc.add_table(rows=1, cols=5)
    t3.style = "Table Grid"
    h3 = ["SH", "Hạng mục / Quy cách", "Mác VL", "Số lượng", "Khối lượng (kg)"] if vi else ["Mark", "Description", "Grade", "Qty", "Mass (kg)"]
    for i, h in enumerate(h3):
        t3.rows[0].cells[i].text = h
        _shade_cell(t3.rows[0].cells[i], "0F3D6E")
        for run in t3.rows[0].cells[i].paragraphs[0].runs:
            run.bold = True
            run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
    for idx, item in enumerate(data["bom"]):
        row = t3.add_row().cells
        for i, val in enumerate([item["mark"], item["desc"], item["grade"], item["qty"], f"{item['weight_kg']:.1f}"]):
            row[i].text = str(val)
            if idx % 2:
                _shade_cell(row[i], "F8FAFC")

    # 6. Tài liệu tham khảo & Tiêu chuẩn áp dụng
    _add_heading("6. TIÊU CHUẨN & TÀI LIỆU KHOA HỌC THAM CHIẾU" if vi else "6. DESIGN CODES & SCIENTIFIC REFERENCES")
    for ref in data["refs"]:
        p = doc.add_paragraph(ref)
        p.paragraph_format.space_after = Pt(2)
        p.runs[0].font.size = Pt(9.5)

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    doc.save(out_path)
    return out_path


def _export_pdf_generic(analysis: Dict[str, object], out_path: str, lang: str = "vi") -> str:
    """Tạo tệp thuyết minh PDF chuẩn học thuật song ngữ VI / EN bằng ReportLab Platypus."""
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import mm
    from reportlab.lib import colors
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, KeepTogether

    font_reg, font_bold = _register_unicode_fonts()
    data = _build_report_sections_data(analysis, lang=lang)
    vi = (lang == "vi")

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    doc = SimpleDocTemplate(
        out_path, pagesize=A4,
        leftMargin=16 * mm, rightMargin=16 * mm, topMargin=16 * mm, bottomMargin=16 * mm,
    )

    st_title = ParagraphStyle("TitleVN", fontName=font_bold, fontSize=13.5, leading=18, alignment=1, textColor=colors.HexColor("#0F3D6E"))
    st_sub = ParagraphStyle("SubVN", fontName=font_reg, fontSize=9.2, leading=13, alignment=1, textColor=colors.HexColor("#475569"))
    st_h = ParagraphStyle("HeadVN", fontName=font_bold, fontSize=10.8, leading=15, spaceBefore=9, spaceAfter=4, textColor=colors.HexColor("#0F3D6E"))
    st_body = ParagraphStyle("BodyVN", fontName=font_reg, fontSize=9.2, leading=13.2, textColor=colors.HexColor("#0F172A"))
    st_ref = ParagraphStyle("RefVN", fontName=font_reg, fontSize=8.2, leading=11.5, textColor=colors.HexColor("#334155"))

    story = [
        Paragraph(data["title"], st_title),
        Spacer(1, 3 * mm),
        Paragraph(data["subtitle"], st_sub),
        Spacer(1, 5 * mm),
    ]

    def _make_table(headers: List[str], rows: List[List[str]], col_widths: List[float]):
        tdata = [[Paragraph(f"<b>{h}</b>", ParagraphStyle("TH", fontName=font_bold, fontSize=8.2, textColor=colors.white)) for h in headers]]
        for r in rows:
            tdata.append([Paragraph(str(v), ParagraphStyle("TD", fontName=font_reg, fontSize=8.0, leading=10.5)) for v in r])
        tbl = Table(tdata, colWidths=col_widths, repeatRows=1)
        tbl.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0F3D6E")),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8FAFC")]),
            ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#CBD5E1")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))
        return tbl

    story.append(Paragraph("1. THÔNG SỐ HÌNH HỌC, VẬT LIỆU & TẢI TRỌNG" if vi else "1. GEOMETRY, MATERIAL & LOADING PARAMETERS", st_h))
    story.append(_make_table(
        ["Thông số" if vi else "Parameter", "Giá trị" if vi else "Value"],
        data["param_rows"], [56 * mm, 122 * mm]
    ))

    story.append(Paragraph("2. KẾT QUẢ PHÂN TÍCH PHI TUYẾN & KIỂM TRA ĐA TIÊU CHUẨN" if vi else "2. NONLINEAR FEM & MULTI-CODE VERIFICATION", st_h))
    n_c = len(data["code_headers"])
    cw2 = [54 * mm, 26 * mm, 24 * mm, 25 * mm, 25 * mm, 24 * mm] if n_c == 6 else [56 * mm, 32 * mm, 40 * mm, 24 * mm, 26 * mm]
    story.append(_make_table(data["code_headers"], data["code_rows"], cw2))

    story.append(Paragraph("3. NHẬN XÉT KHOA HỌC & KẾT LUẬN AN TOÀN" if vi else "3. ENGINEERING ASSESSMENT & VERDICT", st_h))
    for b in data["summary_bullets"]:
        story.append(Paragraph(f"• {b}", st_body))
        story.append(Spacer(1, 1.5 * mm))

    v_col = "#059669" if data["overall_pass"] else "#DC2626"
    v_txt = (
        ("KẾT LUẬN: ĐẠT YÊU CẦU THIẾT KẾ (PASS)" if data["overall_pass"] else "KẾT LUẬN: CHƯA ĐẠT YÊU CẦU (FAIL)")
        if vi else
        ("VERDICT: DESIGN REQUIREMENTS SATISFIED (PASS)" if data["overall_pass"] else "VERDICT: DESIGN CHECK FAILED (FAIL)")
    )
    story.append(Paragraph(f'<font color="{v_col}"><b>{v_txt}</b></font>', st_h))

    png_bytes = _render_analysis_chart_png(analysis, lang=lang)
    story.append(KeepTogether([
        Paragraph("4. BIỂU ĐỒ ĐÁP ỨNG PHI TUYẾN & PHẪU THUẬT MẶT CẮT (ANSYS)" if vi else "4. NONLINEAR RESPONSE & CROSS-SECTION DISSECTION", st_h),
        Image(io.BytesIO(png_bytes), width=176 * mm, height=72 * mm),
        Spacer(1, 3 * mm),
    ]))

    story.append(Paragraph("5. BẢNG THỐNG KÊ VẬT LIỆU CHẾ TẠO (BOM / BBS)" if vi else "5. BILL OF MATERIALS (BOM / BBS)", st_h))
    h3 = ["SH", "Hạng mục", "Mác VL", "SL", "KL (kg)"] if vi else ["Mark", "Description", "Grade", "Qty", "Mass (kg)"]
    r3 = [[x["mark"], x["desc"], x["grade"], x["qty"], f"{x['weight_kg']:.1f}"] for x in data["bom"]]
    story.append(_make_table(h3, r3, [16 * mm, 84 * mm, 30 * mm, 26 * mm, 22 * mm]))

    story.append(Paragraph("6. TÀI LIỆU & TIÊU CHUẨN THAM CHIẾU" if vi else "6. REFERENCES & DESIGN STANDARDS", st_h))
    for ref in data["refs"]:
        story.append(Paragraph(ref, st_ref))

    doc.build(story)
    return out_path


def export_beam_report_docx(analysis: Dict[str, object], out_path: str, lang: str = "vi") -> str:
    """Xuất thuyết minh Word (.DOCX) cho Dầm bê tông cốt cứng (lang='vi' hoặc 'en')."""
    return _export_docx_generic(analysis, out_path, lang=lang)


def export_beam_report_pdf(analysis: Dict[str, object], out_path: str, lang: str = "vi") -> str:
    """Xuất thuyết minh PDF (.PDF) cho Dầm bê tông cốt cứng (lang='vi' hoặc 'en')."""
    return _export_pdf_generic(analysis, out_path, lang=lang)


def export_column_report_docx(analysis: Dict[str, object], out_path: str, lang: str = "vi") -> str:
    """Xuất thuyết minh Word (.DOCX) cho Cột bê tông cốt cứng (lang='vi' hoặc 'en')."""
    return _export_docx_generic(analysis, out_path, lang=lang)


def export_column_report_pdf(analysis: Dict[str, object], out_path: str, lang: str = "vi") -> str:
    """Xuất thuyết minh PDF (.PDF) cho Cột bê tông cốt cứng (lang='vi' hoặc 'en')."""
    return _export_pdf_generic(analysis, out_path, lang=lang)
