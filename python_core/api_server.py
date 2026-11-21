# -*- coding: utf-8 -*-
"""
================================================================================
MÔ-ĐUN 8: MÁY CHỦ API CỤC BỘ (HTTP JSON) KẾT NỐI LÕI PYTHON VỚI GIAO DIỆN FLUTTER
================================================================================
Chức năng khối:
  Cung cấp dịch vụ HTTP nhẹ chạy trên `127.0.0.1:<port>` (dùng thư viện chuẩn
  `http.server` để đóng gói gọn nhẹ và siêu ổn định):
    - GET  /api/health          : Kiểm tra trạng thái lõi tính toán Python SRC/CES.
    - POST /api/analyze_beam    : Phân tích phi tuyến & thiết kế đa tiêu chuẩn Dầm SRC.
    - POST /api/analyze_column  : Phân tích phi tuyến P-δ & thiết kế đa tiêu chuẩn Cột SRC.
    - POST /api/export          : Xuất thuyết minh Word/PDF (VI/EN) hoặc bản vẽ DXF/PDF.
================================================================================
"""

from __future__ import annotations
import argparse
import base64
import json
import os
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Dict

from .materials import MaterialConfig
from .section_fiber import SectionGeometry
from .beam_solver import SrcBeamConfig, solve_src_beam_nonlinear
from .column_solver import SrcColumnConfig, solve_src_column_nonlinear
from .probe_dissection import dissect_section_2d, probe_member_point
from .cad_exporter import export_beam_dxf, export_column_dxf, export_beam_drawing_pdf, export_column_drawing_pdf
from .report_exporter import (
    export_beam_report_docx, export_beam_report_pdf,
    export_column_report_docx, export_column_report_pdf,
)


def _geom_from_dict(d: Dict[str, Any]) -> SectionGeometry:
    defaults = SectionGeometry().__dict__
    merged = {k: d.get(k, v) for k, v in defaults.items()}
    return SectionGeometry(**merged)


def _mat_from_dict(d: Dict[str, Any]) -> MaterialConfig:
    defaults = MaterialConfig().__dict__
    merged = {k: d.get(k, v) for k, v in defaults.items()}
    return MaterialConfig(**merged)


def _beam_cfg_from_dict(p: Dict[str, Any]) -> SrcBeamConfig:
    cfg = SrcBeamConfig()
    if "geometry" in p:
        cfg.geometry = _geom_from_dict(p["geometry"])
    if "material" in p:
        cfg.material = _mat_from_dict(p["material"])
    for key in (
        "name", "span_mm", "load_type", "q_udl_kn_m", "p_point_kn", "load_a_mm",
        "left_support", "right_support", "stud_dia_mm", "stud_height_mm",
        "stud_fu_mpa", "stud_spacing_mm", "stud_rows", "n_elems", "n_steps_design",
        "push_to_ultimate", "deflection_limit_ratio",
    ):
        if key in p:
            setattr(cfg, key, p[key])
    return cfg


def _col_cfg_from_dict(p: Dict[str, Any]) -> SrcColumnConfig:
    cfg = SrcColumnConfig()
    if "geometry" in p:
        cfg.geometry = _geom_from_dict(p["geometry"])
    if "material" in p:
        cfg.material = _mat_from_dict(p["material"])
    for key in (
        "name", "height_mm", "k_eff_z", "k_eff_y", "loading_mode", "n_ed_kn",
        "mz_ed_knm", "my_ed_knm", "use_eccentricity_input", "ez_mm", "ey_mm",
        "moment_ratio_r", "v_ed_kn", "imperfection_ratio", "n_elems",
        "n_steps_design", "push_to_ultimate",
    ):
        if key in p:
            setattr(cfg, key, p[key])
    return cfg


def _serialize_analysis(res: Dict[str, Any]) -> Dict[str, Any]:
    """Chuyển kết quả phân tích sang JSON gọn sạch để trả về giao diện Flutter."""
    is_beam = res["member_kind"] == "beam"
    dis = dissect_section_2d(res, x_norm=0.5)
    out = {
        "member_kind": res["member_kind"],
        "props": {
            "ag_mm2": res["props"].ag_mm2,
            "ac_mm2": res["props"].ac_mm2,
            "aa_mm2": res["props"].aa_mm2,
            "as_mm2": res["props"].as_mm2,
            "steel_ratio": res["props"].steel_ratio,
            "rebar_ratio": res["props"].rebar_ratio,
            "vol_stirrup_ratio": res["props"].vol_stirrup_ratio,
        },
        "confinement": {
            "kp": res["conf"].kp,
            "kh": res["conf"].kh,
            "eta_hsc": res["conf"].eta_hsc,
        },
        "history": res["history"],
        "design_checks": res["design_checks"],
        "mid_dissection": dis,
    }
    if is_beam:
        out.update({
            "max_defl_linear_mm": res["max_defl_linear_mm"],
            "max_defl_design_mm": res["max_defl_design_mm"],
            "m_ed_knm": res["m_ed_knm"],
            "v_ed_kn": res["v_ed_kn"],
            "p_ultimate_kn": res["p_ultimate_kn"],
            "m_ultimate_fem_knm": res["m_ultimate_fem_knm"],
            "ductility_mu": res["ductility_mu"],
            "span_profiles": res["span_profiles"],
            "mk_curve": res["mk_curve"],
        })
    else:
        out.update({
            "n_ultimate_fem_kn": res["n_ultimate_fem_kn"],
            "m_ultimate_fem_knm": res["m_ultimate_fem_knm"],
            "lat_defl_design_mm": res["lat_defl_design_mm"],
            "axial_short_design_mm": res["axial_short_design_mm"],
            "p_delta_amp_fem": res["p_delta_amp_fem"],
            "height_profiles": res["height_profiles"],
            "nm_z_nominal": res["nm_z_nominal"],
            "nm_z_design": res["nm_z_design"],
        })
    return out


class SrcApiHandler(BaseHTTPRequestHandler):
    """Bộ xử lý yêu cầu HTTP JSON của lõi tính toán SRC/CES Python."""

    def _send_json(self, obj: Dict[str, Any], code: int = 200) -> None:
        raw = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:
        if self.path == "/api/health":
            self._send_json({"status": "ok", "engine": "SRC-CES Python Nonlinear Core v1.0"})
        else:
            self._send_json({"error": "Not found"}, code=404)

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length > 0 else b"{}"
        try:
            payload = json.loads(body.decode("utf-8"))
        except Exception as exc:
            self._send_json({"error": f"Invalid JSON: {exc}"}, code=400)
            return

        try:
            if self.path == "/api/analyze_beam":
                res = solve_src_beam_nonlinear(_beam_cfg_from_dict(payload))
                self._send_json(_serialize_analysis(res))
            elif self.path == "/api/analyze_column":
                res = solve_src_column_nonlinear(_col_cfg_from_dict(payload))
                self._send_json(_serialize_analysis(res))
            elif self.path == "/api/export":
                kind = payload.get("member_kind", "beam")
                fmt = payload.get("format", "docx")
                lang = payload.get("lang", "vi")
                res = solve_src_beam_nonlinear(_beam_cfg_from_dict(payload)) if kind == "beam" else solve_src_column_nonlinear(_col_cfg_from_dict(payload))
                ext = "dxf" if fmt == "dxf" else ("docx" if fmt == "docx" else "pdf")
                with tempfile.NamedTemporaryFile(suffix=f".{ext}", delete=False) as tf:
                    tmp_path = tf.name
                try:
                    if fmt == "docx":
                        (export_beam_report_docx if kind == "beam" else export_column_report_docx)(res, tmp_path, lang=lang)
                    elif fmt == "report_pdf":
                        (export_beam_report_pdf if kind == "beam" else export_column_report_pdf)(res, tmp_path, lang=lang)
                    elif fmt == "dxf":
                        (export_beam_dxf if kind == "beam" else export_column_dxf)(res, tmp_path, lang=lang)
                    else:
                        (export_beam_drawing_pdf if kind == "beam" else export_column_drawing_pdf)(res, tmp_path, lang=lang)
                    with open(tmp_path, "rb") as f:
                        b64 = base64.b64encode(f.read()).decode("ascii")
                    self._send_json({"ok": True, "format": fmt, "lang": lang, "base64": b64})
                finally:
                    if os.path.exists(tmp_path):
                        os.remove(tmp_path)
            else:
                self._send_json({"error": "Unknown endpoint"}, code=404)
        except Exception as exc:
            self._send_json({"error": str(exc)}, code=500)


def main() -> None:
    parser = argparse.ArgumentParser(description="SRC-CES Python Nonlinear API Server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    srv = ThreadingHTTPServer((args.host, args.port), SrcApiHandler)
    print(f"[SRC-CES Python API] Listening on http://{args.host}:{args.port}")
    srv.serve_forever()


if __name__ == "__main__":
    main()
