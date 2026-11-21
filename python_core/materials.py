# -*- coding: utf-8 -*-
"""
================================================================================
MÔ-ĐUN 1: MÔ HÌNH VẬT LIỆU PHI TUYẾN & HIỆU ỨNG GIAM GIỮ 3 VÙNG (SRC / CES)
================================================================================
Chức năng khối:
  - Cung cấp thư viện tiêu chuẩn mác bê tông (TCVN 5574:2018 / EN 1992-1-1 / VHSC),
    thép hình kết cấu (EN 10025 / TCVN 5575:2024 / AISC / GB), cốt thép thanh
    và bảng tra tiết diện thép hình chữ H/I phổ biến.
  - Mô phỏng quan hệ ứng suất – biến dạng phi tuyến σ(ε) và mô-đun tiếp tuyến
    nhất quán E_t(ε) = dσ/dε cho:
      1) Bê tông KHÔNG giam giữ (lớp bảo vệ ngoài cốt đai — Unconfined Concrete):
         Hognestad / EC2 nén parabol + nhánh suy giảm sau đỉnh + mềm hóa kéo
         (Tension Stiffening) hàm mũ mượt.
      2) Bê tông GIAM GIỮ MỘT PHẦN (lõi bên trong cốt đai — Partially Confined):
         Mander et al. (1988) / El-Tawil & Deierlein (1999) với hệ số tăng cường K_p.
      3) Bê tông GIAM GIỮ MẠNH (kẹp giữa bản bụng và hai cánh thép chữ H hoặc trong
         ống thép CFST — Highly Confined): Chen & Lin (2006) với hệ số K_h và vùng
         dẻo sau đỉnh mở rộng.
      4) Hệ số suy giảm giòn cho bê tông cường độ cao / siêu cao (HSC / VHSC):
         Lai, Liew & Xiong (2019, Construction & Building Materials 228, Eq. 5–6)
         và EN 1992-1-1 §3.1.7.
      5) Thép hình cốt cứng & cốt thép thanh: Đàn – dẻo song tuyến tính có tái bền
         đẳng hướng (Bilinear Isotropic Hardening).

Quy ước dấu cơ học (xuyên suốt toàn bộ hệ thống):
  - Kéo dương (ε > 0, σ > 0), Nén âm (ε < 0, σ < 0).
  - Mô-đun tiếp tuyến E_t = dσ/dε (MPa = N/mm²).
================================================================================
"""

from __future__ import annotations
from dataclasses import dataclass
from enum import Enum
from typing import Dict, Tuple
import math


class ConcreteZone(str, Enum):
    """Phân vùng ứng xử giam giữ của thớ bê tông trong mặt cắt bê tông cốt cứng."""
    UNCONFINED = "unconfined"                  # Vùng 0: Lớp bê tông bảo vệ ngoài cốt đai
    PARTIALLY_CONFINED = "partially_confined"  # Vùng 1: Lõi bê tông trong lồng cốt đai
    HIGHLY_CONFINED = "highly_confined"        # Vùng 2: Lõi bê tông kẹp giữa cánh thép hình H / ống CFST


@dataclass(frozen=True)
class ConfinementParams:
    """Bộ tham số ứng xử phi tuyến của 3 vùng bê tông sau khi xét hiệu ứng giam giữ."""
    kp: float          # Hệ số tăng cường cường độ vùng giam giữ một phần (K_p >= 1.0)
    kh: float          # Hệ số tăng cường cường độ vùng giam giữ mạnh (K_h >= K_p)
    eps_c0_u: float    # Biến dạng đỉnh bê tông không giam giữ
    eps_cu_u: float    # Biến dạng phá hoại nén bê tông không giam giữ
    eps_c0_p: float    # Biến dạng đỉnh bê tông giam giữ một phần
    eps_cu_p: float    # Biến dạng cực hạn bê tông giam giữ một phần
    eps_c0_h: float    # Biến dạng đỉnh bê tông giam giữ mạnh
    eps_cu_h: float    # Biến dạng cực hạn bê tông giam giữ mạnh
    fl_p_mpa: float    # Áp lực giam giữ ngang hữu hiệu từ cốt đai (MPa)
    fl_h_mpa: float    # Áp lực giam giữ ngang hữu hiệu vùng lõi thép H (MPa)
    eta_hsc: float     # Hệ số chiết giảm giòn HSC/VHSC (Lai & Liew 2019 / EC2)


@dataclass
class MaterialConfig:
    """
    Cấu hình đầy đủ thông số vật liệu cho kết cấu Dầm / Cột bê tông cốt cứng (SRC / CES).
    Mọi cường độ và mô-đun có đơn vị MPa (= N/mm²).
    """
    # --- 1. Bê tông ---
    concrete_grade: str = "C30/37 (B35)"
    fc_mpa: float = 30.0          # Cường độ chịu nén trụ đặc trưng f'_c / f_ck (MPa)
    ec_mpa: float = 33000.0       # Mô-đun đàn hồi ban đầu E_cm (MPa)
    fct_mpa: float = 2.9          # Cường độ chịu kéo dọc trục f_ctm (MPa)
    eps_c0: float = 0.0020        # Biến dạng nén tại đỉnh ứng suất
    eps_cu: float = 0.0035        # Biến dạng nén giới hạn bê tông không giam giữ
    gamma_c: float = 1.50         # Hệ số an toàn vật liệu bê tông (EC4 = 1.50)

    # --- 2. Thép hình cốt cứng (Structural Steel Core: H / I / Cross-H / CFST) ---
    steel_grade: str = "S355 (Q355)"
    fy_steel_mpa: float = 355.0   # Giới hạn chảy thép hình f_ya / F_y (MPa)
    fu_steel_mpa: float = 490.0   # Cường độ kéo đứt thép hình f_u (MPa)
    es_steel_mpa: float = 210000.0  # Mô-đun đàn hồi thép hình E_a (MPa)
    hardening_steel: float = 0.010  # Tỷ số mô-đun tái bền E_sh / E_a
    gamma_a: float = 1.00         # Hệ số an toàn thép hình (EC4 γ_M0 = 1.00)

    # --- 3. Cốt thép thanh dọc (Longitudinal Rebars) ---
    rebar_grade: str = "CB400-V (B400)"
    fy_rebar_mpa: float = 400.0   # Giới hạn chảy cốt thép dọc f_sk (MPa)
    es_rebar_mpa: float = 200000.0  # Mô-đun đàn hồi cốt thép dọc E_s (MPa)
    hardening_rebar: float = 0.008  # Tỷ số tái bền cốt thép thanh
    gamma_s: float = 1.15         # Hệ số an toàn cốt thép thanh (EC4 = 1.15)

    # --- 4. Cốt thép đai ngang (Transverse Stirrups / Hoops) ---
    fy_stirrup_mpa: float = 300.0  # Giới hạn chảy cốt đai f_yv (MPa)
    rho_v_stirrup: float = 0.012   # Hàm lượng thể tích cốt đai ρ_v (mặc định 1.2%)
    use_confinement: bool = True   # Bật mô hình giam giữ 3 vùng Chen & Lin (2006)
    creep_coeff: float = 0.0       # Hệ số từ biến dài hạn φ_t (cho kiểm tra EC4 dài hạn)


# ==============================================================================
# THƯ VIỆN VẬT LIỆU CHUẨN (TCVN 5574:2018 / EN 1992-1-1 / EN 10025 / AISC / JGJ)
# ==============================================================================

CONCRETE_LIBRARY: Dict[str, Dict[str, float]] = {
    "B25 (C20/25)":   {"fc": 20.0, "ec": 30000.0, "fct": 2.2, "rb_tcvn": 14.5, "rbt_tcvn": 1.05, "eps_c0": 0.0020, "eps_cu": 0.0035},
    "B30 (C25/30)":   {"fc": 25.0, "ec": 31500.0, "fct": 2.6, "rb_tcvn": 17.0, "rbt_tcvn": 1.15, "eps_c0": 0.0020, "eps_cu": 0.0035},
    "C30/37 (B35)":   {"fc": 30.0, "ec": 33000.0, "fct": 2.9, "rb_tcvn": 19.5, "rbt_tcvn": 1.30, "eps_c0": 0.0020, "eps_cu": 0.0035},
    "C35/45 (B40)":   {"fc": 35.0, "ec": 34000.0, "fct": 3.2, "rb_tcvn": 22.0, "rbt_tcvn": 1.40, "eps_c0": 0.0021, "eps_cu": 0.0035},
    "C40/50 (B45)":   {"fc": 40.0, "ec": 35000.0, "fct": 3.5, "rb_tcvn": 25.0, "rbt_tcvn": 1.50, "eps_c0": 0.0022, "eps_cu": 0.0035},
    "C50/60 (B55)":   {"fc": 50.0, "ec": 37000.0, "fct": 4.1, "rb_tcvn": 30.0, "rbt_tcvn": 1.65, "eps_c0": 0.0023, "eps_cu": 0.0034},
    "C60/75 (HSC)":   {"fc": 60.0, "ec": 39000.0, "fct": 4.4, "rb_tcvn": 33.0, "rbt_tcvn": 1.80, "eps_c0": 0.0024, "eps_cu": 0.0032},
    "C80/95 (HSC)":   {"fc": 80.0, "ec": 42000.0, "fct": 4.8, "rb_tcvn": 41.0, "rbt_tcvn": 2.00, "eps_c0": 0.0026, "eps_cu": 0.0029},
    "C110 (VHSC)":    {"fc": 109.3, "ec": 43500.0, "fct": 5.2, "rb_tcvn": 50.0, "rbt_tcvn": 2.20, "eps_c0": 0.0028, "eps_cu": 0.0028},
}

STEEL_GRADE_LIBRARY: Dict[str, Dict[str, float]] = {
    "SS400 / S235":  {"fy": 235.0, "fu": 360.0, "es": 210000.0},
    "S275 / CT38":   {"fy": 275.0, "fu": 430.0, "es": 210000.0},
    "S355 (Q355)":   {"fy": 355.0, "fu": 490.0, "es": 210000.0},
    "S420 / Q420":   {"fy": 420.0, "fu": 520.0, "es": 210000.0},
    "S460 / Q460":   {"fy": 460.0, "fu": 550.0, "es": 210000.0},
    "Q550 (HSS)":    {"fy": 550.0, "fu": 670.0, "es": 210000.0},
    "Q690 (HSS)":    {"fy": 690.0, "fu": 770.0, "es": 210000.0},
}

REBAR_GRADE_LIBRARY: Dict[str, Dict[str, float]] = {
    "CB300-V":       {"fy": 300.0, "es": 200000.0},
    "CB400-V (B400)": {"fy": 400.0, "es": 200000.0},
    "CB500-V (B500)": {"fy": 500.0, "es": 200000.0},
    "HRB550":        {"fy": 550.0, "es": 200000.0},
}

# Bảng tra tiết diện thép hình chữ H / I / UC / HEB phổ biến (đơn vị mm)
STEEL_PROFILE_LIBRARY: Dict[str, Dict[str, float]] = {
    "H150x100x6x9":     {"h": 150.0, "bf": 100.0, "tw": 6.0,  "tf": 9.0},
    "H200x100x5.5x8":   {"h": 200.0, "bf": 100.0, "tw": 5.5,  "tf": 8.0},
    "H250x125x6x9":     {"h": 250.0, "bf": 125.0, "tw": 6.0,  "tf": 9.0},
    "H300x150x6.5x9":   {"h": 300.0, "bf": 150.0, "tw": 6.5,  "tf": 9.0},
    "H350x175x7x11":    {"h": 350.0, "bf": 175.0, "tw": 7.0,  "tf": 11.0},
    "H400x200x8x13":    {"h": 400.0, "bf": 200.0, "tw": 8.0,  "tf": 13.0},
    "H150x150x7x10":    {"h": 150.0, "bf": 150.0, "tw": 7.0,  "tf": 10.0},
    "UC152x152x30":     {"h": 157.6, "bf": 152.9, "tw": 6.5,  "tf": 9.4},
    "UC152x152x37":     {"h": 161.8, "bf": 154.4, "tw": 8.0,  "tf": 11.5},
    "H200x200x8x12":    {"h": 200.0, "bf": 200.0, "tw": 8.0,  "tf": 12.0},
    "HEB200":           {"h": 200.0, "bf": 200.0, "tw": 9.0,  "tf": 15.0},
    "H250x250x9x14":    {"h": 250.0, "bf": 250.0, "tw": 9.0,  "tf": 14.0},
    "HEB240":           {"h": 240.0, "bf": 240.0, "tw": 10.0, "tf": 17.0},
    "H300x300x10x15":   {"h": 300.0, "bf": 300.0, "tw": 10.0, "tf": 15.0},
    "HEB300":           {"h": 300.0, "bf": 300.0, "tw": 11.0, "tf": 19.0},
    "W10x49":           {"h": 253.5, "bf": 254.0, "tw": 8.6,  "tf": 14.2},
}


def compute_hsc_reduction_eta(fc_mpa: float) -> float:
    """
    Tính hệ số chiết giảm cường độ hữu hiệu η cho bê tông cường độ cao / siêu cao (HSC / VHSC).

    Cơ sở khoa học:
      - Lai, Liew & Xiong (2019), Construction & Building Materials 228, Eq. (5)-(6):
          η = 1.0                      khi f'_c <= 50 MPa
          η = 1.0 - (f'_c - 50) / 200  khi 50 < f'_c <= 90 MPa
          η = 0.80                     khi f'_c > 90 MPa
      - Tương thích chặt chẽ với EN 1992-1-1 §3.1.7(3) về hệ số giòn của bê tông HSC.
    """
    if fc_mpa <= 50.0:
        return 1.0
    if fc_mpa <= 90.0:
        return max(0.80, 1.0 - (fc_mpa - 50.0) / 200.0)
    return 0.80


def compute_confinement_params(mat: MaterialConfig, steel_ratio: float = 0.06) -> ConfinementParams:
    """
    Xác định bộ tham số ứng xử cho 3 vùng bê tông theo mô hình giam giữ
    Chen & Lin (2006) — El-Tawil & Deierlein (1999) — Mander et al. (1988).

    Tham số đầu vào:
      - mat         : Cấu hình vật liệu MaterialConfig.
      - steel_ratio : Tỷ lệ diện tích thép hình ρ_a = A_a / A_g (ảnh hưởng áp lực vòm thép H).

    Kết quả trả về:
      - ConfinementParams chứa K_p, K_h và các mốc biến dạng đỉnh/cực hạn từng vùng.
    """
    fc = max(10.0, mat.fc_mpa)
    eta_hsc = compute_hsc_reduction_eta(fc)

    # Biến dạng đỉnh & phá hoại của bê tông không giam giữ (điều chỉnh nhẹ cho HSC theo EC2 Bảng 3.1)
    eps_c0_u = mat.eps_c0 if fc <= 50.0 else min(0.0029, max(mat.eps_c0, 0.0020 + 0.000012 * (fc - 50.0)))
    eps_cu_u = mat.eps_cu if fc <= 50.0 else max(0.0027, 0.0035 - 0.000012 * min(60.0, fc - 50.0))

    if not mat.use_confinement:
        return ConfinementParams(
            kp=1.0, kh=1.0,
            eps_c0_u=eps_c0_u, eps_cu_u=eps_cu_u,
            eps_c0_p=eps_c0_u, eps_cu_p=eps_cu_u,
            eps_c0_h=eps_c0_u, eps_cu_h=eps_cu_u,
            fl_p_mpa=0.0, fl_h_mpa=0.0, eta_hsc=eta_hsc,
        )

    # 1. Vùng giam giữ một phần (Partially Confined): hiệu quả cốt đai k_e ≈ 0.65
    rho_v = max(0.001, min(0.05, mat.rho_v_stirrup))
    fl_p = 0.65 * 0.5 * rho_v * mat.fy_stirrup_mpa
    kp_raw = -1.254 + 2.254 * math.sqrt(1.0 + 7.94 * fl_p / fc) - 2.0 * fl_p / fc
    # Với VHSC (fc > 80 MPa), hiệu ứng tăng cường cường độ giam giữ giảm do độ giòn cao
    hsc_damp = 1.0 if fc <= 50.0 else max(0.35, 1.0 - 0.008 * (fc - 50.0))
    kp = 1.0 + (max(1.0, kp_raw) - 1.0) * hsc_damp
    kp = min(kp, 1.32)

    # 2. Vùng giam giữ mạnh (Highly Confined): cộng thêm hiệu ứng vòm từ 2 cánh và bản bụng thép H
    rho_a_eff = max(0.02, min(0.18, steel_ratio))
    fl_arch = 0.055 * rho_a_eff * min(mat.fy_steel_mpa, 460.0)
    fl_h = fl_p + fl_arch
    kh_raw = -1.254 + 2.254 * math.sqrt(1.0 + 7.94 * fl_h / fc) - 2.0 * fl_h / fc
    kh = 1.0 + (max(1.0, kh_raw) - 1.0) * hsc_damp
    kh = max(kp, min(kh, 1.48))

    # Mốc biến dạng theo Mander (1988) & Chen & Lin (2006)
    eps_c0_p = eps_c0_u * (1.0 + 4.5 * (kp - 1.0))
    eps_cu_p = min(0.016, max(eps_cu_u + 0.0015, 0.004 + 1.4 * rho_v * mat.fy_stirrup_mpa * 0.08 / (kp * fc)))

    eps_c0_h = eps_c0_u * (1.0 + 5.0 * (kh - 1.0))
    eps_cu_h = min(0.025, max(eps_cu_p + 0.0030, eps_cu_p * 1.65))

    return ConfinementParams(
        kp=kp, kh=kh,
        eps_c0_u=eps_c0_u, eps_cu_u=eps_cu_u,
        eps_c0_p=eps_c0_p, eps_cu_p=eps_cu_p,
        eps_c0_h=eps_c0_h, eps_cu_h=eps_cu_h,
        fl_p_mpa=fl_p, fl_h_mpa=fl_h, eta_hsc=eta_hsc,
    )


def concrete_stress_tangent(
    eps: float,
    mat: MaterialConfig,
    zone: ConcreteZone = ConcreteZone.UNCONFINED,
    conf: ConfinementParams | None = None,
    nonlinear: bool = True,
) -> Tuple[float, float, str]:
    """
    Tính ứng suất σ (MPa), mô-đun tiếp tuyến E_t (MPa) và trạng thái làm việc của thớ bê tông.

    Quy ước:
      - eps <= 0 : Chịu nén (σ <= 0).
      - eps >  0 : Chịu kéo (σ >= 0), nứt khi eps > eps_cr = f_ct / E_c.
    """
    ec0_mod = max(5000.0, mat.ec_mpa)
    if not nonlinear:
        st = "Nén đàn hồi" if eps <= 0.0 else "Kéo đàn hồi"
        return ec0_mod * eps, ec0_mod, st

    if conf is None:
        conf = compute_confinement_params(mat)

    if eps <= 0.0:
        ec = -eps  # Độ lớn biến dạng nén dương
        # Hệ số chuyển đổi cường độ mẫu trụ -> cấu kiện thực (0.85 * η_HSC theo EN 1994-1-1 & Lai-Liew 2019)
        fc_insitu = 0.85 * conf.eta_hsc * mat.fc_mpa
        if zone == ConcreteZone.HIGHLY_CONFINED:
            f_peak = fc_insitu * conf.kh
            e0 = conf.eps_c0_h
            eu = conf.eps_cu_h
            drop_at_eu = 0.15  # Nhánh sau đỉnh rất dẻo nhờ vòm cánh thép H
            res_ratio = 0.55
            zone_tag = "Giam giữ mạnh"
        elif zone == ConcreteZone.PARTIALLY_CONFINED:
            f_peak = fc_insitu * conf.kp
            e0 = conf.eps_c0_p
            eu = conf.eps_cu_p
            drop_at_eu = 0.25
            res_ratio = 0.35
            zone_tag = "Giam giữ đai"
        else:
            f_peak = fc_insitu
            e0 = conf.eps_c0_u
            eu = conf.eps_cu_u
            drop_at_eu = 0.20 if mat.fc_mpa <= 50.0 else 0.45  # HSC bong vỏ nhanh hơn
            res_ratio = 0.15
            zone_tag = "Vỏ bảo vệ"

        e0 = max(1e-4, e0)
        eu = max(e0 + 4e-4, eu)

        if ec <= e0:
            # Parabol Hognestad mượt: σ = -f_peak * (2r - r²)
            r = ec / e0
            sig = -f_peak * (2.0 * r - r * r)
            et = (2.0 * f_peak / e0) * (1.0 - r)
            et = max(et, 0.008 * ec0_mod)
            st = f"Nén ĐH ({zone_tag})" if r < 0.42 else f"Nén PT ({zone_tag})"
            return sig, et, st
        if ec <= eu:
            frac = (ec - e0) / (eu - e0)
            sig = -f_peak * (1.0 - drop_at_eu * frac)
            # Giữ mô-đun tiếp tuyến nhỏ dương để bộ giải Newton-Raphson luôn ổn định số
            et_stab = 0.004 * ec0_mod
            return sig, et_stab, f"Nén sau đỉnh ({zone_tag})"

        sig = -res_ratio * f_peak
        return sig, 0.002 * ec0_mod, f"Vỡ nén ({zone_tag})"

    # --- Miền chịu kéo bê tông (Tension Stiffening hàm mũ mượt) ---
    fct = max(0.1, mat.fct_mpa)
    eps_cr = fct / ec0_mod
    if eps <= eps_cr:
        return ec0_mod * eps, ec0_mod, "Kéo chưa nứt"

    ratio = (eps - eps_cr) / max(1e-8, eps_cr)
    sig = fct * math.exp(-0.35 * min(40.0, ratio))
    # Đạo hàm tiếp tuyến nhất quán chính xác: dσ/dε = -0.35 * σ / ε_cr
    et_exact = -0.35 * sig / max(1e-8, eps_cr)
    st = "Nứt kéo (mềm hóa)" if sig > 0.10 * fct else "Nứt kéo hoàn toàn"
    return sig, et_exact, st


def steel_stress_tangent(
    eps: float,
    es_mpa: float,
    fy_mpa: float,
    hardening_ratio: float = 0.01,
    nonlinear: bool = True,
) -> Tuple[float, float, str]:
    """
    Tính ứng suất σ (MPa), mô-đun tiếp tuyến E_t (MPa) và trạng thái của thép hình / cốt thép.

    Mô hình đàn – dẻo song tuyến tính có tái bền đẳng hướng (Bilinear Isotropic Hardening):
      - |ε| <= ε_y = f_y / E_s : σ = E_s · ε, E_t = E_s
      - |ε| >  ε_y             : σ = sgn(ε) · [f_y + b_h · E_s · (|ε| - ε_y)], E_t = b_h · E_s
    """
    es = max(10000.0, es_mpa)
    if not nonlinear:
        return es * eps, es, "Đàn hồi"

    ey = fy_mpa / es
    et_h = max(1e-4, hardening_ratio) * es
    if abs(eps) <= ey:
        return es * eps, es, ("Kéo đàn hồi" if eps >= 0.0 else "Nén đàn hồi")

    sgn = 1.0 if eps >= 0.0 else -1.0
    sig = sgn * (fy_mpa + et_h * (abs(eps) - ey))
    st = "Chảy dẻo kéo" if eps > 0.0 else "Chảy dẻo nén"
    return sig, et_h, st
