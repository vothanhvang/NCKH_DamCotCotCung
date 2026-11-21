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
      final p = SrcNonlinearEngine.probePoint(res, 0.5, -200.0, 0.0);
      expect(p.sigmaXMpa.isFinite, isTrue);
    });

    test('SRC Columns (Concentric, Uniaxial, Biaxial, CE-CFST) solve cleanly', () {
      for (final preset in SrcLibraries.columnPresets()) {
        final res = SrcNonlinearEngine.solve(preset.cfg);
        expect(res.codeChecks.length, 4);
        expect(res.nmDesignCurve.length, greaterThan(10));
        expect(res.ec4Polygon.length, 5);
        expect(res.ultimateLoadKn, greaterThan(1000.0));
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

      // Phone size (Xiaomi 13T Pro logical viewport ~412x915)
      tester.view.physicalSize = const Size(412, 915);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.tune), findsOneWidget);
    });
  });
}
