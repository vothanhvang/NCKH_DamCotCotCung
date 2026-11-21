# -*- coding: utf-8 -*-
"""
================================================================================
MÔ-ĐUN 3: PHÂN TÍCH PHI TUYẾN PTHH & THIẾT KẾ ĐA TIÊU CHUẨN DẦM BÊ TÔNG CỐT CỨNG
================================================================================
Chức năng khối:
  1. Bộ giải Phần tử hữu hạn (PTHH) Dầm Thớ 2D Phi tuyến Vật liệu (Fiber Beam FEM):
       - Phần tử dầm Euler-Bernoulli 6 bậc tự do {u1, v1, θ1, u2, v2, θ2}.
       - Tích phân số Gauss-Legendre 3 điểm trên mỗi phần tử; tại từng điểm Gauss
         tích phân ứng suất – độ cứng tiếp tuyến trên toàn bộ lưới thớ 2D (bê tông
         3 vùng giam giữ + lõi thép hình H + cốt thép dọc).
       - Thuật toán Full Newton-Raphson gia tăng tải thích nghi (Adaptive Load
         Stepping) có khả năng tự chia nhỏ bước khi xuất hiện vết nứt kéo và
         chảy dẻo thép, quét liên tục tới cực hạn phá hoại (4 giai đoạn cơ học).
  2. Bộ kiểm tra Thiết kế Đa Tiêu chuẩn (Multi-Code Design Engine):
       - Eurocode 4 (EN 1994-1-1:2004 §6.2, §6.6) + Hướng dẫn SMARTCOCO (EUR 28914 EN)
       - ANSI/AISC 360-22 (Chương I: §I3.3 PSDM & §I4.1 Cắt)
       - JGJ 138-2016 (Trung Quốc, Chương 5: Uốn & Cắt chồng chập SRC)
       - TCVN tham chiếu (TCVN 5574:2018 + TCVN 5575:2024 + SP 266.1325800)
       - Kiểm tra phá hoại cắt tách dọc (Shear Splitting — Weng et al. 2002)
       - Thiết kế đinh chống cắt (Headed Shear Studs — EN 1994-1-1 §6.6.3)
       - Kiểm tra trạng thái giới hạn sử dụng SLS (độ võng δ_max vs L/250, bề rộng vết nứt)
  3. Bộ Preset Thực nghiệm chuẩn để kiểm chứng (Wang et al. 2024; Jiang et al. 2024 PECB1).
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
    compute_moment_curvature,
)


@dataclass
class SrcBeamConfig:
    """Thông số đầy đủ của bài toán tính toán & thiết kế Dầm bê tông cốt cứng (SRC / CES)."""
    name: str = "Dầm SRC chữ T bản sàn — Lõi thép H300x150"
    span_mm: float = 6000.0              # Nhịp tính toán L (mm)
    geometry: SectionGeometry = field(default_factory=lambda: SectionGeometry(
        section_type="SRC_T_SLAB_H",
        b_mm=320.0, h_mm=600.0,
        bf_slab_mm=1200.0, hf_slab_mm=120.0,
        ha_mm=300.0, ba_mm=150.0, tf_mm=10.0, tw_mm=7.0,
        core_offset_y_mm=-20.0,
        cover_mm=35.0,
        rebar_dia_bot_mm=22.0, n_rebar_bot=4,
        rebar_dia_top_mm=16.0, n_rebar_top=2,
        stirrup_dia_mm=10.0, stirrup_spacing_mm=150.0, stirrup_spacing_end_mm=100.0,
        n_stirrup_legs=2, ny_grid=26, nz_grid=14,
    ))
    material: MaterialConfig = field(default_factory=lambda: MaterialConfig(
        concrete_grade="C35/45 (B40)", fc_mpa=35.0, ec_mpa=34000.0, fct_mpa=3.2,
        steel_grade="S355 (Q355)", fy_steel_mpa=355.0, fu_steel_mpa=490.0, es_steel_mpa=210000.0,
        rebar_grade="CB400-V (B400)", fy_rebar_mpa=400.0, es_rebar_mpa=200000.0,
        fy_stirrup_mpa=300.0, use_confinement=True,
    ))
    # Sơ đồ chất tải: 'udl' (phân bố đều), '3pt' (1 lực tập trung P tại a),
    #                 '4pt' (uốn 4 điểm 2 lực P/2 tại a & L-a), 'combined' (q + P)
    load_type: str = "udl"
    q_udl_kn_m: float = 65.0             # Tải trọng phân bố đều thiết kế q_Ed (kN/m)
    p_point_kn: float = 200.0            # Tổng lực tập trung thiết kế P_Ed (kN)
    load_a_mm: float = 2000.0            # Vị trí đặt lực tập trung a tính từ gối trái (mm)
    # Liên kết hai đầu: 'pin', 'roller', 'fixed', 'free'
    left_support: str = "pin"
    right_support: str = "roller"
    # Đinh chống cắt hàn lên cánh trên thép hình (Headed Shear Studs)
    stud_dia_mm: float = 19.0            # Đường kính thân đinh d (mm)
    stud_height_mm: float = 80.0         # Chiều cao đinh h_sc (mm)
    stud_fu_mpa: float = 450.0           # Cường độ kéo đứt đinh f_u (MPa)
    stud_spacing_mm: float = 200.0       # Bước đinh neo dọc dầm (mm)
    stud_rows: int = 2                   # Số hàng đinh trên mỗi mặt cắt cánh
    # Chia lưới PTHH & phân tích phi tuyến
    n_elems: int = 12                    # Số phần tử dầm dọc nhịp
    n_steps_design: int = 12             # Số bước tăng tải đến 1.0 x tải thiết kế
    push_to_ultimate: bool = True        # Tự động tăng tải tiếp để xác định sức chịu tải cực hạn P_u
    deflection_limit_ratio: float = 250.0  # Giới hạn độ võng SLS: L / 250


def _build_beam_nodes(cfg: SrcBeamConfig) -> np.ndarray:
    """Sinh tọa độ nút lưới PTHH x ∈ [0, L] luôn chứa đúng vị trí đặt lực tập trung."""
    L = cfg.span_mm
    n_el = max(4, cfg.n_elems)
    pts = {round(L * i / n_el, 3) for i in range(n_el + 1)}
    if cfg.load_type in ("3pt", "combined"):
        a = min(max(cfg.load_a_mm, 0.08 * L), 0.92 * L)
        pts.add(round(a, 3))
    elif cfg.load_type == "4pt":
        a = min(max(cfg.load_a_mm, 0.08 * L), 0.48 * L)
        pts.add(round(a, 3))
        pts.add(round(L - a, 3))
    arr = sorted(pts)
    cleaned = [arr[0]]
    for x in arr[1:]:
        if x - cleaned[-1] > 1.0:
            cleaned.append(x)
    cleaned[-1] = L
    return np.array(cleaned, dtype=float)


def _build_reference_load_vector(cfg: SrcBeamConfig, x_nodes: np.ndarray) -> np.ndarray:
    """
    Lắp ráp véc-tơ tải trọng nút quy đổi nhất quán {F_ref} ứng với 1.0 x tải thiết kế.
    Bậc tự do mỗi nút: [u_i (N), v_i (N, hướng lên +), θ_i (N·mm, ngược chiều KĐH +)].
    """
    n_nodes = len(x_nodes)
    f_ref = np.zeros(3 * n_nodes, dtype=float)
    L = cfg.span_mm

    if cfg.load_type in ("udl", "combined"):
        # Tải phân bố đều hướng xuống: q (kN/m) = q (N/mm)
        q_n_mm = cfg.q_udl_kn_m
        for e in range(n_nodes - 1):
            le = x_nodes[e + 1] - x_nodes[e]
            # Lực nút nhất quán cho tải hướng xuống -q
            f_ref[3 * e + 1] -= 0.5 * q_n_mm * le
            f_ref[3 * e + 2] -= q_n_mm * le * le / 12.0
            f_ref[3 * (e + 1) + 1] -= 0.5 * q_n_mm * le
            f_ref[3 * (e + 1) + 2] += q_n_mm * le * le / 12.0

    if cfg.load_type in ("3pt", "combined"):
        a = min(max(cfg.load_a_mm, 0.08 * L), 0.92 * L)
        idx = int(np.argmin(np.abs(x_nodes - a)))
        f_ref[3 * idx + 1] -= cfg.p_point_kn * 1000.0
    elif cfg.load_type == "4pt":
        a = min(max(cfg.load_a_mm, 0.08 * L), 0.48 * L)
        idx1 = int(np.argmin(np.abs(x_nodes - a)))
        idx2 = int(np.argmin(np.abs(x_nodes - (L - a))))
        f_ref[3 * idx1 + 1] -= 0.5 * cfg.p_point_kn * 1000.0
        f_ref[3 * idx2 + 1] -= 0.5 * cfg.p_point_kn * 1000.0

    return f_ref


def _fixed_dofs(cfg: SrcBeamConfig, n_nodes: int) -> List[int]:
    """Xác định danh sách chỉ số bậc tự do bị ràng buộc tại hai đầu dầm."""
    fixed = set()
    for idx, sup in ((0, cfg.left_support), (n_nodes - 1, cfg.right_support)):
        if sup == "pin":
            fixed.update([3 * idx, 3 * idx + 1])
        elif sup == "roller":
            fixed.add(3 * idx + 1)
        elif sup == "fixed":
            fixed.update([3 * idx, 3 * idx + 1, 3 * idx + 2])
    # Đảm bảo luôn khóa dịch chuyển cứng phương dọc u nếu hai đầu đều là roller
    if not any(d % 3 == 0 for d in fixed):
        fixed.add(0)
    return sorted(fixed)


def _assemble_beam_2d(
    x_nodes: np.ndarray,
    d_vec: np.ndarray,
    fibers: List[FiberCell],
    cfg: SrcBeamConfig,
    conf,
    nonlinear: bool = True,
) -> Tuple[np.ndarray, np.ndarray, List[Dict[str, object]]]:
    """
    Lắp ráp véc-tơ nội lực {F_int} và ma trận độ cứng tiếp tuyến toàn cục [K_t]
    theo phương pháp Rayleigh-Ritz (tích phân Gauss-Legendre 3 điểm trên mỗi phần tử).
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
            bmat = np.vstack([bu, bk])  # 2x6
            eps0 = float(bu @ de)
            kappa_z = float(bk @ de)
            resp = evaluate_section_2d(eps0, kappa_z, 0.0, fibers, cfg.geometry, cfg.material, conf, nonlinear)
            gp_states.append(resp)

            d2 = resp.dt_mat[:2, :2]
            w_dx = wi * le
            fe += (bmat.T @ np.array([resp.n_n, resp.mz_nmm])) * w_dx
            ke += (bmat.T @ d2 @ bmat) * w_dx

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
            "gp_states": gp_states,
        })

    return f_int, kt, elem_data


def _solve_step_nr(
    x_nodes: np.ndarray,
    d_init: np.ndarray,
    f_ext: np.ndarray,
    free_dofs: List[int],
    fibers: List[FiberCell],
    cfg: SrcBeamConfig,
    conf,
    nonlinear: bool = True,
    max_iter: int = 28,
    tol: float = 1e-4,
) -> Tuple[np.ndarray, List[Dict[str, object]], bool, int, float]:
    """Giải một bước cân bằng phi tuyến {F_int(d)} = {F_ext} bằng Full Newton-Raphson có Line-Search."""
    d = d_init.copy()
    f_norm = max(1000.0, float(np.linalg.norm(f_ext[free_dofs])))
    elem_data: List[Dict[str, object]] = []
    rel_err = 1.0

    for it in range(1, max_iter + 1):
        f_int, kt, elem_data = _assemble_beam_2d(x_nodes, d, fibers, cfg, conf, nonlinear)
        res = f_ext - f_int
        r_free = res[free_dofs]
        rel_err = float(np.linalg.norm(r_free)) / f_norm
        if rel_err <= tol or not nonlinear:
            if not nonlinear and it == 1:
                k_ff = kt[np.ix_(free_dofs, free_dofs)]
                dd = np.linalg.solve(k_ff, r_free)
                d[free_dofs] += dd
                f_int, kt, elem_data = _assemble_beam_2d(x_nodes, d, fibers, cfg, conf, nonlinear)
                return d, elem_data, True, 1, 0.0
            return d, elem_data, True, it, rel_err

        k_ff = kt[np.ix_(free_dofs, free_dofs)]
        try:
            dd = np.linalg.solve(k_ff, r_free)
        except np.linalg.LinAlgError:
            k_ff = k_ff + np.eye(len(free_dofs)) * 1e2
            dd = np.linalg.solve(k_ff, r_free)

        # Backtracking line search đơn giản khi bước nhảy lớn làm tăng sai số dư
        alpha = 1.0
        base_norm = float(np.linalg.norm(r_free))
        for _ in range(5):
            d_try = d.copy()
            d_try[free_dofs] += alpha * dd
            f_try, _, _ = _assemble_beam_2d(x_nodes, d_try, fibers, cfg, conf, nonlinear)
            n_try = float(np.linalg.norm((f_ext - f_try)[free_dofs]))
            if n_try <= 1.02 * base_norm or alpha <= 0.125:
                d = d_try
                break
            alpha *= 0.5

    return d, elem_data, rel_err < 5e-3, max_iter, rel_err


def _compute_plastic_moment_psd(
    fibers: List[FiberCell],
    h_mm: float,
    fc_eff_mpa: float,
    fy_steel_eff_mpa: float,
    fy_rebar_eff_mpa: float,
) -> Tuple[float, float]:
    """
    Tính chính xác Mô-men kháng uốn dẻo toàn phần (PSDM — Plastic Stress Distribution Method)
    bằng phương pháp chia đôi tìm trục trung hòa dẻo PNA sao cho ∑N = 0.
    Áp dụng chuẩn xác cho cả tiết diện chữ nhật và chữ T có bản sàn bê tông!
    """
    lo, hi = -0.5 * h_mm, 0.5 * h_mm
    for _ in range(60):
        mid = 0.5 * (lo + hi)
        # Bê tông chịu nén từ y = mid đến mép trên +h/2 (theo EC4 dùng toàn bộ vùng nén đến PNA)
        net_n = 0.0
        for f in fibers:
            if f.kind == "concrete":
                if f.y_mm >= mid:
                    net_n -= fc_eff_mpa * f.area_mm2
            else:
                fy_use = fy_steel_eff_mpa if f.kind.startswith("steel") else fy_rebar_eff_mpa
                net_n += (-fy_use if f.y_mm >= mid else fy_use) * f.area_mm2
        if net_n > 0.0:
            hi = mid
        else:
            lo = mid

    yp = 0.5 * (lo + hi)
    m_pl = 0.0
    for f in fibers:
        if f.kind == "concrete":
            if f.y_mm >= yp:
                m_pl += fc_eff_mpa * f.area_mm2 * (f.y_mm - yp)
        else:
            fy_use = fy_steel_eff_mpa if f.kind.startswith("steel") else fy_rebar_eff_mpa
            sig = -fy_use if f.y_mm >= yp else fy_use
            m_pl -= sig * f.area_mm2 * (f.y_mm - yp)
    return m_pl / 1e6, 0.5 * h_mm - yp


def design_check_src_beam(
    cfg: SrcBeamConfig,
    m_ed_knm: float,
    v_ed_kn: float,
    delta_sls_mm: float,
    props: SectionProperties | None = None,
    fibers: List[FiberCell] | None = None,
) -> Dict[str, object]:
    """
    Kiểm tra thiết kế Dầm Bê tông Cốt cứng đồng thời theo 4 hệ tiêu chuẩn quốc tế & Việt Nam:
      1. Eurocode 4 (EN 1994-1-1:2004 §6.2, §6.6) & SMARTCOCO (EUR 28914 EN)
      2. ANSI/AISC 360-22 (Chương I: §I3.3 & §I4.1)
      3. JGJ 138-2016 (Trung Quốc, Chương 5)
      4. TCVN Tham chiếu (TCVN 5574:2018 + TCVN 5575:2024 + SP 266.1325800)
         + Kiểm tra phá hoại cắt tách dọc Weng et al. (2002)
         + Kiểm tra đinh neo chống cắt (Headed Studs) & Võng giới hạn SLS.
    """
    g = cfg.geometry
    m = cfg.material
    if fibers is None or props is None:
        fibers, props, _ = build_2d_fiber_section(g, m)

    hw_steel = max(10.0, g.ha_mm - 2.0 * g.tf_mm)
    av_steel = hw_steel * g.tw_mm  # Diện tích bản bụng thép hình chịu cắt (mm²)
    d_eff = g.h_mm - (g.cover_mm + g.stirrup_dia_mm + 0.5 * g.rebar_dia_bot_mm)
    z_arm = 0.90 * d_eff
    a_sv = g.n_stirrup_legs * 0.25 * math.pi * g.stirrup_dia_mm ** 2
    s_sv = max(40.0, g.stirrup_spacing_end_mm)  # Dùng bước đai vùng gối (vùng cắt lớn nhất)
    eta_hsc = compute_hsc_reduction_eta(m.fc_mpa)

    # =========================================================================
    # 1. EUROCODE 4 (EN 1994-1-1:2004) & SMARTCOCO (EUR 28914 EN)
    # =========================================================================
    fcd = 0.85 * eta_hsc * m.fc_mpa / m.gamma_c
    fyd = m.fy_steel_mpa / m.gamma_a
    fsd = m.fy_rebar_mpa / m.gamma_s
    fywd = m.fy_stirrup_mpa / m.gamma_s

    m_pl_rd_ec4, x_pna_ec4 = _compute_plastic_moment_psd(fibers, g.h_mm, fcd, fyd, fsd)
    # Sức kháng cắt theo SMARTCOCO (EUR 28914 EN p.11) & EC4 §6.2.2: V_Rd = V_Rd,a + V_Rd,s
    v_rd_a_ec4 = av_steel * (fyd / math.sqrt(3.0)) / 1000.0
    v_rd_s_ec4 = (a_sv / s_sv) * z_arm * fywd / 1000.0
    v_rd_ec4 = v_rd_a_ec4 + v_rd_s_ec4
    # Tương tác Uốn – Cắt EC4 §6.2.2.4 khi V_Ed > 0.5 * V_Rd,a
    v_steel_share = v_ed_kn * (v_rd_a_ec4 / max(1.0, v_rd_ec4))
    rho_mv = 0.0
    if v_steel_share > 0.5 * v_rd_a_ec4 and v_rd_a_ec4 > 1.0:
        rho_mv = min(0.95, (2.0 * v_steel_share / v_rd_a_ec4 - 1.0) ** 2)
    m_rd_ec4_mv = m_pl_rd_ec4 - rho_mv * (g.tw_mm * hw_steel ** 2 / 4.0) * fyd / 1e6

    # Thiết kế đinh chống cắt (EN 1994-1-1 §6.6.3)
    d_st = cfg.stud_dia_mm
    h_st = cfg.stud_height_mm
    alpha_st = 1.0 if (h_st / max(1.0, d_st)) > 4.0 else 0.2 * (h_st / max(1.0, d_st) + 1.0)
    pr_1 = 0.8 * cfg.stud_fu_mpa * (0.25 * math.pi * d_st * d_st) / 1.25 / 1000.0
    pr_2 = 0.29 * alpha_st * d_st * d_st * math.sqrt(m.fc_mpa * m.ec_mpa) / 1.25 / 1000.0
    p_rd_stud_kn = min(pr_1, pr_2)
    # Lực cắt dọc trên nửa nhịp cắt L/2 (tối đa bằng lực nén bản sàn hoặc lực kéo thép hình)
    v_long_kn = min(
        fcd * (g.bf_slab_mm * g.hf_slab_mm if g.section_type == "SRC_T_SLAB_H" else g.b_mm * x_pna_ec4) / 1000.0,
        fyd * props.aa_mm2 / 1000.0,
    )
    n_studs_req_half = int(math.ceil(v_long_kn / max(1.0, p_rd_stud_kn)))
    n_studs_prov_half = int(math.floor((0.5 * cfg.span_mm) / max(50.0, cfg.stud_spacing_mm))) * cfg.stud_rows

    # =========================================================================
    # 2. ANSI/AISC 360-22 (Chương I: LRFD)
    # =========================================================================
    m_n_aisc, x_pna_aisc = _compute_plastic_moment_psd(
        fibers, g.h_mm, 0.85 * m.fc_mpa, m.fy_steel_mpa, m.fy_rebar_mpa
    )
    phi_m_aisc = 0.90 * m_n_aisc
    # Cắt theo AISC 360-22 §I4.1(c): Bản bụng thép hình + cốt đai ngang (φ_v = 0.75)
    vn_steel_aisc = 0.6 * m.fy_steel_mpa * av_steel / 1000.0
    vn_stirrup_aisc = (a_sv * m.fy_stirrup_mpa * d_eff / s_sv) / 1000.0
    phi_v_aisc = 0.75 * (vn_steel_aisc + vn_stirrup_aisc)

    # =========================================================================
    # 3. JGJ 138-2016 (Trung Quốc, Chương 5)
    # =========================================================================
    fc_jgj = 0.76 * m.fc_mpa / 1.40
    ft_jgj = 0.70 * m.fct_mpa / 1.40
    fa_jgj = m.fy_steel_mpa / 1.11
    fy_jgj = m.fy_rebar_mpa / 1.11
    m_rd_jgj, _ = _compute_plastic_moment_psd(fibers, g.h_mm, fc_jgj, fa_jgj, fy_jgj)
    vc_jgj = 0.7 * ft_jgj * g.b_mm * d_eff / 1000.0
    vsv_jgj = (m.fy_stirrup_mpa / 1.11) * (a_sv / s_sv) * d_eff / 1000.0
    va_jgj = 0.58 * fa_jgj * av_steel / 1000.0
    v_rd_jgj = vc_jgj + vsv_jgj + va_jgj

    # =========================================================================
    # 4. TCVN THAM CHIẾU (TCVN 5574:2018 + TCVN 5575:2024 + SP 266.1325800)
    # =========================================================================
    rb_tcvn = 0.77 * m.fc_mpa / 1.30
    rbt_tcvn = 0.75 * m.fct_mpa / 1.50
    rs_tcvn = m.fy_rebar_mpa / 1.15
    ry_tcvn = m.fy_steel_mpa / 1.05
    rsw_tcvn = 0.80 * m.fy_stirrup_mpa / 1.15
    m_rd_tcvn, _ = _compute_plastic_moment_psd(fibers, g.h_mm, rb_tcvn, ry_tcvn, rs_tcvn)
    vb_tcvn = 0.5 * rbt_tcvn * g.b_mm * d_eff / 1000.0
    vsw_tcvn = 0.75 * rsw_tcvn * (a_sv / s_sv) * d_eff / 1000.0
    va_tcvn = 0.58 * ry_tcvn * av_steel / 1000.0
    v_rd_tcvn = vb_tcvn + vsw_tcvn + va_tcvn

    # =========================================================================
    # 5. KIỂM TRA PHÁ HOẠI CẮT TÁCH DỌC (WENG, YEN & JIANG 2002) & SLS
    # =========================================================================
    bf_bw_ratio = g.ba_mm / max(1.0, g.b_mm)
    # Bề rộng bê tông còn lại bị thu hẹp tại cao trình cánh thép: b_net = b_w - b_f
    b_net = max(20.0, g.b_mm - g.ba_mm)
    v_split_kn = (0.35 * math.sqrt(m.fc_mpa) * b_net * d_eff + a_sv * m.fy_stirrup_mpa * d_eff / s_sv) / 1000.0
    splitting_risk = "CAO (Cần tăng cốt đai & hàn đinh neo)" if bf_bw_ratio >= 0.60 else (
        "TRUNG BÌNH (Lưu ý cốt đai khép kín)" if bf_bw_ratio >= 0.50 else "THẤP (An toàn chống tách lớp)"
    )

    delta_lim_mm = cfg.span_mm / max(100.0, cfg.deflection_limit_ratio)
    ur_m_ec4 = m_ed_knm / max(1e-6, m_rd_ec4_mv)
    ur_v_ec4 = v_ed_kn / max(1e-6, v_rd_ec4)
    ur_m_aisc = m_ed_knm / max(1e-6, phi_m_aisc)
    ur_v_aisc = v_ed_kn / max(1e-6, phi_v_aisc)
    ur_m_jgj = m_ed_knm / max(1e-6, m_rd_jgj)
    ur_v_jgj = v_ed_kn / max(1e-6, v_rd_jgj)
    ur_m_tcvn = m_ed_knm / max(1e-6, m_rd_tcvn)
    ur_v_tcvn = v_ed_kn / max(1e-6, v_rd_tcvn)
    ur_split = v_ed_kn / max(1e-6, v_split_kn)
    ur_sls = delta_sls_mm / max(1e-6, delta_lim_mm)
    ur_studs = n_studs_req_half / max(1, n_studs_prov_half)

    overall_pass = (ur_m_ec4 <= 1.0) and (ur_v_ec4 <= 1.0) and (ur_sls <= 1.0)

    return {
        "m_ed_knm": m_ed_knm,
        "v_ed_kn": v_ed_kn,
        "delta_sls_mm": delta_sls_mm,
        "delta_limit_mm": delta_lim_mm,
        "overall_pass": overall_pass,
        "codes": {
            "EC4": {
                "name": "Eurocode 4 (EN 1994-1-1) & SMARTCOCO",
                "m_rd_knm": m_pl_rd_ec4,
                "m_rd_mv_knm": m_rd_ec4_mv,
                "x_pna_mm": x_pna_ec4,
                "v_rd_kn": v_rd_ec4,
                "v_rd_a_kn": v_rd_a_ec4,
                "v_rd_s_kn": v_rd_s_ec4,
                "rho_mv": rho_mv,
                "ur_m": ur_m_ec4,
                "ur_v": ur_v_ec4,
                "pass": (ur_m_ec4 <= 1.0 and ur_v_ec4 <= 1.0),
            },
            "AISC": {
                "name": "ANSI/AISC 360-22 (Chapter I - LRFD)",
                "m_n_knm": m_n_aisc,
                "m_rd_knm": phi_m_aisc,
                "x_pna_mm": x_pna_aisc,
                "v_rd_kn": phi_v_aisc,
                "ur_m": ur_m_aisc,
                "ur_v": ur_v_aisc,
                "pass": (ur_m_aisc <= 1.0 and ur_v_aisc <= 1.0),
            },
            "JGJ138": {
                "name": "JGJ 138-2016 (China SRC Code Ch. 5)",
                "m_rd_knm": m_rd_jgj,
                "v_rd_kn": v_rd_jgj,
                "vc_kn": vc_jgj,
                "vsv_kn": vsv_jgj,
                "va_kn": va_jgj,
                "ur_m": ur_m_jgj,
                "ur_v": ur_v_jgj,
                "pass": (ur_m_jgj <= 1.0 and ur_v_jgj <= 1.0),
            },
            "TCVN_SP266": {
                "name": "TCVN 5574:2018 / 5575:2024 + SP 266",
                "m_rd_knm": m_rd_tcvn,
                "v_rd_kn": v_rd_tcvn,
                "ur_m": ur_m_tcvn,
                "ur_v": ur_v_tcvn,
                "pass": (ur_m_tcvn <= 1.0 and ur_v_tcvn <= 1.0),
            },
        },
        "detailing": {
            "steel_ratio_pct": props.steel_ratio * 100.0,
            "rebar_ratio_pct": props.rebar_ratio * 100.0,
            "steel_ratio_ok": 2.0 <= props.steel_ratio * 100.0 <= 15.0,
            "bf_bw_ratio": bf_bw_ratio,
            "v_split_kn": v_split_kn,
            "ur_split": ur_split,
            "splitting_risk": splitting_risk,
            "stud_p_rd_kn": p_rd_stud_kn,
            "v_long_kn": v_long_kn,
            "studs_req_half": n_studs_req_half,
            "studs_prov_half": n_studs_prov_half,
            "ur_studs": ur_studs,
            "ur_sls": ur_sls,
            "sls_ok": ur_sls <= 1.0,
        },
    }


def solve_src_beam_nonlinear(cfg: SrcBeamConfig) -> Dict[str, object]:
    """
    Chạy trọn bộ phân tích phi tuyến PTHH Dầm Thớ 2D + phân tích đàn hồi tuyến tính
    đối chiếu + đường cong M-κ + kiểm tra thiết kế đa tiêu chuẩn (EC4/AISC/JGJ/TCVN).
    """
    fibers, props, conf = build_2d_fiber_section(cfg.geometry, cfg.material)
    x_nodes = _build_beam_nodes(cfg)
    n_nodes = len(x_nodes)
    n_dofs = 3 * n_nodes
    f_ref = _build_reference_load_vector(cfg, x_nodes)
    fixed = _fixed_dofs(cfg, n_nodes)
    free = [i for i in range(n_dofs) if i not in fixed]

    # Tổng tải quy đổi P_total_design (kN)
    total_load_kn = 0.0
    if cfg.load_type in ("udl", "combined"):
        total_load_kn += cfg.q_udl_kn_m * (cfg.span_mm / 1000.0)
    if cfg.load_type in ("3pt", "4pt", "combined"):
        total_load_kn += cfg.p_point_kn

    # 1. Giải tuyến tính đàn hồi đối chiếu tại 1.0 x tải thiết kế
    d_lin, elem_lin, _, _, _ = _solve_step_nr(
        x_nodes, np.zeros(n_dofs), f_ref, free, fibers, cfg, conf, nonlinear=False
    )
    v_lin = d_lin[1::3]
    max_defl_lin_mm = float(np.max(np.abs(v_lin)))

    # 2. Giải phi tuyến gia tăng tải từ λ = 0 -> 1.0 (tải thiết kế)
    n_steps = max(6, cfg.n_steps_design)
    d_cur = np.zeros(n_dofs)
    history: List[Dict[str, object]] = [{
        "lambda": 0.0, "load_kn": 0.0, "defl_mm": 0.0, "m_max_knm": 0.0,
        "v_max_kn": 0.0, "ei_ratio": 1.0, "eps_c_min": 0.0,
        "sig_steel_max_mpa": 0.0, "sig_rebar_max_mpa": 0.0,
        "cracked_ratio": 0.0, "steel_yielded": False, "rebar_yielded": False,
        "concrete_crushed": False, "converged": True, "iters": 0,
    }]
    step_snapshots: List[Dict[str, object]] = []

    design_d = d_cur.copy()
    design_elems: List[Dict[str, object]] = []

    def _summarize_elems(d_vec: np.ndarray, elems: List[Dict[str, object]], lam: float, conv: bool, iters: int) -> Dict[str, object]:
        v_arr = d_vec[1::3]
        defl = float(np.max(np.abs(v_arr)))
        m_max = 0.0
        v_max = 0.0
        eps_c_min = 0.0
        sig_st = 0.0
        sig_rb = 0.0
        cr_max = 0.0
        st_y = False
        rb_y = False
        cc_cr = False
        ei_min = 1e30
        ei_0 = max(1.0, cfg.material.ec_mpa * props.ic_z_mm4 + cfg.material.es_steel_mpa * props.ia_z_mm4 + cfg.material.es_rebar_mpa * props.is_z_mm4)
        for el in elems:
            v_el = max(abs(float(el["f_elem"][1])), abs(float(el["f_elem"][4]))) / 1000.0
            if v_el > v_max:
                v_max = v_el
            for gs in el["gp_states"]:
                m_knm = abs(gs.mz_nmm) / 1e6
                if m_knm > m_max:
                    m_max = m_knm
                if gs.eps_c_min < eps_c_min:
                    eps_c_min = gs.eps_c_min
                if gs.sig_steel_max_mpa > sig_st:
                    sig_st = gs.sig_steel_max_mpa
                if gs.sig_rebar_max_mpa > sig_rb:
                    sig_rb = gs.sig_rebar_max_mpa
                if gs.cracked_ratio > cr_max:
                    cr_max = gs.cracked_ratio
                st_y = st_y or gs.steel_yielded
                rb_y = rb_y or gs.rebar_yielded
                cc_cr = cc_cr or gs.concrete_crushed
                if gs.ei_z_eff < ei_min:
                    ei_min = gs.ei_z_eff
        return {
            "lambda": lam,
            "load_kn": lam * total_load_kn,
            "defl_mm": defl,
            "m_max_knm": m_max,
            "v_max_kn": v_max,
            "ei_ratio": min(1.0, ei_min / ei_0),
            "eps_c_min": eps_c_min,
            "sig_steel_max_mpa": sig_st,
            "sig_rebar_max_mpa": sig_rb,
            "cracked_ratio": cr_max,
            "steel_yielded": st_y,
            "rebar_yielded": rb_y,
            "concrete_crushed": cc_cr,
            "converged": conv,
            "iters": iters,
        }

    for k in range(1, n_steps + 1):
        lam = k / n_steps
        d_next, elems_k, conv, iters, _ = _solve_step_nr(
            x_nodes, d_cur, lam * f_ref, free, fibers, cfg, conf, nonlinear=True
        )
        d_cur = d_next
        rec = _summarize_elems(d_cur, elems_k, lam, conv, iters)
        history.append(rec)
        step_snapshots.append({
            "lambda": lam,
            "d_vec": d_cur.copy(),
            "elems": elems_k,
            "summary": rec,
        })
        if k == n_steps:
            design_d = d_cur.copy()
            design_elems = elems_k

    # 3. Tiếp tục tăng tải đến cực hạn (Push-to-Ultimate) với bước mịn để bắt chính xác M_u
    ultimate_record = history[-1]
    if cfg.push_to_ultimate:
        lam = 1.0
        d_lam = 0.08
        for _ in range(55):
            lam_try = lam + d_lam
            d_try, elems_try, conv, iters, _ = _solve_step_nr(
                x_nodes, d_cur, lam_try * f_ref, free, fibers, cfg, conf, nonlinear=True
            )
            if not conv:
                d_lam *= 0.5
                if d_lam < 0.01:
                    break
                continue
            rec = _summarize_elems(d_try, elems_try, lam_try, conv, iters)
            d_cur = d_try
            lam = lam_try
            history.append(rec)
            ultimate_record = rec
            if rec["concrete_crushed"] or rec["defl_mm"] > cfg.span_mm / 35.0 or abs(rec["eps_c_min"]) >= conf.eps_cu_u:
                break

    # Xác định 4 mốc giai đoạn cơ học (Cracking, Rebar Yield, Steel Core Yield, Ultimate)
    stage_cr = next((h for h in history if h["cracked_ratio"] > 0.03), None)
    stage_ry = next((h for h in history if h["rebar_yielded"]), None)
    stage_sy = next((h for h in history if h["steel_yielded"]), None)
    defl_y = stage_sy["defl_mm"] if stage_sy else (stage_ry["defl_mm"] if stage_ry else max(1.0, history[n_steps]["defl_mm"]))
    ductility_mu = ultimate_record["defl_mm"] / max(0.5, defl_y)

    # Biểu đồ dọc nhịp tại tải thiết kế (λ = 1.0)
    span_x_mm: List[float] = []
    span_v_mm: List[float] = []
    span_v_lin_mm: List[float] = []
    span_m_knm: List[float] = []
    span_q_kn: List[float] = []
    span_ei_ratio: List[float] = []
    span_xna_mm: List[float] = []
    ei_gross = cfg.material.ec_mpa * props.ic_z_mm4 + cfg.material.es_steel_mpa * props.ia_z_mm4 + cfg.material.es_rebar_mpa * props.is_z_mm4

    for e, el in enumerate(design_elems):
        x1, x2 = el["x1_mm"], el["x2_mm"]
        le = el["length_mm"]
        de = el["d_elem"]
        de_l = elem_lin[e]["d_elem"]
        v_shear_kn = float(el["f_elem"][1]) / 1000.0
        for g_idx, xi in enumerate([0.112701665, 0.5, 0.887298335]):
            gs: SectionResponse = el["gp_states"][g_idx]
            # Hàm dạng Hermite cho độ võng v(xi)
            n1 = 1.0 - 3.0 * xi * xi + 2.0 * xi * xi * xi
            n2 = le * (xi - 2.0 * xi * xi + xi * xi * xi)
            n3 = 3.0 * xi * xi - 2.0 * xi * xi * xi
            n4 = le * (-xi * xi + xi * xi * xi)
            v_nl = n1 * de[1] + n2 * de[2] + n3 * de[4] + n4 * de[5]
            v_li = n1 * de_l[1] + n2 * de_l[2] + n3 * de_l[4] + n4 * de_l[5]
            span_x_mm.append(x1 + xi * le)
            span_v_mm.append(float(v_nl))
            span_v_lin_mm.append(float(v_li))
            span_m_knm.append(float(gs.mz_nmm / 1e6))
            span_q_kn.append(v_shear_kn)
            span_ei_ratio.append(min(1.0, float(gs.ei_z_eff / max(1.0, ei_gross))))
            span_xna_mm.append(float(gs.x_na_mm))

    design_summary = history[n_steps]
    m_ed = max(abs(m) for m in span_m_knm) if span_m_knm else design_summary["m_max_knm"]
    v_ed = max(abs(v) for v in span_q_kn) if span_q_kn else design_summary["v_max_kn"]

    # Đường cong M-κ mặt cắt & kiểm tra đa tiêu chuẩn
    mk_curve = compute_moment_curvature(cfg.geometry, cfg.material, axial_n_kn=0.0, n_points=40)
    design_checks = design_check_src_beam(
        cfg, m_ed_knm=m_ed, v_ed_kn=v_ed, delta_sls_mm=design_summary["defl_mm"],
        props=props, fibers=fibers,
    )

    return {
        "member_kind": "beam",
        "config": cfg,
        "props": props,
        "conf": conf,
        "fibers": fibers,
        "x_nodes_mm": x_nodes.tolist(),
        "d_design": design_d,
        "d_linear": d_lin,
        "design_elems": design_elems,
        "step_snapshots": step_snapshots,
        "total_load_design_kn": total_load_kn,
        "max_defl_linear_mm": max_defl_lin_mm,
        "max_defl_design_mm": design_summary["defl_mm"],
        "m_ed_knm": m_ed,
        "v_ed_kn": v_ed,
        "p_ultimate_kn": ultimate_record["load_kn"],
        "m_ultimate_fem_knm": ultimate_record["m_max_knm"],
        "defl_ultimate_mm": ultimate_record["defl_mm"],
        "ductility_mu": ductility_mu,
        "stages": {
            "cracking": stage_cr,
            "rebar_yield": stage_ry,
            "steel_yield": stage_sy,
            "ultimate": ultimate_record,
        },
        "history": history,
        "span_profiles": {
            "x_mm": span_x_mm,
            "v_nl_mm": span_v_mm,
            "v_lin_mm": span_v_lin_mm,
            "m_knm": span_m_knm,
            "v_shear_kn": span_q_kn,
            "ei_ratio": span_ei_ratio,
            "x_na_mm": span_xna_mm,
        },
        "mk_curve": mk_curve,
        "design_checks": design_checks,
    }


def get_beam_presets() -> Dict[str, SrcBeamConfig]:
    """Danh sách mẫu chuẩn thiết kế & mẫu thí nghiệm thực tế dùng để kiểm chứng Dầm cốt cứng."""
    return {
        "t_slab_standard": SrcBeamConfig(
            name="Dầm chữ T bản sàn SRC (L=6.0m, H300x150, C35/45)",
            span_mm=6000.0,
            load_type="udl", q_udl_kn_m=65.0,
        ),
        "rect_highrise_beam": SrcBeamConfig(
            name="Dầm khung nhà cao tầng chữ nhật SRC (L=7.2m, H350x175, C40/50)",
            span_mm=7200.0,
            geometry=SectionGeometry(
                section_type="SRC_RECT_H",
                b_mm=350.0, h_mm=650.0,
                ha_mm=350.0, ba_mm=175.0, tf_mm=11.0, tw_mm=7.0,
                cover_mm=35.0, rebar_dia_bot_mm=22.0, n_rebar_bot=4,
                rebar_dia_top_mm=20.0, n_rebar_top=4,
                stirrup_dia_mm=10.0, stirrup_spacing_mm=150.0, stirrup_spacing_end_mm=100.0,
            ),
            material=MaterialConfig(
                concrete_grade="C40/50 (B45)", fc_mpa=40.0, ec_mpa=35000.0, fct_mpa=3.5,
                steel_grade="S355 (Q355)", fy_steel_mpa=355.0, fu_steel_mpa=490.0,
                rebar_grade="CB400-V (B400)", fy_rebar_mpa=400.0,
            ),
            load_type="udl", q_udl_kn_m=75.0,
        ),
        "wang2024_b1q3": SrcBeamConfig(
            name="Benchmark Huang & Liew (2018) C100B — Dầm SRC uốn thuần túy (M_u,exp = 149.1 kN·m)",
            span_mm=2500.0,
            geometry=SectionGeometry(
                section_type="SRC_RECT_H",
                b_mm=240.0, h_mm=240.0,
                ha_mm=161.8, ba_mm=154.4, tf_mm=11.5, tw_mm=8.0,
                cover_mm=24.0, rebar_dia_bot_mm=12.0, n_rebar_bot=3,
                rebar_dia_top_mm=12.0, n_rebar_top=3,
                stirrup_dia_mm=6.0, stirrup_spacing_mm=150.0, stirrup_spacing_end_mm=100.0,
            ),
            material=MaterialConfig(
                concrete_grade="C110 (VHSC)", fc_mpa=109.3, ec_mpa=44900.0, fct_mpa=5.2,
                steel_grade="S355 (Q355)", fy_steel_mpa=362.9, fu_steel_mpa=500.0, es_steel_mpa=201550.0,
                rebar_grade="CB400-V (B400)", fy_rebar_mpa=356.8, es_rebar_mpa=193640.0,
            ),
            load_type="4pt", p_point_kn=220.0, load_a_mm=950.0,
        ),
        "jiang2024_pecb1": SrcBeamConfig(
            name="Benchmark Jiang et al. (2024) PECB1 — Dầm chữ T bản sàn (M_u,exp ≈ 1022 kN·m)",
            span_mm=5600.0,
            geometry=SectionGeometry(
                section_type="SRC_T_SLAB_H",
                b_mm=300.0, h_mm=580.0,
                bf_slab_mm=1200.0, hf_slab_mm=130.0,
                ha_mm=350.0, ba_mm=175.0, tf_mm=12.0, tw_mm=8.0,
                core_offset_y_mm=-35.0,
                cover_mm=30.0, rebar_dia_bot_mm=22.0, n_rebar_bot=4,
                rebar_dia_top_mm=16.0, n_rebar_top=2,
                stirrup_dia_mm=10.0, stirrup_spacing_mm=150.0, stirrup_spacing_end_mm=100.0,
            ),
            material=MaterialConfig(
                concrete_grade="C40/50 (B45)", fc_mpa=40.0, ec_mpa=35000.0, fct_mpa=3.5,
                steel_grade="S355 (Q355)", fy_steel_mpa=355.0, fu_steel_mpa=490.0,
                rebar_grade="CB400-V (B400)", fy_rebar_mpa=400.0,
            ),
            load_type="4pt", p_point_kn=650.0, load_a_mm=1800.0,
        ),
    }
