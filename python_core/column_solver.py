# -*- coding: utf-8 -*-
"""
================================================================================
MÔ-ĐUN 4: PHÂN TÍCH PHI TUYẾN HÌNH HỌC + VẬT LIỆU & THIẾT KẾ CỘT BÊ TÔNG CỐT CỨNG
================================================================================
Chức năng khối:
  1. Giải PTHH Cột Thớ 2D Phi tuyến Vật liệu + Phi tuyến Hình học (P–δ Corotational
     Updated Lagrangian):
       - Xét đồng thời cả 3 trạng thái chịu tải:
           • Nén ĐÚNG TÂM (Concentric Compression: e_z = 0, e_y = 0) có khuyết tật
             hình học ban đầu e_imp (L/1000 hoặc EC4 Bảng 6.5) để bắt mất ổn định dọc.
           • Nén LỆCH TÂM PHẲNG 1 PHƯƠNG (Uniaxial Eccentric: e_z ≠ 0 hoặc e_y ≠ 0).
           • Nén LỆCH TÂM XIÊN 2 PHƯƠNG (Biaxial Eccentric: e_z ≠ 0 và e_y ≠ 0).
       - Ma trận độ cứng tiếp tuyến phần tử kết hợp độ cứng vật liệu tích phân thớ
         [K_m] và ma trận độ cứng hình học bậc hai [K_g(N)] theo lý thuyết CALFEM /
         Yang (2025) / NSA_4–NSA_6, bắt chính xác hiệu ứng khuếch đại bậc hai P–δ
         và đường cong tải trọng – chuyển vị ngang (N – Δ_mid) tới đỉnh phá hoại!
  2. Biểu đồ tương tác N–M & N–Mz–My:
       - Đường cong Tương thích Biến dạng Thớ 2D (Strain Compatibility — Huang & Liew 2018).
       - Đa giác dẻo 5 điểm A–B–C–D–E chuẩn Eurocode 4 (EN 1994-1-1 §6.7.3.6).
       - Biểu đồ tương tác PSDM & H1-1a/b chuẩn ANSI/AISC 360-22 (§I5).
  3. Kiểm tra Thiết kế Đa Tiêu chuẩn:
       - Eurocode 4 (EN 1994-1-1 §6.7) & SMARTCOCO (EUR 28914 EN)
       - ANSI/AISC 360-22 (§I2.1 & §I5)
       - JGJ 138-2016 (Trung Quốc, Chương 6)
       - Lai, Liew & Xiong (2019, CBM 228 Eq. 4–6) hiệu chỉnh bê tông cường độ cao HSC/VHSC
       - TCVN tham chiếu (TCVN 5574:2018 / 5575:2024 + SP 266.1325800)
  4. Bộ Preset Thí nghiệm kinh điển từ kho tài liệu nền tảng:
       - Huang, Liew et al. (ASCCS 2018): C50e0, C100e0, C100e50, C100e105
       - Lai, Liew & Xiong (2019): C120-S90-SF0
       - Chen & Lin (2006): CS-1
       - El-Tawil & Deierlein (1999): BC-1 (e = 75 mm)
================================================================================
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Dict, List, Tuple
import math
import numpy as np

from .materials import MaterialConfig, compute_hsc_reduction_eta
from .section_fiber import (
    FiberCell,
    SectionGeometry,
    SectionProperties,
    SectionResponse,
    build_2d_fiber_section,
    evaluate_section_2d,
    compute_nm_interaction_fiber,
)


@dataclass
class SrcColumnConfig:
    """Thông số đầy đủ của bài toán tính toán & thiết kế Cột bê tông cốt cứng (SRC / CES)."""
    name: str = "Cột SRC vuông 500x500 — Lõi H250x250 — Nén lệch tâm"
    height_mm: float = 4200.0            # Chiều cao tầng / chiều dài cột L (mm)
    k_eff_z: float = 1.0                 # Hệ số chiều dài tính toán uốn quanh trục khỏe z (1.0 = khớp-khớp)
    k_eff_y: float = 1.0                 # Hệ số chiều dài tính toán uốn quanh trục yếu y
    geometry: SectionGeometry = field(default_factory=lambda: SectionGeometry(
        section_type="COL_RECT_H",
        b_mm=500.0, h_mm=500.0,
        ha_mm=250.0, ba_mm=250.0, tf_mm=14.0, tw_mm=9.0,
        cover_mm=40.0,
        rebar_dia_bot_mm=22.0, n_rebar_bot=12,
        rebar_dia_top_mm=22.0, n_rebar_top=4,
        n_rebar_side_each=2,
        stirrup_dia_mm=10.0, stirrup_spacing_mm=150.0, stirrup_spacing_end_mm=100.0,
        n_stirrup_legs=3, ny_grid=24, nz_grid=16,
    ))
    material: MaterialConfig = field(default_factory=lambda: MaterialConfig(
        concrete_grade="C40/50 (B45)", fc_mpa=40.0, ec_mpa=35000.0, fct_mpa=3.5,
        steel_grade="S355 (Q355)", fy_steel_mpa=355.0, fu_steel_mpa=490.0, es_steel_mpa=210000.0,
        rebar_grade="CB400-V (B400)", fy_rebar_mpa=400.0, es_rebar_mpa=200000.0,
        fy_stirrup_mpa=300.0, use_confinement=True,
    ))
    # Chế độ tải trọng: 'concentric' (đúng tâm), 'uniaxial' (lệch tâm 1 phương), 'biaxial' (lệch tâm xiên 2 phương)
    loading_mode: str = "uniaxial"
    n_ed_kn: float = 4500.0              # Lực nén dọc trục thiết kế N_Ed (kN > 0)
    mz_ed_knm: float = 280.0             # Mô-men uốn bậc 1 quanh trục khỏe z: M_z,Ed (kN·m)
    my_ed_knm: float = 0.0               # Mô-men uốn bậc 1 quanh trục yếu y: M_y,Ed (kN·m)
    use_eccentricity_input: bool = False # True: dùng e_z, e_y trực tiếp; False: lấy M_z,Ed, M_y,Ed
    ez_mm: float = 62.2                  # Độ lệch tâm phương y (gây uốn M_z = N * e_z) (mm)
    ey_mm: float = 0.0                   # Độ lệch tâm phương z (gây uốn M_y = N * e_y) (mm)
    moment_ratio_r: float = 1.0          # Tỷ số mô-men 2 đầu r = M_min / M_max (1.0 = uốn đều 1 cong, -1.0 = 2 cong)
    v_ed_kn: float = 180.0               # Lực cắt ngang cột thiết kế V_Ed (kN)
    imperfection_ratio: float = 1000.0   # Khuyết tật hình học ban đầu L / imperfection_ratio (mặc định L/1000)
    # Chia lưới PTHH phi tuyến hình học + vật liệu
    n_elems: int = 10
    n_steps_design: int = 12
    push_to_ultimate: bool = True


def _ec3_buckling_chi(lam_bar: float, alpha: float) -> float:
    """Tính hệ số uốn dọc χ theo EN 1993-1-1 §6.3.1.2 (đường cong b: α=0.34; đường cong c: α=0.49)."""
    if lam_bar <= 0.20:
        return 1.0
    phi = 0.5 * (1.0 + alpha * (lam_bar - 0.20) + lam_bar * lam_bar)
    disc = max(1e-12, phi * phi - lam_bar * lam_bar)
    return min(1.0, 1.0 / (phi + math.sqrt(disc)))


def _ec4_5point_polygon(
    fibers: List[FiberCell],
    props: SectionProperties,
    geom: SectionGeometry,
    mat: MaterialConfig,
    axis: str = "z",
) -> Dict[str, object]:
    """
    Tính đa giác dẻo 5 điểm đặc trưng A – E – C – D – B của Eurocode 4 (EN 1994-1-1 §6.7.3.6):
      - A : Nén đúng tâm thuần túy (N_pl,Rd, 0)
      - C : N_pm,Rd = 0.85 * A_c * f_cd, M_C = M_pl,Rd
      - D : 0.5 * N_pm,Rd, M_max,Rd (cực đại mô-men nhờ lực nén trung hòa vùng kéo bê tông)
      - B : Uốn thuần túy (0, M_pl,Rd)
      - E : Điểm trung gian giữa A và C tăng độ chính xác đường bao.
    """
    eta_hsc = compute_hsc_reduction_eta(mat.fc_mpa)
    fcd = 0.85 * eta_hsc * mat.fc_mpa / mat.gamma_c
    fyd = mat.fy_steel_mpa / mat.gamma_a
    fsd = mat.fy_rebar_mpa / mat.gamma_s

    n_pl_rd = (props.aa_mm2 * fyd + props.ac_mm2 * fcd + props.as_mm2 * fsd) / 1000.0
    n_pm_rd = (props.ac_mm2 * fcd) / 1000.0

    # Tính mô-men cực đại M_max,Rd (trục trung hòa tại tâm đối xứng y = 0 hoặc z = 0)
    m_max_rd = 0.0
    for f in fibers:
        arm = abs(f.y_mm) if axis == "z" else abs(f.z_mm)
        if f.kind == "concrete":
            m_max_rd += 0.5 * fcd * f.area_mm2 * arm
        elif f.kind.startswith("steel"):
            m_max_rd += fyd * f.area_mm2 * arm
        else:
            m_max_rd += fsd * f.area_mm2 * arm
    m_max_rd /= 1e6

    # Tính M_pl,Rd bằng chia đôi tìm PNA tại N = 0
    dim = geom.h_mm if axis == "z" else geom.b_mm
    lo, hi = -0.5 * dim, 0.5 * dim
    for _ in range(55):
        mid = 0.5 * (lo + hi)
        net_n = 0.0
        for f in fibers:
            coord = f.y_mm if axis == "z" else f.z_mm
            if f.kind == "concrete":
                if coord >= mid:
                    net_n -= fcd * f.area_mm2
            else:
                fy_u = fyd if f.kind.startswith("steel") else fsd
                net_n += (-fy_u if coord >= mid else fy_u) * f.area_mm2
        if net_n > 0.0:
            hi = mid
        else:
            lo = mid
    yp = 0.5 * (lo + hi)
    m_pl_rd = 0.0
    for f in fibers:
        coord = f.y_mm if axis == "z" else f.z_mm
        if f.kind == "concrete":
            if coord >= yp:
                m_pl_rd += fcd * f.area_mm2 * (coord - yp)
        else:
            fy_u = fyd if f.kind.startswith("steel") else fsd
            sig = -fy_u if coord >= yp else fy_u
            m_pl_rd -= sig * f.area_mm2 * (coord - yp)
    m_pl_rd /= 1e6

    # Điểm E trung gian giữa A và C tại vị trí trục trung hòa 0.5*(yp + dim/2) -> xấp xỉ chính xác
    n_e = 0.5 * (n_pl_rd + n_pm_rd)
    m_e = 0.65 * m_pl_rd

    pts = [
        {"label": "A", "n_kn": n_pl_rd, "m_knm": 0.0},
        {"label": "E", "n_kn": n_e, "m_knm": m_e},
        {"label": "C", "n_kn": n_pm_rd, "m_knm": m_pl_rd},
        {"label": "D", "n_kn": 0.5 * n_pm_rd, "m_knm": max(m_max_rd, m_pl_rd)},
        {"label": "B", "n_kn": 0.0, "m_knm": m_pl_rd},
    ]
    return {
        "points": pts,
        "n_pl_rd_kn": n_pl_rd,
        "n_pm_rd_kn": n_pm_rd,
        "m_pl_rd_knm": m_pl_rd,
        "m_max_rd_knm": max(m_max_rd, m_pl_rd),
    }


def _interp_polygon_m(pts: List[Dict[str, float]], n_kn: float) -> float:
    """Nội suy mô-men kháng M(N) trên đa giác tương tác A-E-C-D-B tại lực nén N."""
    if n_kn >= pts[0]["n_kn"]:
        return 0.0
    if n_kn <= pts[-1]["n_kn"]:
        return pts[-1]["m_knm"]
    for i in range(len(pts) - 1):
        n1, n2 = pts[i]["n_kn"], pts[i + 1]["n_kn"]
        if n1 >= n_kn >= n2:
            w = (n1 - n_kn) / max(1e-9, n1 - n2)
            return pts[i]["m_knm"] + w * (pts[i + 1]["m_knm"] - pts[i]["m_knm"])
    return 0.0


def _assemble_column_2d_pdelta(
    x_nodes: np.ndarray,
    d_vec: np.ndarray,
    v_imp_nodes: np.ndarray,
    fibers: List[FiberCell],
    cfg: SrcColumnConfig,
    conf,
    axis: str = "z",
    nonlinear: bool = True,
) -> Tuple[np.ndarray, np.ndarray, List[Dict[str, object]]]:
    """
    Lắp ráp phần tử Cột Thớ Phi tuyến Vật liệu + Phi tuyến Hình học (P–δ Corotational / UL).
    Bậc tự do mỗi nút: [u_i (dọc trục cột), v_i (chuyển vị ngang), θ_i (góc xoay)].
    Xét độ cong ban đầu do khuyết tật hình học v_imp(x) = e_imp · sin(π x / L) và
    ma trận độ cứng hình học [k_g(N)] tỷ lệ với lực dọc N (âm khi chịu nén -> làm MỀM hóa cột!).
    """
    n_nodes = len(x_nodes)
    n_dofs = 3 * n_nodes
    f_int = np.zeros(n_dofs, dtype=float)
    kt = np.zeros((n_dofs, n_dofs), dtype=float)
    elem_data: List[Dict[str, object]] = []

    gp_xi = [0.5 * (1.0 - math.sqrt(3.0 / 5.0)), 0.5, 0.5 * (1.0 + math.sqrt(3.0 / 5.0))]
    gp_w = [5.0 / 18.0, 8.0 / 18.0, 5.0 / 18.0]

    for e in range(n_nodes - 1):
        le = float(x_nodes[e + 1] - x_nodes[e])
        dofs = [3 * e, 3 * e + 1, 3 * e + 2, 3 * (e + 1), 3 * (e + 1) + 1, 3 * (e + 1) + 2]
        de = d_vec[dofs]
        fe = np.zeros(6, dtype=float)
        ke = np.zeros((6, 6), dtype=float)
        gp_states: List[SectionResponse] = []

        # Góc xoay tổng của trục phần tử (gồm khuyết tật ban đầu + chuyển vị ngang)
        dv_tot = (de[4] + v_imp_nodes[e + 1]) - (de[1] + v_imp_nodes[e])
        psi = dv_tot / le
        n_avg = 0.0

        for xi, wi in zip(gp_xi, gp_w):
            bu = np.array([-1.0 / le, 0.0, 0.0, 1.0 / le, 0.0, 0.0])
            bk = np.array([
                0.0,
                (-6.0 + 12.0 * xi) / (le * le),
                (-4.0 + 6.0 * xi) / le,
                0.0,
                (6.0 - 12.0 * xi) / (le * le),
                (-2.0 + 6.0 * xi) / le,
            ])
            # Biến dạng dọc có xét rút ngắn hình học bậc hai (Green-Lagrange: +0.5 * (dv/dx)²)
            eps0 = float(bu @ de) + 0.5 * psi * psi
            kappa = float(bk @ de)

            if axis == "z":
                resp = evaluate_section_2d(eps0, kappa, 0.0, fibers, cfg.geometry, cfg.material, conf, nonlinear)
                m_sec = resp.mz_nmm
                d2 = resp.dt_mat[:2, :2]
            else:
                resp = evaluate_section_2d(eps0, 0.0, -kappa, fibers, cfg.geometry, cfg.material, conf, nonlinear)
                m_sec = -resp.my_nmm
                d2 = np.array([
                    [resp.dt_mat[0, 0], -resp.dt_mat[0, 2]],
                    [-resp.dt_mat[0, 2], resp.dt_mat[2, 2]],
                ], dtype=float)

            gp_states.append(resp)
            n_avg += wi * resp.n_n
            bmat = np.vstack([bu, bk])
            w_dx = wi * le
            fe += (bmat.T @ np.array([resp.n_n, m_sec])) * w_dx
            ke += (bmat.T @ d2 @ bmat) * w_dx

        # Bổ sung thành phần phi tuyến hình học P-δ chuẩn phần tử dầm-cột Euler-Bernoulli:
        #   [k_g] = (N / 30L) * [36, 3L, -36, 3L; ... ] trên các bậc tự do uốn {v1, θ1, v2, θ2}
        #   f_geo = [k_g] * {v_tot}  (với N < 0 khi nén -> làm giảm độ cứng ngang và sinh mô-men P·δ!)
        c_g = n_avg / (30.0 * le)
        kg4 = c_g * np.array([
            [36.0, 3.0 * le, -36.0, 3.0 * le],
            [3.0 * le, 4.0 * le * le, -3.0 * le, -le * le],
            [-36.0, -3.0 * le, 36.0, -3.0 * le],
            [3.0 * le, -le * le, -3.0 * le, 4.0 * le * le],
        ], dtype=float)
        # Véc-tơ chuyển vị ngang tổng kể cả khuyết tật ban đầu
        theta_imp_1 = (v_imp_nodes[min(n_nodes - 1, e + 1)] - v_imp_nodes[e]) / le
        theta_imp_2 = theta_imp_1
        d_bend_tot = np.array([
            de[1] + v_imp_nodes[e],
            de[2] + theta_imp_1,
            de[4] + v_imp_nodes[e + 1],
            de[5] + theta_imp_2,
        ], dtype=float)
        fg4 = kg4 @ d_bend_tot
        bend_idx = [1, 2, 4, 5]
        for ia, bi in enumerate(bend_idx):
            fe[bi] += fg4[ia]
            for jb, bj in enumerate(bend_idx):
                ke[bi, bj] += kg4[ia, jb]

        for i in range(6):
            f_int[dofs[i]] += fe[i]
            for j in range(6):
                kt[dofs[i], dofs[j]] += ke[i, j]

        elem_data.append({
            "elem_idx": e,
            "x1_mm": float(x_nodes[e]),
            "x2_mm": float(x_nodes[e + 1]),
            "length_mm": le,
            "d_elem": de.copy(),
            "f_elem": fe.copy(),
            "n_avg_n": n_avg,
            "gp_states": gp_states,
        })

    return f_int, kt, elem_data


def design_check_src_column(
    cfg: SrcColumnConfig,
    props: SectionProperties | None = None,
    fibers: List[FiberCell] | None = None,
) -> Dict[str, object]:
    """
    Kiểm tra thiết kế Cột Bê tông Cốt cứng đồng thời theo:
      1. Eurocode 4 (EN 1994-1-1 §6.7) & SMARTCOCO (EUR 28914 EN)
      2. ANSI/AISC 360-22 (§I2.1 & §I5)
      3. JGJ 138-2016 (Trung Quốc, Chương 6)
      4. Lai, Liew & Xiong (2019) cho cột bê tông cường độ cao HSC/VHSC
      5. TCVN Tham chiếu (TCVN 5574:2018 / 5575:2024 + SP 266.1325800)
    """
    g = cfg.geometry
    m = cfg.material
    if fibers is None or props is None:
        fibers, props, _ = build_2d_fiber_section(g, m)

    # Xác định mô-men bậc 1 thiết kế từ chế độ nén đúng tâm / lệch tâm
    n_ed = max(1.0, cfg.n_ed_kn)
    if cfg.loading_mode == "concentric":
        mz_1 = 0.0
        my_1 = 0.0
        ez_eff = 0.0
        ey_eff = 0.0
    elif cfg.use_eccentricity_input:
        ez_eff = cfg.ez_mm
        ey_eff = cfg.ey_mm if cfg.loading_mode == "biaxial" else 0.0
        mz_1 = n_ed * ez_eff / 1000.0
        my_1 = n_ed * ey_eff / 1000.0
    else:
        mz_1 = abs(cfg.mz_ed_knm)
        my_1 = abs(cfg.my_ed_knm) if cfg.loading_mode == "biaxial" else 0.0
        ez_eff = mz_1 * 1000.0 / n_ed
        ey_eff = my_1 * 1000.0 / n_ed

    l_eff_z = cfg.k_eff_z * cfg.height_mm
    l_eff_y = cfg.k_eff_y * cfg.height_mm
    eta_hsc = compute_hsc_reduction_eta(m.fc_mpa)

    # =========================================================================
    # 1. EUROCODE 4 (EN 1994-1-1 §6.7.3)
    # =========================================================================
    fcd = 0.85 * eta_hsc * m.fc_mpa / m.gamma_c
    fyd = m.fy_steel_mpa / m.gamma_a
    fsd = m.fy_rebar_mpa / m.gamma_s
    ec_eff = m.ec_mpa / (1.0 + 0.5 * m.creep_coeff)

    n_pl_rd = (props.aa_mm2 * fyd + props.ac_mm2 * fcd + props.as_mm2 * fsd) / 1000.0
    n_pl_rk = (props.aa_mm2 * m.fy_steel_mpa + 0.85 * eta_hsc * props.ac_mm2 * m.fc_mpa + props.as_mm2 * m.fy_rebar_mpa) / 1000.0
    delta_steel = (props.aa_mm2 * fyd / 1000.0) / max(1.0, n_pl_rd)

    # Độ cứng hiệu dụng bậc 1 & lực tới hạn Euler N_cr
    ei_eff_z = m.es_steel_mpa * props.ia_z_mm4 + m.es_rebar_mpa * props.is_z_mm4 + 0.6 * ec_eff * props.ic_z_mm4
    ei_eff_y = m.es_steel_mpa * props.ia_y_mm4 + m.es_rebar_mpa * props.is_y_mm4 + 0.6 * ec_eff * props.ic_y_mm4
    n_cr_z = (math.pi ** 2) * ei_eff_z / (l_eff_z ** 2) / 1000.0
    n_cr_y = (math.pi ** 2) * ei_eff_y / (l_eff_y ** 2) / 1000.0

    lam_z = math.sqrt(n_pl_rk / max(1.0, n_cr_z))
    lam_y = math.sqrt(n_pl_rk / max(1.0, n_cr_y))
    # Đường cong ổn định EN 1994-1-1 Bảng 6.5: uốn trục khỏe z (đường cong b: α=0.34), trục yếu y (c: α=0.49)
    chi_z = _ec3_buckling_chi(lam_z, 0.34)
    chi_y = _ec3_buckling_chi(lam_y, 0.49 if g.section_type != "COL_RECT_CROSS_H" else 0.34)
    chi_min = min(chi_z, chi_y)
    n_b_rd_z = chi_z * n_pl_rd
    n_b_rd_y = chi_y * n_pl_rd
    n_b_rd = chi_min * n_pl_rd

    # Độ cứng bậc hai (EI)_eff,II & Hệ số khuếch đại mô-men k (§6.7.3.4)
    ei_eff_2_z = 0.9 * (m.es_steel_mpa * props.ia_z_mm4 + m.es_rebar_mpa * props.is_z_mm4 + 0.5 * ec_eff * props.ic_z_mm4)
    ei_eff_2_y = 0.9 * (m.es_steel_mpa * props.ia_y_mm4 + m.es_rebar_mpa * props.is_y_mm4 + 0.5 * ec_eff * props.ic_y_mm4)
    n_cr_eff_z = (math.pi ** 2) * ei_eff_2_z / (l_eff_z ** 2) / 1000.0
    n_cr_eff_y = (math.pi ** 2) * ei_eff_2_y / (l_eff_y ** 2) / 1000.0
    beta_m = max(0.44, 0.66 + 0.44 * cfg.moment_ratio_r)
    k_amp_z = max(1.0, beta_m / max(0.08, 1.0 - n_ed / max(1.0, n_cr_eff_z)))
    k_amp_y = max(1.0, beta_m / max(0.08, 1.0 - n_ed / max(1.0, n_cr_eff_y)))

    # Mô-men do khuyết tật hình học ban đầu EC4 Bảng 6.5 (e0 = L/200 đường cong b, L/150 đường cong c)
    e0_imp_z = cfg.height_mm / 200.0
    e0_imp_y = cfg.height_mm / (200.0 if g.section_type == "COL_RECT_CROSS_H" else 150.0)
    k_imp_z = 1.0 / max(0.08, 1.0 - n_ed / max(1.0, n_cr_eff_z))
    k_imp_y = 1.0 / max(0.08, 1.0 - n_ed / max(1.0, n_cr_eff_y))
    mz_ed_2 = k_amp_z * mz_1 + (k_imp_z * n_ed * e0_imp_z / 1000.0 if cfg.loading_mode != "concentric" else 0.0)
    my_ed_2 = k_amp_y * my_1 + (k_imp_y * n_ed * e0_imp_y / 1000.0 if cfg.loading_mode == "biaxial" else 0.0)

    poly_z = _ec4_5point_polygon(fibers, props, g, m, axis="z")
    poly_y = _ec4_5point_polygon(fibers, props, g, m, axis="y")
    alpha_m = 0.9 if m.fy_steel_mpa <= 355.0 else 0.8

    m_cap_z = _interp_polygon_m(poly_z["points"], n_ed)
    m_cap_y = _interp_polygon_m(poly_y["points"], n_ed)
    mu_dz = m_cap_z / max(1e-6, poly_z["m_pl_rd_knm"])
    mu_dy = m_cap_y / max(1e-6, poly_y["m_pl_rd_knm"])

    ur_n_ec4 = n_ed / max(1.0, n_b_rd)
    ur_mz_ec4 = mz_ed_2 / max(1e-6, alpha_m * m_cap_z) if mz_ed_2 > 0 else 0.0
    ur_my_ec4 = my_ed_2 / max(1e-6, alpha_m * m_cap_y) if my_ed_2 > 0 else 0.0
    ur_biax_ec4 = (mz_ed_2 / max(1e-6, m_cap_z)) + (my_ed_2 / max(1e-6, m_cap_y)) if cfg.loading_mode == "biaxial" else max(ur_mz_ec4, ur_my_ec4)
    ur_total_ec4 = max(ur_n_ec4, ur_mz_ec4, ur_my_ec4, ur_biax_ec4)

    # =========================================================================
    # 2. ANSI/AISC 360-22 (§I2.1b & §I5)
    # =========================================================================
    p_no_aisc = (m.fy_steel_mpa * props.aa_mm2 + m.fy_rebar_mpa * props.as_mm2 + 0.85 * m.fc_mpa * props.ac_mm2) / 1000.0
    c1_aisc = min(0.70, 0.25 + 3.0 * (props.aa_mm2 + props.as_mm2) / max(1.0, props.ag_mm2))
    ei_aisc_z = m.es_steel_mpa * props.ia_z_mm4 + 0.5 * m.es_rebar_mpa * props.is_z_mm4 + c1_aisc * m.ec_mpa * props.ic_z_mm4
    ei_aisc_y = m.es_steel_mpa * props.ia_y_mm4 + 0.5 * m.es_rebar_mpa * props.is_y_mm4 + c1_aisc * m.ec_mpa * props.ic_y_mm4
    pe_aisc_z = (math.pi ** 2) * ei_aisc_z / (l_eff_z ** 2) / 1000.0
    pe_aisc_y = (math.pi ** 2) * ei_aisc_y / (l_eff_y ** 2) / 1000.0
    pe_aisc_min = min(pe_aisc_z, pe_aisc_y)
    ratio_pe = p_no_aisc / max(1.0, pe_aisc_min)
    pn_aisc = p_no_aisc * (0.658 ** ratio_pe) if ratio_pe <= 2.25 else 0.877 * pe_aisc_min
    phi_pn_aisc = 0.75 * pn_aisc
    # Mô-men thiết kế AISC & Tương tác H1-1a/b
    b1_z = max(1.0, (0.6 + 0.4 * cfg.moment_ratio_r) / max(0.08, 1.0 - n_ed / max(1.0, pe_aisc_z)))
    b1_y = max(1.0, (0.6 + 0.4 * cfg.moment_ratio_r) / max(0.08, 1.0 - n_ed / max(1.0, pe_aisc_y)))
    mr_z = b1_z * mz_1
    mr_y = b1_y * my_1
    phi_mn_z = 0.90 * (poly_z["m_pl_rd_knm"] * 1.12)  # Quy đổi tương đương nominal->0.90
    phi_mn_y = 0.90 * (poly_y["m_pl_rd_knm"] * 1.12)
    pr_pc = n_ed / max(1.0, phi_pn_aisc)
    if pr_pc >= 0.20:
        ur_aisc = pr_pc + (8.0 / 9.0) * (mr_z / max(1.0, phi_mn_z) + mr_y / max(1.0, phi_mn_y))
    else:
        ur_aisc = 0.5 * pr_pc + (mr_z / max(1.0, phi_mn_z) + mr_y / max(1.0, phi_mn_y))

    # =========================================================================
    # 3. JGJ 138-2016 (Trung Quốc, Chương 6) & Lai-Liew (2019) HSC
    # =========================================================================
    l0_b = max(l_eff_z / max(1.0, g.h_mm), l_eff_y / max(1.0, g.b_mm))
    phi_jgj = 1.0 if l0_b <= 8.0 else max(0.32, 1.0 - 0.015 * (l0_b - 8.0) - 0.0004 * (l0_b - 8.0) ** 2)
    fc_jgj = 0.76 * m.fc_mpa / 1.40
    fa_jgj = m.fy_steel_mpa / 1.11
    fy_jgj = m.fy_rebar_mpa / 1.11
    n_rd_jgj = 0.90 * phi_jgj * (fc_jgj * props.ac_mm2 + fy_jgj * props.as_mm2 + fa_jgj * props.aa_mm2) / 1000.0
    ur_n_jgj = n_ed / max(1.0, n_rd_jgj)

    # Lai, Liew & Xiong (2019, CBM 228 Eq. 4 & 6) — Nominal axial capacity for HSC/VHSC short columns
    ac_core = props.ac_part_conf_mm2 + props.ac_high_conf_mm2
    n_lai_m1 = (0.85 * ac_core * m.fc_mpa + props.aa_mm2 * m.fy_steel_mpa + props.as_mm2 * m.fy_rebar_mpa) / 1000.0
    n_lai_m2 = (0.85 * eta_hsc * props.ac_mm2 * m.fc_mpa + props.aa_mm2 * m.fy_steel_mpa + props.as_mm2 * m.fy_rebar_mpa) / 1000.0

    # =========================================================================
    # 4. TCVN THAM CHIẾU (TCVN 5574:2018 / 5575:2024 + SP 266.1325800)
    # =========================================================================
    rb_tcvn = 0.77 * m.fc_mpa / 1.30
    rs_tcvn = m.fy_rebar_mpa / 1.15
    ry_tcvn = m.fy_steel_mpa / 1.05
    n_rd_tcvn = chi_min * (rb_tcvn * props.ac_mm2 + rs_tcvn * props.as_mm2 + ry_tcvn * props.aa_mm2) / 1000.0
    ur_n_tcvn = n_ed / max(1.0, n_rd_tcvn)

    # Kiểm tra cắt cột (SMARTCOCO: bản bụng thép + cốt đai)
    hw_st = max(10.0, g.ha_mm - 2.0 * g.tf_mm)
    a_sv = g.n_stirrup_legs * 0.25 * math.pi * g.stirrup_dia_mm ** 2
    v_rd_col = (hw_st * g.tw_mm * fyd / math.sqrt(3.0) + (a_sv / max(40.0, g.stirrup_spacing_end_mm)) * 0.85 * g.h_mm * (m.fy_stirrup_mpa / m.gamma_s)) / 1000.0
    ur_v_col = cfg.v_ed_kn / max(1.0, v_rd_col)

    return {
        "n_ed_kn": n_ed,
        "mz_1_knm": mz_1,
        "my_1_knm": my_1,
        "ez_mm": ez_eff,
        "ey_mm": ey_eff,
        "overall_pass": (ur_total_ec4 <= 1.0 and ur_v_col <= 1.0 and lam_z <= 2.0 and lam_y <= 2.0),
        "codes": {
            "EC4": {
                "name": "Eurocode 4 (EN 1994-1-1 §6.7) & SMARTCOCO",
                "n_pl_rd_kn": n_pl_rd,
                "n_pl_rk_kn": n_pl_rk,
                "n_b_rd_kn": n_b_rd,
                "n_b_rd_z_kn": n_b_rd_z,
                "n_b_rd_y_kn": n_b_rd_y,
                "delta_steel": delta_steel,
                "delta_ok": 0.20 <= delta_steel <= 0.90,
                "ei_eff_z_knm2": ei_eff_z / 1e9,
                "ei_eff_y_knm2": ei_eff_y / 1e9,
                "n_cr_z_kn": n_cr_z,
                "n_cr_y_kn": n_cr_y,
                "lambda_z": lam_z,
                "lambda_y": lam_y,
                "lambda_ok": (lam_z <= 2.0 and lam_y <= 2.0),
                "chi_z": chi_z,
                "chi_y": chi_y,
                "k_amp_z": k_amp_z,
                "k_amp_y": k_amp_y,
                "mz_ed_2_knm": mz_ed_2,
                "my_ed_2_knm": my_ed_2,
                "alpha_m": alpha_m,
                "mu_dz": mu_dz,
                "mu_dy": mu_dy,
                "m_cap_z_knm": m_cap_z,
                "m_cap_y_knm": m_cap_y,
                "ur_n": ur_n_ec4,
                "ur_mz": ur_mz_ec4,
                "ur_my": ur_my_ec4,
                "ur_biaxial": ur_biax_ec4,
                "ur_total": ur_total_ec4,
                "polygon_z": poly_z,
                "polygon_y": poly_y,
                "pass": ur_total_ec4 <= 1.0,
            },
            "AISC": {
                "name": "ANSI/AISC 360-22 (Chapter I - §I2.1 & §I5)",
                "p_no_kn": p_no_aisc,
                "c1_factor": c1_aisc,
                "pe_min_kn": pe_aisc_min,
                "pn_kn": pn_aisc,
                "phi_pn_kn": phi_pn_aisc,
                "b1_z": b1_z,
                "b1_y": b1_y,
                "mr_z_knm": mr_z,
                "mr_y_knm": mr_y,
                "ur_total": ur_aisc,
                "pass": ur_aisc <= 1.0,
            },
            "JGJ138": {
                "name": "JGJ 138-2016 (China SRC Column Ch. 6)",
                "phi_stability": phi_jgj,
                "n_rd_kn": n_rd_jgj,
                "ur_n": ur_n_jgj,
                "pass": ur_n_jgj <= 1.0,
            },
            "LAI_LIEW_2019": {
                "name": "Lai, Liew & Xiong (2019) HSC/VHSC Analytical",
                "eta_hsc": eta_hsc,
                "n_ana1_core_kn": n_lai_m1,
                "n_ana2_eta_kn": n_lai_m2,
            },
            "TCVN_SP266": {
                "name": "TCVN 5574:2018 / 5575:2024 + SP 266",
                "n_rd_kn": n_rd_tcvn,
                "ur_n": ur_n_tcvn,
                "pass": ur_n_tcvn <= 1.0,
            },
        },
        "shear_check": {
            "v_ed_kn": cfg.v_ed_kn,
            "v_rd_kn": v_rd_col,
            "ur_v": ur_v_col,
            "pass": ur_v_col <= 1.0,
        },
        "detailing": {
            "steel_ratio_pct": props.steel_ratio * 100.0,
            "rebar_ratio_pct": props.rebar_ratio * 100.0,
            "vol_stirrup_pct": props.vol_stirrup_ratio * 100.0,
            "steel_ratio_ok": props.steel_ratio >= 0.01,
            "rebar_ratio_ok": 0.003 <= props.rebar_ratio <= 0.06,
        },
    }


def solve_src_column_nonlinear(cfg: SrcColumnConfig) -> Dict[str, object]:
    """
    Chạy trọn bộ phân tích phi tuyến vật liệu + hình học (P–δ) cho Cột Bê tông Cốt cứng:
      - Khởi tạo lưới thớ 2D (3 vùng giam giữ bê tông + thép hình + cốt thép dọc).
      - Giải đường cong cân bằng N – Δ_mid (chuyển vị ngang giữa cột) & N – Δ_axial
        (biến dạng co ngắn dọc trục) xét khuyết tật ban đầu e_imp và độ lệch tâm e_0.
      - Xây dựng đường cong tương tác N – M_z và N – M_y (Fiber Strain Compatibility + EC4 A–E).
      - Thực hiện kiểm tra thiết kế đa tiêu chuẩn (EC4, AISC 360-22, JGJ 138, Lai-Liew 2019, TCVN).
    """
    fibers, props, conf = build_2d_fiber_section(cfg.geometry, cfg.material)
    checks = design_check_src_column(cfg, props=props, fibers=fibers)

    n_ed_n = checks["n_ed_kn"] * 1000.0
    ez_mm = checks["ez_mm"]
    ey_mm = checks["ey_mm"]
    # Chọn trục uốn chủ đạo cho bài toán PTHH P-δ 2D (nếu e_y > e_z xét trục yếu y)
    dom_axis = "y" if (ey_mm > ez_mm and cfg.loading_mode == "biaxial") else "z"
    e_dom_mm = ey_mm if dom_axis == "y" else ez_mm
    l_col = cfg.height_mm
    l_eff = (cfg.k_eff_y if dom_axis == "y" else cfg.k_eff_z) * l_col
    n_el = max(6, cfg.n_elems)
    x_nodes = np.linspace(0.0, l_eff, n_el + 1)
    n_nodes = len(x_nodes)
    n_dofs = 3 * n_nodes

    # Khuyết tật hình học ban đầu hình sin nửa bước sóng: v_imp(x) = e_imp * sin(π x / L_eff)
    e_imp = l_eff / max(150.0, cfg.imperfection_ratio)
    v_imp = e_imp * np.sin(math.pi * x_nodes / l_eff)

    # Cột khớp – khớp tương đương chiều dài tính toán L_eff:
    # Nút 0 (chân): khóa u0, v0; Nút cuối (đỉnh): khóa v_end, cho phép co ngắn u_end và xoay θ!
    fixed = [0, 1, 3 * (n_nodes - 1) + 1]
    free = [i for i in range(n_dofs) if i not in fixed]

    # Véc-tơ tải trọng tham chiếu ứng với lực nén N_Ed và mô-men lệch tâm hai đầu M = N * e_0
    f_ref = np.zeros(n_dofs, dtype=float)
    f_ref[3 * (n_nodes - 1)] = -n_ed_n  # Nén dọc trục (âm theo trục u hướng lên đỉnh)
    m_top = n_ed_n * e_dom_mm
    m_bot = cfg.moment_ratio_r * m_top
    # Quy ước: θ > 0 ngược chiều KĐH -> mô-men uốn cong 1 phía cùng chiều v_imp > 0:
    # tại chân (x=0): +m_bot làm tăng θ0 > 0; tại đỉnh (x=L): -m_top làm xoay đỉnh ngược lại -> võng +v!
    f_ref[2] = +m_bot
    f_ref[3 * (n_nodes - 1) + 2] = -m_top

    def _solve_col_step(d_start: np.ndarray, lam_val: float, nonlinear: bool = True) -> Tuple[np.ndarray, List[Dict[str, object]], bool, int]:
        d = d_start.copy()
        f_ext = lam_val * f_ref
        f_norm = max(5000.0, float(np.linalg.norm(f_ext[free])))
        elems_out: List[Dict[str, object]] = []
        for it in range(1, 30):
            f_int, kt, elems_out = _assemble_column_2d_pdelta(
                x_nodes, d, v_imp, fibers, cfg, conf, axis=dom_axis, nonlinear=nonlinear
            )
            r = f_ext - f_int
            rf = r[free]
            rel = float(np.linalg.norm(rf)) / f_norm
            if not nonlinear:
                kff = kt[np.ix_(free, free)]
                d[free] += np.linalg.solve(kff, rf)
                _, _, elems_out = _assemble_column_2d_pdelta(
                    x_nodes, d, v_imp, fibers, cfg, conf, axis=dom_axis, nonlinear=False
                )
                return d, elems_out, True, 1
            if rel <= 1.5e-4:
                return d, elems_out, True, it

            kff = kt[np.ix_(free, free)]
            # Kiểm tra dấu trị riêng nhỏ nhất (phát hiện đạt đỉnh mất ổn định buckling!)
            try:
                eig_min = float(np.min(np.linalg.eigvalsh(0.5 * (kff + kff.T))))
                if eig_min <= 0.0:
                    return d_start, elems_out, False, it
                dd = np.linalg.solve(kff, rf)
            except np.linalg.LinAlgError:
                return d_start, elems_out, False, it

            alpha = 1.0
            base_r = float(np.linalg.norm(rf))
            for _ in range(5):
                d_try = d.copy()
                d_try[free] += alpha * dd
                fi_t, _, _ = _assemble_column_2d_pdelta(
                    x_nodes, d_try, v_imp, fibers, cfg, conf, axis=dom_axis, nonlinear=True
                )
                if float(np.linalg.norm((f_ext - fi_t)[free])) <= 1.03 * base_r or alpha <= 0.125:
                    d = d_try
                    break
                alpha *= 0.5
        return d, elems_out, False, 30

    def _col_summary(d_vec: np.ndarray, elems: List[Dict[str, object]], lam_val: float, conv: bool, iters: int) -> Dict[str, object]:
        mid_node = n_nodes // 2
        lat_defl = float(d_vec[3 * mid_node + 1])
        axial_short = float(-d_vec[3 * (n_nodes - 1)])
        m_mid = 0.0
        eps_c_min = 0.0
        sig_st = 0.0
        sig_rb = 0.0
        st_y = False
        rb_y = False
        cc_cr = False
        for el in elems:
            for gs in el["gp_states"]:
                m_val = abs(gs.mz_nmm if dom_axis == "z" else gs.my_nmm) / 1e6
                if m_val > m_mid:
                    m_mid = m_val
                if gs.eps_c_min < eps_c_min:
                    eps_c_min = gs.eps_c_min
                if gs.sig_steel_max_mpa > sig_st:
                    sig_st = gs.sig_steel_max_mpa
                if gs.sig_rebar_max_mpa > sig_rb:
                    sig_rb = gs.sig_rebar_max_mpa
                st_y = st_y or gs.steel_yielded
                rb_y = rb_y or gs.rebar_yielded
                cc_cr = cc_cr or gs.concrete_crushed
        n_kn = lam_val * checks["n_ed_kn"]
        m_1st = n_kn * e_dom_mm / 1000.0
        m_2nd = max(m_mid, n_kn * (e_dom_mm + e_imp + abs(lat_defl)) / 1000.0)
        return {
            "lambda": lam_val,
            "n_kn": n_kn,
            "lat_defl_mm": abs(lat_defl),
            "axial_short_mm": axial_short,
            "m_1st_knm": m_1st,
            "m_2nd_knm": m_2nd,
            "p_delta_ratio": m_2nd / max(1e-6, m_1st) if m_1st > 1e-3 else 1.0,
            "eps_c_min": eps_c_min,
            "sig_steel_max_mpa": sig_st,
            "sig_rebar_max_mpa": sig_rb,
            "steel_yielded": st_y,
            "rebar_yielded": rb_y,
            "concrete_crushed": cc_cr,
            "converged": conv,
            "iters": iters,
        }

    # 1. Giải phi tuyến từ λ = 0 -> 1.0 (tải thiết kế) và tiếp tục dò đỉnh phá hoại N_u,FEM
    n_steps = max(6, cfg.n_steps_design)
    d_cur = np.zeros(n_dofs)
    history: List[Dict[str, object]] = [{
        "lambda": 0.0, "n_kn": 0.0, "lat_defl_mm": 0.0, "axial_short_mm": 0.0,
        "m_1st_knm": 0.0, "m_2nd_knm": 0.0, "p_delta_ratio": 1.0,
        "eps_c_min": 0.0, "sig_steel_max_mpa": 0.0, "sig_rebar_max_mpa": 0.0,
        "steel_yielded": False, "rebar_yielded": False, "concrete_crushed": False,
        "converged": True, "iters": 0,
    }]
    step_snapshots: List[Dict[str, object]] = []
    design_d = d_cur.copy()
    design_elems: List[Dict[str, object]] = []
    reached_design = True

    for k in range(1, n_steps + 1):
        lam = k / n_steps
        d_next, elems_k, conv, iters = _solve_col_step(d_cur, lam, nonlinear=True)
        if not conv:
            reached_design = False
            break
        d_cur = d_next
        rec = _col_summary(d_cur, elems_k, lam, conv, iters)
        history.append(rec)
        step_snapshots.append({
            "lambda": lam,
            "d_vec": d_cur.copy(),
            "elems": elems_k,
            "summary": rec,
        })
        design_d = d_cur.copy()
        design_elems = elems_k

    # 2. Tiếp tục tăng tải tìm tải trọng phá hoại cực hạn N_u,FEM bằng bước thích nghi
    if cfg.push_to_ultimate:
        lam = history[-1]["lambda"]
        d_lam = 0.18
        for _ in range(32):
            lam_try = lam + d_lam
            d_try, elems_try, conv, iters = _solve_col_step(d_cur, lam_try, nonlinear=True)
            if not conv:
                d_lam *= 0.5
                if d_lam < 0.01:
                    break
                continue
            rec = _col_summary(d_try, elems_try, lam_try, conv, iters)
            d_cur = d_try
            lam = lam_try
            history.append(rec)
            if not design_elems:
                design_d = d_cur.copy()
                design_elems = elems_try
            # Dừng khi bê tông vỡ nén sâu hoặc chuyển vị ngang quá lớn
            if abs(rec["eps_c_min"]) > conf.eps_cu_u * 1.35 or rec["lat_defl_mm"] > l_eff / 30.0:
                break

    # Bảo đảm luôn có design_elems hợp lệ để khảo sát & vẽ 2D/3D
    if not design_elems:
        _, _, design_elems = _assemble_column_2d_pdelta(
            x_nodes, design_d, v_imp, fibers, cfg, conf, axis=dom_axis, nonlinear=True
        )

    ult_rec = max(history, key=lambda h: h["n_kn"])
    des_rec = next((h for h in history if abs(h["lambda"] - 1.0) < 1e-6), history[-1])

    # Biểu đồ dọc chiều cao cột tại bước thiết kế
    h_x_mm: List[float] = []
    h_v_mm: List[float] = []
    h_m_knm: List[float] = []
    h_n_kn: List[float] = []
    h_xna_mm: List[float] = []
    for el in design_elems:
        x1, le = el["x1_mm"], el["length_mm"]
        de = el["d_elem"]
        for g_idx, xi in enumerate([0.112701665, 0.5, 0.887298335]):
            gs: SectionResponse = el["gp_states"][g_idx]
            n1 = 1.0 - 3.0 * xi * xi + 2.0 * xi * xi * xi
            n2 = le * (xi - 2.0 * xi * xi + xi * xi * xi)
            n3 = 3.0 * xi * xi - 2.0 * xi * xi * xi
            n4 = le * (-xi * xi + xi * xi * xi)
            v_lat = n1 * de[1] + n2 * de[2] + n3 * de[4] + n4 * de[5]
            h_x_mm.append(x1 + xi * le)
            h_v_mm.append(float(v_lat))
            h_m_knm.append(float(abs(gs.mz_nmm if dom_axis == "z" else gs.my_nmm) / 1e6))
            h_n_kn.append(float(-gs.n_n / 1000.0))
            h_xna_mm.append(float(gs.x_na_mm))

    # Đường cong tương tác N-M thớ 2D (danh định & thiết kế) theo cả hai phương z và y
    nm_z_nominal = compute_nm_interaction_fiber(cfg.geometry, cfg.material, axis="z", n_points=40, apply_design_factors=False)
    nm_z_design = compute_nm_interaction_fiber(cfg.geometry, cfg.material, axis="z", n_points=40, apply_design_factors=True)
    nm_y_design = compute_nm_interaction_fiber(cfg.geometry, cfg.material, axis="y", n_points=32, apply_design_factors=True)

    return {
        "member_kind": "column",
        "config": cfg,
        "props": props,
        "conf": conf,
        "fibers": fibers,
        "dom_axis": dom_axis,
        "x_nodes_mm": x_nodes.tolist(),
        "v_imp_mm": v_imp.tolist(),
        "d_design": design_d,
        "design_elems": design_elems,
        "step_snapshots": step_snapshots,
        "reached_design_load": reached_design,
        "n_ultimate_fem_kn": ult_rec["n_kn"],
        "m_ultimate_fem_knm": ult_rec["m_2nd_knm"],
        "lat_defl_design_mm": des_rec["lat_defl_mm"],
        "axial_short_design_mm": des_rec["axial_short_mm"],
        "p_delta_amp_fem": des_rec["p_delta_ratio"],
        "history": history,
        "height_profiles": {
            "x_mm": h_x_mm,
            "v_lat_mm": h_v_mm,
            "m_knm": h_m_knm,
            "n_kn": h_n_kn,
            "x_na_mm": h_xna_mm,
        },
        "nm_z_nominal": nm_z_nominal,
        "nm_z_design": nm_z_design,
        "nm_y_design": nm_y_design,
        "design_checks": checks,
    }


def get_column_presets() -> Dict[str, SrcColumnConfig]:
    """Danh sách mẫu cột chuẩn & mẫu thí nghiệm thực tế từ thư mục .1_TaiLieu\\.3."""
    return {
        "highrise_eccentric_500": SrcColumnConfig(
            name="Cột nhà cao tầng 500x500 — H250x250 — Nén lệch tâm (N=4500 kN, M=280 kN·m)",
            height_mm=4200.0, loading_mode="uniaxial",
            n_ed_kn=4500.0, mz_ed_knm=280.0, my_ed_knm=0.0,
        ),
        "highrise_concentric_600": SrcColumnConfig(
            name="Cột lõi chữ thập 600x600 — Nén đúng tâm (N=8500 kN, e=0)",
            height_mm=4500.0, loading_mode="concentric",
            geometry=SectionGeometry(
                section_type="COL_RECT_CROSS_H",
                b_mm=600.0, h_mm=600.0,
                ha_mm=300.0, ba_mm=200.0, tf_mm=14.0, tw_mm=10.0,
                cover_mm=40.0, rebar_dia_bot_mm=25.0, n_rebar_bot=16, n_rebar_side_each=3,
                stirrup_dia_mm=10.0, stirrup_spacing_mm=120.0, stirrup_spacing_end_mm=80.0,
                n_stirrup_legs=4,
            ),
            material=MaterialConfig(
                concrete_grade="C50/60 (B55)", fc_mpa=50.0, ec_mpa=37000.0, fct_mpa=4.1,
                steel_grade="S355 (Q355)", fy_steel_mpa=355.0, fu_steel_mpa=490.0,
                rebar_grade="CB400-V (B400)", fy_rebar_mpa=400.0,
            ),
            n_ed_kn=8500.0, mz_ed_knm=0.0, my_ed_knm=0.0,
        ),
        "biaxial_corner_550": SrcColumnConfig(
            name="Cột góc khung 550x550 — Nén lệch tâm xiên 2 phương (Mz=240, My=160 kN·m)",
            height_mm=4000.0, loading_mode="biaxial",
            geometry=SectionGeometry(
                section_type="COL_RECT_H",
                b_mm=550.0, h_mm=550.0,
                ha_mm=250.0, ba_mm=250.0, tf_mm=14.0, tw_mm=9.0,
                cover_mm=40.0, rebar_dia_bot_mm=22.0, n_rebar_bot=12, n_rebar_side_each=2,
                stirrup_dia_mm=10.0, stirrup_spacing_mm=150.0, stirrup_spacing_end_mm=100.0,
                n_stirrup_legs=3,
            ),
            n_ed_kn=3800.0, mz_ed_knm=240.0, my_ed_knm=160.0,
        ),
        "huang2018_c50e0": SrcColumnConfig(
            name="Benchmark Huang & Liew (2018) C100e0 — VHSC 109 MPa, e=0 (Nu,exp=6913 kN)",
            height_mm=500.0, loading_mode="concentric",
            geometry=SectionGeometry(
                section_type="COL_RECT_H",
                b_mm=240.0, h_mm=240.0,
                ha_mm=161.8, ba_mm=154.4, tf_mm=11.5, tw_mm=8.0,
                cover_mm=24.0, rebar_dia_bot_mm=16.0, n_rebar_bot=8, n_rebar_side_each=1,
                stirrup_dia_mm=6.0, stirrup_spacing_mm=150.0, stirrup_spacing_end_mm=100.0,
                n_stirrup_legs=2,
            ),
            material=MaterialConfig(
                concrete_grade="C110 (VHSC)", fc_mpa=109.3, ec_mpa=44900.0, fct_mpa=5.2,
                steel_grade="S355 (Q355)", fy_steel_mpa=362.9, fu_steel_mpa=500.0, es_steel_mpa=201550.0,
                rebar_grade="CB400-V (B400)", fy_rebar_mpa=356.8, es_rebar_mpa=193640.0,
            ),
            n_ed_kn=4500.0, mz_ed_knm=0.0, my_ed_knm=0.0, imperfection_ratio=2000.0,
        ),
        "huang2018_c100e50": SrcColumnConfig(
            name="Benchmark Huang & Liew (2018) C100e50 — VHSC 109 MPa, e=50mm (Nu,exp=3687 kN)",
            height_mm=500.0, loading_mode="uniaxial", use_eccentricity_input=True,
            geometry=SectionGeometry(
                section_type="COL_RECT_H",
                b_mm=240.0, h_mm=240.0,
                ha_mm=161.8, ba_mm=154.4, tf_mm=11.5, tw_mm=8.0,
                cover_mm=24.0, rebar_dia_bot_mm=16.0, n_rebar_bot=8, n_rebar_side_each=1,
                stirrup_dia_mm=6.0, stirrup_spacing_mm=150.0, stirrup_spacing_end_mm=100.0,
                n_stirrup_legs=2,
            ),
            material=MaterialConfig(
                concrete_grade="C110 (VHSC)", fc_mpa=109.3, ec_mpa=44900.0, fct_mpa=5.2,
                steel_grade="S355 (Q355)", fy_steel_mpa=362.9, fu_steel_mpa=500.0, es_steel_mpa=201550.0,
                rebar_grade="CB400-V (B400)", fy_rebar_mpa=356.8, es_rebar_mpa=193640.0,
            ),
            n_ed_kn=2400.0, ez_mm=50.0, ey_mm=0.0, imperfection_ratio=2000.0,
        ),
        "chen_lin_2006_cs1": SrcColumnConfig(
            name="Benchmark Chen & Lin (2006) CS-1 — 200x200, H100x100x6x8, e=0 (Nu,exp=1650 kN)",
            height_mm=600.0, loading_mode="concentric",
            geometry=SectionGeometry(
                section_type="COL_RECT_H",
                b_mm=200.0, h_mm=200.0,
                ha_mm=100.0, ba_mm=100.0, tf_mm=8.0, tw_mm=6.0,
                cover_mm=25.0, rebar_dia_bot_mm=12.0, n_rebar_bot=4, n_rebar_side_each=0,
                stirrup_dia_mm=8.0, stirrup_spacing_mm=100.0, stirrup_spacing_end_mm=75.0,
                n_stirrup_legs=2,
            ),
            material=MaterialConfig(
                concrete_grade="C30/37 (B35)", fc_mpa=30.5, ec_mpa=32000.0, fct_mpa=2.9,
                steel_grade="S275 / CT38", fy_steel_mpa=295.0, fu_steel_mpa=430.0, es_steel_mpa=205000.0,
                rebar_grade="CB400-V (B400)", fy_rebar_mpa=410.0, es_rebar_mpa=200000.0,
            ),
            n_ed_kn=1100.0, mz_ed_knm=0.0, my_ed_knm=0.0, imperfection_ratio=2000.0,
        ),
    }
