# -*- coding: utf-8 -*-
"""
================================================================================
MÔ-ĐUN 2: RỜI RẠC HÓA MẶT CẮT THỚ 2D (2D FIBER SECTION) & TƯƠNG TÁC N–M / M–κ
================================================================================
Chức năng khối:
  - Rời rạc hóa chính xác hình học mặt cắt ngang bê tông cốt cứng (SRC / CES)
    thành tập hợp các ô thớ 2D (FiberCell) không chồng lấn diện tích (tự động
    trừ phần diện tích thép hình và cốt thép khỏi bê tông!):
      • Dầm cốt cứng chữ nhật bọc thép hình H/I   (`SRC_RECT_H`)
      • Dầm cốt cứng chữ T có bản sàn BT + thép H (`SRC_T_SLAB_H`)
      • Cột cốt cứng chữ nhật / vuông lõi thép H  (`COL_RECT_H`)
      • Cột cốt cứng chữ nhật / vuông lõi chữ thập(`COL_RECT_CROSS_H`)
      • Cột cốt cứng tròn lõi thép H              (`COL_CIRC_H`)
      • Cột ống thép nhồi BT bọc BT (CE-CFST)     (`COL_RECT_CFST`)
  - Tự động phân vùng giam giữ bê tông 3 miền (Unconfined / Partially Confined /
    Highly Confined) theo Chen & Lin (2006) & El-Tawil & Deierlein (1999).
  - Tích phân chính xác nội lực mặt cắt (N, M_z, M_y) và ma trận độ cứng tiếp
    tuyến 3x3 [D_t] đối xứng theo định luật biến dạng phẳng Euler-Bernoulli:
        ε(y, z) = ε₀ − y · κ_z + z · κ_y
  - Xây dựng đường cong Mô-men – Độ cong (M – κ) và Biểu đồ tương tác (N – M_z,
    N – M_y, mặt tương tác 3D N – M_z – M_y) theo phương pháp tương thích biến
    dạng thớ phi tuyến (Strain Compatibility — Huang & Liew 2018; AISC 360-22;
    EC4 §6.7.3.6).
================================================================================
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Dict, List, Tuple
import math
import numpy as np

from .materials import (
    ConcreteZone,
    ConfinementParams,
    MaterialConfig,
    compute_confinement_params,
    concrete_stress_tangent,
    steel_stress_tangent,
)


@dataclass(frozen=True)
class FiberCell:
    """Một ô thớ nguyên tố 2D trong mặt cắt ngang (tọa độ tâm y, z theo mm)."""
    y_mm: float            # Tọa độ đứng y ∈ [-h/2, +h/2] (+h/2 là mép trên, -h/2 là mép dưới)
    z_mm: float            # Tọa độ ngang z ∈ [-b/2, +b/2]
    dy_mm: float           # Chiều cao ô thớ (mm)
    dz_mm: float           # Bề rộng ô thớ (mm)
    area_mm2: float        # Diện tích ô thớ (mm²)
    kind: str              # 'concrete', 'steel_flange', 'steel_web', 'steel_tube', 'rebar'
    zone: ConcreteZone     # Vùng giam giữ (chỉ có ý nghĩa với bê tông)
    fy_mpa: float = 0.0    # Giới hạn chảy riêng (nếu là thép hình hoặc cốt thép)
    es_mpa: float = 0.0    # Mô-đun đàn hồi riêng


@dataclass
class SectionGeometry:
    """
    Thông số hình học tổng quát cho tiết diện Dầm hoặc Cột bê tông cốt cứng.
    Đơn vị chuẩn: mm.
    """
    section_type: str = "SRC_RECT_H"  # SRC_RECT_H, SRC_T_SLAB_H, COL_RECT_H, COL_RECT_CROSS_H, COL_CIRC_H, COL_RECT_CFST
    b_mm: float = 300.0               # Bề rộng sườn bê tông b (hoặc đường kính D cho cột tròn)
    h_mm: float = 550.0               # Tổng chiều cao tiết diện h (gồm cả bản sàn nếu là dầm chữ T)
    # Bản sàn bê tông (chỉ dùng cho dầm chữ T: SRC_T_SLAB_H)
    bf_slab_mm: float = 1200.0        # Bề rộng hữu hiệu bản sàn b_eff (mm)
    hf_slab_mm: float = 120.0         # Chiều dày bản sàn h_f (mm)
    # Lõi thép hình chữ H / I / chữ thập / ống thép vuông/tròn
    ha_mm: float = 300.0              # Chiều cao thép hình h_a (hoặc đường kính ngoài ống CFST D_tube)
    ba_mm: float = 150.0              # Bề rộng cánh thép hình b_f (hoặc chiều rộng ống CFST)
    tf_mm: float = 10.0               # Chiều dày cánh thép t_f (hoặc bề dày thành ống t_tube)
    tw_mm: float = 7.0                # Chiều dày bản bụng thép t_w
    core_offset_y_mm: float = 0.0     # Độ lệch tâm đặt lõi thép theo phương y (0 = đồng tâm sườn)
    # Cốt thép dọc & cốt đai
    cover_mm: float = 35.0            # Chiều dày lớp bê tông bảo vệ tới mép cốt đai (mm)
    rebar_dia_bot_mm: float = 20.0    # Đường kính cốt thép dọc dưới (hoặc toàn bộ cốt dọc cột)
    n_rebar_bot: int = 4              # Số thanh cốt dọc lớp dưới (dầm) hoặc tổng số thanh chu vi (cột)
    rebar_dia_top_mm: float = 16.0    # Đường kính cốt thép dọc trên (dầm)
    n_rebar_top: int = 2              # Số thanh cốt dọc lớp trên (dầm)
    n_rebar_side_each: int = 1        # Số thanh cốt dọc bổ sung mỗi cạnh bên (cột)
    stirrup_dia_mm: float = 10.0      # Đường kính cốt thép đai d_sv
    stirrup_spacing_mm: float = 150.0 # Bước cốt đai vùng giữa s_2 (mm)
    stirrup_spacing_end_mm: float = 100.0  # Bước cốt đai vùng đầu gia cường s_1 (mm)
    n_stirrup_legs: int = 2           # Số nhánh cốt đai cắt qua tiết diện
    # Mật độ lưới thớ 2D
    ny_grid: int = 28                 # Số hàng thớ theo phương y
    nz_grid: int = 16                 # Số cột thớ theo phương z


@dataclass
class SectionProperties:
    """Các đặc trưng hình học chính xác tích phân từ lưới thớ 2D (để phục vụ thiết kế đa tiêu chuẩn)."""
    ag_mm2: float          # Tổng diện tích mặt cắt ngang A_g
    ac_mm2: float          # Diện tích thực bê tông A_c (đã trừ thép hình & cốt thép)
    aa_mm2: float          # Diện tích lõi thép hình A_a
    as_mm2: float          # Tổng diện tích cốt thép dọc A_s
    as_bot_mm2: float      # Diện tích cốt thép lớp dưới (dầm)
    as_top_mm2: float      # Diện tích cốt thép lớp trên (dầm)
    ac_unconfined_mm2: float
    ac_part_conf_mm2: float
    ac_high_conf_mm2: float
    ic_z_mm4: float        # Mô-men quán tính bê tông quanh trục z (uốn chính)
    ia_z_mm4: float        # Mô-men quán tính thép hình quanh trục z
    is_z_mm4: float        # Mô-men quán tính cốt thép quanh trục z
    ic_y_mm4: float        # Mô-men quán tính bê tông quanh trục y (uốn phương phụ)
    ia_y_mm4: float        # Mô-men quán tính thép hình quanh trục y
    is_y_mm4: float        # Mô-men quán tính cốt thép quanh trục y
    steel_ratio: float     # Hàm lượng thép hình ρ_a = A_a / A_g
    rebar_ratio: float     # Hàm lượng cốt thép dọc ρ_s = A_s / A_g
    vol_stirrup_ratio: float  # Hàm lượng thể tích cốt đai ρ_v
    y_centroid_mm: float   # Tọa độ trọng tâm hình học của mặt cắt quy đổi (so với y = 0)
    rebar_coords: List[Tuple[float, float, float]] = field(default_factory=list)  # (y, z, dia)


@dataclass
class SectionResponse:
    """Trạng thái nội lực, độ cứng tiếp tuyến và cực trị ứng suất – biến dạng của mặt cắt."""
    eps0: float
    kappa_z: float
    kappa_y: float
    n_n: float             # Lực dọc N (N; nén < 0, kéo > 0)
    mz_nmm: float          # Mô-men uốn quanh trục z (N·mm; uốn võng xuống +)
    my_nmm: float          # Mô-men uốn quanh trục y (N·mm)
    dt_mat: np.ndarray     # Ma trận độ cứng tiếp tuyến 3x3: d{N, Mz, My} / d{eps0, kz, ky}
    ea_t: float
    ei_z_eff: float
    ei_y_eff: float
    x_na_mm: float         # Chiều cao vùng nén tính từ mép trên (mm)
    eps_c_min: float       # Biến dạng nén lớn nhất của bê tông (âm)
    eps_c_max: float       # Biến dạng kéo lớn nhất của bê tông (dương)
    sig_c_min_mpa: float   # Ứng suất nén lớn nhất bê tông (âm, MPa)
    sig_steel_max_mpa: float  # Ứng suất cực đại |σ| trong thép hình (MPa)
    sig_rebar_max_mpa: float  # Ứng suất cực đại |σ| trong cốt thép dọc (MPa)
    cracked_ratio: float   # Tỷ lệ diện tích bê tông đã bị nứt kéo
    steel_yielded: bool    # Lõi thép hình đã chảy dẻo chưa
    rebar_yielded: bool    # Cốt thép dọc đã chảy dẻo chưa
    concrete_crushed: bool # Bê tông vỏ đã chạm biến dạng phá hoại nén chưa


def _point_in_steel_core(y: float, z: float, geom: SectionGeometry) -> str | None:
    """
    Kiểm tra điểm (y, z) có nằm bên trong vùng lõi thép hình không.
    Trả về 'steel_flange', 'steel_web', 'steel_tube' hoặc None nếu nằm ngoài thép hình.
    """
    yc = y - geom.core_offset_y_mm
    ha = geom.ha_mm
    ba = geom.ba_mm
    tf = min(geom.tf_mm, 0.4 * ha)
    tw = min(geom.tw_mm, 0.4 * ba)
    st = geom.section_type

    if st == "COL_RECT_CFST":
        # Ống thép tròn nhồi bê tông đặt giữa cột bọc bê tông (Concrete-Encased CFST)
        r_out = 0.5 * ha
        r_in = max(0.0, r_out - tf)
        r = math.hypot(yc, z)
        if r_in <= r <= r_out:
            return "steel_tube"
        return None

    # Kiểm tra chữ H đứng (trục khỏe chống uốn M_z)
    in_h_flange = (abs(z) <= 0.5 * ba) and ((0.5 * ha - tf) <= abs(yc) <= 0.5 * ha)
    in_h_web = (abs(z) <= 0.5 * tw) and (abs(yc) < (0.5 * ha - tf))
    if in_h_flange:
        return "steel_flange"
    if in_h_web:
        return "steel_web"

    if st == "COL_RECT_CROSS_H":
        # Thêm chữ H thứ hai xoay 90° tạo lõi thép chữ thập (Cruciform SRC Column)
        in_h2_flange = (abs(yc) <= 0.5 * ba) and ((0.5 * ha - tf) <= abs(z) <= 0.5 * ha)
        in_h2_web = (abs(yc) <= 0.5 * tw) and (abs(z) < (0.5 * ha - tf))
        if in_h2_flange:
            return "steel_flange"
        if in_h2_web:
            return "steel_web"

    return None


def _classify_concrete_zone(y: float, z: float, geom: SectionGeometry) -> ConcreteZone:
    """
    Phân vùng giam giữ bê tông theo Chen & Lin (2006) & El-Tawil & Deierlein (1999):
      - UNCONFINED         : Nằm ngoài lồng cốt đai hoặc ở cánh bản sàn bê tông.
      - HIGHLY_CONFINED    : Kẹp trong khoang giữa hai cánh thép hình H / bên trong ống CFST.
      - PARTIALLY_CONFINED : Nằm bên trong lồng cốt đai nhưng ngoài khoang thép hình.
    """
    st = geom.section_type
    c = geom.cover_mm + 0.5 * geom.stirrup_dia_mm
    yc = y - geom.core_offset_y_mm

    if st == "COL_RECT_CFST":
        r_in = max(0.0, 0.5 * geom.ha_mm - geom.tf_mm)
        if math.hypot(yc, z) < r_in:
            return ConcreteZone.HIGHLY_CONFINED

    if st == "COL_CIRC_H":
        r_core = 0.5 * geom.b_mm - c
        if math.hypot(y, z) > r_core:
            return ConcreteZone.UNCONFINED
        if abs(yc) <= 0.5 * geom.ha_mm and abs(z) <= 0.5 * geom.ba_mm:
            return ConcreteZone.HIGHLY_CONFINED
        return ConcreteZone.PARTIALLY_CONFINED

    # Dầm chữ T: vùng cánh bản sàn nhô ra ngoài sườn là bê tông không giam giữ
    if st == "SRC_T_SLAB_H" and abs(z) > 0.5 * geom.b_mm:
        return ConcreteZone.UNCONFINED

    # Kiểm tra nằm trong lồng cốt đai
    in_stirrup = (abs(y) <= 0.5 * geom.h_mm - c) and (abs(z) <= 0.5 * geom.b_mm - c)
    if not in_stirrup:
        return ConcreteZone.UNCONFINED

    # Kiểm tra nằm trong khoang vòm giữa hai cánh thép hình H / chữ thập
    in_h_cavity = (abs(yc) <= 0.5 * geom.ha_mm) and (abs(z) <= 0.5 * geom.ba_mm)
    if st == "COL_RECT_CROSS_H":
        in_h_cavity = in_h_cavity or ((abs(z) <= 0.5 * geom.ha_mm) and (abs(yc) <= 0.5 * geom.ba_mm))
    if in_h_cavity:
        return ConcreteZone.HIGHLY_CONFINED

    return ConcreteZone.PARTIALLY_CONFINED


def _build_rebar_layout(geom: SectionGeometry) -> List[Tuple[float, float, float]]:
    """Sinh tọa độ (y_mm, z_mm, dia_mm) của toàn bộ các thanh cốt thép dọc."""
    rebars: List[Tuple[float, float, float]] = []
    st = geom.section_type
    c_ctr_bot = geom.cover_mm + geom.stirrup_dia_mm + 0.5 * geom.rebar_dia_bot_mm
    c_ctr_top = geom.cover_mm + geom.stirrup_dia_mm + 0.5 * geom.rebar_dia_top_mm

    if st == "COL_CIRC_H":
        n_tot = max(6, geom.n_rebar_bot)
        r_bar = max(20.0, 0.5 * geom.b_mm - c_ctr_bot)
        for k in range(n_tot):
            ang = 2.0 * math.pi * k / n_tot + math.pi / n_tot
            rebars.append((r_bar * math.sin(ang), r_bar * math.cos(ang), geom.rebar_dia_bot_mm))
        return rebars

    if st.startswith("COL_"):
        # Bố trí đối xứng quanh chu vi cột chữ nhật / vuông
        y_top = 0.5 * geom.h_mm - c_ctr_bot
        y_bot = -0.5 * geom.h_mm + c_ctr_bot
        z_max = 0.5 * geom.b_mm - c_ctr_bot
        n_row = max(2, geom.n_rebar_bot // 2) if geom.n_rebar_bot >= 4 else 2
        if n_row > 4:
            n_row = max(2, int(round((geom.n_rebar_bot - 2 * geom.n_rebar_side_each) / 2.0)))
        # Hàng trên & hàng dưới
        for i in range(n_row):
            frac = i / max(1, n_row - 1)
            zi = -z_max + 2.0 * z_max * frac
            rebars.append((y_bot, zi, geom.rebar_dia_bot_mm))
            rebars.append((y_top, zi, geom.rebar_dia_bot_mm))
        # Các thanh trung gian hai cạnh bên
        n_side = max(0, geom.n_rebar_side_each)
        for j in range(1, n_side + 1):
            frac = j / (n_side + 1)
            yj = y_bot + (y_top - y_bot) * frac
            rebars.append((yj, -z_max, geom.rebar_dia_bot_mm))
            rebars.append((yj, z_max, geom.rebar_dia_bot_mm))
        return rebars

    # Dầm (SRC_RECT_H hoặc SRC_T_SLAB_H)
    z_max_bot = max(10.0, 0.5 * geom.b_mm - c_ctr_bot)
    y_bot = -0.5 * geom.h_mm + c_ctr_bot
    if geom.n_rebar_bot == 1:
        rebars.append((y_bot, 0.0, geom.rebar_dia_bot_mm))
    elif geom.n_rebar_bot > 1:
        for i in range(geom.n_rebar_bot):
            zi = -z_max_bot + 2.0 * z_max_bot * i / (geom.n_rebar_bot - 1)
            rebars.append((y_bot, zi, geom.rebar_dia_bot_mm))

    z_max_top = max(10.0, 0.5 * geom.b_mm - c_ctr_top)
    y_top = 0.5 * geom.h_mm - c_ctr_top
    if geom.n_rebar_top == 1:
        rebars.append((y_top, 0.0, geom.rebar_dia_top_mm))
    elif geom.n_rebar_top > 1:
        for i in range(geom.n_rebar_top):
            zi = -z_max_top + 2.0 * z_max_top * i / (geom.n_rebar_top - 1)
            rebars.append((y_top, zi, geom.rebar_dia_top_mm))

    return rebars


def build_2d_fiber_section(
    geom: SectionGeometry,
    mat: MaterialConfig,
) -> Tuple[List[FiberCell], SectionProperties, ConfinementParams]:
    """
    Khởi tạo lưới thớ 2D đầy đủ cho mặt cắt bê tông cốt cứng (SRC / CES) và tính
    chính xác các đặc trưng hình học (A_c, A_a, A_s, I_c, I_a, I_s, ρ_a, ρ_s, ρ_v).
    """
    fibers: List[FiberCell] = []
    st = geom.section_type
    ny = max(12, geom.ny_grid)
    nz = max(8, geom.nz_grid)

    # 1. Rời rạc hóa lõi thép hình bằng lưới mịn riêng (chính xác tuyệt đối diện tích A_a và I_a)
    yc_off = geom.core_offset_y_mm
    ha = geom.ha_mm
    ba = geom.ba_mm
    tf = min(geom.tf_mm, 0.4 * ha)
    tw = min(geom.tw_mm, 0.4 * ba)

    if st == "COL_RECT_CFST":
        n_seg = 48
        r_out = 0.5 * ha
        r_in = max(1.0, r_out - tf)
        r_mid = 0.5 * (r_out + r_in)
        a_seg = math.pi * (r_out ** 2 - r_in ** 2) / n_seg
        arc_len = 2.0 * math.pi * r_mid / n_seg
        for k in range(n_seg):
            ang = 2.0 * math.pi * (k + 0.5) / n_seg
            fibers.append(FiberCell(
                y_mm=yc_off + r_mid * math.sin(ang),
                z_mm=r_mid * math.cos(ang),
                dy_mm=tf, dz_mm=arc_len, area_mm2=a_seg,
                kind="steel_tube", zone=ConcreteZone.HIGHLY_CONFINED,
                fy_mpa=mat.fy_steel_mpa, es_mpa=mat.es_steel_mpa,
            ))
    else:
        # Cánh trên & cánh dưới thép H đứng (mỗi cánh chia 2 lớp dày x 8 đoạn rộng)
        nz_f = 8
        ny_f = 2
        dz_f = ba / nz_f
        dy_f = tf / ny_f
        for sign_y in (-1.0, 1.0):
            y_base = yc_off + sign_y * (0.5 * ha - tf) if sign_y > 0 else yc_off - 0.5 * ha
            for iy in range(ny_f):
                yk = y_base + (iy + 0.5) * dy_f
                for iz in range(nz_f):
                    zk = -0.5 * ba + (iz + 0.5) * dz_f
                    fibers.append(FiberCell(
                        y_mm=yk, z_mm=zk, dy_mm=dy_f, dz_mm=dz_f, area_mm2=dy_f * dz_f,
                        kind="steel_flange", zone=ConcreteZone.HIGHLY_CONFINED,
                        fy_mpa=mat.fy_steel_mpa, es_mpa=mat.es_steel_mpa,
                    ))
        # Bản bụng thép H đứng (chia 12 đoạn cao x 2 lớp dày)
        hw = max(0.0, ha - 2.0 * tf)
        if hw > 0.5:
            ny_w = 12
            dy_w = hw / ny_w
            for iy in range(ny_w):
                yk = yc_off - 0.5 * hw + (iy + 0.5) * dy_w
                fibers.append(FiberCell(
                    y_mm=yk, z_mm=0.0, dy_mm=dy_w, dz_mm=tw, area_mm2=dy_w * tw,
                    kind="steel_web", zone=ConcreteZone.HIGHLY_CONFINED,
                    fy_mpa=mat.fy_steel_mpa, es_mpa=mat.es_steel_mpa,
                ))

        # Nếu là cột lõi chữ thập (Cross-H): thêm 2 cánh đứng và 2 đoạn bụng ngang (tránh trùng tâm)
        if st == "COL_RECT_CROSS_H":
            for sign_z in (-1.0, 1.0):
                z_base = sign_z * (0.5 * ha - tf) if sign_z > 0 else -0.5 * ha
                for iz in range(ny_f):
                    zk = z_base + (iz + 0.5) * dy_f
                    for iy in range(nz_f):
                        yk = yc_off - 0.5 * ba + (iy + 0.5) * dz_f
                        fibers.append(FiberCell(
                            y_mm=yk, z_mm=zk, dy_mm=dz_f, dz_mm=dy_f, area_mm2=dy_f * dz_f,
                            kind="steel_flange", zone=ConcreteZone.HIGHLY_CONFINED,
                            fy_mpa=mat.fy_steel_mpa, es_mpa=mat.es_steel_mpa,
                        ))
            half_arm = max(0.0, 0.5 * ha - tf - 0.5 * tw)
            if half_arm > 0.5:
                n_arm = 5
                dz_a = half_arm / n_arm
                for sign_z in (-1.0, 1.0):
                    for ia in range(n_arm):
                        zk = sign_z * (0.5 * tw + (ia + 0.5) * dz_a)
                        fibers.append(FiberCell(
                            y_mm=yc_off, z_mm=zk, dy_mm=tw, dz_mm=dz_a, area_mm2=tw * dz_a,
                            kind="steel_web", zone=ConcreteZone.HIGHLY_CONFINED,
                            fy_mpa=mat.fy_steel_mpa, es_mpa=mat.es_steel_mpa,
                        ))

    # 2. Cốt thép dọc (Rebars)
    rebar_coords = _build_rebar_layout(geom)
    for y_r, z_r, dia in rebar_coords:
        a_bar = 0.25 * math.pi * dia * dia
        fibers.append(FiberCell(
            y_mm=y_r, z_mm=z_r, dy_mm=dia, dz_mm=dia, area_mm2=a_bar,
            kind="rebar", zone=ConcreteZone.PARTIALLY_CONFINED,
            fy_mpa=mat.fy_rebar_mpa, es_mpa=mat.es_rebar_mpa,
        ))

    # 3. Lưới thớ bê tông 2D (loại trừ chính xác các ô rơi vào lõi thép hình)
    if st == "COL_CIRC_H":
        r_ext = 0.5 * geom.b_mm
        dy = geom.b_mm / ny
        dz = geom.b_mm / ny
        for iy in range(ny):
            yk = -r_ext + (iy + 0.5) * dy
            for iz in range(ny):
                zk = -r_ext + (iz + 0.5) * dz
                if math.hypot(yk, zk) > r_ext:
                    continue
                if _point_in_steel_core(yk, zk, geom) is not None:
                    continue
                z_type = _classify_concrete_zone(yk, zk, geom)
                fibers.append(FiberCell(yk, zk, dy, dz, dy * dz, "concrete", z_type))
    elif st == "SRC_T_SLAB_H":
        # Sườn dầm phía dưới bản sàn: y ∈ [-h/2, +h/2 - hf], z ∈ [-b/2, +b/2]
        h_web = max(50.0, geom.h_mm - geom.hf_slab_mm)
        ny_web = max(12, int(round(ny * h_web / geom.h_mm)))
        ny_slab = max(4, ny - ny_web)
        dy_w = h_web / ny_web
        dz_w = geom.b_mm / nz
        for iy in range(ny_web):
            yk = -0.5 * geom.h_mm + (iy + 0.5) * dy_w
            for iz in range(nz):
                zk = -0.5 * geom.b_mm + (iz + 0.5) * dz_w
                if _point_in_steel_core(yk, zk, geom) is not None:
                    continue
                fibers.append(FiberCell(yk, zk, dy_w, dz_w, dy_w * dz_w, "concrete", _classify_concrete_zone(yk, zk, geom)))
        # Bản sàn bê tông phía trên: y ∈ [h/2 - hf, h/2], z ∈ [-bf_slab/2, +bf_slab/2]
        dy_s = geom.hf_slab_mm / ny_slab
        nz_s = max(nz, 24)
        dz_s = geom.bf_slab_mm / nz_s
        for iy in range(ny_slab):
            yk = 0.5 * geom.h_mm - geom.hf_slab_mm + (iy + 0.5) * dy_s
            for iz in range(nz_s):
                zk = -0.5 * geom.bf_slab_mm + (iz + 0.5) * dz_s
                if _point_in_steel_core(yk, zk, geom) is not None:
                    continue
                fibers.append(FiberCell(yk, zk, dy_s, dz_s, dy_s * dz_s, "concrete", _classify_concrete_zone(yk, zk, geom)))
    else:
        # Tiết diện chữ nhật / vuông (SRC_RECT_H, COL_RECT_H, COL_RECT_CROSS_H, COL_RECT_CFST)
        dy = geom.h_mm / ny
        dz = geom.b_mm / nz
        for iy in range(ny):
            yk = -0.5 * geom.h_mm + (iy + 0.5) * dy
            for iz in range(nz):
                zk = -0.5 * geom.b_mm + (iz + 0.5) * dz
                if _point_in_steel_core(yk, zk, geom) is not None:
                    continue
                fibers.append(FiberCell(yk, zk, dy, dz, dy * dz, "concrete", _classify_concrete_zone(yk, zk, geom)))

    # 4. Hiệu chỉnh trừ diện tích cốt thép chiếm chỗ khỏi các ô bê tông gần nhất (đảm bảo A_c + A_a + A_s = A_g)
    aa_mm2 = sum(f.area_mm2 for f in fibers if f.kind.startswith("steel"))
    as_mm2 = sum(f.area_mm2 for f in fibers if f.kind == "rebar")
    ac_raw = sum(f.area_mm2 for f in fibers if f.kind == "concrete")

    if st == "COL_CIRC_H":
        ag_mm2 = 0.25 * math.pi * geom.b_mm ** 2
    elif st == "SRC_T_SLAB_H":
        ag_mm2 = geom.b_mm * (geom.h_mm - geom.hf_slab_mm) + geom.bf_slab_mm * geom.hf_slab_mm
    else:
        ag_mm2 = geom.b_mm * geom.h_mm

    target_ac = max(1.0, ag_mm2 - aa_mm2 - as_mm2)
    scale_c = target_ac / max(1.0, ac_raw)
    if abs(scale_c - 1.0) > 1e-4:
        fibers = [
            FiberCell(f.y_mm, f.z_mm, f.dy_mm, f.dz_mm, f.area_mm2 * scale_c, f.kind, f.zone, f.fy_mpa, f.es_mpa)
            if f.kind == "concrete" else f
            for f in fibers
        ]

    # Tính đặc trưng hình học chính xác
    ac_mm2 = sum(f.area_mm2 for f in fibers if f.kind == "concrete")
    ac_unc = sum(f.area_mm2 for f in fibers if f.kind == "concrete" and f.zone == ConcreteZone.UNCONFINED)
    ac_par = sum(f.area_mm2 for f in fibers if f.kind == "concrete" and f.zone == ConcreteZone.PARTIALLY_CONFINED)
    ac_hig = sum(f.area_mm2 for f in fibers if f.kind == "concrete" and f.zone == ConcreteZone.HIGHLY_CONFINED)

    # Trọng tâm mặt cắt quy đổi (so với y = 0)
    num_yc = sum(f.y_mm * f.area_mm2 for f in fibers)
    y_cent = num_yc / max(1.0, ag_mm2)

    ic_z = sum(f.area_mm2 * ((f.y_mm - y_cent) ** 2 + (f.dy_mm ** 2) / 12.0) for f in fibers if f.kind == "concrete")
    ia_z = sum(f.area_mm2 * ((f.y_mm - y_cent) ** 2 + (f.dy_mm ** 2) / 12.0) for f in fibers if f.kind.startswith("steel"))
    is_z = sum(f.area_mm2 * ((f.y_mm - y_cent) ** 2) for f in fibers if f.kind == "rebar")

    ic_y = sum(f.area_mm2 * (f.z_mm ** 2 + (f.dz_mm ** 2) / 12.0) for f in fibers if f.kind == "concrete")
    ia_y = sum(f.area_mm2 * (f.z_mm ** 2 + (f.dz_mm ** 2) / 12.0) for f in fibers if f.kind.startswith("steel"))
    is_y = sum(f.area_mm2 * (f.z_mm ** 2) for f in fibers if f.kind == "rebar")

    as_bot = sum(0.25 * math.pi * d * d for (yr, _, d) in rebar_coords if yr < 0.0)
    as_top = sum(0.25 * math.pi * d * d for (yr, _, d) in rebar_coords if yr >= 0.0)

    # Hàm lượng thể tích cốt đai ρ_v tính trực tiếp từ kích thước lõi cốt đai
    a_sv1 = 0.25 * math.pi * geom.stirrup_dia_mm ** 2
    if st == "COL_CIRC_H":
        d_core = max(60.0, geom.b_mm - 2.0 * geom.cover_mm - geom.stirrup_dia_mm)
        rho_v = 4.0 * a_sv1 / (d_core * max(30.0, geom.stirrup_spacing_mm))
    else:
        b_core = max(60.0, geom.b_mm - 2.0 * geom.cover_mm - geom.stirrup_dia_mm)
        h_core = max(60.0, geom.h_mm - 2.0 * geom.cover_mm - geom.stirrup_dia_mm)
        l_hoop = 2.0 * (b_core + h_core) + max(0, geom.n_stirrup_legs - 2) * h_core
        rho_v = (a_sv1 * l_hoop) / (b_core * h_core * max(30.0, geom.stirrup_spacing_mm))

    # Cập nhật rho_v thực vào bản sao tạm MaterialConfig khi tính confinement
    mat_eff = MaterialConfig(**{**mat.__dict__, "rho_v_stirrup": rho_v})
    steel_ratio = aa_mm2 / max(1.0, ag_mm2)
    conf = compute_confinement_params(mat_eff, steel_ratio=steel_ratio)

    props = SectionProperties(
        ag_mm2=ag_mm2, ac_mm2=ac_mm2, aa_mm2=aa_mm2, as_mm2=as_mm2,
        as_bot_mm2=as_bot, as_top_mm2=as_top,
        ac_unconfined_mm2=ac_unc, ac_part_conf_mm2=ac_par, ac_high_conf_mm2=ac_hig,
        ic_z_mm4=ic_z, ia_z_mm4=ia_z, is_z_mm4=is_z,
        ic_y_mm4=ic_y, ia_y_mm4=ia_y, is_y_mm4=is_y,
        steel_ratio=steel_ratio, rebar_ratio=as_mm2 / max(1.0, ag_mm2),
        vol_stirrup_ratio=rho_v, y_centroid_mm=y_cent,
        rebar_coords=rebar_coords,
    )
    return fibers, props, conf


_FIBER_CACHE: Dict[int, Dict[str, np.ndarray]] = {}


def _get_fiber_arrays(fibers: List[FiberCell]) -> Dict[str, np.ndarray]:
    """Chuyển danh sách FiberCell sang mảng NumPy vector hóa (cache theo id để tăng tốc ~40x)."""
    key = id(fibers)
    cached = _FIBER_CACHE.get(key)
    if cached is not None and cached["y"].shape[0] == len(fibers):
        return cached
    y = np.array([f.y_mm for f in fibers], dtype=float)
    z = np.array([f.z_mm for f in fibers], dtype=float)
    a = np.array([f.area_mm2 for f in fibers], dtype=float)
    is_conc = np.array([f.kind == "concrete" for f in fibers], dtype=bool)
    is_steel = np.array([f.kind.startswith("steel") for f in fibers], dtype=bool)
    is_rebar = np.array([f.kind == "rebar" for f in fibers], dtype=bool)
    zone_code = np.array(
        [0 if f.zone == ConcreteZone.UNCONFINED else (1 if f.zone == ConcreteZone.PARTIALLY_CONFINED else 2) for f in fibers],
        dtype=np.int8,
    )
    fy = np.array([f.fy_mpa for f in fibers], dtype=float)
    es = np.array([f.es_mpa for f in fibers], dtype=float)
    arrs = {
        "y": y, "z": z, "a": a,
        "is_conc": is_conc, "is_steel": is_steel, "is_rebar": is_rebar,
        "zone_code": zone_code, "fy": fy, "es": es,
    }
    if len(_FIBER_CACHE) > 64:
        _FIBER_CACHE.clear()
    _FIBER_CACHE[key] = arrs
    return arrs


def evaluate_section_2d(
    eps0: float,
    kappa_z: float,
    kappa_y: float,
    fibers: List[FiberCell],
    geom: SectionGeometry,
    mat: MaterialConfig,
    conf: ConfinementParams,
    nonlinear: bool = True,
) -> SectionResponse:
    """
    Tích phân ứng suất và độ cứng tiếp tuyến trên toàn bộ lưới thớ 2D (Vector hóa NumPy)
    tại trạng thái biến dạng tổng quát (ε₀, κ_z, κ_y):
        ε(y, z) = ε₀ − y · κ_z + z · κ_y
        N   =  ∑ σ_i · A_i
        M_z = −∑ σ_i · y_i · A_i     (dương khi mép trên chịu nén, mép dưới chịu kéo)
        M_y = +∑ σ_i · z_i · A_i
    """
    arr = _get_fiber_arrays(fibers)
    y = arr["y"]
    z = arr["z"]
    a = arr["a"]
    is_conc = arr["is_conc"]
    is_steel = arr["is_steel"]
    is_rebar = arr["is_rebar"]
    zone_code = arr["zone_code"]
    fy = arr["fy"]
    es = arr["es"]

    eps = eps0 - y * kappa_z + z * kappa_y
    sig = np.empty_like(eps)
    et = np.empty_like(eps)

    ec0_mod = max(5000.0, mat.ec_mpa)
    fct = max(0.1, mat.fct_mpa)
    eps_cr = fct / ec0_mod

    if not nonlinear:
        sig[is_conc] = ec0_mod * eps[is_conc]
        et[is_conc] = ec0_mod
        non_c = ~is_conc
        sig[non_c] = es[non_c] * eps[non_c]
        et[non_c] = es[non_c]
        ac_cracked = 0.0
        steel_yielded = False
        rebar_yielded = False
        concrete_crushed = False
    else:
        # 1. Bê tông 3 vùng giam giữ (vector hóa toàn bộ lưới)
        eps_c = eps[is_conc]
        zc = zone_code[is_conc]
        sig_c = np.empty_like(eps_c)
        et_c = np.empty_like(eps_c)

        # Tham số theo từng vùng giam giữ (0=unconfined, 1=partially, 2=highly)
        # Xét hệ số cấu kiện thực 0.85 * η_HSC (EN 1994-1-1 & Lai-Liew 2019)
        fc_insitu = 0.85 * conf.eta_hsc * mat.fc_mpa
        f_peak_tbl = np.array([fc_insitu, fc_insitu * conf.kp, fc_insitu * conf.kh])
        e0_tbl = np.array([max(1e-4, conf.eps_c0_u), max(1e-4, conf.eps_c0_p), max(1e-4, conf.eps_c0_h)])
        eu_tbl = np.array([
            max(e0_tbl[0] + 4e-4, conf.eps_cu_u),
            max(e0_tbl[1] + 4e-4, conf.eps_cu_p),
            max(e0_tbl[2] + 4e-4, conf.eps_cu_h),
        ])
        drop_tbl = np.array([0.20 if mat.fc_mpa <= 50.0 else 0.45, 0.25, 0.15])
        res_tbl = np.array([0.15, 0.35, 0.55])

        fp = f_peak_tbl[zc]
        e0 = e0_tbl[zc]
        eu = eu_tbl[zc]
        dr = drop_tbl[zc]
        rs = res_tbl[zc]

        m_comp = eps_c <= 0.0
        ec_pos = -eps_c
        m_asc = m_comp & (ec_pos <= e0)
        m_desc = m_comp & (ec_pos > e0) & (ec_pos <= eu)
        m_crush = m_comp & (ec_pos > eu)
        m_t_el = (~m_comp) & (eps_c <= eps_cr)
        m_t_cr = (~m_comp) & (eps_c > eps_cr)

        if np.any(m_asc):
            r = ec_pos[m_asc] / e0[m_asc]
            sig_c[m_asc] = -fp[m_asc] * (2.0 * r - r * r)
            et_c[m_asc] = np.maximum((2.0 * fp[m_asc] / e0[m_asc]) * (1.0 - r), 0.008 * ec0_mod)
        if np.any(m_desc):
            frac = (ec_pos[m_desc] - e0[m_desc]) / (eu[m_desc] - e0[m_desc])
            sig_c[m_desc] = -fp[m_desc] * (1.0 - dr[m_desc] * frac)
            et_c[m_desc] = 0.004 * ec0_mod
        if np.any(m_crush):
            sig_c[m_crush] = -rs[m_crush] * fp[m_crush]
            et_c[m_crush] = 0.002 * ec0_mod
        if np.any(m_t_el):
            sig_c[m_t_el] = ec0_mod * eps_c[m_t_el]
            et_c[m_t_el] = ec0_mod
        if np.any(m_t_cr):
            rat = np.minimum(40.0, (eps_c[m_t_cr] - eps_cr) / max(1e-8, eps_cr))
            s_cr = fct * np.exp(-0.35 * rat)
            sig_c[m_t_cr] = s_cr
            et_c[m_t_cr] = -0.35 * s_cr / max(1e-8, eps_cr)

        sig[is_conc] = sig_c
        et[is_conc] = et_c
        ac_cracked = float(np.sum(a[is_conc][m_t_cr]))
        concrete_crushed = bool(np.any(m_crush & (zc == 0)))

        # 2. Thép hình & Cốt thép dọc (đàn-dẻo song tuyến tính có tái bền)
        for mask_s, b_h in ((is_steel, mat.hardening_steel), (is_rebar, mat.hardening_rebar)):
            if not np.any(mask_s):
                continue
            es_m = np.maximum(10000.0, es[mask_s])
            fy_m = fy[mask_s]
            ep_m = eps[mask_s]
            ey_m = fy_m / es_m
            et_h = max(1e-4, b_h) * es_m
            m_el = np.abs(ep_m) <= ey_m
            s_out = np.where(m_el, es_m * ep_m, np.sign(ep_m) * (fy_m + et_h * (np.abs(ep_m) - ey_m)))
            e_out = np.where(m_el, es_m, et_h)
            sig[mask_s] = s_out
            et[mask_s] = e_out

        steel_yielded = bool(np.any(np.abs(eps[is_steel]) > (fy[is_steel] / np.maximum(10000.0, es[is_steel])))) if np.any(is_steel) else False
        rebar_yielded = bool(np.any(np.abs(eps[is_rebar]) > (fy[is_rebar] / np.maximum(10000.0, es[is_rebar])))) if np.any(is_rebar) else False

    sa = sig * a
    ea = et * a
    n_n = float(np.sum(sa))
    mz = float(-np.sum(sa * y))
    my = float(np.sum(sa * z))
    d00 = float(np.sum(ea))
    d01 = float(-np.sum(ea * y))
    d02 = float(np.sum(ea * z))
    d11 = float(np.sum(ea * y * y))
    d12 = float(-np.sum(ea * y * z))
    d22 = float(np.sum(ea * z * z))

    eps_c_arr = eps[is_conc]
    sig_c_arr = sig[is_conc]
    ac_total = float(np.sum(a[is_conc])) if np.any(is_conc) else 1.0
    eps_c_min = float(np.min(eps_c_arr)) if eps_c_arr.size else 0.0
    eps_c_max = float(np.max(eps_c_arr)) if eps_c_arr.size else 0.0
    sig_c_min = float(np.min(sig_c_arr)) if sig_c_arr.size else 0.0
    sig_steel_max = float(np.max(np.abs(sig[is_steel]))) if np.any(is_steel) else 0.0
    sig_rebar_max = float(np.max(np.abs(sig[is_rebar]))) if np.any(is_rebar) else 0.0

    # Đảm bảo tính xác định dương của ma trận [D_t] 3x3
    ea_min = 0.004 * mat.ec_mpa * geom.b_mm * geom.h_mm
    ei_min = 0.004 * mat.ec_mpa * geom.b_mm * (geom.h_mm ** 3) / 12.0
    if d00 < ea_min:
        d00 = ea_min
    ei_z_eff = d11 - (d01 * d01) / d00
    if ei_z_eff < ei_min:
        d11 = (d01 * d01) / d00 + ei_min
        ei_z_eff = ei_min
    ei_y_eff = d22 - (d02 * d02) / d00
    ei_y_min = 0.004 * mat.ec_mpa * geom.h_mm * (geom.b_mm ** 3) / 12.0
    if ei_y_eff < ei_y_min:
        d22 = (d02 * d02) / d00 + ei_y_min
        ei_y_eff = ei_y_min

    dt = np.array([
        [d00, d01, d02],
        [d01, d11, d12],
        [d02, d12, d22],
    ], dtype=float)

    if abs(kappa_z) > 1e-11:
        y_na = eps0 / kappa_z
        x_na = max(0.0, min(geom.h_mm, 0.5 * geom.h_mm - y_na))
    else:
        x_na = geom.h_mm if eps0 < 0.0 else 0.0

    return SectionResponse(
        eps0=eps0, kappa_z=kappa_z, kappa_y=kappa_y,
        n_n=n_n, mz_nmm=mz, my_nmm=my, dt_mat=dt,
        ea_t=d00, ei_z_eff=ei_z_eff, ei_y_eff=ei_y_eff,
        x_na_mm=x_na, eps_c_min=eps_c_min, eps_c_max=eps_c_max,
        sig_c_min_mpa=sig_c_min, sig_steel_max_mpa=sig_steel_max,
        sig_rebar_max_mpa=sig_rebar_max,
        cracked_ratio=ac_cracked / max(1.0, ac_total),
        steel_yielded=steel_yielded, rebar_yielded=rebar_yielded,
        concrete_crushed=concrete_crushed,
    )


def solve_eps0_for_axial_force(
    target_n_n: float,
    kappa_z: float,
    kappa_y: float,
    fibers: List[FiberCell],
    geom: SectionGeometry,
    mat: MaterialConfig,
    conf: ConfinementParams,
    eps0_init: float = 0.0,
) -> SectionResponse:
    """
    Tìm biến dạng trục ε₀ sao cho cân bằng lực dọc N(ε₀, κ_z, κ_y) = target_n_n
    bằng phương pháp Newton-Raphson kết hợp kẹp nghiệm chia đôi (safeguarded NR).
    """
    eps0 = eps0_init
    for _ in range(30):
        resp = evaluate_section_2d(eps0, kappa_z, kappa_y, fibers, geom, mat, conf, nonlinear=True)
        err = resp.n_n - target_n_n
        if abs(err) <= max(10.0, 1e-6 * max(1e5, abs(target_n_n))):
            return resp
        step = -err / max(1e3, resp.ea_t)
        step = max(-0.005, min(0.005, step))
        eps0 += step

    # Dự phòng chia đôi chắc chắn hội tụ nếu vùng nhảy mềm hóa mạnh
    lo, hi = -0.025, 0.045
    for _ in range(45):
        mid = 0.5 * (lo + hi)
        resp = evaluate_section_2d(mid, kappa_z, kappa_y, fibers, geom, mat, conf, nonlinear=True)
        if resp.n_n < target_n_n:
            lo = mid
        else:
            hi = mid
    return evaluate_section_2d(0.5 * (lo + hi), kappa_z, kappa_y, fibers, geom, mat, conf, nonlinear=True)


def compute_moment_curvature(
    geom: SectionGeometry,
    mat: MaterialConfig,
    axial_n_kn: float = 0.0,
    n_points: int = 45,
    max_kappa_1_per_m: float | None = None,
) -> Dict[str, object]:
    """
    Xây dựng đường cong Mô-men – Độ cong (M – κ) phi tuyến cho tiết diện chịu lực dọc N cố định.
    (Quy ước đầu vào axial_n_kn > 0 là lực NÉN cột, nên target_n_n = -axial_n_kn * 1000).
    """
    fibers, props, conf = build_2d_fiber_section(geom, mat)
    target_n_n = -axial_n_kn * 1000.0
    if max_kappa_1_per_m is None:
        # Độ cong cực đại tương ứng ~ 10 * ε_cu / h (đủ bắt toàn bộ giai đoạn dẻo & đỉnh)
        max_kappa_1_per_mm = max(0.015 / geom.h_mm, 5.0 * conf.eps_cu_u / geom.h_mm)
    else:
        max_kappa_1_per_mm = max_kappa_1_per_m / 1000.0

    kappas_1_m: List[float] = []
    moments_knm: List[float] = []
    ei_ratios: List[float] = []
    x_na_list: List[float] = []
    stage_cracking = None
    stage_rebar_yield = None
    stage_steel_yield = None
    stage_ultimate = None

    resp0 = solve_eps0_for_axial_force(target_n_n, 1e-9, 0.0, fibers, geom, mat, conf, 0.0)
    ei_init = max(1.0, resp0.ei_z_eff)
    eps0_prev = resp0.eps0
    m_max = -1e18

    for i in range(n_points + 1):
        # Bước mật độ mịn gần gốc để bắt chính xác điểm nứt & điểm chảy dẻo
        t = i / n_points
        kz = max_kappa_1_per_mm * (0.25 * t + 0.75 * t * t)
        resp = solve_eps0_for_axial_force(target_n_n, kz, 0.0, fibers, geom, mat, conf, eps0_prev)
        eps0_prev = resp.eps0
        m_knm = resp.mz_nmm / 1e6
        k_1m = kz * 1000.0

        kappas_1_m.append(k_1m)
        moments_knm.append(m_knm)
        ei_ratios.append(min(1.0, resp.ei_z_eff / ei_init))
        x_na_list.append(resp.x_na_mm)

        if stage_cracking is None and resp.cracked_ratio > 0.02:
            stage_cracking = {"kappa_1m": k_1m, "moment_knm": m_knm, "x_na_mm": resp.x_na_mm}
        if stage_rebar_yield is None and resp.rebar_yielded:
            stage_rebar_yield = {"kappa_1m": k_1m, "moment_knm": m_knm, "x_na_mm": resp.x_na_mm}
        if stage_steel_yield is None and resp.steel_yielded:
            stage_steel_yield = {"kappa_1m": k_1m, "moment_knm": m_knm, "x_na_mm": resp.x_na_mm}
        if m_knm > m_max:
            m_max = m_knm
            stage_ultimate = {
                "kappa_1m": k_1m, "moment_knm": m_knm, "x_na_mm": resp.x_na_mm,
                "eps_c_min": resp.eps_c_min, "sig_steel_max_mpa": resp.sig_steel_max_mpa,
            }

    return {
        "kappa_1_per_m": kappas_1_m,
        "moment_knm": moments_knm,
        "ei_ratio": ei_ratios,
        "x_na_mm": x_na_list,
        "m_max_knm": m_max,
        "ei_initial_knm2": ei_init / 1e9,
        "stages": {
            "cracking": stage_cracking,
            "rebar_yield": stage_rebar_yield,
            "steel_yield": stage_steel_yield,
            "ultimate": stage_ultimate,
        },
    }


def compute_nm_interaction_fiber(
    geom: SectionGeometry,
    mat: MaterialConfig,
    axis: str = "z",
    n_points: int = 44,
    apply_design_factors: bool = False,
) -> Dict[str, object]:
    """
    Xây dựng đường cong tương tác N – M của mặt cắt bằng Phương pháp Tương thích
    Biến dạng Thớ 2D (Strain Compatibility Method — Huang & Liew 2018; AISC 360-22 §I5;
    EN 1994-1-1 §6.7.3).

    Nguyên lý:
      Quét chiều sâu trục trung hòa c từ ∞ (nén đúng tâm thuần túy, ε_top = ε_bot = -ε_cu)
      qua các trạng thái nén lệch tâm nhỏ -> cân bằng -> uốn thuần túy -> kéo đúng tâm,
      giữ biến dạng nén mép ngoài cùng tại -ε_cu (hoặc -ε_c0 ở nén đúng tâm).
      Trả về tập điểm (N_c_kN >= 0 là nén, M_kNm >= 0).
    """
    fibers, props, conf = build_2d_fiber_section(geom, mat)

    # Nếu tính sức kháng thiết kế (EC4), chia cường độ vật liệu cho hệ số an toàn γ_c, γ_a, γ_s
    if apply_design_factors:
        mat_eval = MaterialConfig(
            **{
                **mat.__dict__,
                "fc_mpa": 0.85 * mat.fc_mpa / mat.gamma_c,
                "fy_steel_mpa": mat.fy_steel_mpa / mat.gamma_a,
                "fy_rebar_mpa": mat.fy_rebar_mpa / mat.gamma_s,
            }
        )
        fibers_eval = [
            FiberCell(
                f.y_mm, f.z_mm, f.dy_mm, f.dz_mm, f.area_mm2, f.kind, f.zone,
                fy_mpa=(mat_eval.fy_steel_mpa if f.kind.startswith("steel") else mat_eval.fy_rebar_mpa),
                es_mpa=f.es_mpa,
            ) if f.kind != "concrete" else f
            for f in fibers
        ]
    else:
        mat_eval = mat
        fibers_eval = fibers

    dim = geom.h_mm if axis == "z" else geom.b_mm
    eps_cu = conf.eps_cu_u

    pts_n_kn: List[float] = []
    pts_m_knm: List[float] = []
    pts_c_mm: List[float] = []

    # 1. Điểm nén đúng tâm thuần túy (ε = -ε_c0 đồng đều; xét thêm điểm cực đại lực nén)
    best_n_pure = -1e18
    for eps_u in np.linspace(-conf.eps_c0_u * 0.85, -conf.eps_cu_u * 1.15, 18):
        r = evaluate_section_2d(float(eps_u), 0.0, 0.0, fibers_eval, geom, mat_eval, conf, nonlinear=True)
        if -r.n_n > best_n_pure:
            best_n_pure = -r.n_n
    pts_n_kn.append(best_n_pure / 1000.0)
    pts_m_knm.append(0.0)
    pts_c_mm.append(9999.0)

    # 2. Quét chiều sâu trục trung hòa c từ 2.4*dim giảm dần về 0.05*dim
    c_ratios = np.concatenate([
        np.linspace(2.4, 1.05, n_points // 4),
        np.linspace(1.0, 0.35, n_points // 2),
        np.linspace(0.33, 0.04, n_points // 4),
    ])
    for cr in c_ratios:
        c = float(cr) * dim
        # Mép chịu nén (+dim/2) đạt -eps_cu, trục trung hòa cách mép nén c -> y_na = dim/2 - c
        kappa = eps_cu / max(1.0, c)
        eps0 = kappa * (0.5 * dim - c)
        if axis == "z":
            r = evaluate_section_2d(eps0, kappa, 0.0, fibers_eval, geom, mat_eval, conf, nonlinear=True)
            m_val = abs(r.mz_nmm) / 1e6
        else:
            r = evaluate_section_2d(eps0, 0.0, -kappa, fibers_eval, geom, mat_eval, conf, nonlinear=True)
            m_val = abs(r.my_nmm) / 1e6
        pts_n_kn.append(-r.n_n / 1000.0)
        pts_m_knm.append(m_val)
        pts_c_mm.append(c)

    # 3. Điểm kéo đúng tâm thuần túy (bê tông nứt hoàn toàn, chỉ còn thép hình + cốt thép)
    r_tens = evaluate_section_2d(0.015, 0.0, 0.0, fibers_eval, geom, mat_eval, conf, nonlinear=True)
    pts_n_kn.append(-r_tens.n_n / 1000.0)
    pts_m_knm.append(0.0)
    pts_c_mm.append(0.0)

    # Tìm mô-men uốn thuần túy (N ≈ 0) bằng nội suy tuyến tính trên đường bao
    m_pure_knm = 0.0
    for i in range(len(pts_n_kn) - 1):
        n1, n2 = pts_n_kn[i], pts_n_kn[i + 1]
        if (n1 >= 0.0 >= n2) or (n1 <= 0.0 <= n2):
            if abs(n1 - n2) > 1e-9:
                w = n1 / (n1 - n2)
                m_pure_knm = pts_m_knm[i] + w * (pts_m_knm[i + 1] - pts_m_knm[i])
                break

    idx_mmax = int(np.argmax(pts_m_knm))
    return {
        "axis": axis,
        "n_kn": pts_n_kn,
        "m_knm": pts_m_knm,
        "c_na_mm": pts_c_mm,
        "n_max_kn": pts_n_kn[0],
        "n_min_kn": pts_n_kn[-1],
        "m_pure_knm": m_pure_knm,
        "m_max_knm": pts_m_knm[idx_mmax],
        "n_at_m_max_kn": pts_n_kn[idx_mmax],
    }
