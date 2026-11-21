// ============================================================================
// MÔ-ĐUN XUẤT THUYẾT MINH TÍNH TOÁN WORD (.DOCX), PDF (.PDF) & CSV SONG NGỮ
// TIẾNG VIỆT / TIẾNG ANH (TÙY CHỌN) — CHẠY NGOẠI TUYẾN ĐA NỀN TẢNG
// ============================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'i18n.dart';
import 'src_engine.dart';
import 'file_saver_stub.dart'
    if (dart.library.io) 'file_saver_io.dart'
    if (dart.library.js_interop) 'file_saver_web.dart';

class SrcReportExporter {
  static String _xmlEsc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _wPara(
    String text, {
    bool bold = false,
    bool italic = false,
    int sz = 22,
    String color = '0F172A',
    String align = 'left',
    int before = 40,
    int after = 70,
  }) {
    final b = bold ? '<w:b/>' : '';
    final it = italic ? '<w:i/>' : '';
    return '<w:p><w:pPr><w:jc w:val="$align"/><w:spacing w:before="$before" w:after="$after"/></w:pPr>'
        '<w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>$b$it<w:color w:val="$color"/><w:sz w:val="$sz"/></w:rPr>'
        '<w:t xml:space="preserve">${_xmlEsc(text)}</w:t></w:r></w:p>';
  }

  static String _wTable(List<String> headers, List<List<String>> rows) {
    final sb = StringBuffer()
      ..write('<w:tbl><w:tblPr><w:tblW w:w="9500" w:type="dxa"/><w:tblBorders>'
          '<w:top w:val="single" w:sz="6" w:space="0" w:color="0F3D6E"/>'
          '<w:bottom w:val="single" w:sz="8" w:space="0" w:color="0F3D6E"/>'
          '<w:left w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>'
          '<w:right w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>'
          '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>'
          '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>'
          '</w:tblBorders></w:tblPr><w:tr>');
    for (final h in headers) {
      sb.write('<w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="0F3D6E"/></w:tcPr>'
          '${_wPara(h, bold: true, sz: 18, color: "FFFFFF", align: "center", before: 25, after: 25)}</w:tc>');
    }
    sb.write('</w:tr>');
    for (int r = 0; r < rows.length; r++) {
      final fill = r.isOdd ? 'F8FAFC' : 'FFFFFF';
      sb.write('<w:tr>');
      for (int c = 0; c < rows[r].length; c++) {
        sb.write('<w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="$fill"/></w:tcPr>'
            '${_wPara(rows[r][c], sz: 18, align: c == 0 ? "left" : "right", before: 20, after: 20)}</w:tc>');
      }
      sb.write('</w:tr>');
    }
    sb.write('</w:tbl><w:p><w:pPr><w:spacing w:after="60"/></w:pPr></w:p>');
    return sb.toString();
  }

  static List<List<String>> _paramRows(SrcAnalysisResult res, AppLang lang) {
    final cfg = res.config;
    final g = cfg.geometry;
    final m = cfg.material;
    final p = res.props;
    final isBeam = cfg.kind == MemberKind.beam;
    return [
      [tr(lang, 'Cấu kiện / Bài toán', 'Member / Case'), cfg.name],
      [tr(lang, 'Loại tiết diện', 'Section Type'), g.sectionType],
      [
        tr(lang, 'Kích thước bê tông b × h (mm)', 'Concrete Section b × h (mm)'),
        '${g.bMm.toStringAsFixed(0)} × ${g.hMm.toStringAsFixed(0)}'
            '${g.sectionType == 'SRC_T_SLAB_H' ? ' (Slab ${g.bfSlabMm.toStringAsFixed(0)}×${g.hfSlabMm.toStringAsFixed(0)})' : ''}',
      ],
      [tr(lang, 'Chiều dài nhịp / chiều cao L (mm)', 'Span / Column Height L (mm)'), cfg.lengthMm.toStringAsFixed(0)],
      [
        tr(lang, 'Lõi thép hình cốt cứng', 'Encased Steel Core'),
        'H${g.haMm.toStringAsFixed(0)}×${g.baMm.toStringAsFixed(0)}×${g.twMm.toStringAsFixed(1)}×${g.tfMm.toStringAsFixed(1)} '
            '(Aa=${p.aaMm2.toStringAsFixed(0)} mm², ρa=${(p.steelRatio * 100).toStringAsFixed(2)}%)',
      ],
      [
        tr(lang, 'Cốt thép dọc & Cốt đai', 'Rebar & Stirrups'),
        '${p.rebars.length} bars (As=${p.asMm2.toStringAsFixed(0)} mm², ρs=${(p.rebarRatio * 100).toStringAsFixed(2)}%) | Ø${g.stirrupDiaMm.toStringAsFixed(0)} @${g.stirrupSpacingEndMm.toStringAsFixed(0)}/${g.stirrupSpacingMm.toStringAsFixed(0)}',
      ],
      [
        tr(lang, 'Bê tông (3 vùng giam giữ)', 'Concrete (3-Zone Confinement)'),
        '${m.concreteGrade} (f\'c=${m.fcMpa.toStringAsFixed(1)}, Ec=${m.ecMpa.toStringAsFixed(0)} MPa) | Kp=${res.conf.kp.toStringAsFixed(2)}, Kh=${res.conf.kh.toStringAsFixed(2)}, ηHSC=${res.conf.etaHsc.toStringAsFixed(2)}',
      ],
      [
        tr(lang, 'Thép hình & Cốt thép', 'Steel & Rebar Grades'),
        '${m.steelGrade} (fy=${m.fySteelMpa.toStringAsFixed(0)} MPa) | ${m.rebarGrade} (fyr=${m.fyRebarMpa.toStringAsFixed(0)} MPa)',
      ],
      if (isBeam)
        [
          tr(lang, 'Nội lực & Độ võng thiết kế', 'Design Demand & Deflection'),
          'M_Ed=${res.demandPrimary.toStringAsFixed(1)} kN·m, V_Ed=${res.demandSecondary.toStringAsFixed(1)} kN | δ_NL=${res.deflDesignMm.toStringAsFixed(2)} mm (Limit=${res.deflLimitMm.toStringAsFixed(2)} mm)',
        ]
      else
        [
          tr(lang, 'Nội lực nén & Mô-men bậc 1 / bậc 2', 'Axial Load & 1st / 2nd Order Moment'),
          'N_Ed=${res.demandPrimary.toStringAsFixed(0)} kN, M_z,I=${res.demandFirstOrderM.toStringAsFixed(1)} kN·m (ez=${res.ezEffMm.toStringAsFixed(1)}mm) → M_z,II=${res.demandSecondary.toStringAsFixed(1)} kN·m',
        ],
    ];
  }

  static List<List<String>> _codeRows(SrcAnalysisResult res, AppLang lang) {
    final isBeam = res.config.kind == MemberKind.beam;
    return [
      for (final c in res.codeChecks)
        [
          c.title,
          c.capacityPrimary.toStringAsFixed(1),
          c.capacitySecondary.toStringAsFixed(1),
          c.urTotal.toStringAsFixed(3),
          c.extraNote,
          c.pass ? tr(lang, 'ĐẠT', 'PASS') : tr(lang, 'KHÔNG ĐẠT', 'FAIL'),
        ],
      [
        tr(lang, 'PTHH Thớ 2D Phi tuyến (Cực hạn danh định)', 'Nonlinear 2D Fiber FEM (Nominal Ultimate)'),
        (isBeam ? res.ultimateMomentKnm : res.ultimateLoadKn).toStringAsFixed(1),
        (isBeam ? res.ultimateLoadKn : res.ultimateMomentKnm).toStringAsFixed(1),
        (res.demandPrimary / (isBeam ? res.ultimateMomentKnm : res.ultimateLoadKn).clamp(1.0, 1e9)).toStringAsFixed(3),
        isBeam ? 'μ=${res.ductilityMu.toStringAsFixed(2)}' : 'P-δ=${res.pDeltaAmp.toStringAsFixed(2)}',
        res.overallPass ? tr(lang, 'ĐẠT', 'PASS') : tr(lang, 'KIỂM TRA', 'CHECK'),
      ],
    ];
  }

  static const _refs = [
    '[1] EN 1994-1-1:2004 (Eurocode 4) — Design of composite steel and concrete structures (§6.2, §6.6, §6.7).',
    '[2] European Commission RFCS SMARTCOCO (EUR 28914 EN, 2018) — Concrete Structures Reinforced by Steel Profiles.',
    '[3] ANSI/AISC 360-22 — Specification for Structural Steel Buildings, Chapter I: Composite Members.',
    '[4] JGJ 138-2016 — Code for Design of Composite Structures (China, Chapters 5 & 6).',
    '[5] TCVN 5574:2018, TCVN 5575:2024, TCVN 11823-6:2017 & SP 266.1325800.2016.',
    '[6] Lai, B., Liew, J.Y.R., & Xiong, M. (2019). High-strength concrete encased steel short columns. CBM 228.',
    '[7] Huang, Z., Liew, J.Y.R. et al. (2018). VHSC-encased steel composite columns under axial & eccentric loads. ASCCS 2018.',
    '[8] Chen, C.C. & Lin, N.J. (2006). Analytical model for concrete-encased steel stub columns. JCSR 62(5):424–433.',
    '[9] Weng, C.C., Yen, S.I., & Jiang, M.H. (2002). Shear splitting failure of full-scale SRC beams. ASCE JSE.',
  ];

  /// Tạo tệp Microsoft Word (.DOCX) hoàn chỉnh song ngữ VI / EN
  static Uint8List buildDocxBytes(SrcAnalysisResult res, AppLang lang) {
    final isBeam = res.config.kind == MemberKind.beam;
    final vi = lang.isVi;
    final title = isBeam
        ? tr(lang, 'THUYẾT MINH TÍNH TOÁN & THIẾT KẾ PHI TUYẾN DẦM BÊ TÔNG CỐT CỨNG (SRC/CES)',
            'NONLINEAR ANALYSIS & MULTI-CODE DESIGN REPORT — SRC COMPOSITE BEAM')
        : tr(lang, 'THUYẾT MINH TÍNH TOÁN & THIẾT KẾ PHI TUYẾN CỘT BÊ TÔNG CỐT CỨNG (SRC/CES)',
            'NONLINEAR ANALYSIS & MULTI-CODE DESIGN REPORT — SRC COMPOSITE COLUMN');
    final instLine = tr(
      lang,
      'Trường Đại học Bách Khoa - Đại học Quốc Gia TP. Hồ Chí Minh - Giảng viên hướng dẫn: PGS.TS Ngô Cường - Học viên thực hiện: Võ Thanh Vang (2670624) - Email: vothanhvang@gmail.com - Phone: 0973.993.494',
      'Ho Chi Minh City University of Technology (VNU-HCM) - Advisor: Assoc. Prof. Dr. Ngo Cuong - Student: Vo Thanh Vang (2670624) - Email: vothanhvang@gmail.com - Phone: 0973.993.494',
    );
    final sub = tr(
      lang,
      'Đề tài Nghiên cứu Khoa học Cấp Quốc gia — Đối chiếu Eurocode 4, ANSI/AISC 360-22, JGJ 138-2016, TCVN/SP 266 & SMARTCOCO',
      'National Scientific Research Report — Multi-Code Verification (EC4, AISC 360-22, JGJ 138-2016, TCVN/SP 266 & SMARTCOCO)',
    );

    final body = StringBuffer()
      ..write(_wPara(instLine, bold: true, sz: 19, color: '1E3A8A', align: 'center', before: 0, after: 60))
      ..write(_wPara(title, bold: true, sz: 28, color: '0F3D6E', align: 'center', before: 40, after: 40))
      ..write(_wPara(sub, italic: true, sz: 20, color: '475569', align: 'center', before: 0, after: 140))
      ..write(_wPara(tr(lang, '1. THÔNG SỐ HÌNH HỌC, VẬT LIỆU & TẢI TRỌNG', '1. GEOMETRY, MATERIAL & LOADING PARAMETERS'),
          bold: true, sz: 24, color: '0F3D6E', before: 120, after: 60))
      ..write(_wTable([tr(lang, 'Thông số', 'Parameter'), tr(lang, 'Giá trị thiết kế', 'Design Value')], _paramRows(res, lang)))
      ..write(_wPara(tr(lang, '2. KẾT QUẢ PHÂN TÍCH PHI TUYẾN & KIỂM TRA ĐA TIÊU CHUẨN', '2. NONLINEAR FEM & MULTI-CODE DESIGN VERIFICATION'),
          bold: true, sz: 24, color: '0F3D6E', before: 120, after: 60))
      ..write(_wTable(
        isBeam
            ? [
                tr(lang, 'Tiêu chuẩn / Mô hình', 'Standard / Model'),
                'M_Rd (kN·m)',
                'V_Rd (kN)',
                'UR_max',
                tr(lang, 'Ghi chú kỹ thuật', 'Key Factor'),
                tr(lang, 'Kết luận', 'Verdict'),
              ]
            : [
                tr(lang, 'Tiêu chuẩn / Mô hình', 'Standard / Model'),
                'N_Rd (kN)',
                'M_cap (kN·m)',
                'UR_max',
                tr(lang, 'Độ mảnh / Hệ số', 'Slenderness / Factor'),
                tr(lang, 'Kết luận', 'Verdict'),
              ],
        _codeRows(res, lang),
      ))
      ..write(_wPara(tr(lang, '3. CƠ SỞ TOÁN HỌC & NHẬN XÉT KHOA HỌC', '3. GOVERNING MECHANICS & SCIENTIFIC ASSESSMENT'),
          bold: true, sz: 24, color: '0F3D6E', before: 120, after: 60))
      ..write(_wPara('• ${tr(lang, "Giả thiết tiết diện phẳng 2D: ε(y,z) = ε₀ − y·κ_z + z·κ_y; tích phân thớ phi tuyến 3 vùng giam giữ bê tông (Chen & Lin 2006): Kp=", "2D Euler-Bernoulli fiber strain: ε(y,z) = ε₀ − y·κ_z + z·κ_y; 3-zone concrete confinement (Chen & Lin 2006): Kp=")}${res.conf.kp.toStringAsFixed(2)}, Kh=${res.conf.kh.toStringAsFixed(2)}, η_HSC=${res.conf.etaHsc.toStringAsFixed(2)}.'))
      ..write(_wPara(isBeam
          ? '• ${tr(lang, "Kiểm tra cắt tách dọc Weng et al. (2002): bf/bw=", "Weng et al. (2002) shear splitting: bf/bw=")}${res.bfBwRatio.toStringAsFixed(2)}, V_split=${res.vSplitKn.toStringAsFixed(1)} kN | ${tr(lang, "Đinh chống cắt EC4 §6.6.3: PRd=", "Headed studs EC4 §6.6.3: PRd=")}${res.studPRdKn.toStringAsFixed(1)} kN (${res.studsReqHalf}/${res.studsProvHalf} / L/2).'
          : '• ${tr(lang, "Ổn định bậc hai P–δ (EC4 §6.7): δ=", "Second-order P–δ stability (EC4 §6.7): δ=")}${res.ec4DeltaSteel.toStringAsFixed(3)}, λ̄_z=${res.ec4LambdaZ.toStringAsFixed(3)}, χ_z=${res.ec4ChiZ.toStringAsFixed(3)}, k=${res.ec4KAmpZ.toStringAsFixed(3)} | Lai-Liew (2019) N_ana2=${res.laiLiewAna2Kn.toStringAsFixed(0)} kN.'))
      ..write(_wPara(
        res.overallPass
            ? tr(lang, 'KẾT LUẬN TỔNG QUÁT: TIẾT DIỆN ĐẠT YÊU CẦU CHỊU LỰC & SỬ DỤNG (PASS).', 'OVERALL VERDICT: DESIGN REQUIREMENTS SATISFIED (PASS).')
            : tr(lang, 'KẾT LUẬN TỔNG QUÁT: TIẾT DIỆN CHƯA ĐẠT — CẦN TĂNG TIẾT DIỆN HOẶC LÕI THÉP (FAIL).', 'OVERALL VERDICT: DESIGN CHECK FAILED — INCREASE STEEL CORE OR SECTION (FAIL).'),
        bold: true,
        sz: 23,
        color: res.overallPass ? '059669' : 'DC2626',
        before: 80,
        after: 100,
      ))
      ..write(_wPara(tr(lang, '4. BẢNG THỐNG KÊ THÉP HÌNH, CỐT THÉP & BÊ TÔNG CHẾ TẠO (BOM / BBS)', '4. BILL OF MATERIALS & FABRICATION SCHEDULE (BOM / BBS)'),
          bold: true, sz: 24, color: '0F3D6E', before: 100, after: 60))
      ..write(_wTable(
        vi ? const ['SH', 'Hạng mục', 'Mác VL', 'Số lượng', 'KL (kg)'] : const ['Mark', 'Description', 'Grade', 'Qty', 'Mass (kg)'],
        [
          for (final b in res.bom) [b.mark, vi ? b.descVi : b.descEn, b.grade, vi ? b.qtyVi : b.qtyEn, b.weightKg.toStringAsFixed(1)],
        ],
      ))
      ..write(_wPara(tr(lang, '5. TIÊU CHUẨN & TÀI LIỆU THAM KHẢO', '5. DESIGN CODES & SCIENTIFIC REFERENCES'),
          bold: true, sz: 24, color: '0F3D6E', before: 100, after: 50));
    for (final r in _refs) {
      body.write(_wPara(r, sz: 18, color: '334155', before: 15, after: 25));
    }

    final docXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>${body.toString()}<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1000" w:right="1000" w:bottom="1000" w:left="1100"/></w:sectPr></w:body></w:document>';

    const contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>';
    const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';

    final archive = Archive();
    void addXml(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addXml('[Content_Types].xml', contentTypes);
    addXml('_rels/.rels', rels);
    addXml('word/document.xml', docXml);
    final zipped = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipped);
  }

  static Future<String?> exportDocx(SrcAnalysisResult res, AppLang lang) async {
    final bytes = buildDocxBytes(res, lang);
    final tag = res.config.kind == MemberKind.beam ? 'DamCotCung' : 'CotCotCung';
    final prefix = lang.isVi ? 'ThuyetMinh' : 'Report';
    return saveBinaryFile(
      '${prefix}_${tag}_${lang.code.toUpperCase()}.docx',
      bytes,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
  }

  /// Xuất thuyết minh PDF chuẩn học thuật song ngữ VI / EN
  static Future<String?> exportPdf(SrcAnalysisResult res, AppLang lang) async {
    final fontReg = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final fontBold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    final isBeam = res.config.kind == MemberKind.beam;
    final vi = lang.isVi;
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        build: (ctx) => [
          pw.Center(
            child: pw.Text(
              tr(
                lang,
                'Trường Đại học Bách Khoa - Đại học Quốc Gia TP. Hồ Chí Minh - Giảng viên hướng dẫn: PGS.TS Ngô Cường - Học viên thực hiện: Võ Thanh Vang (2670624) - Email: vothanhvang@gmail.com - Phone: 0973.993.494',
                'Ho Chi Minh City University of Technology (VNU-HCM) - Advisor: Assoc. Prof. Dr. Ngo Cuong - Student: Vo Thanh Vang (2670624) - Email: vothanhvang@gmail.com - Phone: 0973.993.494',
              ),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 8.2, color: PdfColor.fromHex('#1E3A8A')),
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Center(
            child: pw.Text(
              isBeam
                  ? tr(lang, 'THUYẾT MINH TÍNH TOÁN & THIẾT KẾ PHI TUYẾN DẦM BÊ TÔNG CỐT CỨNG (SRC/CES)',
                      'NONLINEAR ANALYSIS & MULTI-CODE DESIGN REPORT — SRC BEAM')
                  : tr(lang, 'THUYẾT MINH TÍNH TOÁN & THIẾT KẾ PHI TUYẾN CỘT BÊ TÔNG CỐT CỨNG (SRC/CES)',
                      'NONLINEAR ANALYSIS & MULTI-CODE DESIGN REPORT — SRC COLUMN'),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColor.fromHex('#0F3D6E')),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              tr(lang, 'Báo cáo Nghiên cứu Khoa học Cấp Quốc gia — EC4 • ANSI/AISC 360-22 • JGJ 138 • TCVN/SP 266 • SMARTCOCO',
                  'National Scientific Research Report — EC4 • ANSI/AISC 360-22 • JGJ 138 • TCVN/SP 266 • SMARTCOCO'),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontReg, fontSize: 8.5, color: PdfColors.blueGrey600),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(tr(lang, '1. THÔNG SỐ HÌNH HỌC, VẬT LIỆU & TẢI TRỌNG', '1. GEOMETRY, MATERIAL & LOADING'),
              style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColor.fromHex('#0F3D6E'))),
          pw.SizedBox(height: 5),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.2, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F3D6E')),
            cellStyle: pw.TextStyle(font: fontReg, fontSize: 8.0),
            cellPadding: const pw.EdgeInsets.all(4),
            headers: [tr(lang, 'Thông số', 'Parameter'), tr(lang, 'Giá trị thiết kế', 'Design Value')],
            data: _paramRows(res, lang),
          ),
          pw.SizedBox(height: 12),
          pw.Text(tr(lang, '2. KẾT QUẢ PHÂN TÍCH PHI TUYẾN & KIỂM TRA ĐA TIÊU CHUẨN', '2. NONLINEAR FEM & MULTI-CODE CHECKS'),
              style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColor.fromHex('#0F3D6E'))),
          pw.SizedBox(height: 5),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 7.8, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F3D6E')),
            cellStyle: pw.TextStyle(font: fontReg, fontSize: 7.6),
            cellPadding: const pw.EdgeInsets.all(3.5),
            headers: isBeam
                ? [tr(lang, 'Tiêu chuẩn', 'Code'), 'M_Rd', 'V_Rd', 'UR', tr(lang, 'Ghi chú', 'Note'), tr(lang, 'KQ', 'Status')]
                : [tr(lang, 'Tiêu chuẩn', 'Code'), 'N_Rd', 'M_cap', 'UR', tr(lang, 'Độ mảnh/Hệ số', 'Factor'), tr(lang, 'KQ', 'Status')],
            data: _codeRows(res, lang),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: res.overallPass ? PdfColor.fromHex('#ECFDF5') : PdfColor.fromHex('#FEF2F2'),
              border: pw.Border.all(color: res.overallPass ? PdfColor.fromHex('#059669') : PdfColor.fromHex('#DC2626')),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              res.overallPass
                  ? tr(lang, 'KẾT LUẬN: TIẾT DIỆN ĐẠT YÊU CẦU CHỊU LỰC & SỬ DỤNG (PASS)', 'VERDICT: SECTION SATISFIES STRENGTH & SERVICEABILITY (PASS)')
                  : tr(lang, 'KẾT LUẬN: TIẾT DIỆN CHƯA ĐẠT — CẦN ĐIỀU CHỈNH KÍCH THƯỚC / LÕI THÉP (FAIL)', 'VERDICT: SECTION FAILS — INCREASE STEEL CORE OR DIMENSIONS (FAIL)'),
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 9.5,
                color: res.overallPass ? PdfColor.fromHex('#047857') : PdfColor.fromHex('#B91C1C'),
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(tr(lang, '3. BẢNG THỐNG KÊ THÉP HÌNH, CỐT THÉP & BÊ TÔNG (BOM / BBS)', '3. BILL OF MATERIALS (BOM / BBS)'),
              style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColor.fromHex('#0F3D6E'))),
          pw.SizedBox(height: 5),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.0, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F3D6E')),
            cellStyle: pw.TextStyle(font: fontReg, fontSize: 7.8),
            cellPadding: const pw.EdgeInsets.all(4),
            headers: vi ? const ['SH', 'Hạng mục', 'Mác VL', 'SL', 'KL (kg)'] : const ['Mark', 'Description', 'Grade', 'Qty', 'Mass (kg)'],
            data: [
              for (final b in res.bom) [b.mark, vi ? b.descVi : b.descEn, b.grade, vi ? b.qtyVi : b.qtyEn, b.weightKg.toStringAsFixed(1)],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(tr(lang, '4. TIÊU CHUẨN & TÀI LIỆU THAM KHẢO', '4. STANDARDS & REFERENCES'),
              style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColor.fromHex('#0F3D6E'))),
          pw.SizedBox(height: 4),
          for (final r in _refs)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(r, style: pw.TextStyle(font: fontReg, fontSize: 7.6, color: PdfColors.blueGrey700)),
            ),
        ],
      ),
    );

    final bytes = await doc.save();
    final tag = isBeam ? 'DamCotCung' : 'CotCotCung';
    final prefix = vi ? 'ThuyetMinh' : 'Report';
    return saveBinaryFile('${prefix}_${tag}_${lang.code.toUpperCase()}.pdf', Uint8List.fromList(bytes), 'application/pdf');
  }

  static Future<String?> exportCsv(SrcAnalysisResult res) async {
    final sb = StringBuffer()..writeln('step,lambda,load_kN,deflection_mm,moment_kNm,eps_c_min,sig_steel_max_MPa');
    for (int i = 0; i < res.history.length; i++) {
      final h = res.history[i];
      sb.writeln('$i,${h.lambda.toStringAsFixed(4)},${h.loadKn.toStringAsFixed(2)},${h.deflMm.toStringAsFixed(3)},'
          '${h.mMaxKnm.toStringAsFixed(2)},${h.epsCMin.toStringAsFixed(6)},${h.sigSteelMaxMpa.toStringAsFixed(2)}');
    }
    final tag = res.config.kind == MemberKind.beam ? 'DamCotCung' : 'CotCotCung';
    return saveBinaryFile('DuLieu_PhiTuyen_$tag.csv', Uint8List.fromList(utf8.encode(sb.toString())), 'text/csv');
  }
}
