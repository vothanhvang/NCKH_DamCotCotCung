# -*- coding: utf-8 -*-
"""
================================================================================
GÓI LÕI TÍNH TOÁN PHI TUYẾN & THIẾT KẾ KẾT CẤU BÊ TÔNG CỐT CỨNG (SRC / CES)
================================================================================
Đề tài Nghiên cứu Khoa học Cấp Quốc gia:
    "Phân tích phi tuyến, thiết kế đa tiêu chuẩn và mô phỏng 2D/3D kiểu ANSYS
     cho dầm và cột bê tông cốt cứng (Concrete-Encased Steel / SRC)"

Cấu trúc các mô-đun chức năng (Architecture Map):
  1. materials.py              : Mô hình vật liệu phi tuyến 3 vùng giam giữ bê tông
                                 (Unconfined / Partially Confined / Highly Confined),
                                 hệ số giòn bê tông cường độ cao (Lai & Liew 2019),
                                 thép hình & cốt thép đàn-dẻo tái bền, thư viện mác vật liệu.
  2. section_fiber.py          : Rời rạc hóa lưới thớ 2D (2D Fiber Section) cho dầm
                                 (chữ nhật, chữ T có bản sàn) và cột (chữ H, chữ thập,
                                 cột tròn, CFST bọc bê tông); tính [D_t] 3x3, đường cong
                                 M-κ và biểu đồ tương tác N-M / N-My-Mz.
  3. beam_solver.py            : Giải PTHH dầm thớ phi tuyến (Rayleigh-Ritz + Gauss 3 điểm
                                 + Full Newton-Raphson thích nghi 4 giai đoạn cơ học) và
                                 kiểm tra thiết kế đa tiêu chuẩn (EC4, AISC 360-22, JGJ 138,
                                 TCVN/SP 266, SMARTCOCO, Weng 2002 cắt tách dọc).
  4. column_solver.py          : Giải PTHH cột dầm phi tuyến vật liệu + hình học (P-δ
                                 Corotational UL + khuyết tật ban đầu e_imp) chịu nén đúng
                                 tâm & nén lệch tâm 1 phương / 2 phương; kiểm tra đa tiêu
                                 chuẩn (EC4 §6.7, AISC 360-22 §I2/I5, JGJ 138, Lai-Liew 2019).
  5. probe_dissection.py       : Khảo sát điểm bất kỳ (x/L, y, z) & Phẫu thuật mặt cắt ngang /
                                 mặt cắt dọc (ứng suất pháp, biến dạng, ứng suất cắt, von Mises).
  6. cad_exporter.py           : Xuất bản vẽ gia công, chế tạo & thi công chuyên nghiệp định
                                 dạng AutoCAD (.DXF đa lớp R2000) và bản vẽ vector PDF (.PDF)
                                 kèm bảng thống kê thép hình, cốt thép, đinh chống cắt.
  7. report_exporter.py        : Xuất thuyết minh tính toán chuyên nghiệp Word (.DOCX) và
                                 PDF (.PDF) song ngữ Tiếng Việt / Tiếng Anh (tùy chọn).
  8. api_server.py             : Máy chủ HTTP JSON cục bộ phục vụ kết nối giao diện Flutter.
  9. benchmarks_verification.py: Bộ kiểm chứng tự động 8 trụ cột khoa học đối chiếu nghiệm
                                 giải tích và thí nghiệm thực tế (Huang-Liew 2018, Lai 2019,
                                 Chen-Lin 2006, Wang 2024, Jiang 2024).
================================================================================
"""

from .materials import (
    ConcreteZone,
    MaterialConfig,
    CONCRETE_LIBRARY,
    STEEL_GRADE_LIBRARY,
    REBAR_GRADE_LIBRARY,
    STEEL_PROFILE_LIBRARY,
    compute_confinement_params,
    concrete_stress_tangent,
    steel_stress_tangent,
)
from .section_fiber import (
    FiberCell,
    SectionGeometry,
    SectionResponse,
    build_2d_fiber_section,
    evaluate_section_2d,
    compute_moment_curvature,
    compute_nm_interaction_fiber,
)
from .beam_solver import (
    SrcBeamConfig,
    solve_src_beam_nonlinear,
    design_check_src_beam,
    get_beam_presets,
)
from .column_solver import (
    SrcColumnConfig,
    solve_src_column_nonlinear,
    design_check_src_column,
    get_column_presets,
)
from .probe_dissection import (
    probe_member_point,
    dissect_section_2d,
    dissect_longitudinal_slice,
)
from .cad_exporter import (
    export_beam_dxf,
    export_column_dxf,
    export_beam_drawing_pdf,
    export_column_drawing_pdf,
)
from .report_exporter import (
    export_beam_report_docx,
    export_beam_report_pdf,
    export_column_report_docx,
    export_column_report_pdf,
)

__all__ = [
    "ConcreteZone",
    "MaterialConfig",
    "CONCRETE_LIBRARY",
    "STEEL_GRADE_LIBRARY",
    "REBAR_GRADE_LIBRARY",
    "STEEL_PROFILE_LIBRARY",
    "compute_confinement_params",
    "concrete_stress_tangent",
    "steel_stress_tangent",
    "FiberCell",
    "SectionGeometry",
    "SectionResponse",
    "build_2d_fiber_section",
    "evaluate_section_2d",
    "compute_moment_curvature",
    "compute_nm_interaction_fiber",
    "SrcBeamConfig",
    "solve_src_beam_nonlinear",
    "design_check_src_beam",
    "get_beam_presets",
    "SrcColumnConfig",
    "solve_src_column_nonlinear",
    "design_check_src_column",
    "get_column_presets",
    "probe_member_point",
    "dissect_section_2d",
    "dissect_longitudinal_slice",
    "export_beam_dxf",
    "export_column_dxf",
    "export_beam_drawing_pdf",
    "export_column_drawing_pdf",
    "export_beam_report_docx",
    "export_beam_report_pdf",
    "export_column_report_docx",
    "export_column_report_pdf",
]
