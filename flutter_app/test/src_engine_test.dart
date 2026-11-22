import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:src_ces_studio/core/i18n.dart';
import 'package:src_ces_studio/core/src_cad_exporter.dart';
import 'package:src_ces_studio/core/src_engine.dart';
import 'package:src_ces_studio/core/src_report_exporter.dart';
import 'package:src_ces_studio/main.dart';

void main() {
  group('SRC-CES Nonlinear Dart Core Verification', () {
    test('SRC T-Slab Beam solves cleanly with 4 codes and passes equilibrium', () {
      final cfg = SrcLibraries.beamPresets().first.cfg;
      final res = SrcNonlinearEngine.solve(cfg);
      expect(res.codeChecks.length, 4);
      expect(res.ultimateMomentKnm, greaterThan(res.demandPrimary));
      expect(res.mkCurve.length, greaterThan(10));
      expect(res.overallPass, isTrue);

      final dis = SrcNonlinearEngine.dissectSection(res, 0.5);
      expect((dis.mzKnm - res.demandPrimary).abs() / res.demandPrimary, lessThan(0.05));
      expect((dis.steelSharePct + dis.concreteSharePct + dis.rebarSharePct - 100.0).abs(), lessThan(0.2));
      expect(dis.bondPerimeterMm, greaterThan(500.0));
      // Kiểm tra vị trí gần gối x/L = 0.10 nơi lực trượt mặt tiếp xúc & đinh neo lớn nhất
      final disEnd = SrcNonlinearEngine.dissectSection(res, 0.10);
      expect(disEnd.vInterfaceKnPerM, greaterThan(10.0));
      expect(disEnd.tauBondMpa, greaterThan(0.01));
      expect(disEnd.studForceKn, greaterThan(1.0));
      expect(disEnd.slipMm, greaterThanOrEqualTo(0.0));
      // Kiểm tra mô phỏng động theo tiến trình 5 giai đoạn (Đàn hồi → Nứt → Phi tuyến → Đứt gãy kết thúc)
      final disUlt = SrcNonlinearEngine.dissectSectionAtUltimateFrac(res, 0.15, 1.0);
      expect(disUlt.epsMin, lessThan(disEnd.epsMin));
      expect(disUlt.bondStatusLevel, 2);
      final failCurve = SrcNonlinearEngine.computeFailurePathCurve(res);
      expect(failCurve.length, 33);
      expect(failCurve.last.stage, 5);
      expect(failCurve.last.loadRatio, lessThan(0.85)); // Nhánh suy giảm sau đỉnh tới đứt gãy!
      final curve = SrcNonlinearEngine.computeLoadRedistributionCurve(res, 0.5);
      expect(curve.length, 16);
      final p = SrcNonlinearEngine.probePoint(res, 0.5, -200.0, 0.0);
      expect(p.sigmaXMpa.isFinite, isTrue);
    });

    test('SRC Columns (Concentric, Uniaxial, Biaxial, CE-CFST) solve cleanly & classify Elastic/Nonlinear/Fracture regimes', () {
      for (final preset in SrcLibraries.columnPresets()) {
        final res = SrcNonlinearEngine.solve(preset.cfg);
        expect(res.codeChecks.length, 4);
        expect(res.nmDesignCurve.length, greaterThan(10));
        expect(res.ec4Polygon.length, 5);
        expect(res.ultimateLoadKn, greaterThan(1000.0));

        // Kiểm chứng ngưỡng chuyển vùng Đàn hồi → Vượt đàn hồi / Phi tuyến → Đứt gãy cho từng loại Cột
        final th = SrcNonlinearEngine.computeRegimeThresholds(res);
        expect(th.elasticLoadKn, greaterThan(0.0));
        expect(th.elasticLoadKn, lessThan(th.peakLoadKn));
        expect(th.yieldLoadKn, lessThanOrEqualTo(th.peakLoadKn));

        final pEl = (th.elasticProg * 0.50).clamp(0.05, 0.16);
        final disEl = SrcNonlinearEngine.dissectSectionAtUltimateFrac(res, 0.5, pEl);
        final regEl = SrcNonlinearEngine.classifySectionRegime(res, disEl, progress: pEl);
        expect(regEl.regimeCode, 0);
        expect(regEl.badgeVi, contains('VÙNG ĐÀN HỒI'));

        final pNl = (th.yieldProg + th.peakProg) * 0.5;
        final pNlSafe = pNl > 0.80 ? 0.80 : (pNl < th.yieldProg ? th.yieldProg : pNl);
        final disNl = SrcNonlinearEngine.dissectSectionAtUltimateFrac(res, 0.5, pNlSafe);
        final regNl = SrcNonlinearEngine.classifySectionRegime(res, disNl, progress: pNlSafe);
        expect(regNl.regimeCode, 1);
        expect(regNl.badgeVi, contains('VƯỢT'));

        final disFr = SrcNonlinearEngine.dissectSectionAtUltimateFrac(res, 0.5, 1.0);
        final regFr = SrcNonlinearEngine.classifySectionRegime(res, disFr, progress: 1.0);
        expect(regFr.regimeCode, 2);
        expect(regFr.badgeVi, contains('ĐỨT GÃY'));
      }
    });

    test('Experimental benchmarks match published test results within tolerance', () {
      final jiang = SrcNonlinearEngine.solve(
        SrcLibraries.beamPresets().firstWhere((p) => p.id == 'jiang_2024').cfg,
      );
      expect((jiang.ultimateMomentKnm - 1022.0).abs() / 1022.0, lessThan(0.15));

      final cs1 = SrcNonlinearEngine.solve(
        SrcLibraries.columnPresets().firstWhere((p) => p.id == 'chen_lin_cs1').cfg,
      );
      expect((cs1.ultimateLoadKn - 1650.0).abs() / 1650.0, lessThan(0.15));

      final c100e50 = SrcNonlinearEngine.solve(
        SrcLibraries.columnPresets().firstWhere((p) => p.id == 'huang_c100e50').cfg,
      );
      expect((c100e50.ultimateLoadKn - 3686.7).abs() / 3686.7, lessThan(0.15));
    });

    test('AutoCAD DXF and Bilingual VI/EN Word DOCX export valid outputs', () {
      final resBeam = SrcNonlinearEngine.solve(SrcLibraries.beamPresets().first.cfg);
      final dxf = SrcCadExporter.buildDxfString(resBeam);
      expect(dxf, contains('SECTION'));
      expect(dxf, contains('2_THEP_HINH_H'));
      expect(dxf, contains('EOF'));

      final docxVi = SrcReportExporter.buildDocxBytes(resBeam, AppLang.vi);
      final docxEn = SrcReportExporter.buildDocxBytes(resBeam, AppLang.en);
      expect(docxVi.length, greaterThan(1000));
      expect(docxEn.length, greaterThan(1000));
      // PK zip header for valid .docx archive
      expect(docxVi[0], 0x50);
      expect(docxVi[1], 0x4B);
    });

    testWidgets('UI renders cleanly on Desktop, Tablet (Pad 8 Pro) & Phone (13T Pro)', (tester) async {
      // Desktop size
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const SrcCesStudioApp());
      await tester.pumpAndSettle();
      expect(find.text('SRC–CES Nonlinear Studio'), findsOneWidget);
      expect(find.text('Mô phỏng 3D'), findsOneWidget);
      expect(find.textContaining('Trường Đại học Bách Khoa'), findsOneWidget);
      expect(find.textContaining('PGS.TS Ngô Hữu Cường'), findsOneWidget);
      expect(find.textContaining('PGS.TS Ngô Cường'), findsNothing);
      expect(find.text('Tác giả'), findsOneWidget);

      // Mở hộp thoại Thông tin Tác giả kiểm tra đủ GVHD (PGS.TS Ngô Hữu Cường), Email & Phone
      await tester.tap(find.text('Tác giả'));
      await tester.pumpAndSettle();
      expect(find.text('Giảng viên hướng dẫn: PGS.TS Ngô Hữu Cường'), findsOneWidget);
      expect(find.textContaining('PGS.TS Ngô Cường'), findsNothing);
      expect(find.text('Email: vothanhvang@gmail.com'), findsWidgets);
      expect(find.text('Phone: 0973.993.494'), findsWidgets);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      // Kiểm tra tab 2D & Phẫu thuật — Chế độ 0 (5 giai đoạn: Đàn hồi → Nứt → Phi tuyến → Cực hạn → Đứt gãy)
      await tester.tap(find.text('2D & Phẫu thuật'));
      await tester.pumpAndSettle();
      expect(find.textContaining('GĐ1 Đàn hồi'), findsOneWidget);
      expect(find.textContaining('GĐ5 Đứt gãy'), findsOneWidget);
      expect(find.textContaining('Khuếch đại'), findsOneWidget);
      expect(find.textContaining('PHÍA LÕI THÉP HÌNH'), findsOneWidget);
      await tester.tap(find.text('×100'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GĐ5 Đứt gãy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ĐỨT GÃY'), findsWidgets);

      // Chuyển sang CỘT CỐT CỨNG để kiểm tra nhãn Đàn hồi / Vượt đàn hồi – Phi tuyến / Đứt gãy ở cả 2 chế độ Phẫu thuật
      await tester.tap(find.text('Cột Cốt Cứng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GĐ1 Đàn hồi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('TRONG VÙNG ĐÀN HỒI'), findsWidgets);
      await tester.tap(find.text('GĐ3 Phi tuyến'));
      await tester.pumpAndSettle();
      expect(find.textContaining('VƯỢT NGOÀI VÙNG ĐÀN HỒI – VÙNG PHI TUYẾN'), findsWidgets);
      await tester.tap(find.text('GĐ5 Đứt gãy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ĐỨT GÃY – PHÁ HOẠI KẾT THÚC'), findsWidgets);

      // Chuyển sang Chế độ 1 (Toàn cấu kiện 2D & Phẫu thuật Khảo sát Tự do) trên Cột
      await tester.tap(find.textContaining('Toàn cấu kiện 2D'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ỨNG XỬ LIÊN KẾT CỐT CỨNG'), findsOneWidget);
      await tester.tap(find.text('● Đàn hồi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('TRONG VÙNG ĐÀN HỒI'), findsWidgets);
      await tester.tap(find.text('▲ Phi tuyến'));
      await tester.pumpAndSettle();
      expect(find.textContaining('VƯỢT'), findsWidgets);
      await tester.tap(find.text('✕ Đứt gãy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ĐỨT GÃY'), findsWidgets);

      // Quay lại Chế độ 0 để kiểm tra trên điện thoại 412px
      await tester.tap(find.textContaining('Mô phỏng Chi tiết Tương tác'));
      await tester.pumpAndSettle();

      // Kiểm tra tab Lý thuyết & Code (các công thức đầy đủ dấu căn thức)
      await tester.tap(find.text('Lý thuyết & Code'));
      await tester.pumpAndSettle();
      expect(find.textContaining('THÔNG TIN TÁC GIẢ'), findsWidgets);

      // Phone size (Xiaomi 13T Pro logical viewport ~412x915)
      tester.view.physicalSize = const Size(412, 915);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.tune), findsOneWidget);
      await tester.ensureVisible(find.text('2D & Phẫu thuật'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2D & Phẫu thuật'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PHÍA LÕI THÉP HÌNH'), findsOneWidget);
    });
  });
}
