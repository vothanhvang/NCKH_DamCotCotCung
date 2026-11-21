# -*- coding: utf-8 -*-
"""
================================================================================
MÔ-ĐUN 5: KHẢO SÁT BẤT KỲ VỊ TRÍ (x/L, y, z) & PHẪU THUẬT MẶT CẮT KIỂU ANSYS
================================================================================
Chức năng khối:
  - Cho phép người dùng chọn tọa độ dọc cấu kiện bất kỳ x/L ∈ [0, 1] và tọa độ
    điểm bất kỳ (y, z) bên trong tiết diện dầm hoặc cột bê tông cốt cứng.
  - Tính chính xác trạng thái ứng suất – biến dạng nội tại tại điểm khảo sát:
      • Biến dạng pháp tuyến ε_x(x, y, z) = ε₀(x) − y · κ_z(x) + z · κ_y(x)
      • Ứng suất pháp tuyến σ_x(x, y, z) theo đúng định luật vật liệu (bê tông
        3 vùng giam giữ, cánh/bụng thép hình H, cốt thép dọc)
      • Ứng suất tiếp cắt τ_xy(x, y, z) (phân bố Jourawski trong bản bụng thép H
        và sườn bê tông)
      • Ứng suất tương đương von Mises σ_vM = √(σ_x² + 3 τ_xy²) cho lõi thép hình
      • Hệ số sử dụng ứng suất, vùng giam giữ, trạng thái Nứt / Chảy dẻo / Vỡ nén
  - Xuất dữ liệu đầy đủ cho:
      • Phẫu thuật mặt cắt ngang 2D (Cross-Section Dissection Heatmap)
      • Phẫu thuật bổ dọc thân dầm/cột 2D/3D (Longitudinal Cutaway Slice)
================================================================================
"""

from __future__ import annotations
from typing import Dict, List, Tuple
import math

from .materials import ConcreteZone, concrete_stress_tangent, steel_stress_tangent
from .section_fiber import FiberCell, SectionGeometry, _point_in_steel_core, _classify_concrete_zone


def _interpolate_section_kinematics(analysis: Dict[str, object], x_norm: float) -> Tuple[float, float, float, float, float, float]:
    """
    Nội suy chính xác (eps0, kappa_z, kappa_y, v_shear_n, n_n, m_nmm) tại vị trí x/L ∈ [0, 1]
    từ kết quả phần tử hữu hạn (dầm hoặc cột).
    """
    x_clamped = max(0.0, min(1.0, x_norm))
    elems = analysis["design_elems"]
    x_nodes = analysis["x_nodes_mm"]
    L = float(x_nodes[-1])
    x_pos = x_clamped * L

    # Tìm phần tử chứa x_pos
    chosen = elems[-1]
    for el in elems:
        if el["x1_mm"] - 1e-6 <= x_pos <= el["x2_mm"] + 1e-6:
            chosen = el
            break

    le = max(1e-6, chosen["length_mm"])
    xi = max(0.0, min(1.0, (x_pos - chosen["x1_mm"]) / le))
    de = chosen["d_elem"]

    # Đạo hàm hàm dạng tại xi
    eps0 = float((-de[0] + de[3]) / le)
    kappa = float(
        ((-6.0 + 12.0 * xi) / (le * le)) * de[1]
        + ((-4.0 + 6.0 * xi) / le) * de[2]
        + ((6.0 - 12.0 * xi) / (le * le)) * de[4]
        + ((-2.0 + 6.0 * xi) / le) * de[5]
    )
    v_shear_n = float(chosen["f_elem"][1])

    # Nội suy nội lực (N, M) từ 3 điểm Gauss
    gs0, gs1, gs2 = chosen["gp_states"]
    if xi <= 0.5:
        w = max(0.0, min(1.0, (xi - 0.1127) / (0.5 - 0.1127)))
        n_n = (1.0 - w) * gs0.n_n + w * gs1.n_n
        m_nmm = (1.0 - w) * gs0.mz_nmm + w * gs1.mz_nmm
    else:
        w = max(0.0, min(1.0, (xi - 0.5) / (0.8873 - 0.5)))
        n_n = (1.0 - w) * gs1.n_n + w * gs2.n_n
        m_nmm = (1.0 - w) * gs1.mz_nmm + w * gs2.mz_nmm

    dom_axis = analysis.get("dom_axis", "z")
    if dom_axis == "y":
        return eps0, 0.0, -kappa, v_shear_n, n_n, m_nmm
    return eps0, kappa, 0.0, v_shear_n, n_n, m_nmm


def probe_member_point(
    analysis: Dict[str, object],
    x_norm: float,
    y_mm: float,
    z_mm: float = 0.0,
) -> Dict[str, object]:
    """
    Khảo sát ứng xử cơ học nội tại tại điểm bất kỳ (x/L, y, z) bên trong dầm hoặc cột SRC.
    """
    cfg = analysis["config"]
    geom: SectionGeometry = cfg.geometry
    mat = cfg.material
    conf = analysis["conf"]
    props = analysis["props"]

    eps0, kz, ky, v_shear_n, n_n, m_nmm = _interpolate_section_kinematics(analysis, x_norm)
    eps_x = eps0 - y_mm * kz + z_mm * ky

    # Xác định loại vật liệu tại điểm (y, z)
    steel_part = _point_in_steel_core(y_mm, z_mm, geom)
    near_rebar = None
    for yr, zr, dia in props.rebar_coords:
        if math.hypot(y_mm - yr, z_mm - zr) <= 0.65 * dia:
            near_rebar = dia
            break

    if steel_part is not None:
        sig_x, et, state = steel_stress_tangent(eps_x, mat.es_steel_mpa, mat.fy_steel_mpa, mat.hardening_steel, True)
        mat_label = "Thép hình cốt cứng (Cánh)" if steel_part == "steel_flange" else (
            "Thép hình cốt cứng (Bụng)" if steel_part == "steel_web" else "Ống thép cốt cứng (CFST)"
        )
        zone_label = "Lõi thép hình"
        limit_mpa = mat.fy_steel_mpa
    elif near_rebar is not None:
        sig_x, et, state = steel_stress_tangent(eps_x, mat.es_rebar_mpa, mat.fy_rebar_mpa, mat.hardening_rebar, True)
        mat_label = f"Cốt thép dọc Ø{near_rebar:.0f}"
        zone_label = "Cốt thép thanh"
        limit_mpa = mat.fy_rebar_mpa
    else:
        zone = _classify_concrete_zone(y_mm, z_mm, geom)
        sig_x, et, state = concrete_stress_tangent(eps_x, mat, zone, conf, True)
        mat_label = "Bê tông"
        zone_label = {
            ConcreteZone.UNCONFINED: "Vùng 0 — Bê tông vỏ bảo vệ (Không giam giữ)",
            ConcreteZone.PARTIALLY_CONFINED: f"Vùng 1 — Giam giữ một phần trong cốt đai (K_p={conf.kp:.2f})",
            ConcreteZone.HIGHLY_CONFINED: f"Vùng 2 — Giam giữ mạnh trong khoang thép H (K_h={conf.kh:.2f})",
        }[zone]
        limit_mpa = mat.fc_mpa * (conf.kh if zone == ConcreteZone.HIGHLY_CONFINED else (conf.kp if zone == ConcreteZone.PARTIALLY_CONFINED else 1.0))

    # Ước lượng phân bố ứng suất tiếp cắt τ_xy (Jourawski parabol, tập trung mạnh ở bản bụng thép)
    hw_st = max(10.0, geom.ha_mm - 2.0 * geom.tf_mm)
    parab = max(0.0, 1.0 - (2.0 * y_mm / max(1.0, geom.h_mm)) ** 2)
    if steel_part == "steel_web":
        tau_xy = 0.72 * abs(v_shear_n) / max(1.0, hw_st * geom.tw_mm) * (0.75 + 0.45 * parab)
    elif steel_part == "steel_flange":
        tau_xy = 0.15 * abs(v_shear_n) / max(1.0, geom.ba_mm * geom.tf_mm)
    else:
        tau_xy = 0.28 * 1.5 * abs(v_shear_n) / max(1.0, geom.b_mm * geom.h_mm) * parab

    sigma_vm = math.sqrt(sig_x * sig_x + 3.0 * tau_xy * tau_xy)
    x_na = (0.5 * geom.h_mm - eps0 / kz) if abs(kz) > 1e-11 else (geom.h_mm if eps0 < 0 else 0.0)
    x_na = max(0.0, min(geom.h_mm, x_na))

    return {
        "x_norm": x_norm,
        "x_mm": x_norm * float(analysis["x_nodes_mm"][-1]),
        "y_mm": y_mm,
        "z_mm": z_mm,
        "material": mat_label,
        "zone": zone_label,
        "eps_x": eps_x,
        "eps_x_permille": eps_x * 1000.0,
        "sigma_x_mpa": sig_x,
        "tau_xy_mpa": tau_xy,
        "sigma_vm_mpa": sigma_vm,
        "tangent_modulus_mpa": et,
        "utilization_ratio": abs(sig_x) / max(1.0, limit_mpa),
        "state": state,
        "section_n_kn": -n_n / 1000.0,
        "section_m_knm": m_nmm / 1e6,
        "section_v_kn": v_shear_n / 1000.0,
        "x_na_mm": x_na,
    }


def dissect_section_2d(analysis: Dict[str, object], x_norm: float = 0.5) -> Dict[str, object]:
    """
    Phẫu thuật toàn bộ mặt cắt ngang 2D tại tọa độ x/L:
    Trả về trường ứng suất – biến dạng chi tiết cho từng ô thớ (FiberCell) để dựng
    bản đồ màu ANSYS 2D/3D, kiểm tra cân bằng tích phân (∑σA = N, −∑σyA = M) và
    đường phân bố ứng suất – biến dạng dọc chiều cao tiết diện.
    """
    cfg = analysis["config"]
    geom: SectionGeometry = cfg.geometry
    mat = cfg.material
    conf = analysis["conf"]
    fibers: List[FiberCell] = analysis["fibers"]

    eps0, kz, ky, v_shear_n, _, _ = _interpolate_section_kinematics(analysis, x_norm)

    fiber_states: List[Dict[str, object]] = []
    n_sum = 0.0
    mz_sum = 0.0
    my_sum = 0.0
    n_conc = 0.0
    n_steel = 0.0
    n_rebar = 0.0
    mz_conc = 0.0
    mz_steel = 0.0
    mz_rebar = 0.0
    sig_min = 1e18
    sig_max = -1e18
    eps_min = 1e18
    eps_max = -1e18

    for f in fibers:
        eps = eps0 - f.y_mm * kz + f.z_mm * ky
        if f.kind == "concrete":
            sig, et, state = concrete_stress_tangent(eps, mat, f.zone, conf, True)
            n_conc += -sig * f.area_mm2 / 1000.0
            mz_conc += -sig * f.y_mm * f.area_mm2 / 1e6
        else:
            bh = mat.hardening_steel if f.kind.startswith("steel") else mat.hardening_rebar
            sig, et, state = steel_stress_tangent(eps, f.es_mpa, f.fy_mpa, bh, True)
            if f.kind.startswith("steel"):
                n_steel += -sig * f.area_mm2 / 1000.0
                mz_steel += -sig * f.y_mm * f.area_mm2 / 1e6
            else:
                n_rebar += -sig * f.area_mm2 / 1000.0
                mz_rebar += -sig * f.y_mm * f.area_mm2 / 1e6

        n_sum += sig * f.area_mm2
        mz_sum -= sig * f.y_mm * f.area_mm2
        my_sum += sig * f.z_mm * f.area_mm2

        sig_min = min(sig_min, sig)
        sig_max = max(sig_max, sig)
        eps_min = min(eps_min, eps)
        eps_max = max(eps_max, eps)

        fiber_states.append({
            "y_mm": f.y_mm,
            "z_mm": f.z_mm,
            "dy_mm": f.dy_mm,
            "dz_mm": f.dz_mm,
            "area_mm2": f.area_mm2,
            "kind": f.kind,
            "zone": f.zone.value,
            "eps": eps,
            "sigma_mpa": sig,
            "et_mpa": et,
            "state": state,
        })

    x_na = (0.5 * geom.h_mm - eps0 / kz) if abs(kz) > 1e-11 else (geom.h_mm if eps0 < 0 else 0.0)
    x_na = max(0.0, min(geom.h_mm, x_na))

    # =========================================================================
    # PHÂN TÍCH ỨNG XỬ LIÊN KẾT CỐT CỨNG (THÉP HÌNH) ↔ BÊ TÔNG CỐT THÉP TẠI x/L
    # (Tỷ lệ chia tải, lực trượt mặt tiếp xúc v_L, dính bám τ_b, đinh neo & trượt vi mô)
    # =========================================================================
    is_beam = (analysis.get("member_kind") == "beam")
    L_mm = float(analysis["x_nodes_mm"][-1])
    x_mm = max(0.0, min(1.0, x_norm)) * L_mm
    props = analysis["props"]

    # 1. Tỷ lệ phân chia nội lực giữa Thép hình — Bê tông — Cốt thép thanh
    if is_beam:
        tot_m = abs(mz_steel) + abs(mz_conc) + abs(mz_rebar)
        if tot_m > 1.0:
            steel_pct = 100.0 * abs(mz_steel) / tot_m
            conc_pct = 100.0 * abs(mz_conc) / tot_m
            rebar_pct = max(0.0, 100.0 - steel_pct - conc_pct)
        else:
            ei_a = mat.es_steel_mpa * props.ia_z_mm4
            ei_c = mat.ec_mpa * props.ic_z_mm4
            ei_s = mat.es_rebar_mpa * props.is_z_mm4
            ei_t = max(1.0, ei_a + ei_c + ei_s)
            steel_pct = 100.0 * ei_a / ei_t
            conc_pct = 100.0 * ei_c / ei_t
            rebar_pct = max(0.0, 100.0 - steel_pct - conc_pct)
    else:
        tot_n = abs(n_steel) + abs(n_conc) + abs(n_rebar)
        if tot_n > 1.0:
            steel_pct = 100.0 * abs(n_steel) / tot_n
            conc_pct = 100.0 * abs(n_conc) / tot_n
            rebar_pct = max(0.0, 100.0 - steel_pct - conc_pct)
        else:
            steel_pct, conc_pct, rebar_pct = 35.0, 55.0, 10.0

    # 2. Chu vi tiếp xúc thép hình – bê tông u_a (mm) & Lực trượt dọc v_L (kN/m)
    if geom.section_type == "COL_RECT_CFST":
        u_bond_mm = math.pi * geom.ha_mm + math.pi * max(20.0, geom.ha_mm - 2.0 * geom.tw_mm)
        tau_rd0 = 0.55
    elif geom.section_type == "COL_RECT_CROSS_H":
        u_bond_mm = 8.0 * geom.ba_mm + 4.0 * max(10.0, geom.ha_mm - 2.0 * geom.tf_mm) - 6.0 * geom.tw_mm
        tau_rd0 = 0.30
    else:
        u_bond_mm = 4.0 * geom.ba_mm + 2.0 * max(10.0, geom.ha_mm - 2.0 * geom.tf_mm) - 2.0 * geom.tw_mm
        tau_rd0 = 0.30

    ei_a = mat.es_steel_mpa * props.ia_z_mm4
    ei_tot = max(1.0, ei_a + mat.ec_mpa * props.ic_z_mm4 + mat.es_rebar_mpa * props.is_z_mm4)
    alpha_a = max(0.25, min(0.75, ei_a / ei_tot))
    z_lev_m = 0.85 * max(geom.ha_mm, 0.70 * geom.h_mm) / 1000.0
    v_flex_kn_m = abs(v_shear_n / 1000.0) * alpha_a / max(0.15, z_lev_m)

    # Vùng truyền lực đầu cột l_V = min(2h, L/3) theo EN 1994-1-1 §6.7.4.2
    v_intro_kn_m = 0.0
    if not is_beam:
        l_intro_mm = min(2.0 * geom.h_mm, L_mm / 3.0)
        dist_end = min(x_mm, L_mm - x_mm)
        phi_intro = max(0.0, 1.0 - dist_end / max(100.0, l_intro_mm))
        v_intro_kn_m = abs(n_steel) * (1.0 - steel_pct / 100.0) / max(0.25, l_intro_mm / 1000.0) * phi_intro

    v_interface_kn_m = v_flex_kn_m + v_intro_kn_m
    tau_bond_mpa = v_interface_kn_m / max(100.0, u_bond_mm)  # (kN/m) / mm = N/mm / mm = MPa!
    tau_rd_eff = tau_rd0 + 0.25 * conf.fl_p_mpa  # Tăng cường ma sát nhờ áp lực cốt đai

    # 3. Lực cắt tác dụng lên đinh chống cắt (dầm) & Trượt tương đối vi mô s_slip (mm)
    det = analysis.get("design_checks", {}).get("detailing", {})
    stud_p_rd = float(det.get("stud_p_rd_kn", 70.0))
    v_split_kn = float(det.get("v_split_kn", 1e6))
    stud_spacing_mm = float(getattr(cfg, "stud_spacing_mm", 200.0))
    stud_rows = int(getattr(cfg, "stud_rows", 2))
    stud_force_kn = v_interface_kn_m * (stud_spacing_mm / 1000.0) / max(1, stud_rows) if is_beam else 0.0
    stud_ur = stud_force_kn / max(1.0, stud_p_rd) if is_beam else 0.0
    split_ur = abs(v_shear_n / 1000.0) / max(1.0, v_split_kn) if is_beam else 0.0

    k_bond = 12.0  # MPa/mm độ cứng dính bám ban đầu
    if is_beam:
        k_stud = max(40.0, 0.7 * stud_p_rd / 0.5)
        slip_mm = (tau_bond_mpa / k_bond) if tau_bond_mpa <= tau_rd0 else (0.025 + max(0.0, stud_force_kn - 0.25 * stud_p_rd) / k_stud)
        if stud_ur > 1.0 or split_ur > 1.0:
            bond_state = "Cảnh báo trượt / Tách dọc cánh thép"
        elif tau_bond_mpa > tau_rd0 or stud_ur > 0.45:
            bond_state = "Đinh neo & Ma sát đang chịu trượt tích cực"
        else:
            bond_state = "Liên kết hoàn toàn — Dính bám đàn hồi"
    else:
        slip_mm = (tau_bond_mpa / k_bond) if tau_bond_mpa <= tau_rd_eff else (0.025 + (tau_bond_mpa - tau_rd_eff) / 2.5)
        if tau_bond_mpa > tau_rd_eff:
            bond_state = "Vượt dính bám tự nhiên — Cần tăng đinh neo / đai dày"
        elif tau_bond_mpa > 0.55 * tau_rd_eff or conf.fl_h_mpa > 1.0:
            bond_state = "Ma sát & Giam giữ vòm lõi thép H tích cực"
        else:
            bond_state = "Liên kết hoàn toàn — Biến dạng tương thích"

    return {
        "x_norm": x_norm,
        "x_mm": x_mm,
        "eps0": eps0,
        "kappa_z": kz,
        "kappa_y": ky,
        "n_kn": -n_sum / 1000.0,
        "mz_knm": mz_sum / 1e6,
        "my_knm": my_sum / 1e6,
        "v_shear_kn": v_shear_n / 1000.0,
        "x_na_mm": x_na,
        "sigma_min_mpa": sig_min,
        "sigma_max_mpa": sig_max,
        "eps_min": eps_min,
        "eps_max": eps_max,
        "fibers": fiber_states,
        "interface_behavior": {
            "n_steel_kn": n_steel,
            "n_concrete_kn": n_conc,
            "n_rebar_kn": n_rebar,
            "mz_steel_knm": mz_steel,
            "mz_concrete_knm": mz_conc,
            "mz_rebar_knm": mz_rebar,
            "steel_share_pct": steel_pct,
            "concrete_share_pct": conc_pct,
            "rebar_share_pct": rebar_pct,
            "bond_perimeter_mm": u_bond_mm,
            "v_interface_kn_per_m": v_interface_kn_m,
            "tau_bond_mpa": tau_bond_mpa,
            "tau_rd_mpa": tau_rd_eff,
            "stud_force_kn": stud_force_kn,
            "stud_p_rd_kn": stud_p_rd,
            "stud_ur": stud_ur,
            "split_ur": split_ur,
            "slip_mm": slip_mm,
            "conf_fl_p_mpa": conf.fl_p_mpa,
            "conf_fl_h_mpa": conf.fl_h_mpa,
            "bond_state": bond_state,
        },
    }


def dissect_longitudinal_slice(
    analysis: Dict[str, object],
    z_slice_mm: float = 0.0,
    nx: int = 36,
    ny: int = 20,
) -> Dict[str, object]:
    """
    Phẫu thuật bổ dọc cấu kiện tại mặt phẳng z = z_slice_mm (mặc định z = 0 đi qua
    đúng tâm bản bụng thép hình H!), xuất lưới 2D (nx × ny) ứng suất σ_x, biến dạng ε_x
    và von Mises σ_vM để hiển thị bản đồ màu bổ dọc như trong ANSYS Mechanical!
    """
    geom: SectionGeometry = analysis["config"].geometry
    L = float(analysis["x_nodes_mm"][-1])
    xs = [L * i / max(1, nx - 1) for i in range(nx)]
    ys = [-0.5 * geom.h_mm + geom.h_mm * j / max(1, ny - 1) for j in range(ny)]

    sigma_grid: List[List[float]] = []
    eps_grid: List[List[float]] = []
    vm_grid: List[List[float]] = []

    for y in ys:
        row_s: List[float] = []
        row_e: List[float] = []
        row_v: List[float] = []
        for x in xs:
            p = probe_member_point(analysis, x / max(1.0, L), y, z_slice_mm)
            row_s.append(p["sigma_x_mpa"])
            row_e.append(p["eps_x_permille"])
            row_v.append(p["sigma_vm_mpa"])
        sigma_grid.append(row_s)
        eps_grid.append(row_e)
        vm_grid.append(row_v)

    return {
        "z_slice_mm": z_slice_mm,
        "x_mm": xs,
        "y_mm": ys,
        "sigma_x_mpa": sigma_grid,
        "eps_x_permille": eps_grid,
        "sigma_vm_mpa": vm_grid,
    }
