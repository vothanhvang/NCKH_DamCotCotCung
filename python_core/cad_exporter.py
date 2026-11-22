# -*- coding: utf-8 -*-
"""
================================================================================
MÔ-ĐUN 6: XUẤT BẢN VẼ GIA CÔNG, CHẾ TẠO & THI CÔNG AUTOCAD (.DXF) VÀ PDF (.PDF)
================================================================================
Chức năng khối:
  - Tạo bản vẽ kỹ thuật chuyên nghiệp khổ A3 ngang (420 × 297 mm) phục vụ trực
    tiếp công tác gia công nhà máy (lõi thép hình chữ H, đinh neo chống cắt,
    bản đế cột, sườn tăng cứng, đường hàn) và thi công ngoài công trường (cốt
    thép dọc, cốt thép đai 2 vùng mật độ, lớp bê tông bảo vệ, kích thước mm).
  - Định dạng AutoCAD (.DXF chuẩn AC1015 / R2000) chia 10 LAYER chuyên nghiệp:
      0_KHUNG_TEN, 1_NET_BAO_BT, 2_THEP_HINH_H, 3_COT_THEP_DOC, 4_COT_DAI,
      5_DINH_NEO_STUD, 6_BAN_DE_LIEN_KET, 7_KICH_THUOC, 8_TIM_TRUC, 9_GHI_CHU
    mở trực tiếp trong AutoCAD, BricsCAD, ZWCAD, LibreCAD ở tỷ lệ chuẩn mm!
  - Định dạng Bản vẽ Kỹ thuật Vector PDF (.PDF khổ A3 ngang) dựng bằng ReportLab
    với phông DejaVuSans hỗ trợ đầy đủ tiếng Việt có dấu / tiếng Anh (tùy chọn).
  - Tích hợp Bảng Thống Kê Vật Liệu (Bill of Materials / Bar Bending Schedule):
    khối lượng thép hình (kg), cốt thép dọc (kg), cốt đai (kg), đinh neo (cái/kg),
    thể tích bê tông (m³) và tổng khối lượng thép chế tạo!
================================================================================
"""

from __future__ import annotations
from typing import Dict, List, Tuple
import math
import os


# ==============================================================================
# TRÌNH GHI AUTOCAD DXF ĐA LỚP CHUẨN R2000 (THUẦN PYTHON, KHÔNG PHỤ THUỘC NGOÀI)
# ==============================================================================

class DxfWriter:
    """Bộ tạo tệp AutoCAD DXF (AC1015 / R2000) hỗ trợ nhiều lớp màu, đường nét, chữ và kích thước."""

    LAYERS: List[Tuple[str, int, str]] = [
        ("0_KHUNG_TEN",       7, "CONTINUOUS"),   # Trắng/Đen - Khung tên & viền bản vẽ
        ("1_NET_BAO_BT",      7, "CONTINUOUS"),   # Nét bao bê tông chính
        ("2_THEP_HINH_H",     1, "CONTINUOUS"),   # Đỏ - Lõi thép hình chữ H / CFST
        ("3_COT_THEP_DOC",    3, "CONTINUOUS"),   # Xanh lá - Cốt thép dọc
        ("4_COT_DAI",         4, "CONTINUOUS"),   # Lục lam - Cốt thép đai
        ("5_DINH_NEO_STUD",   6, "CONTINUOUS"),   # Tím hồng - Đinh chống cắt (Headed Studs)
        ("6_BAN_DE_LIEN_KET", 5, "CONTINUOUS"),   # Xanh dương - Bản đế, sườn tăng cứng, bu-lông
        ("7_KICH_THUOC",      2, "CONTINUOUS"),   # Vàng - Đường gióng & số kích thước
        ("8_TIM_TRUC",        8, "CENTER"),       # Xám - Tim trục đối xứng
        ("9_GHI_CHU",         7, "CONTINUOUS"),   # Ghi chú, bảng thống kê vật liệu
    ]

    def __init__(self) -> None:
        self._entities: List[str] = []

    def add_line(self, x1: float, y1: float, x2: float, y2: float, layer: str) -> None:
        self._entities.append(
            f"0\nLINE\n8\n{layer}\n10\n{x1:.3f}\n20\n{y1:.3f}\n30\n0.0\n"
            f"11\n{x2:.3f}\n21\n{y2:.3f}\n31\n0.0\n"
        )

    def add_rect(self, x: float, y: float, w: float, h: float, layer: str) -> None:
        self.add_polyline([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], layer, closed=True)

    def add_polyline(self, pts: List[Tuple[float, float]], layer: str, closed: bool = False) -> None:
        if len(pts) < 2:
            return
        flag = 1 if closed else 0
        out = [f"0\nLWPOLYLINE\n8\n{layer}\n90\n{len(pts)}\n70\n{flag}\n"]
        for px, py in pts:
            out.append(f"10\n{px:.3f}\n20\n{py:.3f}\n")
        self._entities.append("".join(out))

    def add_circle(self, cx: float, cy: float, r: float, layer: str) -> None:
        self._entities.append(
            f"0\nCIRCLE\n8\n{layer}\n10\n{cx:.3f}\n20\n{cy:.3f}\n30\n0.0\n40\n{r:.3f}\n"
        )

    def add_text(self, x: float, y: float, text: str, height: float, layer: str, align: int = 0) -> None:
        safe = text.replace("\n", " ").replace("\r", " ")
        # align: 0 = trái, 1 = giữa, 2 = phải
        if align == 0:
            self._entities.append(
                f"0\nTEXT\n8\n{layer}\n10\n{x:.3f}\n20\n{y:.3f}\n30\n0.0\n"
                f"40\n{height:.3f}\n1\n{safe}\n"
            )
        else:
            self._entities.append(
                f"0\nTEXT\n8\n{layer}\n10\n{x:.3f}\n20\n{y:.3f}\n30\n0.0\n"
                f"40\n{height:.3f}\n1\n{safe}\n72\n{align}\n11\n{x:.3f}\n21\n{y:.3f}\n31\n0.0\n"
            )

    def add_dim_horizontal(self, x1: float, x2: float, y_ref: float, y_dim: float, label: str, text_h: float = 3.2) -> None:
        """Vẽ đường kích thước ngang chuẩn kỹ thuật kèm vạch chân 45°."""
        self.add_line(x1, y_ref, x1, y_dim + (2.0 if y_dim >= y_ref else -2.0), "7_KICH_THUOC")
        self.add_line(x2, y_ref, x2, y_dim + (2.0 if y_dim >= y_ref else -2.0), "7_KICH_THUOC")
        self.add_line(x1 - 2.0, y_dim, x2 + 2.0, y_dim, "7_KICH_THUOC")
        # Vạch xiên 45° tại 2 đầu mút kích thước
        t = 1.6
        self.add_line(x1 - t, y_dim - t, x1 + t, y_dim + t, "7_KICH_THUOC")
        self.add_line(x2 - t, y_dim - t, x2 + t, y_dim + t, "7_KICH_THUOC")
        self.add_text(0.5 * (x1 + x2), y_dim + 1.2, label, text_h, "7_KICH_THUOC", align=1)

    def add_dim_vertical(self, x_ref: float, x_dim: float, y1: float, y2: float, label: str, text_h: float = 3.2) -> None:
        """Vẽ đường kích thước đứng chuẩn kỹ thuật."""
        self.add_line(x_ref, y1, x_dim + (2.0 if x_dim >= x_ref else -2.0), y1, "7_KICH_THUOC")
        self.add_line(x_ref, y2, x_dim + (2.0 if x_dim >= x_ref else -2.0), y2, "7_KICH_THUOC")
        self.add_line(x_dim, y1 - 2.0, x_dim, y2 + 2.0, "7_KICH_THUOC")
        t = 1.6
        self.add_line(x_dim - t, y1 - t, x_dim + t, y1 + t, "7_KICH_THUOC")
        self.add_line(x_dim - t, y2 - t, x_dim + t, y2 + t, "7_KICH_THUOC")
        self.add_text(x_dim + (2.2 if x_dim >= x_ref else -2.2), 0.5 * (y1 + y2) - 0.5 * text_h, label, text_h, "7_KICH_THUOC", align=(0 if x_dim >= x_ref else 2))

    def to_string(self) -> str:
        """Kết xuất toàn bộ nội dung tệp DXF hợp lệ (HEADER + TABLES + ENTITIES + EOF)."""
        parts: List[str] = [
            "0\nSECTION\n2\nHEADER\n"
            "9\n$ACADVER\n1\nAC1009\n"
            "9\n$INSUNITS\n70\n4\n"
            "0\nENDSEC\n",
            "0\nSECTION\n2\nTABLES\n"
            "0\nTABLE\n2\nLTYPE\n70\n2\n"
            "0\nLTYPE\n2\nCONTINUOUS\n70\n0\n3\nSolid line\n72\n65\n73\n0\n40\n0.0\n"
            "0\nLTYPE\n2\nCENTER\n70\n0\n3\nCenter ____ _ ____\n72\n65\n73\n4\n40\n20.0\n"
            "49\n12.0\n49\n-3.0\n49\n2.0\n49\n-3.0\n"
            "0\nENDTAB\n",
            f"0\nTABLE\n2\nLAYER\n70\n{len(self.LAYERS)}\n",
        ]
        for name, color, ltype in self.LAYERS:
            parts.append(f"0\nLAYER\n2\n{name}\n70\n0\n62\n{color}\n6\n{ltype}\n")
        parts.append("0\nENDTAB\n0\nENDSEC\n")
        parts.append("0\nSECTION\n2\nENTITIES\n")
        parts.extend(self._entities)
        parts.append("0\nENDSEC\n0\nEOF\n")
        return "".join(parts)


# ==============================================================================
# TÍNH TOÁN BẢNG THỐNG KÊ THÉP HÌNH, CỐT THÉP, ĐINH NEO & BÊ TÔNG (BOM / BBS)
# ==============================================================================

def compute_material_schedule(analysis: Dict[str, object], lang: str = "vi") -> List[Dict[str, object]]:
    """
    Lập bảng thống kê vật liệu chế tạo & thi công (BBS / MTO) cho dầm hoặc cột SRC.
    """
    is_beam = analysis["member_kind"] == "beam"
    cfg = analysis["config"]
    g = cfg.geometry
    props = analysis["props"]
    L_m = (cfg.span_mm if is_beam else cfg.height_mm) / 1000.0
    rho_steel = 7850.0  # kg/m³

    # 1. Thép hình lõi cốt cứng (có thêm 3% hao hụt & bản mã / sườn tăng cứng)
    w_steel_m = (props.aa_mm2 / 1e6) * rho_steel
    w_steel_tot = w_steel_m * L_m * 1.03

    # 2. Cốt thép dọc chủ (kể thêm đoạn neo hai đầu 2 x 35d)
    w_rebar_tot = 0.0
    for (_, _, dia) in props.rebar_coords:
        a_m2 = 0.25 * math.pi * (dia / 1000.0) ** 2
        l_bar = L_m + 2.0 * 35.0 * (dia / 1000.0)
        w_rebar_tot += a_m2 * l_bar * rho_steel

    # 3. Cốt thép đai ngang (vùng đầu L/4 bước s_1, vùng giữa L/2 bước s_2)
    n_end = int(math.ceil((0.5 * L_m * 1000.0) / max(40.0, g.stirrup_spacing_end_mm)))
    n_mid = int(math.ceil((0.5 * L_m * 1000.0) / max(40.0, g.stirrup_spacing_mm)))
    n_stirrups = n_end + n_mid + 2
    if g.section_type == "COL_CIRC_H":
        p_hoop = math.pi * max(80.0, g.b_mm - 2.0 * g.cover_mm) + 20.0 * g.stirrup_dia_mm
    else:
        p_hoop = 2.0 * (max(60.0, g.b_mm - 2.0 * g.cover_mm) + max(60.0, g.h_mm - 2.0 * g.cover_mm)) + 20.0 * g.stirrup_dia_mm
        if g.n_stirrup_legs > 2:
            p_hoop += (g.n_stirrup_legs - 2) * (max(60.0, g.h_mm - 2.0 * g.cover_mm) + 12.0 * g.stirrup_dia_mm)
    a_sv1_m2 = 0.25 * math.pi * (g.stirrup_dia_mm / 1000.0) ** 2
    w_stirrup_tot = n_stirrups * (p_hoop / 1000.0) * a_sv1_m2 * rho_steel

    # 4. Đinh chống cắt (dầm) hoặc Bản đế + Bu-lông neo (cột)
    if is_beam:
        n_studs = int(math.floor((cfg.span_mm - 200.0) / max(60.0, cfg.stud_spacing_mm)) + 1) * cfg.stud_rows
        w_stud1 = 0.25 * math.pi * (cfg.stud_dia_mm / 1000.0) ** 2 * ((cfg.stud_height_mm + 15.0) / 1000.0) * rho_steel
        w_extra_tot = n_studs * w_stud1
        extra_item = {
            "mark": "ST-1",
            "desc": f"Đinh neo chống cắt Ø{cfg.stud_dia_mm:.0f}×{cfg.stud_height_mm:.0f} @{cfg.stud_spacing_mm:.0f}" if lang == "vi" else f"Headed Shear Studs Ø{cfg.stud_dia_mm:.0f}×{cfg.stud_height_mm:.0f} @{cfg.stud_spacing_mm:.0f}",
            "grade": f"fu={cfg.stud_fu_mpa:.0f} MPa",
            "qty": f"{n_studs} cái" if lang == "vi" else f"{n_studs} pcs",
            "weight_kg": w_extra_tot,
        }
    else:
        bp_w = (g.b_mm + 120.0) / 1000.0
        bp_h = (g.h_mm + 120.0) / 1000.0
        bp_t = 0.030  # Bản đế dày 30 mm + 4 sườn tăng cứng 12 mm
        w_extra_tot = (bp_w * bp_h * bp_t + 4.0 * 0.15 * 0.20 * 0.012) * rho_steel
        extra_item = {
            "mark": "BP-1",
            "desc": f"Bản đế thép PL30×{g.b_mm+120:.0f}×{g.h_mm+120:.0f} + 8 bu-lông M24" if lang == "vi" else f"Baseplate PL30×{g.b_mm+120:.0f}×{g.h_mm+120:.0f} + 8×M24 Bolts",
            "grade": cfg.material.steel_grade,
            "qty": "1 bộ" if lang == "vi" else "1 set",
            "weight_kg": w_extra_tot,
        }

    vol_conc_m3 = (props.ac_mm2 / 1e6) * L_m
    profile_desc = f"H{g.ha_mm:.0f}×{g.ba_mm:.0f}×{g.tw_mm:.1f}×{g.tf_mm:.1f}"
    if g.section_type == "COL_RECT_CROSS_H":
        profile_desc = f"2×{profile_desc} (Cross-H)"
    elif g.section_type == "COL_RECT_CFST":
        profile_desc = f"CHS Ø{g.ha_mm:.0f}×{g.tf_mm:.1f}"

    return [
        {
            "mark": "S-1",
            "desc": (f"Lõi thép hình {profile_desc}, L={L_m*1000:.0f} mm" if lang == "vi" else f"Steel Core {profile_desc}, L={L_m*1000:.0f} mm"),
            "grade": cfg.material.steel_grade,
            "qty": "1 cây" if lang == "vi" else "1 pc",
            "weight_kg": w_steel_tot,
        },
        {
            "mark": "R-1",
            "desc": (f"Cốt thép dọc ({len(props.rebar_coords)} thanh Ø{g.rebar_dia_bot_mm:.0f}/Ø{g.rebar_dia_top_mm:.0f})" if lang == "vi" else f"Longitudinal Rebar ({len(props.rebar_coords)} bars Ø{g.rebar_dia_bot_mm:.0f}/Ø{g.rebar_dia_top_mm:.0f})"),
            "grade": cfg.material.rebar_grade,
            "qty": f"{len(props.rebar_coords)} thanh" if lang == "vi" else f"{len(props.rebar_coords)} bars",
            "weight_kg": w_rebar_tot,
        },
        {
            "mark": "R-2",
            "desc": (f"Cốt thép đai Ø{g.stirrup_dia_mm:.0f} @{g.stirrup_spacing_end_mm:.0f}/{g.stirrup_spacing_mm:.0f} ({g.n_stirrup_legs} nhánh)" if lang == "vi" else f"Stirrups Ø{g.stirrup_dia_mm:.0f} @{g.stirrup_spacing_end_mm:.0f}/{g.stirrup_spacing_mm:.0f} ({g.n_stirrup_legs} legs)"),
            "grade": f"fy={cfg.material.fy_stirrup_mpa:.0f} MPa",
            "qty": f"{n_stirrups} đai" if lang == "vi" else f"{n_stirrups} pcs",
            "weight_kg": w_stirrup_tot,
        },
        extra_item,
        {
            "mark": "C-1",
            "desc": (f"Bê tông đổ tại chỗ {cfg.material.concrete_grade} (f'c={cfg.material.fc_mpa:.1f} MPa)" if lang == "vi" else f"Cast-in-place Concrete {cfg.material.concrete_grade} (f'c={cfg.material.fc_mpa:.1f} MPa)"),
            "grade": cfg.material.concrete_grade,
            "qty": f"{vol_conc_m3:.3f} m³",
            "weight_kg": vol_conc_m3 * 2450.0,
        },
    ]


def _draw_title_block_dxf(dxf: DxfWriter, sheet_w: float, sheet_h: float, title: str, code_ref: str, member_tag: str, lang: str) -> None:
    """Vẽ khung viền khổ A3 ngang và khung tên tiêu chuẩn TCVN 7285 / ISO 7200 trong DXF."""
    dxf.add_rect(0, 0, sheet_w, sheet_h, "0_KHUNG_TEN")
    dxf.add_rect(10, 8, sheet_w - 18, sheet_h - 16, "0_KHUNG_TEN")

    # Khung tên góc dưới bên phải (165 x 42 mm)
    tx = sheet_w - 8 - 165
    ty = 8.0
    dxf.add_rect(tx, ty, 165, 42, "0_KHUNG_TEN")
    dxf.add_line(tx, ty + 28, tx + 165, ty + 28, "0_KHUNG_TEN")
    dxf.add_line(tx, ty + 14, tx + 165, ty + 14, "0_KHUNG_TEN")
    dxf.add_line(tx + 115, ty, tx + 115, ty + 28, "0_KHUNG_TEN")

    hdr = "DE TAI NCKH CAP QUOC GIA — KET CAU BE TONG COT CUNG (SRC/CES)" if lang == "vi" else "NATIONAL SCIENTIFIC RESEARCH — COMPOSITE SRC/CES STRUCTURES"
    dxf.add_text(tx + 4, ty + 33.5, hdr, 2.7, "9_GHI_CHU")
    dxf.add_text(tx + 4, ty + 20.0, title[:48], 3.1, "9_GHI_CHU")
    dxf.add_text(tx + 4, ty + 6.0, f"Standards: {code_ref}", 2.5, "9_GHI_CHU")
    dxf.add_text(tx + 119, ty + 19.0, f"TAG: {member_tag}", 2.8, "9_GHI_CHU")
    dxf.add_text(tx + 119, ty + 6.0, "A3 | UNIT: mm", 2.6, "9_GHI_CHU")


def _draw_steel_section_dxf(dxf: DxfWriter, cx: float, cy: float, scale: float, g, layer: str = "2_THEP_HINH_H") -> None:
    """Vẽ chính xác mặt cắt ngang lõi thép hình H / Cross-H / CFST vào bản vẽ DXF."""
    yc = cy + g.core_offset_y_mm * scale
    ha = g.ha_mm * scale
    ba = g.ba_mm * scale
    tf = g.tf_mm * scale
    tw = g.tw_mm * scale

    if g.section_type == "COL_RECT_CFST":
        dxf.add_circle(cx, yc, 0.5 * ha, layer)
        dxf.add_circle(cx, yc, max(1.0, 0.5 * ha - tf), layer)
        return

    # Chữ H đứng (12 đỉnh khép kín)
    h2, b2, tw2 = 0.5 * ha, 0.5 * ba, 0.5 * tw
    h_pts = [
        (cx - b2, yc - h2), (cx + b2, yc - h2), (cx + b2, yc - h2 + tf),
        (cx + tw2, yc - h2 + tf), (cx + tw2, yc + h2 - tf), (cx + b2, yc + h2 - tf),
        (cx + b2, yc + h2), (cx - b2, yc + h2), (cx - b2, yc + h2 - tf),
        (cx - tw2, yc + h2 - tf), (cx - tw2, yc - h2 + tf), (cx - b2, yc - h2 + tf),
    ]
    dxf.add_polyline(h_pts, layer, closed=True)

    if g.section_type == "COL_RECT_CROSS_H":
        # Chữ H xoay 90 độ
        c_pts = [
            (cx - h2, yc - b2), (cx - h2 + tf, yc - b2), (cx - h2 + tf, yc - tw2),
            (cx + h2 - tf, yc - tw2), (cx + h2 - tf, yc - b2), (cx + h2, yc - b2),
            (cx + h2, yc + b2), (cx + h2 - tf, yc + b2), (cx + h2 - tf, yc + tw2),
            (cx - h2 + tf, yc + tw2), (cx - h2 + tf, yc + b2), (cx - h2, yc + b2),
        ]
        dxf.add_polyline(c_pts, layer, closed=True)


def export_beam_dxf(analysis: Dict[str, object], out_path: str, lang: str = "vi") -> str:
    """
    Xuất bản vẽ gia công, chế tạo & thi công DẦM BÊ TÔNG CỐT CỨNG định dạng AutoCAD (.DXF).
    Gồm: Mặt đứng dọc dầm tỷ lệ chuẩn + Mặt cắt 1-1 tỷ lệ lớn + Chi tiết đinh neo/đầu dầm + Bảng thống kê.
    """
    cfg = analysis["config"]
    g = cfg.geometry
    props = analysis["props"]
    dxf = DxfWriter()
    sw, sh = 420.0, 297.0
    _draw_title_block_dxf(
        dxf, sw, sh,
        title=f"SRC BEAM SHOP DRAWING — L={cfg.span_mm:.0f}mm, {g.b_mm:.0f}x{g.h_mm:.0f}",
        code_ref="EN 1994-1-1 / AISC 360-22 / JGJ 138",
        member_tag="SRC-B1",
        lang=lang,
    )

    # -------------------------------------------------------------------------
    # 1. MẶT ĐỨNG DỌC DẦM (LONGITUDINAL ELEVATION) — vùng trên bên trái
    # -------------------------------------------------------------------------
    ex0, ey0 = 28.0, 185.0
    elev_w = 230.0
    sc_e = min(elev_w / max(1000.0, cfg.span_mm), 52.0 / max(200.0, g.h_mm))
    el_len = cfg.span_mm * sc_e
    el_h = g.h_mm * sc_e

    dxf.add_text(ex0, ey0 + el_h + 15.0,
                 f"1. LONGITUDINAL ELEVATION — SRC BEAM (L = {cfg.span_mm:.0f} mm, SCALE 1:{1.0/sc_e:.0f})",
                 3.6, "9_GHI_CHU")
    # Viền ngoài dầm bê tông
    dxf.add_rect(ex0, ey0, el_len, el_h, "1_NET_BAO_BT")
    if g.section_type == "SRC_T_SLAB_H":
        hf_e = g.hf_slab_mm * sc_e
        dxf.add_line(ex0, ey0 + el_h - hf_e, ex0 + el_len, ey0 + el_h - hf_e, "1_NET_BAO_BT")

    # Lõi thép hình chữ H dọc nhịp
    yc_e = ey0 + 0.5 * el_h + g.core_offset_y_mm * sc_e
    ha_e = g.ha_mm * sc_e
    tf_e = max(0.8, g.tf_mm * sc_e)
    dxf.add_rect(ex0 - 3.0, yc_e - 0.5 * ha_e, el_len + 6.0, ha_e, "2_THEP_HINH_H")
    dxf.add_line(ex0 - 3.0, yc_e - 0.5 * ha_e + tf_e, ex0 + el_len + 3.0, yc_e - 0.5 * ha_e + tf_e, "2_THEP_HINH_H")
    dxf.add_line(ex0 - 3.0, yc_e + 0.5 * ha_e - tf_e, ex0 + el_len + 3.0, yc_e + 0.5 * ha_e - tf_e, "2_THEP_HINH_H")
    # Tim trục thép hình
    dxf.add_line(ex0 - 8.0, yc_e, ex0 + el_len + 8.0, yc_e, "8_TIM_TRUC")

    # Cốt thép dọc trên & dưới + móc neo đầu dầm
    c_e = (g.cover_mm + g.stirrup_dia_mm) * sc_e
    dxf.add_polyline([(ex0 + 2, ey0 + c_e + 4), (ex0 + 2, ey0 + c_e), (ex0 + el_len - 2, ey0 + c_e), (ex0 + el_len - 2, ey0 + c_e + 4)], "3_COT_THEP_DOC")
    dxf.add_polyline([(ex0 + 2, ey0 + el_h - c_e - 4), (ex0 + 2, ey0 + el_h - c_e), (ex0 + el_len - 2, ey0 + el_h - c_e), (ex0 + el_len - 2, ey0 + el_h - c_e - 4)], "3_COT_THEP_DOC")

    # Cốt thép đai 2 vùng mật độ (đầu dầm dày s1, giữa nhịp s2)
    x_pos = 80.0
    while x_pos < cfg.span_mm - 40.0:
        in_end = (x_pos <= 0.25 * cfg.span_mm) or (x_pos >= 0.75 * cfg.span_mm)
        sx = ex0 + x_pos * sc_e
        dxf.add_line(sx, ey0 + c_e, sx, ey0 + el_h - c_e, "4_COT_DAI")
        x_pos += g.stirrup_spacing_end_mm if in_end else g.stirrup_spacing_mm

    # Đinh neo chống cắt (Headed Studs) trên cánh trên thép H
    st_x = 120.0
    stud_h_e = max(2.2, cfg.stud_height_mm * sc_e)
    while st_x < cfg.span_mm - 80.0:
        sx = ex0 + st_x * sc_e
        y_top_fl = yc_e + 0.5 * ha_e
        dxf.add_line(sx, y_top_fl, sx, y_top_fl + stud_h_e, "5_DINH_NEO_STUD")
        dxf.add_line(sx - 1.0, y_top_fl + stud_h_e, sx + 1.0, y_top_fl + stud_h_e, "5_DINH_NEO_STUD")
        st_x += max(100.0, cfg.stud_spacing_mm)

    # Sườn tăng cứng gối tựa (End Bearing Stiffeners)
    for x_end in (ex0 + 1.5, ex0 + el_len - 1.5):
        dxf.add_rect(x_end - 1.2, yc_e - 0.5 * ha_e, 2.4, ha_e, "6_BAN_DE_LIEN_KET")

    # Đường kích thước mặt đứng
    dxf.add_dim_horizontal(ex0, ex0 + 0.25 * el_len, ey0, ey0 - 12.0, f"L/4={0.25*cfg.span_mm:.0f} (s1={g.stirrup_spacing_end_mm:.0f})")
    dxf.add_dim_horizontal(ex0 + 0.25 * el_len, ex0 + 0.75 * el_len, ey0, ey0 - 12.0, f"L/2={0.50*cfg.span_mm:.0f} (s2={g.stirrup_spacing_mm:.0f})")
    dxf.add_dim_horizontal(ex0 + 0.75 * el_len, ex0 + el_len, ey0, ey0 - 12.0, f"L/4={0.25*cfg.span_mm:.0f}")
    dxf.add_dim_horizontal(ex0, ex0 + el_len, ey0, ey0 - 24.0, f"SPAN L = {cfg.span_mm:.0f} mm")
    dxf.add_dim_vertical(ex0, ex0 - 11.0, ey0, ey0 + el_h, f"h={g.h_mm:.0f}")

    # -------------------------------------------------------------------------
    # 2. MẶT CẮT NGANG 1-1 TỶ LỆ LỚN (CROSS-SECTION DETAIL) — vùng trên phải
    # -------------------------------------------------------------------------
    sc_s = min(92.0 / max(300.0, (g.bf_slab_mm if g.section_type == "SRC_T_SLAB_H" else g.b_mm)),
               82.0 / max(250.0, g.h_mm))
    cx_s, cy_s = 335.0, 210.0
    dxf.add_text(cx_s, cy_s + 0.5 * g.h_mm * sc_s + 16.0,
                 f"2. SECTION 1-1 (SCALE 1:{1.0/sc_s:.1f})", 3.6, "9_GHI_CHU", align=1)

    b_s, h_s = g.b_mm * sc_s, g.h_mm * sc_s
    if g.section_type == "SRC_T_SLAB_H":
        bf_s, hf_s = g.bf_slab_mm * sc_s, g.hf_slab_mm * sc_s
        t_poly = [
            (cx_s - 0.5 * b_s, cy_s - 0.5 * h_s),
            (cx_s + 0.5 * b_s, cy_s - 0.5 * h_s),
            (cx_s + 0.5 * b_s, cy_s + 0.5 * h_s - hf_s),
            (cx_s + 0.5 * bf_s, cy_s + 0.5 * h_s - hf_s),
            (cx_s + 0.5 * bf_s, cy_s + 0.5 * h_s),
            (cx_s - 0.5 * bf_s, cy_s + 0.5 * h_s),
            (cx_s - 0.5 * bf_s, cy_s + 0.5 * h_s - hf_s),
            (cx_s - 0.5 * b_s, cy_s + 0.5 * h_s - hf_s),
        ]
        dxf.add_polyline(t_poly, "1_NET_BAO_BT", closed=True)
        dxf.add_dim_horizontal(cx_s - 0.5 * bf_s, cx_s + 0.5 * bf_s, cy_s + 0.5 * h_s, cy_s + 0.5 * h_s + 8.0, f"beff={g.bf_slab_mm:.0f}")
    else:
        dxf.add_rect(cx_s - 0.5 * b_s, cy_s - 0.5 * h_s, b_s, h_s, "1_NET_BAO_BT")

    # Lồng cốt đai & lõi thép hình chữ H & cốt thép dọc & đinh chống cắt
    cov_s = g.cover_mm * sc_s
    dxf.add_rect(cx_s - 0.5 * b_s + cov_s, cy_s - 0.5 * h_s + cov_s, b_s - 2 * cov_s, h_s - 2 * cov_s, "4_COT_DAI")
    _draw_steel_section_dxf(dxf, cx_s, cy_s, sc_s, g, "2_THEP_HINH_H")
    for yr, zr, dia in props.rebar_coords:
        dxf.add_circle(cx_s + zr * sc_s, cy_s + yr * sc_s, max(1.1, 0.5 * dia * sc_s), "3_COT_THEP_DOC")

    # Đinh chống cắt trên cánh trên thép H trong mặt cắt 1-1
    y_st_base = cy_s + (g.core_offset_y_mm + 0.5 * g.ha_mm) * sc_s
    stud_h_s = cfg.stud_height_mm * sc_s
    for sgn in ([-0.28, 0.28] if cfg.stud_rows >= 2 else [0.0]):
        sx = cx_s + sgn * g.ba_mm * sc_s
        dxf.add_rect(sx - 0.5 * cfg.stud_dia_mm * sc_s, y_st_base, cfg.stud_dia_mm * sc_s, stud_h_s, "5_DINH_NEO_STUD")
        dxf.add_rect(sx - 0.85 * cfg.stud_dia_mm * sc_s, y_st_base + stud_h_s, 1.7 * cfg.stud_dia_mm * sc_s, 1.5, "5_DINH_NEO_STUD")

    dxf.add_dim_horizontal(cx_s - 0.5 * b_s, cx_s + 0.5 * b_s, cy_s - 0.5 * h_s, cy_s - 0.5 * h_s - 10.0, f"b={g.b_mm:.0f}")
    dxf.add_dim_vertical(cx_s + 0.5 * b_s, cx_s + 0.5 * (g.bf_slab_mm if g.section_type == "SRC_T_SLAB_H" else g.b_mm) * sc_s + 10.0,
                         cy_s - 0.5 * h_s, cy_s + 0.5 * h_s, f"h={g.h_mm:.0f}")
    dxf.add_line(cx_s, cy_s - 0.5 * h_s - 5, cx_s, cy_s + 0.5 * h_s + 5, "8_TIM_TRUC")

    # -------------------------------------------------------------------------
    # 3. BẢNG THỐNG KÊ THÉP & VẬT LIỆU (BOM / BBS) — vùng dưới bên trái
    # -------------------------------------------------------------------------
    sched = compute_material_schedule(analysis, lang="en")  # ASCII sạch cho DXF
    bx, by = 18.0, 128.0
    dxf.add_text(bx, by + 6.0, "3. BILL OF MATERIALS & FABRICATION SCHEDULE (BOM / BBS)", 3.4, "9_GHI_CHU")
    col_w = [18.0, 108.0, 34.0, 28.0, 28.0]
    row_h = 8.5
    tot_w = sum(col_w)
    headers = ["MARK", "DESCRIPTION / SPECIFICATION", "GRADE", "QTY", "MASS (kg)"]
    dxf.add_rect(bx, by - row_h * (len(sched) + 2), tot_w, row_h * (len(sched) + 2), "9_GHI_CHU")
    # Header
    cx_t = bx
    for w_c, h_txt in zip(col_w, headers):
        dxf.add_text(cx_t + 2.0, by - 6.0, h_txt, 2.6, "9_GHI_CHU")
        cx_t += w_c
    dxf.add_line(bx, by - row_h, bx + tot_w, by - row_h, "9_GHI_CHU")

    steel_mass = 0.0
    for idx, item in enumerate(sched):
        ry = by - row_h * (idx + 2)
        if item["mark"] != "C-1":
            steel_mass += item["weight_kg"]
        vals = [item["mark"], item["desc"], item["grade"], item["qty"], f"{item['weight_kg']:.1f}"]
        cx_t = bx
        for w_c, val in zip(col_w, vals):
            dxf.add_text(cx_t + 2.0, ry + 2.5, str(val)[:46], 2.4, "9_GHI_CHU")
            cx_t += w_c
        dxf.add_line(bx, ry, bx + tot_w, ry, "9_GHI_CHU")
    # Dòng tổng kết thép
    ry_tot = by - row_h * (len(sched) + 2)
    dxf.add_text(bx + 2.0, ry_tot + 2.5, f"TOTAL STRUCTURAL STEEL + REBAR + STUDS: {steel_mass:.1f} kg ({steel_mass/1000:.3f} t)", 2.6, "9_GHI_CHU")

    # Ghi chú kỹ thuật chế tạo & thi công (Construction Notes)
    nx, ny = 246.0, 128.0
    dxf.add_text(nx, ny + 6.0, "4. FABRICATION & CONSTRUCTION NOTES:", 3.2, "9_GHI_CHU")
    notes = [
        f"- Concrete: {cfg.material.concrete_grade} (f'c={cfg.material.fc_mpa:.1f} MPa), Cover c={g.cover_mm:.0f} mm.",
        f"- Steel Core: H{g.ha_mm:.0f}x{g.ba_mm:.0f}x{g.tw_mm:.1f}x{g.tf_mm:.1f} ({cfg.material.steel_grade}, fy={cfg.material.fy_steel_mpa:.0f} MPa).",
        f"- Shear Studs: {cfg.stud_rows}xØ{cfg.stud_dia_mm:.0f}x{cfg.stud_height_mm:.0f} @{cfg.stud_spacing_mm:.0f} mm, arc-stud welded to top flange.",
        f"- Fillet welds: hf = 8 mm (E70XX / AWS D1.1) for bearing stiffeners & web splice.",
        f"- Stirrups: 135-deg seismic hooks (len >= 10d = {10*g.stirrup_dia_mm:.0f} mm); dense zone L/4.",
        f"- Nonlinear FEM Mu = {analysis['m_ultimate_fem_knm']:.1f} kNm | EC4 MRd = {analysis['design_checks']['codes']['EC4']['m_rd_mv_knm']:.1f} kNm.",
    ]
    for i, line in enumerate(notes):
        dxf.add_text(nx, ny - 6.0 - i * 8.0, line, 2.35, "9_GHI_CHU")

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(dxf.to_string())
    return out_path


def export_column_dxf(analysis: Dict[str, object], out_path: str, lang: str = "vi") -> str:
    """
    Xuất bản vẽ gia công, chế tạo & thi công CỘT BÊ TÔNG CỐT CỨNG định dạng AutoCAD (.DXF).
    Gồm: Mặt đứng cột + Mặt cắt ngang 1-1 + Chi tiết Bản đế chân cột (Baseplate) + Bảng thống kê.
    """
    cfg = analysis["config"]
    g = cfg.geometry
    props = analysis["props"]
    dxf = DxfWriter()
    sw, sh = 420.0, 297.0
    _draw_title_block_dxf(
        dxf, sw, sh,
        title=f"SRC COLUMN SHOP DRAWING — H={cfg.height_mm:.0f}mm, {g.b_mm:.0f}x{g.h_mm:.0f}",
        code_ref="EN 1994-1-1 §6.7 / AISC 360-22 §I2,I5 / JGJ 138",
        member_tag="SRC-C1",
        lang=lang,
    )

    # 1. MẶT ĐỨNG CỘT (VERTICAL ELEVATION) — bên trái
    sc_e = min(195.0 / max(1500.0, cfg.height_mm), 46.0 / max(200.0, g.b_mm))
    col_w = g.b_mm * sc_e
    col_h = cfg.height_mm * sc_e
    cx_e = 56.0
    ey0 = 42.0

    dxf.add_text(cx_e, ey0 + col_h + 15.0,
                 f"1. COLUMN ELEVATION (H={cfg.height_mm:.0f} mm, 1:{1.0/sc_e:.0f})", 3.5, "9_GHI_CHU", align=1)
    dxf.add_rect(cx_e - 0.5 * col_w, ey0, col_w, col_h, "1_NET_BAO_BT")
    dxf.add_line(cx_e, ey0 - 10.0, cx_e, ey0 + col_h + 10.0, "8_TIM_TRUC")

    # Lõi thép hình đứng
    ha_e = g.ha_mm * sc_e
    tf_e = max(0.8, g.tf_mm * sc_e)
    dxf.add_rect(cx_e - 0.5 * ha_e, ey0, ha_e, col_h, "2_THEP_HINH_H")
    dxf.add_line(cx_e - 0.5 * ha_e + tf_e, ey0, cx_e - 0.5 * ha_e + tf_e, ey0 + col_h, "2_THEP_HINH_H")
    dxf.add_line(cx_e + 0.5 * ha_e - tf_e, ey0, cx_e + 0.5 * ha_e - tf_e, ey0 + col_h, "2_THEP_HINH_H")

    # Bản đế thép chân cột (Baseplate) + Bu-lông neo
    bp_w_e = col_w + 10.0
    dxf.add_rect(cx_e - 0.5 * bp_w_e, ey0 - 3.5, bp_w_e, 3.5, "6_BAN_DE_LIEN_KET")
    for sgn in (-0.38, 0.38):
        bx_a = cx_e + sgn * bp_w_e
        dxf.add_line(bx_a, ey0 - 15.0, bx_a, ey0 + 4.0, "6_BAN_DE_LIEN_KET")

    # Cốt thép dọc & cốt đai dày vùng đầu cột (L/6)
    cov_e = g.cover_mm * sc_e
    dxf.add_line(cx_e - 0.5 * col_w + cov_e, ey0, cx_e - 0.5 * col_w + cov_e, ey0 + col_h, "3_COT_THEP_DOC")
    dxf.add_line(cx_e + 0.5 * col_w - cov_e, ey0, cx_e + 0.5 * col_w - cov_e, ey0 + col_h, "3_COT_THEP_DOC")
    y_pos = 80.0
    while y_pos < cfg.height_mm - 50.0:
        in_conf = (y_pos <= cfg.height_mm / 5.0) or (y_pos >= 4.0 * cfg.height_mm / 5.0)
        sy = ey0 + y_pos * sc_e
        dxf.add_line(cx_e - 0.5 * col_w + cov_e, sy, cx_e + 0.5 * col_w - cov_e, sy, "4_COT_DAI")
        y_pos += g.stirrup_spacing_end_mm if in_conf else g.stirrup_spacing_mm

    dxf.add_dim_vertical(cx_e - 0.5 * col_w, cx_e - 0.5 * col_w - 15.0, ey0, ey0 + col_h, f"H={cfg.height_mm:.0f}")
    dxf.add_dim_horizontal(cx_e - 0.5 * col_w, cx_e + 0.5 * col_w, ey0, ey0 - 22.0, f"b={g.b_mm:.0f}")

    # 2. MẶT CẮT NGANG 1-1 TỶ LỆ LỚN — giữa trên
    sc_s = min(78.0 / max(200.0, g.b_mm), 78.0 / max(200.0, g.h_mm))
    cx_s, cy_s = 165.0, 212.0
    dxf.add_text(cx_s, cy_s + 0.5 * g.h_mm * sc_s + 14.0,
                 f"2. SECTION 1-1 (SCALE 1:{1.0/sc_s:.1f})", 3.5, "9_GHI_CHU", align=1)
    b_s, h_s = g.b_mm * sc_s, g.h_mm * sc_s
    cov_s = g.cover_mm * sc_s
    if g.section_type == "COL_CIRC_H":
        dxf.add_circle(cx_s, cy_s, 0.5 * b_s, "1_NET_BAO_BT")
        dxf.add_circle(cx_s, cy_s, 0.5 * b_s - cov_s, "4_COT_DAI")
    else:
        dxf.add_rect(cx_s - 0.5 * b_s, cy_s - 0.5 * h_s, b_s, h_s, "1_NET_BAO_BT")
        dxf.add_rect(cx_s - 0.5 * b_s + cov_s, cy_s - 0.5 * h_s + cov_s, b_s - 2 * cov_s, h_s - 2 * cov_s, "4_COT_DAI")
    _draw_steel_section_dxf(dxf, cx_s, cy_s, sc_s, g, "2_THEP_HINH_H")
    for yr, zr, dia in props.rebar_coords:
        dxf.add_circle(cx_s + zr * sc_s, cy_s + yr * sc_s, max(1.1, 0.5 * dia * sc_s), "3_COT_THEP_DOC")
    dxf.add_dim_horizontal(cx_s - 0.5 * b_s, cx_s + 0.5 * b_s, cy_s - 0.5 * h_s, cy_s - 0.5 * h_s - 10.0, f"b={g.b_mm:.0f}")
    dxf.add_dim_vertical(cx_s + 0.5 * b_s, cx_s + 0.5 * b_s + 10.0, cy_s - 0.5 * h_s, cy_s + 0.5 * h_s, f"h={g.h_mm:.0f}")

    # 3. CHI TIẾT BẢN ĐẾ CHÂN CỘT (BASEPLATE PLAN VIEW) — góc trên phải
    cx_b, cy_b = 318.0, 212.0
    bp_w_mm = g.b_mm + 120.0
    bp_h_mm = g.h_mm + 120.0
    sc_b = min(76.0 / bp_w_mm, 76.0 / bp_h_mm)
    bw_s, bh_s = bp_w_mm * sc_b, bp_h_mm * sc_b
    dxf.add_text(cx_b, cy_b + 0.5 * bh_s + 14.0,
                 f"3. BASEPLATE DETAIL PL30x{bp_w_mm:.0f}x{bp_h_mm:.0f}", 3.5, "9_GHI_CHU", align=1)
    dxf.add_rect(cx_b - 0.5 * bw_s, cy_b - 0.5 * bh_s, bw_s, bh_s, "6_BAN_DE_LIEN_KET")
    _draw_steel_section_dxf(dxf, cx_b, cy_b, sc_b, g, "2_THEP_HINH_H")
    # 8 bu-lông neo M24 quanh chu vi bản đế
    for bx_f, by_f in [(-0.38, -0.38), (0.0, -0.38), (0.38, -0.38), (0.38, 0.0), (0.38, 0.38), (0.0, 0.38), (-0.38, 0.38), (-0.38, 0.0)]:
        dxf.add_circle(cx_b + bx_f * bw_s, cy_b + by_f * bh_s, 1.8, "6_BAN_DE_LIEN_KET")
    dxf.add_dim_horizontal(cx_b - 0.5 * bw_s, cx_b + 0.5 * bw_s, cy_b - 0.5 * bh_s, cy_b - 0.5 * bh_s - 10.0, f"Bbp={bp_w_mm:.0f}")

    # 4. BẢNG THỐNG KÊ VẬT LIỆU (BOM / BBS) — vùng dưới giữa
    sched = compute_material_schedule(analysis, lang="en")
    bx, by = 112.0, 128.0
    dxf.add_text(bx, by + 6.0, "4. BILL OF MATERIALS & FABRICATION SCHEDULE (BOM / BBS)", 3.3, "9_GHI_CHU")
    col_w = [18.0, 114.0, 36.0, 30.0, 30.0]
    row_h = 8.5
    tot_w = sum(col_w)
    dxf.add_rect(bx, by - row_h * (len(sched) + 2), tot_w, row_h * (len(sched) + 2), "9_GHI_CHU")
    cx_t = bx
    for w_c, h_txt in zip(col_w, ["MARK", "DESCRIPTION / SPECIFICATION", "GRADE", "QTY", "MASS (kg)"]):
        dxf.add_text(cx_t + 2.0, by - 6.0, h_txt, 2.5, "9_GHI_CHU")
        cx_t += w_c
    dxf.add_line(bx, by - row_h, bx + tot_w, by - row_h, "9_GHI_CHU")
    steel_mass = 0.0
    for idx, item in enumerate(sched):
        ry = by - row_h * (idx + 2)
        if item["mark"] != "C-1":
            steel_mass += item["weight_kg"]
        cx_t = bx
        for w_c, val in zip(col_w, [item["mark"], item["desc"], item["grade"], item["qty"], f"{item['weight_kg']:.1f}"]):
            dxf.add_text(cx_t + 2.0, ry + 2.5, str(val)[:48], 2.35, "9_GHI_CHU")
            cx_t += w_c
        dxf.add_line(bx, ry, bx + tot_w, ry, "9_GHI_CHU")
    ry_tot = by - row_h * (len(sched) + 2)
    dxf.add_text(bx + 2.0, ry_tot + 2.5, f"TOTAL STEEL CORE + REBAR + BASEPLATE: {steel_mass:.1f} kg ({steel_mass/1000:.3f} t)", 2.55, "9_GHI_CHU")

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(dxf.to_string())
    return out_path


# ==============================================================================
# XUẤT BẢN VẼ KỸ THUẬT VECTOR PDF (KHỔ A3 NGANG — REPORTLAB + DEJAVU UNICODE)
# ==============================================================================

def _register_unicode_fonts() -> Tuple[str, str]:
    """Đăng ký phông chữ Unicode hỗ trợ tiếng Việt có dấu (DejaVuSans / Arial) cho ReportLab."""
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont

    candidates = [
        (r"C:\Windows\Fonts\arial.ttf", r"C:\Windows\Fonts\arialbd.ttf", "VN_Sans", "VN_SansBold"),
        (r"C:\Windows\Fonts\times.ttf", r"C:\Windows\Fonts\timesbd.ttf", "VN_Sans", "VN_SansBold"),
    ]
    for reg, bold, n_reg, n_bold in candidates:
        if os.path.exists(reg) and os.path.exists(bold):
            try:
                pdfmetrics.getFont(n_reg)
            except KeyError:
                pdfmetrics.registerFont(TTFont(n_reg, reg))
                pdfmetrics.registerFont(TTFont(n_bold, bold))
            return n_reg, n_bold
    return "Helvetica", "Helvetica-Bold"


def _render_drawing_pdf(analysis: Dict[str, object], out_path: str, lang: str = "vi") -> str:
    """
    Kết xuất trực tiếp bản vẽ kỹ thuật gia công & thi công vector sắc nét khổ A3 ngang (.PDF)
    cho cả Dầm và Cột bê tông cốt cứng, hỗ trợ song ngữ Tiếng Việt / Tiếng Anh.
    """
    from reportlab.pdfgen import canvas as rl_canvas
    from reportlab.lib.pagesizes import A3, landscape
    from reportlab.lib.units import mm
    from reportlab.lib import colors

    font_reg, font_bold = _register_unicode_fonts()
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    page_w, page_h = landscape(A3)  # 420 x 297 mm
    c = rl_canvas.Canvas(out_path, pagesize=(page_w, page_h))

    is_beam = analysis["member_kind"] == "beam"
    cfg = analysis["config"]
    g = cfg.geometry
    props = analysis["props"]
    checks = analysis["design_checks"]

    # Khung bản vẽ A3 & khung tên chuyên nghiệp
    c.setStrokeColor(colors.HexColor("#0F172A"))
    c.setLineWidth(1.4)
    c.rect(10 * mm, 8 * mm, 402 * mm, 281 * mm)
    c.setLineWidth(0.6)
    c.rect(12 * mm, 10 * mm, 398 * mm, 277 * mm)

    # Khung tên góc dưới phải
    tx, ty = 242 * mm, 10 * mm
    c.setFillColor(colors.HexColor("#F8FAFC"))
    c.rect(tx, ty, 168 * mm, 42 * mm, fill=1, stroke=1)
    c.setFillColor(colors.HexColor("#0F3D6E"))
    c.rect(tx, ty + 31 * mm, 168 * mm, 11 * mm, fill=1, stroke=0)
    c.setFillColor(colors.white)
    c.setFont(font_bold, 8.5)
    hdr_txt = "ĐH BÁCH KHOA - ĐHQG TP.HCM | GVHD: PGS.TS NGÔ HỮU CƯỜNG | HVTH: VÕ THANH VANG (2670624)" if lang == "vi" else "HCMUT (VNU-HCM) | ADVISOR: ASSOC. PROF. DR. NGO HUU CUONG | VO THANH VANG (2670624)"
    c.setFont(font_bold, 6.8)
    c.drawString(tx + 3 * mm, ty + 34.8 * mm, hdr_txt)

    c.setFillColor(colors.HexColor("#0F172A"))
    c.setFont(font_bold, 9.5)
    title_txt = (
        (f"DẦM BÊ TÔNG CỐT CỨNG — L={cfg.span_mm:.0f} mm | {g.b_mm:.0f}×{g.h_mm:.0f} mm" if lang == "vi" else f"SRC COMPOSITE BEAM — L={cfg.span_mm:.0f} mm | {g.b_mm:.0f}×{g.h_mm:.0f} mm")
        if is_beam else
        (f"CỘT BÊ TÔNG CỐT CỨNG — H={cfg.height_mm:.0f} mm | {g.b_mm:.0f}×{g.h_mm:.0f} mm" if lang == "vi" else f"SRC COMPOSITE COLUMN — H={cfg.height_mm:.0f} mm | {g.b_mm:.0f}×{g.h_mm:.0f} mm")
    )
    c.drawString(tx + 4 * mm, ty + 23.0 * mm, title_txt)
    c.setFont(font_reg, 7.8)
    c.drawString(tx + 4 * mm, ty + 14.5 * mm, f"EC4 (EN 1994-1-1) | ANSI/AISC 360-22 | JGJ 138-2016 | TCVN 5574/5575")
    c.drawString(tx + 4 * mm, ty + 5.5 * mm, (f"Vật liệu: {cfg.material.concrete_grade} | {cfg.material.steel_grade} | {cfg.material.rebar_grade}" if lang == "vi" else f"Materials: {cfg.material.concrete_grade} | {cfg.material.steel_grade} | {cfg.material.rebar_grade}"))
    c.setStrokeColor(colors.HexColor("#0F172A"))
    c.line(tx, ty + 19.5 * mm, tx + 168 * mm, ty + 19.5 * mm)
    c.line(tx, ty + 11.0 * mm, tx + 168 * mm, ty + 11.0 * mm)
    c.line(tx + 128 * mm, ty, tx + 128 * mm, ty + 31 * mm)
    c.setFont(font_bold, 8.5)
    c.drawCentredString(tx + 148 * mm, ty + 23.0 * mm, "SRC-B1" if is_beam else "SRC-C1")
    c.setFont(font_reg, 7.5)
    c.drawCentredString(tx + 148 * mm, ty + 14.0 * mm, "A3 | mm")
    status_ok = checks["overall_pass"]
    c.setFillColor(colors.HexColor("#059669") if status_ok else colors.HexColor("#DC2626"))
    c.setFont(font_bold, 8.5)
    c.drawCentredString(tx + 148 * mm, ty + 4.5 * mm, ("ĐẠT / PASS" if status_ok else "CHƯA ĐẠT / NG"))

    # Helper vẽ thép hình mặt cắt ngang trên PDF
    def draw_steel_pdf(cx_pt: float, cy_pt: float, sc_pt: float) -> None:
        yc = cy_pt + g.core_offset_y_mm * sc_pt
        ha = g.ha_mm * sc_pt
        ba = g.ba_mm * sc_pt
        tf = g.tf_mm * sc_pt
        tw = g.tw_mm * sc_pt
        c.setFillColor(colors.HexColor("#DC2626"))
        c.setStrokeColor(colors.HexColor("#7F1D1D"))
        c.setLineWidth(0.8)
        if g.section_type == "COL_RECT_CFST":
            c.setLineWidth(max(1.5, tf))
            c.setStrokeColor(colors.HexColor("#DC2626"))
            c.circle(cx_pt, yc, 0.5 * ha - 0.5 * tf, fill=0, stroke=1)
            return
        # Cánh dưới, cánh trên, bản bụng chữ H
        c.rect(cx_pt - 0.5 * ba, yc - 0.5 * ha, ba, tf, fill=1, stroke=1)
        c.rect(cx_pt - 0.5 * ba, yc + 0.5 * ha - tf, ba, tf, fill=1, stroke=1)
        c.rect(cx_pt - 0.5 * tw, yc - 0.5 * ha + tf, tw, ha - 2 * tf, fill=1, stroke=1)
        if g.section_type == "COL_RECT_CROSS_H":
            c.rect(cx_pt - 0.5 * ha, yc - 0.5 * ba, tf, ba, fill=1, stroke=1)
            c.rect(cx_pt + 0.5 * ha - tf, yc - 0.5 * ba, tf, ba, fill=1, stroke=1)
            c.rect(cx_pt - 0.5 * ha + tf, yc - 0.5 * tw, ha - 2 * tf, tw, fill=1, stroke=1)

    if is_beam:
        # 1. Mặt đứng dọc dầm
        ex0, ey0 = 26 * mm, 190 * mm
        sc_e = min((225 * mm) / max(1000.0, cfg.span_mm), (48 * mm) / max(200.0, g.h_mm))
        el_l, el_h = cfg.span_mm * sc_e, g.h_mm * sc_e
        c.setFillColor(colors.HexColor("#0F3D6E"))
        c.setFont(font_bold, 10)
        c.drawString(ex0, ey0 + el_h + 12 * mm,
                     f"1. MẶT ĐỨNG DỌC DẦM BÊ TÔNG CỐT CỨNG (L = {cfg.span_mm:.0f} mm)" if lang == "vi" else f"1. SRC BEAM LONGITUDINAL ELEVATION (L = {cfg.span_mm:.0f} mm)")
        c.setFillColor(colors.HexColor("#E2E8F0"))
        c.setStrokeColor(colors.HexColor("#0F172A"))
        c.setLineWidth(1.1)
        c.rect(ex0, ey0, el_l, el_h, fill=1, stroke=1)
        if g.section_type == "SRC_T_SLAB_H":
            c.setFillColor(colors.HexColor("#CBD5E1"))
            c.rect(ex0, ey0 + el_h - g.hf_slab_mm * sc_e, el_l, g.hf_slab_mm * sc_e, fill=1, stroke=1)

        yc_e = ey0 + 0.5 * el_h + g.core_offset_y_mm * sc_e
        ha_e = g.ha_mm * sc_e
        tf_e = max(1.8, g.tf_mm * sc_e)
        c.setFillColor(colors.HexColor("#FCA5A5"))
        c.setStrokeColor(colors.HexColor("#B91C1C"))
        c.rect(ex0, yc_e - 0.5 * ha_e, el_l, ha_e, fill=1, stroke=1)
        c.setFillColor(colors.HexColor("#DC2626"))
        c.rect(ex0, yc_e - 0.5 * ha_e, el_l, tf_e, fill=1, stroke=0)
        c.rect(ex0, yc_e + 0.5 * ha_e - tf_e, el_l, tf_e, fill=1, stroke=0)

        # Cốt đai & cốt dọc & đinh chống cắt
        cov_e = (g.cover_mm + g.stirrup_dia_mm) * sc_e
        c.setStrokeColor(colors.HexColor("#0284C7"))
        c.setLineWidth(0.6)
        xp = 80.0
        while xp < cfg.span_mm - 40.0:
            in_end = xp <= 0.25 * cfg.span_mm or xp >= 0.75 * cfg.span_mm
            c.line(ex0 + xp * sc_e, ey0 + cov_e, ex0 + xp * sc_e, ey0 + el_h - cov_e)
            xp += g.stirrup_spacing_end_mm if in_end else g.stirrup_spacing_mm
        c.setStrokeColor(colors.HexColor("#15803D"))
        c.setLineWidth(1.5)
        c.line(ex0 + 4, ey0 + cov_e, ex0 + el_l - 4, ey0 + cov_e)
        c.line(ex0 + 4, ey0 + el_h - cov_e, ex0 + el_l - 4, ey0 + el_h - cov_e)

        c.setStrokeColor(colors.HexColor("#7E22CE"))
        c.setLineWidth(1.1)
        stx = 120.0
        sh_e = max(5.0, cfg.stud_height_mm * sc_e)
        while stx < cfg.span_mm - 80.0:
            sx = ex0 + stx * sc_e
            c.line(sx, yc_e + 0.5 * ha_e, sx, yc_e + 0.5 * ha_e + sh_e)
            c.line(sx - 2.2, yc_e + 0.5 * ha_e + sh_e, sx + 2.2, yc_e + 0.5 * ha_e + sh_e)
            stx += max(100.0, cfg.stud_spacing_mm)

        # Kích thước dầm
        c.setStrokeColor(colors.HexColor("#334155"))
        c.setFillColor(colors.HexColor("#0F172A"))
        c.setLineWidth(0.7)
        c.setFont(font_reg, 8)
        c.line(ex0, ey0 - 11 * mm, ex0 + el_l, ey0 - 11 * mm)
        c.drawCentredString(ex0 + 0.5 * el_l, ey0 - 9.5 * mm, f"L = {cfg.span_mm:.0f} mm (Đai vùng gối @{g.stirrup_spacing_end_mm:.0f} / giữa nhịp @{g.stirrup_spacing_mm:.0f} | Đinh neo Ø{cfg.stud_dia_mm:.0f}@{cfg.stud_spacing_mm:.0f})")

        # 2. Mặt cắt ngang 1-1
        cx_s, cy_s = 335 * mm, 212 * mm
        sc_s = min((95 * mm) / max(300.0, g.bf_slab_mm if g.section_type == "SRC_T_SLAB_H" else g.b_mm),
                   (78 * mm) / max(250.0, g.h_mm))
        c.setFillColor(colors.HexColor("#0F3D6E"))
        c.setFont(font_bold, 10)
        c.drawCentredString(cx_s, cy_s + 0.5 * g.h_mm * sc_s + 12 * mm,
                            "2. MẶT CẮT NGANG 1–1 (CHI TIẾT CẤU TẠO)" if lang == "vi" else "2. CROSS-SECTION 1–1 (DETAIL)")
        b_s, h_s = g.b_mm * sc_s, g.h_mm * sc_s
        c.setFillColor(colors.HexColor("#E2E8F0"))
        c.setStrokeColor(colors.HexColor("#0F172A"))
        c.setLineWidth(1.2)
        c.rect(cx_s - 0.5 * b_s, cy_s - 0.5 * h_s, b_s, h_s, fill=1, stroke=1)
        if g.section_type == "SRC_T_SLAB_H":
            bf_s, hf_s = g.bf_slab_mm * sc_s, g.hf_slab_mm * sc_s
            c.rect(cx_s - 0.5 * bf_s, cy_s + 0.5 * h_s - hf_s, bf_s, hf_s, fill=1, stroke=1)
        cov_s = g.cover_mm * sc_s
        c.setStrokeColor(colors.HexColor("#0284C7"))
        c.setLineWidth(1.2)
        c.rect(cx_s - 0.5 * b_s + cov_s, cy_s - 0.5 * h_s + cov_s, b_s - 2 * cov_s, h_s - 2 * cov_s, fill=0, stroke=1)
        draw_steel_pdf(cx_s, cy_s, sc_s)
        c.setFillColor(colors.HexColor("#15803D"))
        for yr, zr, dia in props.rebar_coords:
            c.circle(cx_s + zr * sc_s, cy_s + yr * sc_s, max(2.2, 0.5 * dia * sc_s), fill=1, stroke=0)
        c.setFillColor(colors.HexColor("#0F172A"))
        c.setFont(font_reg, 8)
        c.drawCentredString(cx_s, cy_s - 0.5 * h_s - 7 * mm, f"b = {g.b_mm:.0f} mm × h = {g.h_mm:.0f} mm | H{g.ha_mm:.0f}×{g.ba_mm:.0f}×{g.tw_mm:.0f}×{g.tf_mm:.0f}")
    else:
        # 1. Mặt đứng cột
        sc_e = min((180 * mm) / max(1500.0, cfg.height_mm), (42 * mm) / max(200.0, g.b_mm))
        cw, ch = g.b_mm * sc_e, cfg.height_mm * sc_e
        cx_e, ey0 = 56 * mm, 48 * mm
        c.setFillColor(colors.HexColor("#0F3D6E"))
        c.setFont(font_bold, 10)
        c.drawCentredString(cx_e, ey0 + ch + 10 * mm, "1. MẶT ĐỨNG CỘT SRC" if lang == "vi" else "1. SRC COLUMN ELEVATION")
        c.setFillColor(colors.HexColor("#E2E8F0"))
        c.setStrokeColor(colors.HexColor("#0F172A"))
        c.rect(cx_e - 0.5 * cw, ey0, cw, ch, fill=1, stroke=1)
        ha_e = g.ha_mm * sc_e
        c.setFillColor(colors.HexColor("#FCA5A5"))
        c.setStrokeColor(colors.HexColor("#B91C1C"))
        c.rect(cx_e - 0.5 * ha_e, ey0, ha_e, ch, fill=1, stroke=1)
        c.setFillColor(colors.HexColor("#1E40AF"))
        c.rect(cx_e - 0.5 * cw - 6 * mm, ey0 - 4 * mm, cw + 12 * mm, 4 * mm, fill=1, stroke=1)
        cov_e = g.cover_mm * sc_e
        c.setStrokeColor(colors.HexColor("#0284C7"))
        c.setLineWidth(0.6)
        yp = 80.0
        while yp < cfg.height_mm - 50.0:
            in_end = yp <= 0.2 * cfg.height_mm or yp >= 0.8 * cfg.height_mm
            c.line(cx_e - 0.5 * cw + cov_e, ey0 + yp * sc_e, cx_e + 0.5 * cw - cov_e, ey0 + yp * sc_e)
            yp += g.stirrup_spacing_end_mm if in_end else g.stirrup_spacing_mm
        c.setFillColor(colors.HexColor("#0F172A"))
        c.setFont(font_reg, 8)
        c.drawCentredString(cx_e, ey0 - 11 * mm, f"H = {cfg.height_mm:.0f} mm | b×h = {g.b_mm:.0f}×{g.h_mm:.0f}")

        # 2. Mặt cắt ngang 1-1 cột
        cx_s, cy_s = 168 * mm, 208 * mm
        sc_s = min((74 * mm) / max(200.0, g.b_mm), (74 * mm) / max(200.0, g.h_mm))
        b_s, h_s = g.b_mm * sc_s, g.h_mm * sc_s
        cov_s = g.cover_mm * sc_s
        c.setFillColor(colors.HexColor("#0F3D6E"))
        c.setFont(font_bold, 10)
        c.drawCentredString(cx_s, cy_s + 0.5 * h_s + 11 * mm, "2. MẶT CẮT NGANG 1–1" if lang == "vi" else "2. CROSS-SECTION 1–1")
        c.setFillColor(colors.HexColor("#E2E8F0"))
        c.setStrokeColor(colors.HexColor("#0F172A"))
        if g.section_type == "COL_CIRC_H":
            c.circle(cx_s, cy_s, 0.5 * b_s, fill=1, stroke=1)
            c.setStrokeColor(colors.HexColor("#0284C7"))
            c.circle(cx_s, cy_s, 0.5 * b_s - cov_s, fill=0, stroke=1)
        else:
            c.rect(cx_s - 0.5 * b_s, cy_s - 0.5 * h_s, b_s, h_s, fill=1, stroke=1)
            c.setStrokeColor(colors.HexColor("#0284C7"))
            c.rect(cx_s - 0.5 * b_s + cov_s, cy_s - 0.5 * h_s + cov_s, b_s - 2 * cov_s, h_s - 2 * cov_s, fill=0, stroke=1)
        draw_steel_pdf(cx_s, cy_s, sc_s)
        c.setFillColor(colors.HexColor("#15803D"))
        for yr, zr, dia in props.rebar_coords:
            c.circle(cx_s + zr * sc_s, cy_s + yr * sc_s, max(2.2, 0.5 * dia * sc_s), fill=1, stroke=0)
        c.setFillColor(colors.HexColor("#0F172A"))
        c.setFont(font_reg, 8)
        c.drawCentredString(cx_s, cy_s - 0.5 * h_s - 7 * mm, f"{g.b_mm:.0f}×{g.h_mm:.0f} mm | ρa={props.steel_ratio*100:.2f}%, ρs={props.rebar_ratio*100:.2f}%")

        # 3. Mặt bằng bản đế chân cột
        cx_b, cy_b = 315 * mm, 208 * mm
        bp_w, bp_h = g.b_mm + 120.0, g.h_mm + 120.0
        sc_b = min((72 * mm) / bp_w, (72 * mm) / bp_h)
        bw_s, bh_s = bp_w * sc_b, bp_h * sc_b
        c.setFillColor(colors.HexColor("#0F3D6E"))
        c.setFont(font_bold, 10)
        c.drawCentredString(cx_b, cy_b + 0.5 * bh_s + 11 * mm,
                            f"3. CHI TIẾT BẢN ĐẾ PL30×{bp_w:.0f}×{bp_h:.0f}" if lang == "vi" else f"3. BASEPLATE DETAIL PL30×{bp_w:.0f}×{bp_h:.0f}")
        c.setFillColor(colors.HexColor("#DBEAFE"))
        c.setStrokeColor(colors.HexColor("#1E40AF"))
        c.rect(cx_b - 0.5 * bw_s, cy_b - 0.5 * bh_s, bw_s, bh_s, fill=1, stroke=1)
        draw_steel_pdf(cx_b, cy_b, sc_b)
        c.setFillColor(colors.HexColor("#1E3A8A"))
        for bxf, byf in [(-0.38, -0.38), (0.0, -0.38), (0.38, -0.38), (0.38, 0.0), (0.38, 0.38), (0.0, 0.38), (-0.38, 0.38), (-0.38, 0.0)]:
            c.circle(cx_b + bxf * bw_s, cy_b + byf * bh_s, 3.0, fill=1, stroke=0)

    # BẢNG THỐNG KÊ VẬT LIỆU (BOM / BBS)
    sched = compute_material_schedule(analysis, lang=lang)
    bx = (20 if is_beam else 108) * mm
    by = 128 * mm
    c.setFillColor(colors.HexColor("#0F3D6E"))
    c.setFont(font_bold, 9.5)
    c.drawString(bx, by + 5 * mm,
                 "3. BẢNG THỐNG KÊ THÉP HÌNH, CỐT THÉP & VẬT LIỆU CHẾ TẠO (BOM / BBS)" if lang == "vi" else "3. BILL OF MATERIALS & FABRICATION SCHEDULE (BOM / BBS)")
    col_ws = [18 * mm, 106 * mm, 34 * mm, 30 * mm, 26 * mm]
    rh = 7.8 * mm
    hdrs = (["SH", "HẠNG MỤC / QUY CÁCH", "MÁC VL", "SỐ LƯỢNG", "KL (kg)"] if lang == "vi" else ["MARK", "SPECIFICATION", "GRADE", "QTY", "MASS (kg)"])
    c.setFillColor(colors.HexColor("#0F3D6E"))
    c.rect(bx, by - rh, sum(col_ws), rh, fill=1, stroke=1)
    c.setFillColor(colors.white)
    c.setFont(font_bold, 7.6)
    cx_t = bx
    for w_c, h_txt in zip(col_ws, hdrs):
        c.drawString(cx_t + 2 * mm, by - rh + 2.4 * mm, h_txt)
        cx_t += w_c

    steel_tot = 0.0
    for idx, item in enumerate(sched):
        ry = by - (idx + 2) * rh
        if item["mark"] != "C-1":
            steel_tot += item["weight_kg"]
        c.setFillColor(colors.HexColor("#F8FAFC") if idx % 2 else colors.white)
        c.setStrokeColor(colors.HexColor("#CBD5E1"))
        c.rect(bx, ry, sum(col_ws), rh, fill=1, stroke=1)
        c.setFillColor(colors.HexColor("#0F172A"))
        c.setFont(font_reg, 7.4)
        cx_t = bx
        for w_c, val in zip(col_ws, [item["mark"], item["desc"], item["grade"], item["qty"], f"{item['weight_kg']:.1f}"]):
            c.drawString(cx_t + 2 * mm, ry + 2.4 * mm, str(val))
            cx_t += w_c

    ry_sum = by - (len(sched) + 2) * rh
    c.setFillColor(colors.HexColor("#E0F2FE"))
    c.rect(bx, ry_sum, sum(col_ws), rh, fill=1, stroke=1)
    c.setFillColor(colors.HexColor("#0F3D6E"))
    c.setFont(font_bold, 7.8)
    sum_lbl = (f"TỔNG KHỐI LƯỢNG THÉP GIA CÔNG (THÉP HÌNH + CỐT THÉP + PHỤ KIỆN): {steel_tot:.1f} kg ({steel_tot/1000:.3f} tấn)"
               if lang == "vi" else
               f"TOTAL FABRICATED STEEL MASS (PROFILE + REBAR + HARDWARE): {steel_tot:.1f} kg ({steel_tot/1000:.3f} t)")
    c.drawString(bx + 2 * mm, ry_sum + 2.4 * mm, sum_lbl)

    c.showPage()
    c.save()
    return out_path


def export_beam_drawing_pdf(analysis: Dict[str, object], out_path: str, lang: str = "vi") -> str:
    """Xuất bản vẽ kỹ thuật gia công & thi công Dầm cốt cứng dạng vector PDF khổ A3 ngang."""
    return _render_drawing_pdf(analysis, out_path, lang=lang)


def export_column_drawing_pdf(analysis: Dict[str, object], out_path: str, lang: str = "vi") -> str:
    """Xuất bản vẽ kỹ thuật gia công & thi công Cột cốt cứng dạng vector PDF khổ A3 ngang."""
    return _render_drawing_pdf(analysis, out_path, lang=lang)
