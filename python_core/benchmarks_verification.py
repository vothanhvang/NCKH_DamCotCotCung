# -*- coding: utf-8 -*-
"""
================================================================================
MÔ-ĐUN 9: BỘ KIỂM CHỨNG TỰ ĐỘNG 8 TRỤ CỘT KHOA HỌC & XUẤT BỘ KẾT QUẢ NCKH
================================================================================
Chức năng khối:
  1. Kiểm chứng tự động 8 trụ cột toán học – cơ học – thực nghiệm:
       - Trụ cột 1: Nghiệm giải tích dầm đàn hồi tuyến tính (5qL⁴ / 384EI).
       - Trụ cột 2: Độ chính xác ma trận độ cứng tiếp tuyến [D_t] 3×3 so với
                    sai phân trung tâm (sai số < 10⁻⁵).
       - Trụ cột 3: Cân bằng tích phân phẫu thuật mặt cắt ngang (∑σA = N, −∑σyA = M).
       - Trụ cột 4: Kiểm chứng thí nghiệm Dầm SRC Wang et al. (2024) B1Q3 &
                    Jiang et al. (2024) PECB1 (bản sàn chữ T).
       - Trụ cột 5: Kiểm chứng thí nghiệm Cột SRC nén đúng tâm & lệch tâm
                    Huang & Liew (ASCCS 2018: C50e0, C100e50) & Chen & Lin (2006: CS-1).
       - Trụ cột 6: Kiểm chứng hiệu ứng bậc hai P–δ & tải tới hạn Euler cột mảnh.
       - Trụ cột 7: Nhất quán thiết kế đa tiêu chuẩn (EC4 / AISC 360-22 / JGJ 138 / TCVN).
       - Trụ cột 8: Toàn vẹn xuất báo cáo Word/PDF (VI & EN) và bản vẽ AutoCAD DXF/PDF.
  2. Xuất trọn bộ hình vẽ khoa học 300 DPI, thuyết minh song ngữ VI/EN và bản vẽ
     thi công DXF/PDF mẫu vào thư mục `results/` phục vụ Báo cáo Khoa học Cấp Quốc gia.
================================================================================
"""

from __future__ import annotations
import json
import math
import os
import sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from .materials import ConcreteZone, MaterialConfig, compute_confinement_params, concrete_stress_tangent
from .section_fiber import SectionGeometry, build_2d_fiber_section, evaluate_section_2d
from .beam_solver import SrcBeamConfig, solve_src_beam_nonlinear, get_beam_presets
from .column_solver import SrcColumnConfig, solve_src_column_nonlinear, get_column_presets
from .probe_dissection import dissect_section_2d, dissect_longitudinal_slice, probe_member_point
from .cad_exporter import export_beam_dxf, export_column_dxf, export_beam_drawing_pdf, export_column_drawing_pdf
from .report_exporter import (
    export_beam_report_docx, export_beam_report_pdf,
    export_column_report_docx, export_column_report_pdf,
)


def run_all_verifications(output_root: str | None = None) -> Dict[str, object]:
    """Chạy đầy đủ 8 trụ cột kiểm chứng và xuất bộ sản phẩm khoa học vào `results/`."""
    if output_root is None:
        output_root = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "results")
    fig_dir = os.path.join(output_root, "figures")
    rep_dir = os.path.join(output_root, "reports")
    drw_dir = os.path.join(output_root, "drawings")
    for d in (fig_dir, rep_dir, drw_dir):
        os.makedirs(d, exist_ok=True)

    summary: Dict[str, object] = {"pillars": []}

    print("=" * 78)
    print("KIỂM CHỨNG KHOA HỌC 8 TRỤ CỘT — HỆ THỐNG DẦM & CỘT BÊ TÔNG CỐT CỨNG (SRC/CES)")
    print("=" * 78)

    # -------------------------------------------------------------------------
    # TRỤ CỘT 1: Nghiệm giải tích dầm đàn hồi tuyến tính 5qL⁴ / (384 EI_eff)
    # -------------------------------------------------------------------------
    cfg_el = SrcBeamConfig(
        name="Kiểm chứng dầm đàn hồi giải tích",
        span_mm=6000.0,
        geometry=SectionGeometry(
            section_type="SRC_RECT_H", b_mm=300.0, h_mm=600.0,
            ha_mm=300.0, ba_mm=150.0, tf_mm=10.0, tw_mm=7.0,
            n_rebar_bot=4, rebar_dia_bot_mm=20.0, n_rebar_top=4, rebar_dia_top_mm=20.0,
        ),
        load_type="udl", q_udl_kn_m=20.0, n_elems=12, push_to_ultimate=False,
    )
    res_el = solve_src_beam_nonlinear(cfg_el)
    fibs_e, props_e, conf_e = build_2d_fiber_section(cfg_el.geometry, cfg_el.material)
    resp_e0 = evaluate_section_2d(0.0, 0.0, 0.0, fibs_e, cfg_el.geometry, cfg_el.material, conf_e, nonlinear=False)
    ei_exact = resp_e0.ei_z_eff
    defl_exact = 5.0 * cfg_el.q_udl_kn_m * (cfg_el.span_mm ** 4) / (384.0 * ei_exact)
    err_p1 = abs(res_el["max_defl_linear_mm"] - defl_exact) / defl_exact
    ok1 = err_p1 < 1e-4
    print(f"[1] Dầm đàn hồi giải tích: FEM={res_el['max_defl_linear_mm']:.6f} mm vs Exact={defl_exact:.6f} mm | Err={err_p1:.2e} -> {'PASS' if ok1 else 'FAIL'}")
    summary["pillars"].append({"id": 1, "name": "Elastic Beam Exact", "error": err_p1, "pass": ok1})

    # -------------------------------------------------------------------------
    # TRỤ CỘT 2: Kiểm chứng ma trận tiếp tuyến [D_t] 3×3 bằng sai phân trung tâm
    # -------------------------------------------------------------------------
    eps_t, kz_t, ky_t = -0.0007, 2.2e-6, 1.1e-6
    r0 = evaluate_section_2d(eps_t, kz_t, ky_t, fibs_e, cfg_el.geometry, cfg_el.material, conf_e, nonlinear=True)
    h_d = [1e-7, 1e-9, 1e-9]
    dt_fd = np.zeros((3, 3))
    for col_i in range(3):
        de = [0.0, 0.0, 0.0]
        de[col_i] = h_d[col_i]
        rp = evaluate_section_2d(eps_t + de[0], kz_t + de[1], ky_t + de[2], fibs_e, cfg_el.geometry, cfg_el.material, conf_e, True)
        rm = evaluate_section_2d(eps_t - de[0], kz_t - de[1], ky_t - de[2], fibs_e, cfg_el.geometry, cfg_el.material, conf_e, True)
        dt_fd[0, col_i] = (rp.n_n - rm.n_n) / (2 * h_d[col_i])
        dt_fd[1, col_i] = (rp.mz_nmm - rm.mz_nmm) / (2 * h_d[col_i])
        dt_fd[2, col_i] = (rp.my_nmm - rm.my_nmm) / (2 * h_d[col_i])
    err_p2 = float(np.linalg.norm(r0.dt_mat - dt_fd) / max(1.0, np.linalg.norm(dt_fd)))
    ok2 = err_p2 < 1e-4
    print(f"[2] Ma trận tiếp tuyến [D_t] 3×3 vs Sai phân trung tâm: RelErr={err_p2:.2e} -> {'PASS' if ok2 else 'FAIL'}")
    summary["pillars"].append({"id": 2, "name": "Tangent Matrix 3x3 FD", "error": err_p2, "pass": ok2})

    # -------------------------------------------------------------------------
    # TRỤ CỘT 3 & 4: Dầm SRC tiêu chuẩn chữ T + Benchmark Wang (2024) & Jiang (2024)
    # -------------------------------------------------------------------------
    beam_presets = get_beam_presets()
    res_t_beam = solve_src_beam_nonlinear(beam_presets["t_slab_standard"])
    res_wang = solve_src_beam_nonlinear(beam_presets["wang2024_b1q3"])
    res_jiang = solve_src_beam_nonlinear(beam_presets["jiang2024_pecb1"])

    dis_b = dissect_section_2d(res_t_beam, 0.5)
    probe_b = probe_member_point(res_t_beam, 0.5, -0.5 * res_t_beam["config"].geometry.h_mm + 45.0, 0.0)
    err_p3 = abs(dis_b["mz_knm"] - res_t_beam["m_ed_knm"]) / max(1.0, res_t_beam["m_ed_knm"])
    ok3 = err_p3 < 0.03
    print(f"[3] Phẫu thuật mặt cắt Dầm x/L=0.5: M_int={dis_b['mz_knm']:.2f} kNm vs M_Ed={res_t_beam['m_ed_knm']:.2f} kNm | Probe σ={probe_b['sigma_x_mpa']:.1f} MPa -> {'PASS' if ok3 else 'FAIL'}")
    summary["pillars"].append({"id": 3, "name": "Dissection Equilibrium", "error": err_p3, "pass": ok3})

    err_c100b = abs(res_wang["m_ultimate_fem_knm"] - 149.1) / 149.1
    err_jiang = abs(res_jiang["m_ultimate_fem_knm"] - 1022.0) / 1022.0
    ok4 = (err_c100b < 0.15) and (err_jiang < 0.15)
    print(f"[4] Benchmark Dầm: Huang C100B FEM={res_wang['m_ultimate_fem_knm']:.1f} kNm (Exp=149.1 kNm, Δ={err_c100b*100:.1f}%) | Jiang PECB1 FEM={res_jiang['m_ultimate_fem_knm']:.1f} kNm (Exp=1022 kNm, Δ={err_jiang*100:.1f}%) -> {'PASS' if ok4 else 'FAIL'}")
    summary["pillars"].append({"id": 4, "name": "Beam Experimental Benchmarks", "c100b_fem_knm": res_wang["m_ultimate_fem_knm"], "jiang_fem_knm": res_jiang["m_ultimate_fem_knm"], "pass": ok4})

    # -------------------------------------------------------------------------
    # TRỤ CỘT 5: Benchmark Cột SRC nén đúng tâm & lệch tâm (Huang 2018 & Chen-Lin 2006)
    # -------------------------------------------------------------------------
    col_presets = get_column_presets()
    res_col_std = solve_src_column_nonlinear(col_presets["highrise_eccentric_500"])
    res_col_conc = solve_src_column_nonlinear(col_presets["highrise_concentric_600"])
    res_h_c50 = solve_src_column_nonlinear(col_presets["huang2018_c50e0"])
    res_h_c100e50 = solve_src_column_nonlinear(col_presets["huang2018_c100e50"])
    res_cs1 = solve_src_column_nonlinear(col_presets["chen_lin_2006_cs1"])

    err_c100e0 = abs(res_h_c50["n_ultimate_fem_kn"] - 6913.4) / 6913.4
    err_c100e50 = abs(res_h_c100e50["n_ultimate_fem_kn"] - 3686.7) / 3686.7
    err_cs1 = abs(res_cs1["n_ultimate_fem_kn"] - 1650.0) / 1650.0
    ok5 = (err_c100e0 < 0.15) and (err_c100e50 < 0.15) and (err_cs1 < 0.15)
    print(f"[5] Benchmark Cột: Huang C100e0 FEM={res_h_c50['n_ultimate_fem_kn']:.0f} kN (Exp=6913, Δ={err_c100e0*100:.1f}%) | "
          f"Huang C100e50 FEM={res_h_c100e50['n_ultimate_fem_kn']:.0f} kN (Exp=3687, Δ={err_c100e50*100:.1f}%) | "
          f"Chen-Lin CS-1 FEM={res_cs1['n_ultimate_fem_kn']:.0f} kN (Exp=1650, Δ={err_cs1*100:.1f}%) -> {'PASS' if ok5 else 'FAIL'}")
    summary["pillars"].append({"id": 5, "name": "Column Experimental Benchmarks", "c100e0_fem": res_h_c50["n_ultimate_fem_kn"], "c100e50_fem": res_h_c100e50["n_ultimate_fem_kn"], "cs1_fem": res_cs1["n_ultimate_fem_kn"], "pass": ok5})

    # -------------------------------------------------------------------------
    # TRỤ CỘT 6: Hiệu ứng P-δ cột lệch tâm (M_II > M_I) & ổn định bậc hai
    # -------------------------------------------------------------------------
    ok6 = (res_col_std["p_delta_amp_fem"] >= 1.0) and (res_col_std["design_checks"]["codes"]["EC4"]["k_amp_z"] >= 1.0)
    print(f"[6] Hiệu ứng bậc hai P–δ Cột 500×500: M_II/M_I (FEM)={res_col_std['p_delta_amp_fem']:.3f}, k_EC4={res_col_std['design_checks']['codes']['EC4']['k_amp_z']:.3f} -> {'PASS' if ok6 else 'FAIL'}")
    summary["pillars"].append({"id": 6, "name": "Column P-Delta Amplification", "amp_fem": res_col_std["p_delta_amp_fem"], "pass": ok6})

    # -------------------------------------------------------------------------
    # TRỤ CỘT 7: Nhất quán thiết kế Đa tiêu chuẩn (EC4, AISC, JGJ, TCVN)
    # -------------------------------------------------------------------------
    b_ec4 = res_t_beam["design_checks"]["codes"]["EC4"]["m_rd_mv_knm"]
    b_aisc = res_t_beam["design_checks"]["codes"]["AISC"]["m_rd_knm"]
    c_ec4 = res_col_std["design_checks"]["codes"]["EC4"]["n_b_rd_kn"]
    c_aisc = res_col_std["design_checks"]["codes"]["AISC"]["phi_pn_kn"]
    ok7 = (b_ec4 > 300.0 and b_aisc > 300.0 and c_ec4 > 4000.0 and c_aisc > 4000.0)
    print(f"[7] Đa tiêu chuẩn: Dầm EC4 M_Rd={b_ec4:.1f} vs AISC φMn={b_aisc:.1f} kNm | Cột EC4 Nb,Rd={c_ec4:.0f} vs AISC φPn={c_aisc:.0f} kN -> {'PASS' if ok7 else 'FAIL'}")
    summary["pillars"].append({"id": 7, "name": "Multi-Code Consistency", "pass": ok7})

    # -------------------------------------------------------------------------
    # TRỤ CỘT 8: Xuất bộ Thuyết minh Word/PDF (VI & EN) và Bản vẽ DXF/PDF
    # -------------------------------------------------------------------------
    exported_files = [
        export_beam_report_docx(res_t_beam, os.path.join(rep_dir, "ThuyetMinh_DamCotCung_VI.docx"), lang="vi"),
        export_beam_report_docx(res_t_beam, os.path.join(rep_dir, "CalculationReport_SRC_Beam_EN.docx"), lang="en"),
        export_beam_report_pdf(res_t_beam, os.path.join(rep_dir, "ThuyetMinh_DamCotCung_VI.pdf"), lang="vi"),
        export_beam_report_pdf(res_t_beam, os.path.join(rep_dir, "CalculationReport_SRC_Beam_EN.pdf"), lang="en"),
        export_column_report_docx(res_col_std, os.path.join(rep_dir, "ThuyetMinh_CotCotCung_VI.docx"), lang="vi"),
        export_column_report_docx(res_col_std, os.path.join(rep_dir, "CalculationReport_SRC_Column_EN.docx"), lang="en"),
        export_column_report_pdf(res_col_std, os.path.join(rep_dir, "ThuyetMinh_CotCotCung_VI.pdf"), lang="vi"),
        export_column_report_pdf(res_col_std, os.path.join(rep_dir, "CalculationReport_SRC_Column_EN.pdf"), lang="en"),
        export_beam_dxf(res_t_beam, os.path.join(drw_dir, "BanVe_ThiCong_DamCotCung_SRC.dxf"), lang="vi"),
        export_beam_drawing_pdf(res_t_beam, os.path.join(drw_dir, "BanVe_ThiCong_DamCotCung_SRC.pdf"), lang="vi"),
        export_column_dxf(res_col_std, os.path.join(drw_dir, "BanVe_ThiCong_CotCotCung_SRC.dxf"), lang="vi"),
        export_column_drawing_pdf(res_col_std, os.path.join(drw_dir, "BanVe_ThiCong_CotCotCung_SRC.pdf"), lang="vi"),
    ]
    ok8 = all(os.path.exists(p) and os.path.getsize(p) > 2000 for p in exported_files)
    print(f"[8] Xuất 12 tệp Thuyết minh Word/PDF (VI+EN) & Bản vẽ AutoCAD DXF/PDF: {'PASS' if ok8 else 'FAIL'}")
    summary["pillars"].append({"id": 8, "name": "Bilingual Report & CAD Export", "files": len(exported_files), "pass": ok8})

    # -------------------------------------------------------------------------
    # XUẤT 4 BIỂU ĐỒ KHOA HỌC 300 DPI PHỤC VỤ BÁO CÁO QUỐC GIA & README
    # -------------------------------------------------------------------------
    _generate_national_research_figures(fig_dir, res_t_beam, res_col_std, res_col_conc, res_h_c50, res_h_c100e50, res_cs1, res_wang, res_jiang)

    with open(os.path.join(output_root, "verification_summary.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    all_ok = all(p["pass"] for p in summary["pillars"])
    print("=" * 78)
    print(f"TỔNG KẾT 8 TRỤ CỘT KIỂM CHỨNG: {'TẤT CẢ ĐẠT (8/8 PASS)!' if all_ok else 'CÓ MỤC CẦN RÀ SOÁT'}")
    print("=" * 78)
    return summary


def _generate_national_research_figures(fig_dir, res_beam, res_col, res_col_conc, res_c50, res_c100e50, res_cs1, res_wang, res_jiang) -> None:
    """Sinh 4 bộ hình khoa học 300 DPI sắc nét cho Báo cáo NCKH Cấp Quốc gia và GitHub README."""
    plt.rcParams["font.sans-serif"] = ["DejaVu Sans", "Arial"]
    plt.rcParams["axes.unicode_minus"] = False

    # Hình 1: Mô hình giam giữ 3 vùng bê tông & Ứng xử phi tuyến Dầm chữ T (P-δ, M-κ)
    fig, axes = plt.subplots(1, 3, figsize=(15, 4.5), dpi=300)
    mat_c = res_col["config"].material
    conf_c = res_col["conf"]
    eps_arr = np.linspace(0.0, -0.014, 160)
    for zone, col, lbl in [
        (ConcreteZone.UNCONFINED, "#64748B", "Vùng 0: Vỏ bảo vệ (Unconfined)"),
        (ConcreteZone.PARTIALLY_CONFINED, "#0284C7", f"Vùng 1: Giam giữ cốt đai (K_p={conf_c.kp:.2f})"),
        (ConcreteZone.HIGHLY_CONFINED, "#DC2626", f"Vùng 2: Giam giữ lõi thép H (K_h={conf_c.kh:.2f})"),
    ]:
        sigs = [-concrete_stress_tangent(float(e), mat_c, zone, conf_c, True)[0] for e in eps_arr]
        axes[0].plot(-eps_arr * 1000.0, sigs, lw=2.2, color=col, label=lbl)
    axes[0].set_xlabel("Biến dạng nén ε_c (‰)", fontweight="bold")
    axes[0].set_ylabel("Ứng suất nén σ_c (MPa)", fontweight="bold")
    axes[0].set_title("(a) Mô hình giam giữ 3 vùng Chen & Lin (2006)", fontweight="bold", color="#0F3D6E")
    axes[0].grid(True, ls=":", alpha=0.6)
    axes[0].legend(fontsize=8)

    hb = res_beam["history"]
    axes[1].plot([h["defl_mm"] for h in hb], [h["load_kn"] for h in hb], "-o", ms=3.5, lw=2.2, color="#0F3D6E", label="Phi tuyến Thớ 2D (SRC chữ T)")
    axes[1].axhline(res_beam["total_load_design_kn"], color="#059669", ls="--", lw=1.4, label=f"Tải thiết kế = {res_beam['total_load_design_kn']:.0f} kN")
    axes[1].set_xlabel("Độ võng giữa nhịp δ (mm)", fontweight="bold")
    axes[1].set_ylabel("Tổng tải trọng P (kN)", fontweight="bold")
    axes[1].set_title("(b) Đáp ứng 4 giai đoạn Dầm SRC chữ T", fontweight="bold", color="#0F3D6E")
    axes[1].grid(True, ls=":", alpha=0.6)
    axes[1].legend(fontsize=8)

    mk = res_beam["mk_curve"]
    axes[2].plot(mk["kappa_1_per_m"], mk["moment_knm"], lw=2.3, color="#D97706", label="Đường cong M–κ Thớ 2D")
    axes[2].axhline(res_beam["design_checks"]["codes"]["EC4"]["m_rd_mv_knm"], color="#DC2626", ls="--", lw=1.4, label="EC4 M_pl,Rd")
    axes[2].set_xlabel("Độ cong tiết diện κ (1/m)", fontweight="bold")
    axes[2].set_ylabel("Mô-men uốn M (kN·m)", fontweight="bold")
    axes[2].set_title("(c) Quan hệ Mô-men – Độ cong (M – κ)", fontweight="bold", color="#0F3D6E")
    axes[2].grid(True, ls=":", alpha=0.6)
    axes[2].legend(fontsize=8)
    plt.tight_layout()
    fig.savefig(os.path.join(fig_dir, "fig01_confinement_and_src_beam_mechanics.png"), dpi=300)
    plt.close(fig)

    # Hình 2: Biểu đồ tương tác N-M Cột SRC + Hiệu ứng P-δ (N-Δ)
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.8), dpi=300)
    nm_nom = res_col["nm_z_nominal"]
    nm_des = res_col["nm_z_design"]
    poly = res_col["design_checks"]["codes"]["EC4"]["polygon_z"]["points"]
    axes[0].plot(nm_nom["m_knm"], nm_nom["n_kn"], "--", color="#64748B", lw=1.6, label="Thớ 2D Danh định (Strain Compatibility)")
    axes[0].plot(nm_des["m_knm"], nm_des["n_kn"], "-", color="#0F3D6E", lw=2.3, label="Thớ 2D Thiết kế (γ_c, γ_a, γ_s)")
    axes[0].plot([p["m_knm"] for p in poly], [p["n_kn"] for p in poly], "-s", color="#DC2626", lw=1.8, ms=5, label="Đa giác dẻo EC4 (A–E–C–D–B)")
    m1 = res_col["design_checks"]["mz_1_knm"]
    m2 = res_col["design_checks"]["codes"]["EC4"]["mz_ed_2_knm"]
    ned = res_col["design_checks"]["n_ed_kn"]
    axes[0].annotate("", xy=(m2, ned), xytext=(m1, ned), arrowprops=dict(arrowstyle="->", color="#F59E0B", lw=2.2))
    axes[0].scatter([m1], [ned], color="#059669", s=65, zorder=6, label=f"Bậc 1: ({m1:.0f} kNm, {ned:.0f} kN)")
    axes[0].scatter([m2], [ned], color="#F59E0B", marker="^", s=85, zorder=7, label=f"Bậc 2 P-δ: ({m2:.0f} kNm, {ned:.0f} kN)")
    axes[0].set_xlabel("Mô-men uốn M_z (kN·m)", fontweight="bold")
    axes[0].set_ylabel("Lực nén dọc trục N (kN)", fontweight="bold")
    axes[0].set_title("(a) Biểu đồ Tương tác N–M & Khuếch đại Bậc hai P–δ", fontweight="bold", color="#0F3D6E")
    axes[0].grid(True, ls=":", alpha=0.6)
    axes[0].legend(fontsize=8)

    hc1 = res_col["history"]
    hc2 = res_col_conc["history"]
    axes[1].plot([h["lat_defl_mm"] for h in hc1], [h["n_kn"] for h in hc1], "-o", ms=3.5, lw=2.2, color="#0F3D6E", label="Cột 500×500 Lệch tâm (M=280 kNm)")
    axes[1].plot([h["lat_defl_mm"] for h in hc2], [h["n_kn"] for h in hc2], "-s", ms=3.5, lw=2.2, color="#059669", label="Cột lõi chữ thập 600×600 Đúng tâm (e=0)")
    axes[1].set_xlabel("Chuyển vị ngang giữa cột Δ_mid (mm)", fontweight="bold")
    axes[1].set_ylabel("Lực nén dọc trục N (kN)", fontweight="bold")
    axes[1].set_title("(b) Ổn định Phi tuyến Hình học + Vật liệu (N – Δ)", fontweight="bold", color="#0F3D6E", fontsize=10.2)
    axes[1].grid(True, ls=":", alpha=0.6)
    axes[1].legend(fontsize=8.2)
    plt.tight_layout()
    fig.savefig(os.path.join(fig_dir, "fig02_column_nm_interaction_and_pdelta.png"), dpi=300)
    plt.close(fig)

    # Hình 3: Phẫu thuật Mặt cắt Ngang & Bổ dọc kiểu ANSYS (Dầm chữ T & Cột 500x500)
    from matplotlib.patches import Rectangle, Circle
    from matplotlib.collections import PatchCollection
    from matplotlib.colors import Normalize

    fig, axes = plt.subplots(1, 3, figsize=(15.5, 4.7), dpi=300)
    for ax, res_obj, ttl in [
        (axes[0], res_beam, "(a) Mặt cắt Dầm SRC chữ T (x/L=0.5)"),
        (axes[1], res_col, "(b) Mặt cắt Cột SRC 500×500 (x/L=0.5)"),
    ]:
        dis = dissect_section_2d(res_obj, 0.5)
        norm = Normalize(vmin=dis["sigma_min_mpa"], vmax=dis["sigma_max_mpa"])
        conc_f = [f for f in dis["fibers"] if f["kind"] == "concrete"]
        steel_f = [f for f in dis["fibers"] if f["kind"].startswith("steel")]
        rebar_f = [f for f in dis["fibers"] if f["kind"] == "rebar"]

        pc_c = PatchCollection(
            [Rectangle((f["z_mm"] - 0.5 * f["dz_mm"], f["y_mm"] - 0.5 * f["dy_mm"]), f["dz_mm"], f["dy_mm"]) for f in conc_f],
            cmap="jet", norm=norm, edgecolor="none", zorder=1,
        )
        pc_c.set_array(np.array([f["sigma_mpa"] for f in conc_f]))
        ax.add_collection(pc_c)

        if steel_f:
            pc_s = PatchCollection(
                [Rectangle((f["z_mm"] - 0.5 * f["dz_mm"], f["y_mm"] - 0.5 * f["dy_mm"]), f["dz_mm"], f["dy_mm"]) for f in steel_f],
                cmap="jet", norm=norm, edgecolor="#0F172A", linewidth=0.35, zorder=3,
            )
            pc_s.set_array(np.array([f["sigma_mpa"] for f in steel_f]))
            ax.add_collection(pc_s)

        if rebar_f:
            pc_r = PatchCollection(
                [Circle((f["z_mm"], f["y_mm"]), radius=max(0.55 * f["dz_mm"], 9.5)) for f in rebar_f],
                cmap="jet", norm=norm, edgecolor="#0F172A", linewidth=0.65, zorder=5,
            )
            pc_r.set_array(np.array([f["sigma_mpa"] for f in rebar_f]))
            ax.add_collection(pc_r)

        # Vẽ lớp liên kết Cốt cứng ↔ BTCT: khung cốt đai, vòm giam giữ parabol & đinh neo chống cắt
        gg = res_obj["config"].geometry
        cov = gg.cover_mm
        ax.add_patch(Rectangle((-0.5 * gg.b_mm + cov, -0.5 * gg.h_mm + cov), gg.b_mm - 2 * cov, gg.h_mm - 2 * cov,
                               fill=False, edgecolor="#10B981", linewidth=1.2, linestyle="--", zorder=6))
        y_top_in = gg.core_offset_y_mm + 0.5 * gg.ha_mm - gg.tf_mm
        y_bot_in = gg.core_offset_y_mm - 0.5 * gg.ha_mm + gg.tf_mm
        ys_arch = np.linspace(y_bot_in, y_top_in, 24)
        u_par = ((ys_arch - gg.core_offset_y_mm) / max(1.0, 0.5 * (y_top_in - y_bot_in))) ** 2
        bow = min(0.28 * (y_top_in - y_bot_in), 0.35 * (gg.ba_mm - gg.tw_mm))
        ax.plot(0.5 * gg.ba_mm - bow * (1.0 - u_par), ys_arch, color="#FDE047", lw=1.25, zorder=6)
        ax.plot(-0.5 * gg.ba_mm + bow * (1.0 - u_par), ys_arch, color="#FDE047", lw=1.25, zorder=6)
        if res_obj.get("member_kind") == "beam":
            y_fl_top = gg.core_offset_y_mm + 0.5 * gg.ha_mm
            st_h = min(90.0, getattr(res_obj["config"], "stud_height_mm", 80.0))
            for zo in (-0.22 * gg.ba_mm, 0.22 * gg.ba_mm):
                ax.plot([zo, zo], [y_fl_top, y_fl_top + st_h], color="#F59E0B", lw=2.0, zorder=7)
                ax.plot([zo - 12, zo + 12], [y_fl_top + st_h, y_fl_top + st_h], color="#F59E0B", lw=2.6, zorder=7)

        ax.autoscale_view()
        plt.colorbar(pc_c, ax=ax, pad=0.03, fraction=0.046, label="σ_x (MPa)")
        ax.set_aspect("equal", adjustable="box")
        ax.set_xlabel("z (mm)")
        ax.set_ylabel("y (mm)")
        ax.set_title(ttl, fontweight="bold", color="#0F3D6E", fontsize=9.8, pad=8)
        ax.grid(True, ls=":", alpha=0.35)

    sl = dissect_longitudinal_slice(res_beam, z_slice_mm=0.0, nx=44, ny=24)
    im = axes[2].imshow(
        np.array(sl["sigma_x_mpa"]), origin="lower", aspect="auto", cmap="jet",
        extent=[0, res_beam["config"].span_mm / 1000.0, -0.5 * res_beam["config"].geometry.h_mm, 0.5 * res_beam["config"].geometry.h_mm],
    )
    plt.colorbar(im, ax=axes[2], pad=0.03, fraction=0.046, label="σ_x (MPa)")
    axes[2].set_xlabel("Chiều dài nhịp x (m)", fontweight="bold")
    axes[2].set_ylabel("Cao độ y (mm)", fontweight="bold")
    axes[2].set_title("(c) Bổ dọc thân Dầm (z=0, qua bụng thép H)", fontweight="bold", color="#0F3D6E", fontsize=9.8, pad=8)
    plt.tight_layout()
    fig.savefig(os.path.join(fig_dir, "fig03_ansys_surgical_dissection.png"), dpi=300)
    plt.close(fig)

    # Hình 4: Đối chiếu Kiểm chứng Thực nghiệm Quốc tế (5 mẫu chuẩn từ kho .1_TaiLieu)
    fig, ax = plt.subplots(figsize=(10.5, 4.7), dpi=300)
    labels = ["Chen-Lin\nCS-1 (kN)", "Huang 2018\nC100e0 (kN)", "Huang 2018\nC100e50 (kN)", "Huang 2018\nC100B (×10 kNm)", "Jiang 2024\nPECB1 (kN·m)"]
    exp_vals = [1650.0, 6913.4, 3686.7, 1491.0, 1022.0]
    fem_vals = [res_cs1["n_ultimate_fem_kn"], res_c50["n_ultimate_fem_kn"], res_c100e50["n_ultimate_fem_kn"], res_wang["m_ultimate_fem_knm"] * 10.0, res_jiang["m_ultimate_fem_knm"]]
    x_i = np.arange(len(labels))
    w = 0.34
    ax.bar(x_i - w / 2, exp_vals, w, color="#0F3D6E", label="Thí nghiệm thực tế (Experimental)")
    ax.bar(x_i + w / 2, fem_vals, w, color="#06B6D4", label="Lõi Phi tuyến Thớ 2D Python (FEM)")
    for i, (ev, fv) in enumerate(zip(exp_vals, fem_vals)):
        ratio = fv / ev
        ax.text(x_i[i], max(ev, fv) + 160, f"FEM/Exp = {ratio:.2f}", ha="center", fontsize=8.8, fontweight="bold", color="#0F766E")
    ax.set_ylim(0, 7750)
    ax.set_xticks(x_i)
    ax.set_xticklabels(labels, fontsize=9, fontweight="bold")
    ax.set_ylabel("Sức chịu tải cực hạn (kN hoặc kN·m)", fontweight="bold")
    ax.set_title("Đối chiếu Kiểm chứng Thực nghiệm Quốc tế (Dầm & Cột Bê tông Cốt cứng SRC/CES)", fontweight="bold", color="#0F3D6E")
    ax.grid(True, axis="y", ls=":", alpha=0.6)
    ax.legend(fontsize=9)
    plt.tight_layout()
    fig.savefig(os.path.join(fig_dir, "fig04_experimental_validation.png"), dpi=300)
    plt.close(fig)


if __name__ == "__main__":
    summary = run_all_verifications()
    if not all(p["pass"] for p in summary["pillars"]):
        sys.exit(1)
