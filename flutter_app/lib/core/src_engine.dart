// ============================================================================
// LÕI TÍNH TOÁN PHI TUYẾN & THIẾT KẾ ĐA TIÊU CHUẨN DẦM & CỘT BÊ TÔNG CỐT CỨNG
// (SRC / CES NONLINEAR FIBER FEM + P–δ + MULTI-CODE ENGINE — DART MIRROR)
// ============================================================================
// Đồng bộ toán học 1-1 với gói `python_core/` (materials, section_fiber,
// beam_solver, column_solver, probe_dissection) để chạy hoàn toàn ngoại tuyến
// tốc độ cao trên Windows .exe, Android APK (Xiaomi Pad 8 Pro & 13T Pro) và
// Web GitHub Pages!
// ============================================================================

import 'dart:convert';
import 'dart:math' as math;

enum MemberKind { beam, column }

enum ConcreteZone { unconfined, partiallyConfined, highlyConfined }

enum ContourField {
  stressSigmaX,
  strainEpsX,
  vonMises,
  momentOrAxial,
  deflection,
  confinementOrCrack,
}

class ConfinementParams {
  final double kp, kh;
  final double epsC0U, epsCuU;
  final double epsC0P, epsCuP;
  final double epsC0H, epsCuH;
  final double flP, flH, etaHsc;

  const ConfinementParams({
    required this.kp,
    required this.kh,
    required this.epsC0U,
    required this.epsCuU,
    required this.epsC0P,
    required this.epsCuP,
    required this.epsC0H,
    required this.epsCuH,
    required this.flP,
    required this.flH,
    required this.etaHsc,
  });
}

class MaterialConfig {
  final String concreteGrade;
  final double fcMpa;
  final double ecMpa;
  final double fctMpa;
  final double epsC0;
  final double epsCu;
  final double gammaC;

  final String steelGrade;
  final double fySteelMpa;
  final double fuSteelMpa;
  final double esSteelMpa;
  final double hardeningSteel;
  final double gammaA;

  final String rebarGrade;
  final double fyRebarMpa;
  final double esRebarMpa;
  final double hardeningRebar;
  final double gammaS;

  final double fyStirrupMpa;
  final bool useConfinement;
  final double creepCoeff;

  const MaterialConfig({
    this.concreteGrade = 'C35/45 (B40)',
    this.fcMpa = 35.0,
    this.ecMpa = 34000.0,
    this.fctMpa = 3.2,
    this.epsC0 = 0.0020,
    this.epsCu = 0.0035,
    this.gammaC = 1.50,
    this.steelGrade = 'S355 (Q355)',
    this.fySteelMpa = 355.0,
    this.fuSteelMpa = 490.0,
    this.esSteelMpa = 210000.0,
    this.hardeningSteel = 0.010,
    this.gammaA = 1.00,
    this.rebarGrade = 'CB400-V (B400)',
    this.fyRebarMpa = 400.0,
    this.esRebarMpa = 200000.0,
    this.hardeningRebar = 0.008,
    this.gammaS = 1.15,
    this.fyStirrupMpa = 300.0,
    this.useConfinement = true,
    this.creepCoeff = 0.0,
  });

  MaterialConfig copyWith({
    String? concreteGrade,
    double? fcMpa,
    double? ecMpa,
    double? fctMpa,
    String? steelGrade,
    double? fySteelMpa,
    double? fuSteelMpa,
    double? esSteelMpa,
    String? rebarGrade,
    double? fyRebarMpa,
    double? esRebarMpa,
    double? fyStirrupMpa,
    bool? useConfinement,
    double? creepCoeff,
  }) =>
      MaterialConfig(
        concreteGrade: concreteGrade ?? this.concreteGrade,
        fcMpa: fcMpa ?? this.fcMpa,
        ecMpa: ecMpa ?? this.ecMpa,
        fctMpa: fctMpa ?? this.fctMpa,
        epsC0: epsC0,
        epsCu: epsCu,
        gammaC: gammaC,
        steelGrade: steelGrade ?? this.steelGrade,
        fySteelMpa: fySteelMpa ?? this.fySteelMpa,
        fuSteelMpa: fuSteelMpa ?? this.fuSteelMpa,
        esSteelMpa: esSteelMpa ?? this.esSteelMpa,
        hardeningSteel: hardeningSteel,
        gammaA: gammaA,
        rebarGrade: rebarGrade ?? this.rebarGrade,
        fyRebarMpa: fyRebarMpa ?? this.fyRebarMpa,
        esRebarMpa: esRebarMpa ?? this.esRebarMpa,
        hardeningRebar: hardeningRebar,
        gammaS: gammaS,
        fyStirrupMpa: fyStirrupMpa ?? this.fyStirrupMpa,
        useConfinement: useConfinement ?? this.useConfinement,
        creepCoeff: creepCoeff ?? this.creepCoeff,
      );

  Map<String, dynamic> toJson() => {
        'concreteGrade': concreteGrade,
        'fcMpa': fcMpa,
        'ecMpa': ecMpa,
        'fctMpa': fctMpa,
        'steelGrade': steelGrade,
        'fySteelMpa': fySteelMpa,
        'fuSteelMpa': fuSteelMpa,
        'esSteelMpa': esSteelMpa,
        'rebarGrade': rebarGrade,
        'fyRebarMpa': fyRebarMpa,
        'esRebarMpa': esRebarMpa,
        'fyStirrupMpa': fyStirrupMpa,
        'useConfinement': useConfinement,
        'creepCoeff': creepCoeff,
      };

  factory MaterialConfig.fromJson(Map<String, dynamic> m) => MaterialConfig(
        concreteGrade: (m['concreteGrade'] ?? 'C35/45 (B40)') as String,
        fcMpa: (m['fcMpa'] as num? ?? 35.0).toDouble(),
        ecMpa: (m['ecMpa'] as num? ?? 34000.0).toDouble(),
        fctMpa: (m['fctMpa'] as num? ?? 3.2).toDouble(),
        steelGrade: (m['steelGrade'] ?? 'S355 (Q355)') as String,
        fySteelMpa: (m['fySteelMpa'] as num? ?? 355.0).toDouble(),
        fuSteelMpa: (m['fuSteelMpa'] as num? ?? 490.0).toDouble(),
        esSteelMpa: (m['esSteelMpa'] as num? ?? 210000.0).toDouble(),
        rebarGrade: (m['rebarGrade'] ?? 'CB400-V (B400)') as String,
        fyRebarMpa: (m['fyRebarMpa'] as num? ?? 400.0).toDouble(),
        esRebarMpa: (m['esRebarMpa'] as num? ?? 200000.0).toDouble(),
        fyStirrupMpa: (m['fyStirrupMpa'] as num? ?? 300.0).toDouble(),
        useConfinement: (m['useConfinement'] as bool?) ?? true,
        creepCoeff: (m['creepCoeff'] as num? ?? 0.0).toDouble(),
      );
}

class SectionGeometry {
  final String sectionType; // SRC_T_SLAB_H, SRC_RECT_H, COL_RECT_H, COL_RECT_CROSS_H, COL_CIRC_H, COL_RECT_CFST
  final double bMm;
  final double hMm;
  final double bfSlabMm;
  final double hfSlabMm;
  final double haMm;
  final double baMm;
  final double tfMm;
  final double twMm;
  final double coreOffsetYMm;
  final double coverMm;
  final double rebarDiaBotMm;
  final int nRebarBot;
  final double rebarDiaTopMm;
  final int nRebarTop;
  final int nRebarSideEach;
  final double stirrupDiaMm;
  final double stirrupSpacingMm;
  final double stirrupSpacingEndMm;
  final int nStirrupLegs;
  final int nyGrid;
  final int nzGrid;

  const SectionGeometry({
    this.sectionType = 'SRC_T_SLAB_H',
    this.bMm = 320.0,
    this.hMm = 600.0,
    this.bfSlabMm = 1200.0,
    this.hfSlabMm = 120.0,
    this.haMm = 300.0,
    this.baMm = 150.0,
    this.tfMm = 10.0,
    this.twMm = 7.0,
    this.coreOffsetYMm = -20.0,
    this.coverMm = 35.0,
    this.rebarDiaBotMm = 22.0,
    this.nRebarBot = 4,
    this.rebarDiaTopMm = 16.0,
    this.nRebarTop = 2,
    this.nRebarSideEach = 1,
    this.stirrupDiaMm = 10.0,
    this.stirrupSpacingMm = 150.0,
    this.stirrupSpacingEndMm = 100.0,
    this.nStirrupLegs = 2,
    this.nyGrid = 22,
    this.nzGrid = 12,
  });

  SectionGeometry copyWith({
    String? sectionType,
    double? bMm,
    double? hMm,
    double? bfSlabMm,
    double? hfSlabMm,
    double? haMm,
    double? baMm,
    double? tfMm,
    double? twMm,
    double? coreOffsetYMm,
    double? coverMm,
    double? rebarDiaBotMm,
    int? nRebarBot,
    double? rebarDiaTopMm,
    int? nRebarTop,
    int? nRebarSideEach,
    double? stirrupDiaMm,
    double? stirrupSpacingMm,
    double? stirrupSpacingEndMm,
    int? nStirrupLegs,
  }) =>
      SectionGeometry(
        sectionType: sectionType ?? this.sectionType,
        bMm: bMm ?? this.bMm,
        hMm: hMm ?? this.hMm,
        bfSlabMm: bfSlabMm ?? this.bfSlabMm,
        hfSlabMm: hfSlabMm ?? this.hfSlabMm,
        haMm: haMm ?? this.haMm,
        baMm: baMm ?? this.baMm,
        tfMm: tfMm ?? this.tfMm,
        twMm: twMm ?? this.twMm,
        coreOffsetYMm: coreOffsetYMm ?? this.coreOffsetYMm,
        coverMm: coverMm ?? this.coverMm,
        rebarDiaBotMm: rebarDiaBotMm ?? this.rebarDiaBotMm,
        nRebarBot: nRebarBot ?? this.nRebarBot,
        rebarDiaTopMm: rebarDiaTopMm ?? this.rebarDiaTopMm,
        nRebarTop: nRebarTop ?? this.nRebarTop,
        nRebarSideEach: nRebarSideEach ?? this.nRebarSideEach,
        stirrupDiaMm: stirrupDiaMm ?? this.stirrupDiaMm,
        stirrupSpacingMm: stirrupSpacingMm ?? this.stirrupSpacingMm,
        stirrupSpacingEndMm: stirrupSpacingEndMm ?? this.stirrupSpacingEndMm,
        nStirrupLegs: nStirrupLegs ?? this.nStirrupLegs,
        nyGrid: nyGrid,
        nzGrid: nzGrid,
      );

  Map<String, dynamic> toJson() => {
        'sectionType': sectionType,
        'bMm': bMm,
        'hMm': hMm,
        'bfSlabMm': bfSlabMm,
        'hfSlabMm': hfSlabMm,
        'haMm': haMm,
        'baMm': baMm,
        'tfMm': tfMm,
        'twMm': twMm,
        'coreOffsetYMm': coreOffsetYMm,
        'coverMm': coverMm,
        'rebarDiaBotMm': rebarDiaBotMm,
        'nRebarBot': nRebarBot,
        'rebarDiaTopMm': rebarDiaTopMm,
        'nRebarTop': nRebarTop,
        'nRebarSideEach': nRebarSideEach,
        'stirrupDiaMm': stirrupDiaMm,
        'stirrupSpacingMm': stirrupSpacingMm,
        'stirrupSpacingEndMm': stirrupSpacingEndMm,
        'nStirrupLegs': nStirrupLegs,
      };

  factory SectionGeometry.fromJson(Map<String, dynamic> m) => SectionGeometry(
        sectionType: (m['sectionType'] ?? 'SRC_T_SLAB_H') as String,
        bMm: (m['bMm'] as num? ?? 320.0).toDouble(),
        hMm: (m['hMm'] as num? ?? 600.0).toDouble(),
        bfSlabMm: (m['bfSlabMm'] as num? ?? 1200.0).toDouble(),
        hfSlabMm: (m['hfSlabMm'] as num? ?? 120.0).toDouble(),
        haMm: (m['haMm'] as num? ?? 300.0).toDouble(),
        baMm: (m['baMm'] as num? ?? 150.0).toDouble(),
        tfMm: (m['tfMm'] as num? ?? 10.0).toDouble(),
        twMm: (m['twMm'] as num? ?? 7.0).toDouble(),
        coreOffsetYMm: (m['coreOffsetYMm'] as num? ?? 0.0).toDouble(),
        coverMm: (m['coverMm'] as num? ?? 35.0).toDouble(),
        rebarDiaBotMm: (m['rebarDiaBotMm'] as num? ?? 22.0).toDouble(),
        nRebarBot: (m['nRebarBot'] as num? ?? 4).toInt(),
        rebarDiaTopMm: (m['rebarDiaTopMm'] as num? ?? 16.0).toDouble(),
        nRebarTop: (m['nRebarTop'] as num? ?? 2).toInt(),
        nRebarSideEach: (m['nRebarSideEach'] as num? ?? 1).toInt(),
        stirrupDiaMm: (m['stirrupDiaMm'] as num? ?? 10.0).toDouble(),
        stirrupSpacingMm: (m['stirrupSpacingMm'] as num? ?? 150.0).toDouble(),
        stirrupSpacingEndMm: (m['stirrupSpacingEndMm'] as num? ?? 100.0).toDouble(),
        nStirrupLegs: (m['nStirrupLegs'] as num? ?? 2).toInt(),
      );
}

class SrcMemberConfig {
  final MemberKind kind;
  final String name;
  final double lengthMm; // Nhịp dầm L hoặc chiều cao cột H (mm)
  final SectionGeometry geometry;
  final MaterialConfig material;
  // Thông số Dầm
  final String loadType; // 'udl', '3pt', '4pt', 'combined'
  final double qUdlKnM;
  final double pPointKn;
  final double loadAMm;
  final String leftSupport; // 'pin', 'roller', 'fixed'
  final String rightSupport;
  final double studDiaMm;
  final double studHeightMm;
  final double studFuMpa;
  final double studSpacingMm;
  final int studRows;
  final double deflectionLimitRatio;
  // Thông số Cột
  final String loadingMode; // 'concentric', 'uniaxial', 'biaxial'
  final double kEffZ;
  final double kEffY;
  final double nEdKn;
  final double mzEdKnm;
  final double myEdKnm;
  final bool useEccInput;
  final double ezMm;
  final double eyMm;
  final double momentRatioR;
  final double vColEdKn;
  final double imperfectionRatio;
  // Chia lưới PTHH
  final int nElems;
  final int nStepsDesign;
  // Đối chiếu thực nghiệm (tùy chọn cho các preset benchmark)
  final double? expRefValue;
  final String? expRefLabel;

  const SrcMemberConfig({
    this.kind = MemberKind.beam,
    this.name = 'Dầm SRC chữ T bản sàn — H300×150',
    this.lengthMm = 6000.0,
    this.geometry = const SectionGeometry(),
    this.material = const MaterialConfig(),
    this.loadType = 'udl',
    this.qUdlKnM = 65.0,
    this.pPointKn = 220.0,
    this.loadAMm = 2000.0,
    this.leftSupport = 'pin',
    this.rightSupport = 'roller',
    this.studDiaMm = 19.0,
    this.studHeightMm = 80.0,
    this.studFuMpa = 450.0,
    this.studSpacingMm = 200.0,
    this.studRows = 2,
    this.deflectionLimitRatio = 250.0,
    this.loadingMode = 'uniaxial',
    this.kEffZ = 1.0,
    this.kEffY = 1.0,
    this.nEdKn = 4500.0,
    this.mzEdKnm = 280.0,
    this.myEdKnm = 0.0,
    this.useEccInput = false,
    this.ezMm = 62.2,
    this.eyMm = 0.0,
    this.momentRatioR = 1.0,
    this.vColEdKn = 180.0,
    this.imperfectionRatio = 1000.0,
    this.nElems = 10,
    this.nStepsDesign = 10,
    this.expRefValue,
    this.expRefLabel,
  });

  SrcMemberConfig copyWith({
    MemberKind? kind,
    String? name,
    double? lengthMm,
    SectionGeometry? geometry,
    MaterialConfig? material,
    String? loadType,
    double? qUdlKnM,
    double? pPointKn,
    double? loadAMm,
    String? leftSupport,
    String? rightSupport,
    double? studDiaMm,
    double? studHeightMm,
    double? studSpacingMm,
    int? studRows,
    String? loadingMode,
    double? kEffZ,
    double? kEffY,
    double? nEdKn,
    double? mzEdKnm,
    double? myEdKnm,
    bool? useEccInput,
    double? ezMm,
    double? eyMm,
    double? momentRatioR,
    double? vColEdKn,
    double? imperfectionRatio,
    int? nElems,
    double? expRefValue,
    String? expRefLabel,
    bool clearExpRef = false,
  }) =>
      SrcMemberConfig(
        kind: kind ?? this.kind,
        name: name ?? this.name,
        lengthMm: lengthMm ?? this.lengthMm,
        geometry: geometry ?? this.geometry,
        material: material ?? this.material,
        loadType: loadType ?? this.loadType,
        qUdlKnM: qUdlKnM ?? this.qUdlKnM,
        pPointKn: pPointKn ?? this.pPointKn,
        loadAMm: loadAMm ?? this.loadAMm,
        leftSupport: leftSupport ?? this.leftSupport,
        rightSupport: rightSupport ?? this.rightSupport,
        studDiaMm: studDiaMm ?? this.studDiaMm,
        studHeightMm: studHeightMm ?? this.studHeightMm,
        studFuMpa: studFuMpa,
        studSpacingMm: studSpacingMm ?? this.studSpacingMm,
        studRows: studRows ?? this.studRows,
        deflectionLimitRatio: deflectionLimitRatio,
        loadingMode: loadingMode ?? this.loadingMode,
        kEffZ: kEffZ ?? this.kEffZ,
        kEffY: kEffY ?? this.kEffY,
        nEdKn: nEdKn ?? this.nEdKn,
        mzEdKnm: mzEdKnm ?? this.mzEdKnm,
        myEdKnm: myEdKnm ?? this.myEdKnm,
        useEccInput: useEccInput ?? this.useEccInput,
        ezMm: ezMm ?? this.ezMm,
        eyMm: eyMm ?? this.eyMm,
        momentRatioR: momentRatioR ?? this.momentRatioR,
        vColEdKn: vColEdKn ?? this.vColEdKn,
        imperfectionRatio: imperfectionRatio ?? this.imperfectionRatio,
        nElems: nElems ?? this.nElems,
        nStepsDesign: nStepsDesign,
        expRefValue: clearExpRef ? null : (expRefValue ?? this.expRefValue),
        expRefLabel: clearExpRef ? null : (expRefLabel ?? this.expRefLabel),
      );

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert({
        'kind': kind.name,
        'name': name,
        'lengthMm': lengthMm,
        'geometry': geometry.toJson(),
        'material': material.toJson(),
        'loadType': loadType,
        'qUdlKnM': qUdlKnM,
        'pPointKn': pPointKn,
        'loadAMm': loadAMm,
        'leftSupport': leftSupport,
        'rightSupport': rightSupport,
        'studDiaMm': studDiaMm,
        'studHeightMm': studHeightMm,
        'studSpacingMm': studSpacingMm,
        'studRows': studRows,
        'loadingMode': loadingMode,
        'kEffZ': kEffZ,
        'kEffY': kEffY,
        'nEdKn': nEdKn,
        'mzEdKnm': mzEdKnm,
        'myEdKnm': myEdKnm,
        'useEccInput': useEccInput,
        'ezMm': ezMm,
        'eyMm': eyMm,
        'momentRatioR': momentRatioR,
        'vColEdKn': vColEdKn,
        'imperfectionRatio': imperfectionRatio,
        'nElems': nElems,
      });

  factory SrcMemberConfig.fromJsonString(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return SrcMemberConfig(
      kind: (m['kind'] == 'column') ? MemberKind.column : MemberKind.beam,
      name: (m['name'] ?? 'SRC Project') as String,
      lengthMm: (m['lengthMm'] as num? ?? 6000.0).toDouble(),
      geometry: SectionGeometry.fromJson((m['geometry'] as Map<String, dynamic>?) ?? const {}),
      material: MaterialConfig.fromJson((m['material'] as Map<String, dynamic>?) ?? const {}),
      loadType: (m['loadType'] ?? 'udl') as String,
      qUdlKnM: (m['qUdlKnM'] as num? ?? 65.0).toDouble(),
      pPointKn: (m['pPointKn'] as num? ?? 220.0).toDouble(),
      loadAMm: (m['loadAMm'] as num? ?? 2000.0).toDouble(),
      leftSupport: (m['leftSupport'] ?? 'pin') as String,
      rightSupport: (m['rightSupport'] ?? 'roller') as String,
      studDiaMm: (m['studDiaMm'] as num? ?? 19.0).toDouble(),
      studHeightMm: (m['studHeightMm'] as num? ?? 80.0).toDouble(),
      studSpacingMm: (m['studSpacingMm'] as num? ?? 200.0).toDouble(),
      studRows: (m['studRows'] as num? ?? 2).toInt(),
      loadingMode: (m['loadingMode'] ?? 'uniaxial') as String,
      kEffZ: (m['kEffZ'] as num? ?? 1.0).toDouble(),
      kEffY: (m['kEffY'] as num? ?? 1.0).toDouble(),
      nEdKn: (m['nEdKn'] as num? ?? 4500.0).toDouble(),
      mzEdKnm: (m['mzEdKnm'] as num? ?? 280.0).toDouble(),
      myEdKnm: (m['myEdKnm'] as num? ?? 0.0).toDouble(),
      useEccInput: (m['useEccInput'] as bool?) ?? false,
      ezMm: (m['ezMm'] as num? ?? 62.2).toDouble(),
      eyMm: (m['eyMm'] as num? ?? 0.0).toDouble(),
      momentRatioR: (m['momentRatioR'] as num? ?? 1.0).toDouble(),
      vColEdKn: (m['vColEdKn'] as num? ?? 180.0).toDouble(),
      imperfectionRatio: (m['imperfectionRatio'] as num? ?? 1000.0).toDouble(),
      nElems: (m['nElems'] as num? ?? 10).toInt(),
    );
  }
}

class FiberCell {
  final double yMm, zMm, dyMm, dzMm, areaMm2;
  final String kind; // concrete, steel_flange, steel_web, steel_tube, rebar
  final ConcreteZone zone;
  final double fyMpa, esMpa;

  const FiberCell({
    required this.yMm,
    required this.zMm,
    required this.dyMm,
    required this.dzMm,
    required this.areaMm2,
    required this.kind,
    required this.zone,
    this.fyMpa = 0.0,
    this.esMpa = 0.0,
  });
}

class RebarDot {
  final double yMm, zMm, diaMm;
  const RebarDot(this.yMm, this.zMm, this.diaMm);
}

class SectionProperties {
  final double agMm2, acMm2, aaMm2, asMm2;
  final double acUnconfinedMm2, acPartConfMm2, acHighConfMm2;
  final double icZMm4, iaZMm4, isZMm4;
  final double icYMm4, iaYMm4, isYMm4;
  final double steelRatio, rebarRatio, volStirrupRatio;
  final List<RebarDot> rebars;

  const SectionProperties({
    required this.agMm2,
    required this.acMm2,
    required this.aaMm2,
    required this.asMm2,
    required this.acUnconfinedMm2,
    required this.acPartConfMm2,
    required this.acHighConfMm2,
    required this.icZMm4,
    required this.iaZMm4,
    required this.isZMm4,
    required this.icYMm4,
    required this.iaYMm4,
    required this.isYMm4,
    required this.steelRatio,
    required this.rebarRatio,
    required this.volStirrupRatio,
    required this.rebars,
  });
}

class SectionState {
  final double eps0, kappaZ, kappaY;
  final double nN, mzNmm, myNmm;
  final double d00, d01, d02, d11, d12, d22;
  final double eiZEff, eiYEff;
  final double xNaMm;
  final double epsCMin, epsCMax, sigCMinMpa, sigSteelMaxMpa, sigRebarMaxMpa;
  final double crackedRatio;
  final bool steelYielded, rebarYielded, concreteCrushed;

  const SectionState({
    required this.eps0,
    required this.kappaZ,
    required this.kappaY,
    required this.nN,
    required this.mzNmm,
    required this.myNmm,
    required this.d00,
    required this.d01,
    required this.d02,
    required this.d11,
    required this.d12,
    required this.d22,
    required this.eiZEff,
    required this.eiYEff,
    required this.xNaMm,
    required this.epsCMin,
    required this.epsCMax,
    required this.sigCMinMpa,
    required this.sigSteelMaxMpa,
    required this.sigRebarMaxMpa,
    required this.crackedRatio,
    required this.steelYielded,
    required this.rebarYielded,
    required this.concreteCrushed,
  });
}

class ElemSolution {
  final int elemIdx;
  final double x1Mm, x2Mm, lengthMm;
  final List<double> dElem; // 6 DOFs
  final List<double> fElem; // 6 end forces
  final List<SectionState> gpStates; // 3 Gauss points

  const ElemSolution({
    required this.elemIdx,
    required this.x1Mm,
    required this.x2Mm,
    required this.lengthMm,
    required this.dElem,
    required this.fElem,
    required this.gpStates,
  });
}

class LoadStepRecord {
  final double lambda;
  final double loadKn; // P (dầm) hoặc N (cột)
  final double deflMm; // δ_mid (dầm) hoặc Δ_lat (cột)
  final double axialShortMm;
  final double mMaxKnm;
  final double vMaxKn;
  final double eiRatio;
  final double epsCMin;
  final double sigSteelMaxMpa;
  final double sigRebarMaxMpa;
  final double crackedRatio;
  final bool steelYielded, rebarYielded, concreteCrushed;
  final List<ElemSolution>? elemsSnapshot;

  const LoadStepRecord({
    required this.lambda,
    required this.loadKn,
    required this.deflMm,
    required this.axialShortMm,
    required this.mMaxKnm,
    required this.vMaxKn,
    required this.eiRatio,
    required this.epsCMin,
    required this.sigSteelMaxMpa,
    required this.sigRebarMaxMpa,
    required this.crackedRatio,
    required this.steelYielded,
    required this.rebarYielded,
    required this.concreteCrushed,
    this.elemsSnapshot,
  });
}

class Point2D {
  final double x, y;
  final String label;
  const Point2D(this.x, this.y, [this.label = '']);
}

class CodeCheckRow {
  final String codeId;
  final String title;
  final double capacityPrimary; // M_Rd (kNm) cho dầm, N_b,Rd (kN) cho cột
  final double capacitySecondary; // V_Rd (kN) cho dầm, M_cap (kNm) cho cột
  final double urPrimary;
  final double urSecondary;
  final double urTotal;
  final String extraNote;
  final bool pass;

  const CodeCheckRow({
    required this.codeId,
    required this.title,
    required this.capacityPrimary,
    required this.capacitySecondary,
    required this.urPrimary,
    required this.urSecondary,
    required this.urTotal,
    required this.extraNote,
    required this.pass,
  });
}

class DissectedFiber {
  final FiberCell cell;
  final double epsX;
  final double sigmaXMpa;
  final double tauXyMpa;
  final double sigmaVmMpa;
  final String stateVi;
  final String stateEn;

  const DissectedFiber({
    required this.cell,
    required this.epsX,
    required this.sigmaXMpa,
    required this.tauXyMpa,
    required this.sigmaVmMpa,
    required this.stateVi,
    required this.stateEn,
  });
}

class ProbeResult {
  final double xNorm, xMm, yMm, zMm;
  final String materialVi, materialEn;
  final String zoneVi, zoneEn;
  final double epsX, sigmaXMpa, tauXyMpa, sigmaVmMpa, utilRatio;
  final String stateVi, stateEn;
  final double secNKn, secMKnm, secVKn, xNaMm;

  const ProbeResult({
    required this.xNorm,
    required this.xMm,
    required this.yMm,
    required this.zMm,
    required this.materialVi,
    required this.materialEn,
    required this.zoneVi,
    required this.zoneEn,
    required this.epsX,
    required this.sigmaXMpa,
    required this.tauXyMpa,
    required this.sigmaVmMpa,
    required this.utilRatio,
    required this.stateVi,
    required this.stateEn,
    required this.secNKn,
    required this.secMKnm,
    required this.secVKn,
    required this.xNaMm,
  });
}

class DissectionResult {
  final double xNorm, xMm;
  final double eps0, kappaZ, kappaY;
  final double nKn, mzKnm, myKnm, vShearKn, xNaMm;
  final double sigMinMpa, sigMaxMpa, epsMin, epsMax;
  final List<DissectedFiber> fibers;
  // Thông số tương tác liên kết Cốt cứng (Thép hình) ↔ Bê tông cốt thép tại mặt cắt x/L
  final double nSteelKn, nConcreteKn, nRebarKn;
  final double mzSteelKnm, mzConcreteKnm, mzRebarKnm;
  final double steelSharePct, concreteSharePct, rebarSharePct;
  final double bondPerimeterMm;
  final double vInterfaceKnPerM; // Lực trượt dọc mặt tiếp xúc v_L (kN/m)
  final double tauBondMpa; // Ứng suất dính bám dọc bề mặt thép hình – bê tông (MPa)
  final double tauRdMpa; // Khả năng dính bám thiết kế EC4 §6.7.4.2 + ma sát giam giữ (MPa)
  final double studForceKn; // Lực cắt tác dụng lên 1 đinh chống cắt tại x/L (kN)
  final double studUr; // Tỷ số sử dụng đinh neo F_stud / P_Rd
  final double splitUr; // Tỷ số rủi ro cắt tách dọc cánh thép Weng (2002)
  final double slipMm; // Trượt tương đối vi mô tại mặt tiếp xúc thép – bê tông (mm)
  final int bondStatusLevel; // 0 = Tốt (Xanh), 1 = Đinh neo/Ma sát hoạt động (Vàng), 2 = Cảnh báo (Đỏ)
  final String bondStateVi, bondStateEn;

  const DissectionResult({
    required this.xNorm,
    required this.xMm,
    required this.eps0,
    required this.kappaZ,
    required this.kappaY,
    required this.nKn,
    required this.mzKnm,
    required this.myKnm,
    required this.vShearKn,
    required this.xNaMm,
    required this.sigMinMpa,
    required this.sigMaxMpa,
    required this.epsMin,
    required this.epsMax,
    required this.fibers,
    required this.nSteelKn,
    required this.nConcreteKn,
    required this.nRebarKn,
    required this.mzSteelKnm,
    required this.mzConcreteKnm,
    required this.mzRebarKnm,
    required this.steelSharePct,
    required this.concreteSharePct,
    required this.rebarSharePct,
    required this.bondPerimeterMm,
    required this.vInterfaceKnPerM,
    required this.tauBondMpa,
    required this.tauRdMpa,
    required this.studForceKn,
    required this.studUr,
    required this.splitUr,
    required this.slipMm,
    required this.bondStatusLevel,
    required this.bondStateVi,
    required this.bondStateEn,
  });
}

class BomItem {
  final String mark, descVi, descEn, grade, qtyVi, qtyEn;
  final double weightKg;
  const BomItem({
    required this.mark,
    required this.descVi,
    required this.descEn,
    required this.grade,
    required this.qtyVi,
    required this.qtyEn,
    required this.weightKg,
  });
}

class SrcAnalysisResult {
  final SrcMemberConfig config;
  final SectionProperties props;
  final ConfinementParams conf;
  final List<FiberCell> fibers;
  final List<double> xNodesMm;
  final List<ElemSolution> designElems;
  final List<LoadStepRecord> history;
  // Tóm tắt chính
  final double demandPrimary; // M_Ed (dầm) hoặc N_Ed (cột)
  final double demandSecondary; // V_Ed (dầm) hoặc M_z,II (cột)
  final double demandFirstOrderM; // M_z,I (cột) hoặc M_Ed (dầm)
  final double demandMy2Knm;
  final double ezEffMm, eyEffMm;
  final double deflDesignMm;
  final double deflLinearMm;
  final double deflLimitMm;
  final double axialShortMm;
  final double ultimateLoadKn; // P_u (dầm) hoặc N_u (cột)
  final double ultimateMomentKnm;
  final double ductilityMu;
  final double pDeltaAmp;
  final double ec4DeltaSteel;
  final double ec4LambdaZ, ec4LambdaY, ec4ChiZ, ec4ChiY, ec4KAmpZ;
  final double bfBwRatio, vSplitKn, studPRdKn;
  final int studsReqHalf, studsProvHalf;
  final double laiLiewAna1Kn, laiLiewAna2Kn;
  final bool overallPass;
  final List<CodeCheckRow> codeChecks;
  // Đường cong biểu đồ
  final List<Point2D> mkCurve; // (kappa 1/m, M kNm)
  final List<Point2D> nmNominalCurve; // (M kNm, N kN)
  final List<Point2D> nmDesignCurve;
  final List<Point2D> ec4Polygon; // A-E-C-D-B
  // Biểu đồ dọc trục cấu kiện tại bước thiết kế
  final List<double> profileXMm;
  final List<double> profileDeflMm;
  final List<double> profileMKnm;
  final List<double> profileVKn;
  final List<double> profileEiRatio;
  final List<BomItem> bom;

  const SrcAnalysisResult({
    required this.config,
    required this.props,
    required this.conf,
    required this.fibers,
    required this.xNodesMm,
    required this.designElems,
    required this.history,
    required this.demandPrimary,
    required this.demandSecondary,
    required this.demandFirstOrderM,
    required this.demandMy2Knm,
    required this.ezEffMm,
    required this.eyEffMm,
    required this.deflDesignMm,
    required this.deflLinearMm,
    required this.deflLimitMm,
    required this.axialShortMm,
    required this.ultimateLoadKn,
    required this.ultimateMomentKnm,
    required this.ductilityMu,
    required this.pDeltaAmp,
    required this.ec4DeltaSteel,
    required this.ec4LambdaZ,
    required this.ec4LambdaY,
    required this.ec4ChiZ,
    required this.ec4ChiY,
    required this.ec4KAmpZ,
    required this.bfBwRatio,
    required this.vSplitKn,
    required this.studPRdKn,
    required this.studsReqHalf,
    required this.studsProvHalf,
    required this.laiLiewAna1Kn,
    required this.laiLiewAna2Kn,
    required this.overallPass,
    required this.codeChecks,
    required this.mkCurve,
    required this.nmNominalCurve,
    required this.nmDesignCurve,
    required this.ec4Polygon,
    required this.profileXMm,
    required this.profileDeflMm,
    required this.profileMKnm,
    required this.profileVKn,
    required this.profileEiRatio,
    required this.bom,
  });
}

// ============================================================================
// THƯ VIỆN MÁC VẬT LIỆU, THÉP HÌNH & BỘ PRESET NGHIÊN CỨU + THỰC NGHIỆM
// ============================================================================

class SrcLibraries {
  static const Map<String, ({double fc, double ec, double fct})> concreteGrades = {
    'B25 (C20/25)': (fc: 20.0, ec: 30000.0, fct: 2.2),
    'B30 (C25/30)': (fc: 25.0, ec: 31500.0, fct: 2.6),
    'C30/37 (B35)': (fc: 30.0, ec: 33000.0, fct: 2.9),
    'C35/45 (B40)': (fc: 35.0, ec: 34000.0, fct: 3.2),
    'C40/50 (B45)': (fc: 40.0, ec: 35000.0, fct: 3.5),
    'C50/60 (B55)': (fc: 50.0, ec: 37000.0, fct: 4.1),
    'C60/75 (HSC)': (fc: 60.0, ec: 39000.0, fct: 4.4),
    'C80/95 (HSC)': (fc: 80.0, ec: 42000.0, fct: 4.8),
    'C110 (VHSC)': (fc: 109.3, ec: 44900.0, fct: 5.2),
  };

  static const Map<String, ({double fy, double fu, double es})> steelGrades = {
    'SS400 / S235': (fy: 235.0, fu: 360.0, es: 210000.0),
    'S275 / CT38': (fy: 275.0, fu: 430.0, es: 210000.0),
    'S355 (Q355)': (fy: 355.0, fu: 490.0, es: 210000.0),
    'S420 / Q420': (fy: 420.0, fu: 520.0, es: 210000.0),
    'S460 / Q460': (fy: 460.0, fu: 550.0, es: 210000.0),
    'Q550 (HSS)': (fy: 550.0, fu: 670.0, es: 210000.0),
    'Q690 (HSS)': (fy: 690.0, fu: 770.0, es: 210000.0),
  };

  static const Map<String, ({double fy, double es})> rebarGrades = {
    'CB300-V': (fy: 300.0, es: 200000.0),
    'CB400-V (B400)': (fy: 400.0, es: 200000.0),
    'CB500-V (B500)': (fy: 500.0, es: 200000.0),
    'HRB550': (fy: 550.0, es: 200000.0),
  };

  static const Map<String, ({double ha, double ba, double tw, double tf})> steelProfiles = {
    'H200×100×5.5×8': (ha: 200.0, ba: 100.0, tw: 5.5, tf: 8.0),
    'H250×125×6×9': (ha: 250.0, ba: 125.0, tw: 6.0, tf: 9.0),
    'H300×150×6.5×9': (ha: 300.0, ba: 150.0, tw: 6.5, tf: 9.0),
    'H300×150×7×10': (ha: 300.0, ba: 150.0, tw: 7.0, tf: 10.0),
    'H350×175×7×11': (ha: 350.0, ba: 175.0, tw: 7.0, tf: 11.0),
    'H400×200×8×13': (ha: 400.0, ba: 200.0, tw: 8.0, tf: 13.0),
    'UC152×152×37': (ha: 161.8, ba: 154.4, tw: 8.0, tf: 11.5),
    'H200×200×8×12': (ha: 200.0, ba: 200.0, tw: 8.0, tf: 12.0),
    'H250×250×9×14': (ha: 250.0, ba: 250.0, tw: 9.0, tf: 14.0),
    'H300×300×10×15': (ha: 300.0, ba: 300.0, tw: 10.0, tf: 15.0),
    'HEB240': (ha: 240.0, ba: 240.0, tw: 10.0, tf: 17.0),
    'HEB300': (ha: 300.0, ba: 300.0, tw: 11.0, tf: 19.0),
  };

  static List<({String id, String labelVi, String labelEn, SrcMemberConfig cfg})> beamPresets() => [
        (
          id: 't_slab_std',
          labelVi: 'Dầm chữ T bản sàn SRC (L=6m, H300×150)',
          labelEn: 'SRC T-Slab Beam (L=6m, H300×150)',
          cfg: const SrcMemberConfig(),
        ),
        (
          id: 'rect_highrise',
          labelVi: 'Dầm khung nhà cao tầng chữ nhật (L=7.2m, H350)',
          labelEn: 'High-Rise Rect SRC Beam (L=7.2m, H350)',
          cfg: const SrcMemberConfig(
            kind: MemberKind.beam,
            name: 'Dầm khung chữ nhật SRC 350×650 — H350×175',
            lengthMm: 7200.0,
            geometry: SectionGeometry(
              sectionType: 'SRC_RECT_H',
              bMm: 350.0,
              hMm: 650.0,
              haMm: 350.0,
              baMm: 175.0,
              tfMm: 11.0,
              twMm: 7.0,
              coreOffsetYMm: 0.0,
              coverMm: 35.0,
              rebarDiaBotMm: 22.0,
              nRebarBot: 4,
              rebarDiaTopMm: 20.0,
              nRebarTop: 4,
            ),
            material: MaterialConfig(
              concreteGrade: 'C40/50 (B45)',
              fcMpa: 40.0,
              ecMpa: 35000.0,
              fctMpa: 3.5,
            ),
            loadType: 'udl',
            qUdlKnM: 75.0,
          ),
        ),
        (
          id: 'jiang_2024',
          labelVi: 'Thực nghiệm Jiang et al. (2024) PECB1 (Mu=1022 kN·m)',
          labelEn: 'Benchmark Jiang et al. (2024) PECB1 (Mu=1022 kN·m)',
          cfg: const SrcMemberConfig(
            kind: MemberKind.beam,
            name: 'Benchmark Jiang et al. (2024) PECB1 — Dầm chữ T bản sàn',
            lengthMm: 5600.0,
            geometry: SectionGeometry(
              sectionType: 'SRC_T_SLAB_H',
              bMm: 300.0,
              hMm: 580.0,
              bfSlabMm: 1200.0,
              hfSlabMm: 130.0,
              haMm: 350.0,
              baMm: 175.0,
              tfMm: 12.0,
              twMm: 8.0,
              coreOffsetYMm: -35.0,
              coverMm: 30.0,
              rebarDiaBotMm: 22.0,
              nRebarBot: 4,
              rebarDiaTopMm: 16.0,
              nRebarTop: 2,
            ),
            material: MaterialConfig(
              concreteGrade: 'C40/50 (B45)',
              fcMpa: 40.0,
              ecMpa: 35000.0,
              fctMpa: 3.5,
            ),
            loadType: '4pt',
            pPointKn: 650.0,
            loadAMm: 1800.0,
            expRefValue: 1022.0,
            expRefLabel: 'Jiang et al. (2024) Mu,exp = 1022 kN·m',
          ),
        ),
        (
          id: 'huang_c100b',
          labelVi: 'Thực nghiệm Huang & Liew (2018) C100B (Mu=149.1 kN·m)',
          labelEn: 'Benchmark Huang & Liew (2018) C100B (Mu=149.1 kN·m)',
          cfg: const SrcMemberConfig(
            kind: MemberKind.beam,
            name: 'Benchmark Huang & Liew (2018) C100B — VHSC 109 MPa',
            lengthMm: 2500.0,
            geometry: SectionGeometry(
              sectionType: 'SRC_RECT_H',
              bMm: 240.0,
              hMm: 240.0,
              haMm: 161.8,
              baMm: 154.4,
              tfMm: 11.5,
              twMm: 8.0,
              coreOffsetYMm: 0.0,
              coverMm: 24.0,
              rebarDiaBotMm: 12.0,
              nRebarBot: 3,
              rebarDiaTopMm: 12.0,
              nRebarTop: 3,
              stirrupDiaMm: 6.0,
            ),
            material: MaterialConfig(
              concreteGrade: 'C110 (VHSC)',
              fcMpa: 109.3,
              ecMpa: 44900.0,
              fctMpa: 5.2,
              fySteelMpa: 362.9,
              esSteelMpa: 201550.0,
              fyRebarMpa: 356.8,
              esRebarMpa: 193640.0,
            ),
            loadType: '4pt',
            pPointKn: 220.0,
            loadAMm: 950.0,
            expRefValue: 149.1,
            expRefLabel: 'Huang & Liew (2018) Mu,exp = 149.1 kN·m',
          ),
        ),
      ];

  static List<({String id, String labelVi, String labelEn, SrcMemberConfig cfg})> columnPresets() => [
        (
          id: 'col_ecc_500',
          labelVi: 'Cột 500×500 H250 — Nén lệch tâm (N=4500, M=280)',
          labelEn: '500×500 H250 Column — Eccentric (N=4500, M=280)',
          cfg: const SrcMemberConfig(
            kind: MemberKind.column,
            name: 'Cột nhà cao tầng 500×500 — H250×250 (Nén lệch tâm)',
            lengthMm: 4200.0,
            geometry: SectionGeometry(
              sectionType: 'COL_RECT_H',
              bMm: 500.0,
              hMm: 500.0,
              haMm: 250.0,
              baMm: 250.0,
              tfMm: 14.0,
              twMm: 9.0,
              coreOffsetYMm: 0.0,
              coverMm: 40.0,
              rebarDiaBotMm: 22.0,
              nRebarBot: 12,
              rebarDiaTopMm: 22.0,
              nRebarTop: 4,
              nRebarSideEach: 2,
              stirrupDiaMm: 10.0,
              stirrupSpacingMm: 150.0,
              stirrupSpacingEndMm: 100.0,
              nStirrupLegs: 3,
            ),
            material: MaterialConfig(
              concreteGrade: 'C40/50 (B45)',
              fcMpa: 40.0,
              ecMpa: 35000.0,
              fctMpa: 3.5,
            ),
            loadingMode: 'uniaxial',
            nEdKn: 4500.0,
            mzEdKnm: 280.0,
            myEdKnm: 0.0,
          ),
        ),
        (
          id: 'col_conc_cross',
          labelVi: 'Cột lõi chữ thập 600×600 — Nén đúng tâm (N=8500 kN)',
          labelEn: '600×600 Cross-H Column — Concentric (N=8500 kN)',
          cfg: const SrcMemberConfig(
            kind: MemberKind.column,
            name: 'Cột lõi chữ thập 600×600 — Nén đúng tâm (e=0)',
            lengthMm: 4500.0,
            geometry: SectionGeometry(
              sectionType: 'COL_RECT_CROSS_H',
              bMm: 600.0,
              hMm: 600.0,
              haMm: 300.0,
              baMm: 200.0,
              tfMm: 14.0,
              twMm: 10.0,
              coreOffsetYMm: 0.0,
              coverMm: 40.0,
              rebarDiaBotMm: 25.0,
              nRebarBot: 16,
              rebarDiaTopMm: 25.0,
              nRebarTop: 4,
              nRebarSideEach: 3,
              stirrupDiaMm: 10.0,
              stirrupSpacingMm: 120.0,
              stirrupSpacingEndMm: 80.0,
              nStirrupLegs: 4,
            ),
            material: MaterialConfig(
              concreteGrade: 'C50/60 (B55)',
              fcMpa: 50.0,
              ecMpa: 37000.0,
              fctMpa: 4.1,
            ),
            loadingMode: 'concentric',
            nEdKn: 8500.0,
            mzEdKnm: 0.0,
            myEdKnm: 0.0,
          ),
        ),
        (
          id: 'col_biaxial',
          labelVi: 'Cột góc 550×550 — Lệch tâm xiên 2 phương (Mz=240, My=160)',
          labelEn: '550×550 Corner Column — Biaxial (Mz=240, My=160)',
          cfg: const SrcMemberConfig(
            kind: MemberKind.column,
            name: 'Cột góc 550×550 — Nén lệch tâm xiên 2 phương',
            lengthMm: 4000.0,
            geometry: SectionGeometry(
              sectionType: 'COL_RECT_H',
              bMm: 550.0,
              hMm: 550.0,
              haMm: 250.0,
              baMm: 250.0,
              tfMm: 14.0,
              twMm: 9.0,
              coreOffsetYMm: 0.0,
              coverMm: 40.0,
              rebarDiaBotMm: 22.0,
              nRebarBot: 12,
              nRebarSideEach: 2,
              nStirrupLegs: 3,
            ),
            material: MaterialConfig(
              concreteGrade: 'C40/50 (B45)',
              fcMpa: 40.0,
              ecMpa: 35000.0,
              fctMpa: 3.5,
            ),
            loadingMode: 'biaxial',
            nEdKn: 3800.0,
            mzEdKnm: 240.0,
            myEdKnm: 160.0,
          ),
        ),
        (
          id: 'col_cfst_encased',
          labelVi: 'Cột CE-CFST bọc BT (Ma 2022) — Ống thép Ø273×12',
          labelEn: 'CE-CFST Column (Ma 2022) — Tube Ø273×12',
          cfg: const SrcMemberConfig(
            kind: MemberKind.column,
            name: 'Cột CE-CFST 500×500 — Ống thép nhồi BT Ø273×12',
            lengthMm: 4200.0,
            geometry: SectionGeometry(
              sectionType: 'COL_RECT_CFST',
              bMm: 500.0,
              hMm: 500.0,
              haMm: 273.0,
              baMm: 273.0,
              tfMm: 12.0,
              twMm: 12.0,
              coreOffsetYMm: 0.0,
              coverMm: 40.0,
              rebarDiaBotMm: 20.0,
              nRebarBot: 12,
              nRebarSideEach: 2,
              nStirrupLegs: 2,
            ),
            material: MaterialConfig(
              concreteGrade: 'C50/60 (B55)',
              fcMpa: 50.0,
              ecMpa: 37000.0,
              fctMpa: 4.1,
            ),
            loadingMode: 'uniaxial',
            nEdKn: 5500.0,
            mzEdKnm: 260.0,
          ),
        ),
        (
          id: 'huang_c100e50',
          labelVi: 'Thực nghiệm Huang & Liew (2018) C100e50 (Nu=3687 kN)',
          labelEn: 'Benchmark Huang & Liew (2018) C100e50 (Nu=3687 kN)',
          cfg: const SrcMemberConfig(
            kind: MemberKind.column,
            name: 'Benchmark Huang & Liew (2018) C100e50 — VHSC 109 MPa, e=50mm',
            lengthMm: 500.0,
            geometry: SectionGeometry(
              sectionType: 'COL_RECT_H',
              bMm: 240.0,
              hMm: 240.0,
              haMm: 161.8,
              baMm: 154.4,
              tfMm: 11.5,
              twMm: 8.0,
              coreOffsetYMm: 0.0,
              coverMm: 24.0,
              rebarDiaBotMm: 16.0,
              nRebarBot: 8,
              nRebarSideEach: 1,
              stirrupDiaMm: 6.0,
            ),
            material: MaterialConfig(
              concreteGrade: 'C110 (VHSC)',
              fcMpa: 109.3,
              ecMpa: 44900.0,
              fctMpa: 5.2,
              fySteelMpa: 362.9,
              esSteelMpa: 201550.0,
              fyRebarMpa: 356.8,
              esRebarMpa: 193640.0,
            ),
            loadingMode: 'uniaxial',
            useEccInput: true,
            nEdKn: 2400.0,
            ezMm: 50.0,
            imperfectionRatio: 2000.0,
            expRefValue: 3686.7,
            expRefLabel: 'Huang & Liew (2018) Nu,exp = 3686.7 kN',
          ),
        ),
        (
          id: 'chen_lin_cs1',
          labelVi: 'Thực nghiệm Chen & Lin (2006) CS-1 (Nu=1650 kN)',
          labelEn: 'Benchmark Chen & Lin (2006) CS-1 (Nu=1650 kN)',
          cfg: const SrcMemberConfig(
            kind: MemberKind.column,
            name: 'Benchmark Chen & Lin (2006) CS-1 — 200×200, e=0',
            lengthMm: 600.0,
            geometry: SectionGeometry(
              sectionType: 'COL_RECT_H',
              bMm: 200.0,
              hMm: 200.0,
              haMm: 100.0,
              baMm: 100.0,
              tfMm: 8.0,
              twMm: 6.0,
              coreOffsetYMm: 0.0,
              coverMm: 25.0,
              rebarDiaBotMm: 12.0,
              nRebarBot: 4,
              nRebarSideEach: 0,
              stirrupDiaMm: 8.0,
              stirrupSpacingMm: 100.0,
              stirrupSpacingEndMm: 75.0,
            ),
            material: MaterialConfig(
              concreteGrade: 'C30/37 (B35)',
              fcMpa: 30.5,
              ecMpa: 32000.0,
              fctMpa: 2.9,
              fySteelMpa: 295.0,
              esSteelMpa: 205000.0,
              fyRebarMpa: 410.0,
            ),
            loadingMode: 'concentric',
            nEdKn: 1100.0,
            imperfectionRatio: 2000.0,
            expRefValue: 1650.0,
            expRefLabel: 'Chen & Lin (2006) Nu,exp = 1650 kN',
          ),
        ),
      ];
}

// ============================================================================
// BỘ GIẢI CƠ HỌC PHI TUYẾN & ĐA TIÊU CHUẨN (PURE DART)
// ============================================================================

class SrcNonlinearEngine {
  static double computeHscEta(double fcMpa) {
    if (fcMpa <= 50.0) return 1.0;
    if (fcMpa <= 90.0) return math.max(0.80, 1.0 - (fcMpa - 50.0) / 200.0);
    return 0.80;
  }

  static ConfinementParams computeConfinement(
    MaterialConfig mat,
    double rhoV,
    double steelRatio,
  ) {
    final fc = math.max(10.0, mat.fcMpa);
    final eta = computeHscEta(fc);
    final e0u = fc <= 50.0
        ? mat.epsC0
        : math.min(0.0029, math.max(mat.epsC0, 0.0020 + 0.000012 * (fc - 50.0)));
    final euu = fc <= 50.0
        ? mat.epsCu
        : math.max(0.0027, 0.0035 - 0.000012 * math.min(60.0, fc - 50.0));

    if (!mat.useConfinement) {
      return ConfinementParams(
        kp: 1.0,
        kh: 1.0,
        epsC0U: e0u,
        epsCuU: euu,
        epsC0P: e0u,
        epsCuP: euu,
        epsC0H: e0u,
        epsCuH: euu,
        flP: 0.0,
        flH: 0.0,
        etaHsc: eta,
      );
    }
    final rv = rhoV.clamp(0.001, 0.05);
    final flP = 0.65 * 0.5 * rv * mat.fyStirrupMpa;
    final kpRaw = -1.254 + 2.254 * math.sqrt(1.0 + 7.94 * flP / fc) - 2.0 * flP / fc;
    final hscDamp = fc <= 50.0 ? 1.0 : math.max(0.35, 1.0 - 0.008 * (fc - 50.0));
    final kp = (1.0 + (math.max(1.0, kpRaw) - 1.0) * hscDamp).clamp(1.0, 1.32);

    final ra = steelRatio.clamp(0.02, 0.18);
    final flH = flP + 0.055 * ra * math.min(mat.fySteelMpa, 460.0);
    final khRaw = -1.254 + 2.254 * math.sqrt(1.0 + 7.94 * flH / fc) - 2.0 * flH / fc;
    final kh = (1.0 + (math.max(1.0, khRaw) - 1.0) * hscDamp).clamp(kp, 1.48);

    final e0p = e0u * (1.0 + 4.5 * (kp - 1.0));
    final eup = math.min(0.016, math.max(euu + 0.0015, 0.004 + 1.4 * rv * mat.fyStirrupMpa * 0.08 / (kp * fc)));
    final e0h = e0u * (1.0 + 5.0 * (kh - 1.0));
    final euh = math.min(0.025, math.max(eup + 0.0030, eup * 1.65));

    return ConfinementParams(
      kp: kp,
      kh: kh,
      epsC0U: e0u,
      epsCuU: euu,
      epsC0P: e0p,
      epsCuP: eup,
      epsC0H: e0h,
      epsCuH: euh,
      flP: flP,
      flH: flH,
      etaHsc: eta,
    );
  }

  static ({double sig, double et, String stVi, String stEn, bool cracked, bool crushed}) concreteLaw(
    double eps,
    MaterialConfig mat,
    ConcreteZone zone,
    ConfinementParams conf,
    bool nonlinear,
  ) {
    final ec0 = math.max(5000.0, mat.ecMpa);
    if (!nonlinear) {
      return (
        sig: ec0 * eps,
        et: ec0,
        stVi: eps <= 0 ? 'Nén ĐH' : 'Kéo ĐH',
        stEn: eps <= 0 ? 'Elastic Comp.' : 'Elastic Tens.',
        cracked: false,
        crushed: false,
      );
    }
    if (eps <= 0.0) {
      final ec = -eps;
      final fcInsitu = 0.85 * conf.etaHsc * mat.fcMpa;
      final double fp, e0, eu, dr, rs;
      if (zone == ConcreteZone.highlyConfined) {
        fp = fcInsitu * conf.kh;
        e0 = math.max(1e-4, conf.epsC0H);
        eu = math.max(e0 + 4e-4, conf.epsCuH);
        dr = 0.15;
        rs = 0.55;
      } else if (zone == ConcreteZone.partiallyConfined) {
        fp = fcInsitu * conf.kp;
        e0 = math.max(1e-4, conf.epsC0P);
        eu = math.max(e0 + 4e-4, conf.epsCuP);
        dr = 0.25;
        rs = 0.35;
      } else {
        fp = fcInsitu;
        e0 = math.max(1e-4, conf.epsC0U);
        eu = math.max(e0 + 4e-4, conf.epsCuU);
        dr = mat.fcMpa <= 50.0 ? 0.20 : 0.45;
        rs = 0.15;
      }
      if (ec <= e0) {
        final r = ec / e0;
        final sig = -fp * (2.0 * r - r * r);
        final et = math.max((2.0 * fp / e0) * (1.0 - r), 0.008 * ec0);
        return (
          sig: sig,
          et: et,
          stVi: r < 0.42 ? 'Nén ĐH' : 'Nén phi tuyến',
          stEn: r < 0.42 ? 'Elastic Comp.' : 'Nonlinear Comp.',
          cracked: false,
          crushed: false,
        );
      }
      if (ec <= eu) {
        final frac = (ec - e0) / (eu - e0);
        return (
          sig: -fp * (1.0 - dr * frac),
          et: 0.004 * ec0,
          stVi: 'Nén sau đỉnh',
          stEn: 'Post-Peak Comp.',
          cracked: false,
          crushed: false,
        );
      }
      return (
        sig: -rs * fp,
        et: 0.002 * ec0,
        stVi: 'Vỡ nén',
        stEn: 'Crushed',
        cracked: false,
        crushed: zone == ConcreteZone.unconfined,
      );
    }

    final fct = math.max(0.1, mat.fctMpa);
    final epsCr = fct / ec0;
    if (eps <= epsCr) {
      return (
        sig: ec0 * eps,
        et: ec0,
        stVi: 'Kéo chưa nứt',
        stEn: 'Uncracked Tens.',
        cracked: false,
        crushed: false,
      );
    }
    final ratio = math.min(40.0, (eps - epsCr) / math.max(1e-8, epsCr));
    final sig = fct * math.exp(-0.35 * ratio);
    final etExact = -0.35 * sig / math.max(1e-8, epsCr);
    return (
      sig: sig,
      et: etExact,
      stVi: sig > 0.10 * fct ? 'Nứt kéo (mềm hóa)' : 'Nứt kéo hoàn toàn',
      stEn: sig > 0.10 * fct ? 'Cracked (Softening)' : 'Fully Cracked',
      cracked: true,
      crushed: false,
    );
  }

  static ({double sig, double et, String stVi, String stEn, bool yielded}) steelLaw(
    double eps,
    double esMpa,
    double fyMpa,
    double bHard,
    bool nonlinear,
  ) {
    final es = math.max(10000.0, esMpa);
    if (!nonlinear) {
      return (sig: es * eps, et: es, stVi: 'Đàn hồi', stEn: 'Elastic', yielded: false);
    }
    final ey = fyMpa / es;
    final eth = math.max(1e-4, bHard) * es;
    if (eps.abs() <= ey) {
      return (
        sig: es * eps,
        et: es,
        stVi: eps >= 0 ? 'Kéo đàn hồi' : 'Nén đàn hồi',
        stEn: eps >= 0 ? 'Elastic Tens.' : 'Elastic Comp.',
        yielded: false,
      );
    }
    final sgn = eps >= 0 ? 1.0 : -1.0;
    return (
      sig: sgn * (fyMpa + eth * (eps.abs() - ey)),
      et: eth,
      stVi: eps >= 0 ? 'Chảy dẻo kéo' : 'Chảy dẻo nén',
      stEn: eps >= 0 ? 'Yielded (Tens.)' : 'Yielded (Comp.)',
      yielded: true,
    );
  }

  static String? pointInSteelCore(double y, double z, SectionGeometry g) {
    final yc = y - g.coreOffsetYMm;
    final ha = g.haMm;
    final ba = g.baMm;
    final tf = math.min(g.tfMm, 0.4 * ha);
    final tw = math.min(g.twMm, 0.4 * ba);
    if (g.sectionType == 'COL_RECT_CFST') {
      final rOut = 0.5 * ha;
      final rIn = math.max(0.0, rOut - tf);
      final r = math.sqrt(yc * yc + z * z);
      return (r >= rIn && r <= rOut) ? 'steel_tube' : null;
    }
    if (z.abs() <= 0.5 * ba && yc.abs() >= (0.5 * ha - tf) && yc.abs() <= 0.5 * ha) return 'steel_flange';
    if (z.abs() <= 0.5 * tw && yc.abs() < (0.5 * ha - tf)) return 'steel_web';
    if (g.sectionType == 'COL_RECT_CROSS_H') {
      if (yc.abs() <= 0.5 * ba && z.abs() >= (0.5 * ha - tf) && z.abs() <= 0.5 * ha) return 'steel_flange';
      if (yc.abs() <= 0.5 * tw && z.abs() < (0.5 * ha - tf)) return 'steel_web';
    }
    return null;
  }

  static ConcreteZone classifyConcreteZone(double y, double z, SectionGeometry g) {
    final c = g.coverMm + 0.5 * g.stirrupDiaMm;
    final yc = y - g.coreOffsetYMm;
    if (g.sectionType == 'COL_RECT_CFST') {
      final rIn = math.max(0.0, 0.5 * g.haMm - g.tfMm);
      if (math.sqrt(yc * yc + z * z) < rIn) return ConcreteZone.highlyConfined;
    }
    if (g.sectionType == 'COL_CIRC_H') {
      final rCore = 0.5 * g.bMm - c;
      if (math.sqrt(y * y + z * z) > rCore) return ConcreteZone.unconfined;
      if (yc.abs() <= 0.5 * g.haMm && z.abs() <= 0.5 * g.baMm) return ConcreteZone.highlyConfined;
      return ConcreteZone.partiallyConfined;
    }
    if (g.sectionType == 'SRC_T_SLAB_H' && z.abs() > 0.5 * g.bMm) return ConcreteZone.unconfined;
    final inStirrup = y.abs() <= 0.5 * g.hMm - c && z.abs() <= 0.5 * g.bMm - c;
    if (!inStirrup) return ConcreteZone.unconfined;
    bool inH = yc.abs() <= 0.5 * g.haMm && z.abs() <= 0.5 * g.baMm;
    if (g.sectionType == 'COL_RECT_CROSS_H') {
      inH = inH || (z.abs() <= 0.5 * g.haMm && yc.abs() <= 0.5 * g.baMm);
    }
    return inH ? ConcreteZone.highlyConfined : ConcreteZone.partiallyConfined;
  }

  static List<RebarDot> _buildRebarLayout(SectionGeometry g) {
    final out = <RebarDot>[];
    final cBot = g.coverMm + g.stirrupDiaMm + 0.5 * g.rebarDiaBotMm;
    final cTop = g.coverMm + g.stirrupDiaMm + 0.5 * g.rebarDiaTopMm;

    if (g.sectionType == 'COL_CIRC_H') {
      final nTot = math.max(6, g.nRebarBot);
      final rBar = math.max(20.0, 0.5 * g.bMm - cBot);
      for (int k = 0; k < nTot; k++) {
        final ang = 2.0 * math.pi * k / nTot + math.pi / nTot;
        out.add(RebarDot(rBar * math.sin(ang), rBar * math.cos(ang), g.rebarDiaBotMm));
      }
      return out;
    }
    if (g.sectionType.startsWith('COL_')) {
      final yTop = 0.5 * g.hMm - cBot;
      final yBot = -0.5 * g.hMm + cBot;
      final zMax = 0.5 * g.bMm - cBot;
      int nRow = g.nRebarBot >= 4 ? math.max(2, ((g.nRebarBot - 2 * g.nRebarSideEach) / 2).round()) : 2;
      nRow = nRow.clamp(2, 6);
      for (int i = 0; i < nRow; i++) {
        final zi = -zMax + 2.0 * zMax * i / math.max(1, nRow - 1);
        out.add(RebarDot(yBot, zi, g.rebarDiaBotMm));
        out.add(RebarDot(yTop, zi, g.rebarDiaBotMm));
      }
      for (int j = 1; j <= g.nRebarSideEach; j++) {
        final yj = yBot + (yTop - yBot) * j / (g.nRebarSideEach + 1);
        out.add(RebarDot(yj, -zMax, g.rebarDiaBotMm));
        out.add(RebarDot(yj, zMax, g.rebarDiaBotMm));
      }
      return out;
    }
    // Dầm
    final zBot = math.max(10.0, 0.5 * g.bMm - cBot);
    final yBot = -0.5 * g.hMm + cBot;
    if (g.nRebarBot == 1) {
      out.add(RebarDot(yBot, 0.0, g.rebarDiaBotMm));
    } else {
      for (int i = 0; i < g.nRebarBot; i++) {
        out.add(RebarDot(yBot, -zBot + 2.0 * zBot * i / (g.nRebarBot - 1), g.rebarDiaBotMm));
      }
    }
    final zTop = math.max(10.0, 0.5 * g.bMm - cTop);
    final yTop = 0.5 * g.hMm - cTop;
    if (g.nRebarTop == 1) {
      out.add(RebarDot(yTop, 0.0, g.rebarDiaTopMm));
    } else if (g.nRebarTop > 1) {
      for (int i = 0; i < g.nRebarTop; i++) {
        out.add(RebarDot(yTop, -zTop + 2.0 * zTop * i / (g.nRebarTop - 1), g.rebarDiaTopMm));
      }
    }
    return out;
  }

  static ({List<FiberCell> fibers, SectionProperties props, ConfinementParams conf}) build2DFiberSection(
    SectionGeometry g,
    MaterialConfig mat,
  ) {
    final fibers = <FiberCell>[];
    final ny = math.max(12, g.nyGrid);
    final nz = math.max(8, g.nzGrid);
    final ycOff = g.coreOffsetYMm;
    final ha = g.haMm;
    final ba = g.baMm;
    final tf = math.min(g.tfMm, 0.4 * ha);
    final tw = math.min(g.twMm, 0.4 * ba);

    // 1. Lõi thép hình
    if (g.sectionType == 'COL_RECT_CFST') {
      const nSeg = 40;
      final rOut = 0.5 * ha;
      final rIn = math.max(1.0, rOut - tf);
      final rMid = 0.5 * (rOut + rIn);
      final aSeg = math.pi * (rOut * rOut - rIn * rIn) / nSeg;
      final arc = 2.0 * math.pi * rMid / nSeg;
      for (int k = 0; k < nSeg; k++) {
        final ang = 2.0 * math.pi * (k + 0.5) / nSeg;
        fibers.add(FiberCell(
          yMm: ycOff + rMid * math.sin(ang),
          zMm: rMid * math.cos(ang),
          dyMm: tf,
          dzMm: arc,
          areaMm2: aSeg,
          kind: 'steel_tube',
          zone: ConcreteZone.highlyConfined,
          fyMpa: mat.fySteelMpa,
          esMpa: mat.esSteelMpa,
        ));
      }
    } else {
      const nzF = 6;
      const nyF = 2;
      final dzF = ba / nzF;
      final dyF = tf / nyF;
      for (final sgn in const [-1.0, 1.0]) {
        final yBase = sgn > 0 ? ycOff + 0.5 * ha - tf : ycOff - 0.5 * ha;
        for (int iy = 0; iy < nyF; iy++) {
          final yk = yBase + (iy + 0.5) * dyF;
          for (int iz = 0; iz < nzF; iz++) {
            final zk = -0.5 * ba + (iz + 0.5) * dzF;
            fibers.add(FiberCell(
              yMm: yk,
              zMm: zk,
              dyMm: dyF,
              dzMm: dzF,
              areaMm2: dyF * dzF,
              kind: 'steel_flange',
              zone: ConcreteZone.highlyConfined,
              fyMpa: mat.fySteelMpa,
              esMpa: mat.esSteelMpa,
            ));
          }
        }
      }
      final hw = math.max(0.0, ha - 2.0 * tf);
      if (hw > 0.5) {
        const nyW = 10;
        final dyW = hw / nyW;
        for (int iy = 0; iy < nyW; iy++) {
          final yk = ycOff - 0.5 * hw + (iy + 0.5) * dyW;
          fibers.add(FiberCell(
            yMm: yk,
            zMm: 0.0,
            dyMm: dyW,
            dzMm: tw,
            areaMm2: dyW * tw,
            kind: 'steel_web',
            zone: ConcreteZone.highlyConfined,
            fyMpa: mat.fySteelMpa,
            esMpa: mat.esSteelMpa,
          ));
        }
      }
      if (g.sectionType == 'COL_RECT_CROSS_H') {
        for (final sgn in const [-1.0, 1.0]) {
          final zBase = sgn > 0 ? 0.5 * ha - tf : -0.5 * ha;
          for (int iz = 0; iz < nyF; iz++) {
            final zk = zBase + (iz + 0.5) * dyF;
            for (int iy = 0; iy < nzF; iy++) {
              final yk = ycOff - 0.5 * ba + (iy + 0.5) * dzF;
              fibers.add(FiberCell(
                yMm: yk,
                zMm: zk,
                dyMm: dzF,
                dzMm: dyF,
                areaMm2: dyF * dzF,
                kind: 'steel_flange',
                zone: ConcreteZone.highlyConfined,
                fyMpa: mat.fySteelMpa,
                esMpa: mat.esSteelMpa,
              ));
            }
          }
        }
        final arm = math.max(0.0, 0.5 * ha - tf - 0.5 * tw);
        if (arm > 0.5) {
          const nArm = 4;
          final dzA = arm / nArm;
          for (final sgn in const [-1.0, 1.0]) {
            for (int ia = 0; ia < nArm; ia++) {
              fibers.add(FiberCell(
                yMm: ycOff,
                zMm: sgn * (0.5 * tw + (ia + 0.5) * dzA),
                dyMm: tw,
                dzMm: dzA,
                areaMm2: tw * dzA,
                kind: 'steel_web',
                zone: ConcreteZone.highlyConfined,
                fyMpa: mat.fySteelMpa,
                esMpa: mat.esSteelMpa,
              ));
            }
          }
        }
      }
    }

    // 2. Cốt thép dọc
    final rebars = _buildRebarLayout(g);
    for (final rb in rebars) {
      fibers.add(FiberCell(
        yMm: rb.yMm,
        zMm: rb.zMm,
        dyMm: rb.diaMm,
        dzMm: rb.diaMm,
        areaMm2: 0.25 * math.pi * rb.diaMm * rb.diaMm,
        kind: 'rebar',
        zone: ConcreteZone.partiallyConfined,
        fyMpa: mat.fyRebarMpa,
        esMpa: mat.esRebarMpa,
      ));
    }

    // 3. Lưới thớ bê tông 2D
    if (g.sectionType == 'COL_CIRC_H') {
      final rExt = 0.5 * g.bMm;
      final d = g.bMm / ny;
      for (int iy = 0; iy < ny; iy++) {
        final yk = -rExt + (iy + 0.5) * d;
        for (int iz = 0; iz < ny; iz++) {
          final zk = -rExt + (iz + 0.5) * d;
          if (math.sqrt(yk * yk + zk * zk) > rExt) continue;
          if (pointInSteelCore(yk, zk, g) != null) continue;
          fibers.add(FiberCell(
            yMm: yk,
            zMm: zk,
            dyMm: d,
            dzMm: d,
            areaMm2: d * d,
            kind: 'concrete',
            zone: classifyConcreteZone(yk, zk, g),
          ));
        }
      }
    } else if (g.sectionType == 'SRC_T_SLAB_H') {
      final hWeb = math.max(50.0, g.hMm - g.hfSlabMm);
      final nyW = math.max(10, (ny * hWeb / g.hMm).round());
      final nyS = math.max(4, ny - nyW);
      final dyW = hWeb / nyW;
      final dzW = g.bMm / nz;
      for (int iy = 0; iy < nyW; iy++) {
        final yk = -0.5 * g.hMm + (iy + 0.5) * dyW;
        for (int iz = 0; iz < nz; iz++) {
          final zk = -0.5 * g.bMm + (iz + 0.5) * dzW;
          if (pointInSteelCore(yk, zk, g) != null) continue;
          fibers.add(FiberCell(
            yMm: yk,
            zMm: zk,
            dyMm: dyW,
            dzMm: dzW,
            areaMm2: dyW * dzW,
            kind: 'concrete',
            zone: classifyConcreteZone(yk, zk, g),
          ));
        }
      }
      final dyS = g.hfSlabMm / nyS;
      const nzS = 18;
      final dzS = g.bfSlabMm / nzS;
      for (int iy = 0; iy < nyS; iy++) {
        final yk = 0.5 * g.hMm - g.hfSlabMm + (iy + 0.5) * dyS;
        for (int iz = 0; iz < nzS; iz++) {
          final zk = -0.5 * g.bfSlabMm + (iz + 0.5) * dzS;
          if (pointInSteelCore(yk, zk, g) != null) continue;
          fibers.add(FiberCell(
            yMm: yk,
            zMm: zk,
            dyMm: dyS,
            dzMm: dzS,
            areaMm2: dyS * dzS,
            kind: 'concrete',
            zone: classifyConcreteZone(yk, zk, g),
          ));
        }
      }
    } else {
      final dy = g.hMm / ny;
      final dz = g.bMm / nz;
      for (int iy = 0; iy < ny; iy++) {
        final yk = -0.5 * g.hMm + (iy + 0.5) * dy;
        for (int iz = 0; iz < nz; iz++) {
          final zk = -0.5 * g.bMm + (iz + 0.5) * dz;
          if (pointInSteelCore(yk, zk, g) != null) continue;
          fibers.add(FiberCell(
            yMm: yk,
            zMm: zk,
            dyMm: dy,
            dzMm: dz,
            areaMm2: dy * dz,
            kind: 'concrete',
            zone: classifyConcreteZone(yk, zk, g),
          ));
        }
      }
    }

    // Hiệu chỉnh tổng diện tích bê tông chính xác A_c = A_g - A_a - A_s
    double aa = 0, asA = 0, acRaw = 0;
    for (final f in fibers) {
      if (f.kind.startsWith('steel')) {
        aa += f.areaMm2;
      } else if (f.kind == 'rebar') {
        asA += f.areaMm2;
      } else {
        acRaw += f.areaMm2;
      }
    }
    final ag = g.sectionType == 'COL_CIRC_H'
        ? 0.25 * math.pi * g.bMm * g.bMm
        : (g.sectionType == 'SRC_T_SLAB_H'
            ? g.bMm * (g.hMm - g.hfSlabMm) + g.bfSlabMm * g.hfSlabMm
            : g.bMm * g.hMm);
    final targetAc = math.max(1.0, ag - aa - asA);
    final sc = targetAc / math.max(1.0, acRaw);
    final scaled = fibers
        .map((f) => f.kind == 'concrete'
            ? FiberCell(
                yMm: f.yMm,
                zMm: f.zMm,
                dyMm: f.dyMm,
                dzMm: f.dzMm,
                areaMm2: f.areaMm2 * sc,
                kind: f.kind,
                zone: f.zone,
              )
            : f)
        .toList();

    double ac = 0, acU = 0, acP = 0, acH = 0, yNum = 0;
    for (final f in scaled) {
      yNum += f.yMm * f.areaMm2;
      if (f.kind == 'concrete') {
        ac += f.areaMm2;
        if (f.zone == ConcreteZone.unconfined) acU += f.areaMm2;
        if (f.zone == ConcreteZone.partiallyConfined) acP += f.areaMm2;
        if (f.zone == ConcreteZone.highlyConfined) acH += f.areaMm2;
      }
    }
    final yCent = yNum / math.max(1.0, ag);
    double icZ = 0, iaZ = 0, isZ = 0, icY = 0, iaY = 0, isY = 0;
    for (final f in scaled) {
      final dyC = f.yMm - yCent;
      final izLoc = f.areaMm2 * (dyC * dyC + f.dyMm * f.dyMm / 12.0);
      final iyLoc = f.areaMm2 * (f.zMm * f.zMm + f.dzMm * f.dzMm / 12.0);
      if (f.kind == 'concrete') {
        icZ += izLoc;
        icY += iyLoc;
      } else if (f.kind.startsWith('steel')) {
        iaZ += izLoc;
        iaY += iyLoc;
      } else {
        isZ += f.areaMm2 * dyC * dyC;
        isY += f.areaMm2 * f.zMm * f.zMm;
      }
    }

    final aSv1 = 0.25 * math.pi * g.stirrupDiaMm * g.stirrupDiaMm;
    final bCore = math.max(60.0, g.bMm - 2.0 * g.coverMm - g.stirrupDiaMm);
    final hCore = math.max(60.0, g.hMm - 2.0 * g.coverMm - g.stirrupDiaMm);
    final rhoV = g.sectionType == 'COL_CIRC_H'
        ? 4.0 * aSv1 / (bCore * math.max(30.0, g.stirrupSpacingMm))
        : aSv1 * (2.0 * (bCore + hCore) + math.max(0, g.nStirrupLegs - 2) * hCore) /
            (bCore * hCore * math.max(30.0, g.stirrupSpacingMm));

    final steelRatio = aa / math.max(1.0, ag);
    final conf = computeConfinement(mat, rhoV, steelRatio);
    final props = SectionProperties(
      agMm2: ag,
      acMm2: ac,
      aaMm2: aa,
      asMm2: asA,
      acUnconfinedMm2: acU,
      acPartConfMm2: acP,
      acHighConfMm2: acH,
      icZMm4: icZ,
      iaZMm4: iaZ,
      isZMm4: isZ,
      icYMm4: icY,
      iaYMm4: iaY,
      isYMm4: isY,
      steelRatio: steelRatio,
      rebarRatio: asA / math.max(1.0, ag),
      volStirrupRatio: rhoV,
      rebars: rebars,
    );
    return (fibers: scaled, props: props, conf: conf);
  }

  static SectionState evaluateSection(
    double eps0,
    double kappaZ,
    double kappaY,
    List<FiberCell> fibers,
    SectionGeometry g,
    MaterialConfig mat,
    ConfinementParams conf,
    bool nonlinear,
  ) {
    double nN = 0, mz = 0, my = 0;
    double d00 = 0, d01 = 0, d02 = 0, d11 = 0, d12 = 0, d22 = 0;
    double epsCMin = 0, epsCMax = 0, sigCMin = 0, sigStMax = 0, sigRbMax = 0;
    double acTot = 0, acCr = 0;
    bool stY = false, rbY = false, ccCr = false;

    for (final f in fibers) {
      final eps = eps0 - f.yMm * kappaZ + f.zMm * kappaY;
      double sig, et;
      if (f.kind == 'concrete') {
        final r = concreteLaw(eps, mat, f.zone, conf, nonlinear);
        sig = r.sig;
        et = r.et;
        acTot += f.areaMm2;
        if (eps < epsCMin) epsCMin = eps;
        if (eps > epsCMax) epsCMax = eps;
        if (sig < sigCMin) sigCMin = sig;
        if (r.cracked) acCr += f.areaMm2;
        if (r.crushed) ccCr = true;
      } else {
        final bh = f.kind.startsWith('steel') ? mat.hardeningSteel : mat.hardeningRebar;
        final r = steelLaw(eps, f.esMpa, f.fyMpa, bh, nonlinear);
        sig = r.sig;
        et = r.et;
        if (f.kind.startsWith('steel')) {
          if (sig.abs() > sigStMax) sigStMax = sig.abs();
          if (r.yielded) stY = true;
        } else {
          if (sig.abs() > sigRbMax) sigRbMax = sig.abs();
          if (r.yielded) rbY = true;
        }
      }
      final sa = sig * f.areaMm2;
      final ea = et * f.areaMm2;
      nN += sa;
      mz -= sa * f.yMm;
      my += sa * f.zMm;
      d00 += ea;
      d01 -= ea * f.yMm;
      d02 += ea * f.zMm;
      d11 += ea * f.yMm * f.yMm;
      d12 -= ea * f.yMm * f.zMm;
      d22 += ea * f.zMm * f.zMm;
    }

    final eaMin = 0.004 * mat.ecMpa * g.bMm * g.hMm;
    final eiZMin = 0.004 * mat.ecMpa * g.bMm * math.pow(g.hMm, 3) / 12.0;
    final eiYMin = 0.004 * mat.ecMpa * g.hMm * math.pow(g.bMm, 3) / 12.0;
    if (d00 < eaMin) d00 = eaMin;
    double eiZEff = d11 - (d01 * d01) / d00;
    if (eiZEff < eiZMin) {
      d11 = (d01 * d01) / d00 + eiZMin;
      eiZEff = eiZMin;
    }
    double eiYEff = d22 - (d02 * d02) / d00;
    if (eiYEff < eiYMin) {
      d22 = (d02 * d02) / d00 + eiYMin;
      eiYEff = eiYMin;
    }
    final xNa = kappaZ.abs() > 1e-11
        ? (0.5 * g.hMm - eps0 / kappaZ).clamp(0.0, g.hMm)
        : (eps0 < 0 ? g.hMm : 0.0);

    return SectionState(
      eps0: eps0,
      kappaZ: kappaZ,
      kappaY: kappaY,
      nN: nN,
      mzNmm: mz,
      myNmm: my,
      d00: d00,
      d01: d01,
      d02: d02,
      d11: d11,
      d12: d12,
      d22: d22,
      eiZEff: eiZEff,
      eiYEff: eiYEff,
      xNaMm: xNa,
      epsCMin: epsCMin,
      epsCMax: epsCMax,
      sigCMinMpa: sigCMin,
      sigSteelMaxMpa: sigStMax,
      sigRebarMaxMpa: sigRbMax,
      crackedRatio: acCr / math.max(1.0, acTot),
      steelYielded: stY,
      rebarYielded: rbY,
      concreteCrushed: ccCr,
    );
  }

  /// Giải hệ tuyến tính A·x = b bằng khử Gauss chọn phần tử trụ từng phần
  static List<double>? _solveLinearSystem(List<List<double>> aIn, List<double> bIn) {
    final n = bIn.length;
    final a = List.generate(n, (i) => List<double>.from(aIn[i]));
    final b = List<double>.from(bIn);
    for (int col = 0; col < n; col++) {
      int piv = col;
      double maxV = a[col][col].abs();
      for (int r = col + 1; r < n; r++) {
        if (a[r][col].abs() > maxV) {
          maxV = a[r][col].abs();
          piv = r;
        }
      }
      if (maxV < 1e-12) return null;
      if (piv != col) {
        final tmpA = a[col];
        a[col] = a[piv];
        a[piv] = tmpA;
        final tmpB = b[col];
        b[col] = b[piv];
        b[piv] = tmpB;
      }
      final diag = a[col][col];
      for (int r = col + 1; r < n; r++) {
        final f = a[r][col] / diag;
        if (f == 0.0) continue;
        for (int c = col; c < n; c++) {
          a[r][c] -= f * a[col][c];
        }
        b[r] -= f * b[col];
      }
    }
    final x = List<double>.filled(n, 0.0);
    for (int r = n - 1; r >= 0; r--) {
      double s = b[r];
      for (int c = r + 1; c < n; c++) {
        s -= a[r][c] * x[c];
      }
      x[r] = s / a[r][r];
    }
    return x;
  }

  static ({double mPlKnm, double xPnaMm}) _plasticMomentPsd(
    List<FiberCell> fibers,
    double hMm,
    double fcEff,
    double fyStEff,
    double fyRbEff, {
    String axis = 'z',
  }) {
    double lo = -0.5 * hMm, hi = 0.5 * hMm;
    for (int it = 0; it < 52; it++) {
      final mid = 0.5 * (lo + hi);
      double netN = 0.0;
      for (final f in fibers) {
        final coord = axis == 'z' ? f.yMm : f.zMm;
        if (f.kind == 'concrete') {
          if (coord >= mid) netN -= fcEff * f.areaMm2;
        } else {
          final fy = f.kind.startsWith('steel') ? fyStEff : fyRbEff;
          netN += (coord >= mid ? -fy : fy) * f.areaMm2;
        }
      }
      if (netN > 0) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    final yp = 0.5 * (lo + hi);
    double mPl = 0.0;
    for (final f in fibers) {
      final coord = axis == 'z' ? f.yMm : f.zMm;
      if (f.kind == 'concrete') {
        if (coord >= yp) mPl += fcEff * f.areaMm2 * (coord - yp);
      } else {
        final fy = f.kind.startsWith('steel') ? fyStEff : fyRbEff;
        final sig = coord >= yp ? -fy : fy;
        mPl -= sig * f.areaMm2 * (coord - yp);
      }
    }
    return (mPlKnm: mPl / 1e6, xPnaMm: 0.5 * hMm - yp);
  }

  static double _ec3Chi(double lam, double alpha) {
    if (lam <= 0.20) return 1.0;
    final phi = 0.5 * (1.0 + alpha * (lam - 0.20) + lam * lam);
    return math.min(1.0, 1.0 / (phi + math.sqrt(math.max(1e-12, phi * phi - lam * lam))));
  }

  static double _normVec(List<double> v) {
    double s = 0;
    for (final x in v) {
      s += x * x;
    }
    return math.sqrt(s);
  }

  /// Tính Bảng thống kê thép hình, cốt thép, phụ kiện & bê tông (BOM / BBS)
  static List<BomItem> computeBom(SrcMemberConfig cfg, SectionProperties props) {
    final g = cfg.geometry;
    final isBeam = cfg.kind == MemberKind.beam;
    final lM = cfg.lengthMm / 1000.0;
    const rho = 7850.0;

    final wSteel = (props.aaMm2 / 1e6) * rho * lM * 1.03;
    double wRebar = 0;
    for (final rb in props.rebars) {
      final a = 0.25 * math.pi * math.pow(rb.diaMm / 1000.0, 2);
      wRebar += a * (lM + 2.0 * 35.0 * rb.diaMm / 1000.0) * rho;
    }
    final nEnd = (0.5 * cfg.lengthMm / math.max(40.0, g.stirrupSpacingEndMm)).ceil();
    final nMid = (0.5 * cfg.lengthMm / math.max(40.0, g.stirrupSpacingMm)).ceil();
    final nSt = nEnd + nMid + 2;
    final pHoop = g.sectionType == 'COL_CIRC_H'
        ? math.pi * math.max(80.0, g.bMm - 2 * g.coverMm) + 20 * g.stirrupDiaMm
        : 2.0 * (math.max(60.0, g.bMm - 2 * g.coverMm) + math.max(60.0, g.hMm - 2 * g.coverMm)) +
            20 * g.stirrupDiaMm +
            math.max(0, g.nStirrupLegs - 2) * (math.max(60.0, g.hMm - 2 * g.coverMm) + 12 * g.stirrupDiaMm);
    final wStir = nSt * (pHoop / 1000.0) * 0.25 * math.pi * math.pow(g.stirrupDiaMm / 1000.0, 2) * rho;

    final profLabel = g.sectionType == 'COL_RECT_CROSS_H'
        ? '2×H${g.haMm.toStringAsFixed(0)}×${g.baMm.toStringAsFixed(0)}×${g.twMm.toStringAsFixed(1)}×${g.tfMm.toStringAsFixed(1)}'
        : (g.sectionType == 'COL_RECT_CFST'
            ? 'CHS Ø${g.haMm.toStringAsFixed(0)}×${g.tfMm.toStringAsFixed(1)}'
            : 'H${g.haMm.toStringAsFixed(0)}×${g.baMm.toStringAsFixed(0)}×${g.twMm.toStringAsFixed(1)}×${g.tfMm.toStringAsFixed(1)}');

    final BomItem extra;
    if (isBeam) {
      final nStuds = (((cfg.lengthMm - 200.0) / math.max(60.0, cfg.studSpacingMm)).floor() + 1) * cfg.studRows;
      final wStud = nStuds * 0.25 * math.pi * math.pow(cfg.studDiaMm / 1000.0, 2) * ((cfg.studHeightMm + 15.0) / 1000.0) * rho;
      extra = BomItem(
        mark: 'ST-1',
        descVi: 'Đinh neo chống cắt Ø${cfg.studDiaMm.toStringAsFixed(0)}×${cfg.studHeightMm.toStringAsFixed(0)} @${cfg.studSpacingMm.toStringAsFixed(0)}',
        descEn: 'Headed Shear Studs Ø${cfg.studDiaMm.toStringAsFixed(0)}×${cfg.studHeightMm.toStringAsFixed(0)} @${cfg.studSpacingMm.toStringAsFixed(0)}',
        grade: 'fu=${cfg.studFuMpa.toStringAsFixed(0)} MPa',
        qtyVi: '$nStuds cái',
        qtyEn: '$nStuds pcs',
        weightKg: wStud,
      );
    } else {
      final bpW = (g.bMm + 120.0) / 1000.0;
      final bpH = (g.hMm + 120.0) / 1000.0;
      final wBp = (bpW * bpH * 0.030 + 4 * 0.15 * 0.20 * 0.012) * rho;
      extra = BomItem(
        mark: 'BP-1',
        descVi: 'Bản đế chân cột PL30×${(g.bMm + 120).toStringAsFixed(0)}×${(g.hMm + 120).toStringAsFixed(0)} + 8×M24',
        descEn: 'Column Baseplate PL30×${(g.bMm + 120).toStringAsFixed(0)}×${(g.hMm + 120).toStringAsFixed(0)} + 8×M24',
        grade: cfg.material.steelGrade,
        qtyVi: '1 bộ',
        qtyEn: '1 set',
        weightKg: wBp,
      );
    }
    final volC = (props.acMm2 / 1e6) * lM;
    return [
      BomItem(
        mark: 'S-1',
        descVi: 'Lõi thép hình $profLabel, L=${cfg.lengthMm.toStringAsFixed(0)} mm',
        descEn: 'Encased Steel $profLabel, L=${cfg.lengthMm.toStringAsFixed(0)} mm',
        grade: cfg.material.steelGrade,
        qtyVi: '1 cây',
        qtyEn: '1 pc',
        weightKg: wSteel,
      ),
      BomItem(
        mark: 'R-1',
        descVi: 'Cốt thép dọc (${props.rebars.length} thanh Ø${g.rebarDiaBotMm.toStringAsFixed(0)}/Ø${g.rebarDiaTopMm.toStringAsFixed(0)})',
        descEn: 'Longitudinal Rebar (${props.rebars.length} bars Ø${g.rebarDiaBotMm.toStringAsFixed(0)}/Ø${g.rebarDiaTopMm.toStringAsFixed(0)})',
        grade: cfg.material.rebarGrade,
        qtyVi: '${props.rebars.length} thanh',
        qtyEn: '${props.rebars.length} bars',
        weightKg: wRebar,
      ),
      BomItem(
        mark: 'R-2',
        descVi: 'Cốt đai Ø${g.stirrupDiaMm.toStringAsFixed(0)} @${g.stirrupSpacingEndMm.toStringAsFixed(0)}/${g.stirrupSpacingMm.toStringAsFixed(0)} (${g.nStirrupLegs} nhánh)',
        descEn: 'Stirrups Ø${g.stirrupDiaMm.toStringAsFixed(0)} @${g.stirrupSpacingEndMm.toStringAsFixed(0)}/${g.stirrupSpacingMm.toStringAsFixed(0)} (${g.nStirrupLegs} legs)',
        grade: 'fy=${cfg.material.fyStirrupMpa.toStringAsFixed(0)} MPa',
        qtyVi: '$nSt đai',
        qtyEn: '$nSt pcs',
        weightKg: wStir,
      ),
      extra,
      BomItem(
        mark: 'C-1',
        descVi: 'Bê tông ${cfg.material.concreteGrade} (f\'c=${cfg.material.fcMpa.toStringAsFixed(1)} MPa)',
        descEn: 'Concrete ${cfg.material.concreteGrade} (f\'c=${cfg.material.fcMpa.toStringAsFixed(1)} MPa)',
        grade: cfg.material.concreteGrade,
        qtyVi: '${volC.toStringAsFixed(3)} m³',
        qtyEn: '${volC.toStringAsFixed(3)} m³',
        weightKg: volC * 2450.0,
      ),
    ];
  }

  /// Hàm chạy phân tích tổng quát cho cả Dầm và Cột SRC
  static SrcAnalysisResult solve(SrcMemberConfig cfg) {
    return cfg.kind == MemberKind.beam ? _solveBeam(cfg) : _solveColumn(cfg);
  }

  // ==========================================================================
  // BỘ GIẢI PHI TUYẾN DẦM BÊ TÔNG CỐT CỨNG (FIBER BEAM FEM + MULTI-CODE)
  // ==========================================================================
  static SrcAnalysisResult _solveBeam(SrcMemberConfig cfg) {
    final sec = build2DFiberSection(cfg.geometry, cfg.material);
    final fibers = sec.fibers;
    final props = sec.props;
    final conf = sec.conf;
    final g = cfg.geometry;
    final m = cfg.material;
    final L = cfg.lengthMm;

    // Sinh tọa độ nút
    final pts = <double>{};
    final nEl = math.max(4, cfg.nElems);
    for (int i = 0; i <= nEl; i++) {
      pts.add((L * i / nEl * 1000).round() / 1000.0);
    }
    if (cfg.loadType == '3pt' || cfg.loadType == 'combined') {
      pts.add(cfg.loadAMm.clamp(0.08 * L, 0.92 * L));
    } else if (cfg.loadType == '4pt') {
      final a = cfg.loadAMm.clamp(0.08 * L, 0.48 * L);
      pts.add(a);
      pts.add(L - a);
    }
    final sortedPts = pts.toList()..sort();
    final xNodes = <double>[sortedPts.first];
    for (int i = 1; i < sortedPts.length; i++) {
      if (sortedPts[i] - xNodes.last > 1.0) xNodes.add(sortedPts[i]);
    }
    xNodes[xNodes.length - 1] = L;

    final nNodes = xNodes.length;
    final nDofs = 3 * nNodes;
    final fRef = List<double>.filled(nDofs, 0.0);
    double totalLoadKn = 0.0;
    if (cfg.loadType == 'udl' || cfg.loadType == 'combined') {
      final q = cfg.qUdlKnM;
      totalLoadKn += q * L / 1000.0;
      for (int e = 0; e < nNodes - 1; e++) {
        final le = xNodes[e + 1] - xNodes[e];
        fRef[3 * e + 1] -= 0.5 * q * le;
        fRef[3 * e + 2] -= q * le * le / 12.0;
        fRef[3 * (e + 1) + 1] -= 0.5 * q * le;
        fRef[3 * (e + 1) + 2] += q * le * le / 12.0;
      }
    }
    if (cfg.loadType == '3pt' || cfg.loadType == 'combined') {
      final a = cfg.loadAMm.clamp(0.08 * L, 0.92 * L);
      int idx = 0;
      for (int i = 1; i < nNodes; i++) {
        if ((xNodes[i] - a).abs() < (xNodes[idx] - a).abs()) idx = i;
      }
      fRef[3 * idx + 1] -= cfg.pPointKn * 1000.0;
      totalLoadKn += cfg.pPointKn;
    } else if (cfg.loadType == '4pt') {
      final a = cfg.loadAMm.clamp(0.08 * L, 0.48 * L);
      int i1 = 0, i2 = 0;
      for (int i = 1; i < nNodes; i++) {
        if ((xNodes[i] - a).abs() < (xNodes[i1] - a).abs()) i1 = i;
        if ((xNodes[i] - (L - a)).abs() < (xNodes[i2] - (L - a)).abs()) i2 = i;
      }
      fRef[3 * i1 + 1] -= 0.5 * cfg.pPointKn * 1000.0;
      fRef[3 * i2 + 1] -= 0.5 * cfg.pPointKn * 1000.0;
      totalLoadKn += cfg.pPointKn;
    }

    final fixed = <int>{};
    void applySup(int idx, String sup) {
      if (sup == 'pin') {
        fixed.addAll([3 * idx, 3 * idx + 1]);
      } else if (sup == 'roller') {
        fixed.add(3 * idx + 1);
      } else if (sup == 'fixed') {
        fixed.addAll([3 * idx, 3 * idx + 1, 3 * idx + 2]);
      }
    }

    applySup(0, cfg.leftSupport);
    applySup(nNodes - 1, cfg.rightSupport);
    if (!fixed.any((d) => d % 3 == 0)) fixed.add(0);
    final free = [for (int i = 0; i < nDofs; i++) if (!fixed.contains(i)) i];

    const gpXi = [0.1127016653792583, 0.5, 0.8872983346207417];
    const gpW = [5.0 / 18.0, 8.0 / 18.0, 5.0 / 18.0];

    ({List<double> fInt, List<List<double>> kt, List<ElemSolution> elems}) assemble(
      List<double> dVec,
      bool nonlinear,
    ) {
      final fInt = List<double>.filled(nDofs, 0.0);
      final kt = List.generate(nDofs, (_) => List<double>.filled(nDofs, 0.0));
      final elems = <ElemSolution>[];
      for (int e = 0; e < nNodes - 1; e++) {
        final le = xNodes[e + 1] - xNodes[e];
        final dofs = [3 * e, 3 * e + 1, 3 * e + 2, 3 * (e + 1), 3 * (e + 1) + 1, 3 * (e + 1) + 2];
        final de = [for (final k in dofs) dVec[k]];
        final fe = List<double>.filled(6, 0.0);
        final ke = List.generate(6, (_) => List<double>.filled(6, 0.0));
        final gps = <SectionState>[];

        for (int gi = 0; gi < 3; gi++) {
          final xi = gpXi[gi];
          final wDx = gpW[gi] * le;
          final bu = [-1.0 / le, 0.0, 0.0, 1.0 / le, 0.0, 0.0];
          final bk = [
            0.0,
            (-6.0 + 12.0 * xi) / (le * le),
            (-4.0 + 6.0 * xi) / le,
            0.0,
            (6.0 - 12.0 * xi) / (le * le),
            (-2.0 + 6.0 * xi) / le,
          ];
          double eps0 = 0, kz = 0;
          for (int i = 0; i < 6; i++) {
            eps0 += bu[i] * de[i];
            kz += bk[i] * de[i];
          }
          final st = evaluateSection(eps0, kz, 0.0, fibers, g, m, conf, nonlinear);
          gps.add(st);
          for (int i = 0; i < 6; i++) {
            fe[i] += (bu[i] * st.nN + bk[i] * st.mzNmm) * wDx;
            final t0 = st.d00 * bu[i] + st.d01 * bk[i];
            final t1 = st.d01 * bu[i] + st.d11 * bk[i];
            for (int j = 0; j < 6; j++) {
              ke[i][j] += (t0 * bu[j] + t1 * bk[j]) * wDx;
            }
          }
        }
        for (int i = 0; i < 6; i++) {
          fInt[dofs[i]] += fe[i];
          for (int j = 0; j < 6; j++) {
            kt[dofs[i]][dofs[j]] += ke[i][j];
          }
        }
        elems.add(ElemSolution(
          elemIdx: e,
          x1Mm: xNodes[e],
          x2Mm: xNodes[e + 1],
          lengthMm: le,
          dElem: de,
          fElem: fe,
          gpStates: gps,
        ));
      }
      return (fInt: fInt, kt: kt, elems: elems);
    }

    ({List<double> d, List<ElemSolution> elems, bool ok}) solveStep(
      List<double> dInit,
      double lam,
      bool nonlinear,
    ) {
      var d = List<double>.from(dInit);
      final fExt = [for (final f in fRef) f * lam];
      final fFree = [for (final i in free) fExt[i]];
      final fNorm = math.max(1000.0, _normVec(fFree));
      List<ElemSolution> elems = const [];

      for (int it = 0; it < 24; it++) {
        final a = assemble(d, nonlinear);
        elems = a.elems;
        final rf = [for (final i in free) fExt[i] - a.fInt[i]];
        final err = _normVec(rf) / fNorm;
        if (!nonlinear) {
          final kff = [for (final r in free) [for (final c in free) a.kt[r][c]]];
          final dd = _solveLinearSystem(kff, rf);
          if (dd != null) {
            for (int i = 0; i < free.length; i++) {
              d[free[i]] += dd[i];
            }
          }
          final a2 = assemble(d, false);
          return (d: d, elems: a2.elems, ok: true);
        }
        if (err < 2e-4) return (d: d, elems: elems, ok: true);
        final kff = [for (final r in free) [for (final c in free) a.kt[r][c]]];
        final dd = _solveLinearSystem(kff, rf);
        if (dd == null) return (d: dInit, elems: elems, ok: false);

        double alpha = 1.0;
        final baseR = _normVec(rf);
        for (int ls = 0; ls < 4; ls++) {
          final dTry = List<double>.from(d);
          for (int i = 0; i < free.length; i++) {
            dTry[free[i]] += alpha * dd[i];
          }
          final aTry = assemble(dTry, true);
          final rTry = [for (final i in free) fExt[i] - aTry.fInt[i]];
          if (_normVec(rTry) <= 1.03 * baseR || alpha <= 0.125) {
            d = dTry;
            break;
          }
          alpha *= 0.5;
        }
      }
      return (d: d, elems: elems, ok: true);
    }

    // 1. Đàn hồi tuyến tính
    final lin = solveStep(List<double>.filled(nDofs, 0.0), 1.0, false);
    double maxDeflLin = 0;
    for (int i = 0; i < nNodes; i++) {
      maxDeflLin = math.max(maxDeflLin, lin.d[3 * i + 1].abs());
    }

    // 2. Gia tăng phi tuyến đến 1.0 x tải thiết kế + đẩy tới cực hạn
    final eiGross = m.ecMpa * props.icZMm4 + m.esSteelMpa * props.iaZMm4 + m.esRebarMpa * props.isZMm4;
    LoadStepRecord summarize(List<double> dVec, List<ElemSolution> els, double lam, bool keepSnap) {
      double defl = 0, mMax = 0, vMax = 0, epsMin = 0, sSt = 0, sRb = 0, cr = 0, eiMin = eiGross;
      bool stY = false, rbY = false, ccCr = false;
      for (int i = 0; i < nNodes; i++) {
        defl = math.max(defl, dVec[3 * i + 1].abs());
      }
      for (final el in els) {
        vMax = math.max(vMax, math.max(el.fElem[1].abs(), el.fElem[4].abs()) / 1000.0);
        for (final gs in el.gpStates) {
          mMax = math.max(mMax, gs.mzNmm.abs() / 1e6);
          epsMin = math.min(epsMin, gs.epsCMin);
          sSt = math.max(sSt, gs.sigSteelMaxMpa);
          sRb = math.max(sRb, gs.sigRebarMaxMpa);
          cr = math.max(cr, gs.crackedRatio);
          stY = stY || gs.steelYielded;
          rbY = rbY || gs.rebarYielded;
          ccCr = ccCr || gs.concreteCrushed;
          eiMin = math.min(eiMin, gs.eiZEff);
        }
      }
      return LoadStepRecord(
        lambda: lam,
        loadKn: lam * totalLoadKn,
        deflMm: defl,
        axialShortMm: 0.0,
        mMaxKnm: mMax,
        vMaxKn: vMax,
        eiRatio: (eiMin / math.max(1.0, eiGross)).clamp(0.0, 1.0),
        epsCMin: epsMin,
        sigSteelMaxMpa: sSt,
        sigRebarMaxMpa: sRb,
        crackedRatio: cr,
        steelYielded: stY,
        rebarYielded: rbY,
        concreteCrushed: ccCr,
        elemsSnapshot: keepSnap ? els : null,
      );
    }

    final history = <LoadStepRecord>[
      const LoadStepRecord(
        lambda: 0, loadKn: 0, deflMm: 0, axialShortMm: 0, mMaxKnm: 0, vMaxKn: 0,
        eiRatio: 1, epsCMin: 0, sigSteelMaxMpa: 0, sigRebarMaxMpa: 0, crackedRatio: 0,
        steelYielded: false, rebarYielded: false, concreteCrushed: false,
      ),
    ];

    var dCur = List<double>.filled(nDofs, 0.0);
    List<ElemSolution> designElems = lin.elems;
    final nSteps = math.max(6, cfg.nStepsDesign);
    for (int k = 1; k <= nSteps; k++) {
      final lam = k / nSteps;
      final res = solveStep(dCur, lam, true);
      dCur = res.d;
      final rec = summarize(dCur, res.elems, lam, true);
      history.add(rec);
      if (k == nSteps) designElems = res.elems;
    }

    // Đẩy tải tới cực hạn phá hoại
    double lam = 1.0;
    double dLam = 0.09;
    var ultRec = history.last;
    for (int step = 0; step < 42; step++) {
      final res = solveStep(dCur, lam + dLam, true);
      if (!res.ok) {
        dLam *= 0.5;
        if (dLam < 0.015) break;
        continue;
      }
      lam += dLam;
      dCur = res.d;
      final rec = summarize(dCur, res.elems, lam, false);
      history.add(rec);
      ultRec = rec;
      if (rec.concreteCrushed || rec.epsCMin.abs() >= conf.epsCuU || rec.deflMm > L / 35.0) break;
    }

    final desRec = history[math.min(nSteps, history.length - 1)];
    final yRec = history.firstWhere((h) => h.steelYielded || h.rebarYielded, orElse: () => desRec);
    final ductility = ultRec.deflMm / math.max(0.5, yRec.deflMm);

    // Biểu đồ dọc nhịp
    final pX = <double>[], pDefl = <double>[], pM = <double>[], pV = <double>[], pEi = <double>[];
    for (final el in designElems) {
      final le = el.lengthMm;
      final de = el.dElem;
      final vSh = el.fElem[1] / 1000.0;
      for (int gi = 0; gi < 3; gi++) {
        final xi = gpXi[gi];
        final n1 = 1 - 3 * xi * xi + 2 * xi * xi * xi;
        final n2 = le * (xi - 2 * xi * xi + xi * xi * xi);
        final n3 = 3 * xi * xi - 2 * xi * xi * xi;
        final n4 = le * (-xi * xi + xi * xi * xi);
        pX.add(el.x1Mm + xi * le);
        pDefl.add(n1 * de[1] + n2 * de[2] + n3 * de[4] + n4 * de[5]);
        pM.add(el.gpStates[gi].mzNmm / 1e6);
        pV.add(vSh);
        pEi.add((el.gpStates[gi].eiZEff / math.max(1.0, eiGross)).clamp(0.0, 1.0));
      }
    }

    final mEd = pM.fold<double>(0.0, (mx, v) => math.max(mx, v.abs()));
    final vEd = pV.fold<double>(0.0, (mx, v) => math.max(mx, v.abs()));

    // Đường cong M–κ
    final mkCurve = _computeMKCurve(fibers, g, m, conf, 0.0);

    // Kiểm tra đa tiêu chuẩn Dầm
    final hwSt = math.max(10.0, g.haMm - 2 * g.tfMm);
    final avSt = hwSt * g.twMm;
    final dEff = g.hMm - (g.coverMm + g.stirrupDiaMm + 0.5 * g.rebarDiaBotMm);
    final zArm = 0.90 * dEff;
    final aSv = g.nStirrupLegs * 0.25 * math.pi * g.stirrupDiaMm * g.stirrupDiaMm;
    final sSv = math.max(40.0, g.stirrupSpacingEndMm);
    final eta = conf.etaHsc;

    // 1. EC4 + SMARTCOCO
    final fcd = 0.85 * eta * m.fcMpa / m.gammaC;
    final fyd = m.fySteelMpa / m.gammaA;
    final fsd = m.fyRebarMpa / m.gammaS;
    final fywd = m.fyStirrupMpa / m.gammaS;
    final psdEc4 = _plasticMomentPsd(fibers, g.hMm, fcd, fyd, fsd);
    final vRdA = avSt * (fyd / math.sqrt(3.0)) / 1000.0;
    final vRdS = (aSv / sSv) * zArm * fywd / 1000.0;
    final vRdEc4 = vRdA + vRdS;
    final vShare = vEd * (vRdA / math.max(1.0, vRdEc4));
    final rhoMv = vShare > 0.5 * vRdA ? math.min(0.95, math.pow(2.0 * vShare / math.max(1.0, vRdA) - 1.0, 2).toDouble()) : 0.0;
    final mRdEc4 = psdEc4.mPlKnm - rhoMv * (g.twMm * hwSt * hwSt / 4.0) * fyd / 1e6;

    // 2. AISC 360-22
    final psdAisc = _plasticMomentPsd(fibers, g.hMm, 0.85 * m.fcMpa, m.fySteelMpa, m.fyRebarMpa);
    final phiMAisc = 0.90 * psdAisc.mPlKnm;
    final phiVAisc = 0.75 * (0.6 * m.fySteelMpa * avSt + aSv * m.fyStirrupMpa * dEff / sSv) / 1000.0;

    // 3. JGJ 138-2016
    final fcJ = 0.76 * m.fcMpa / 1.40;
    final ftJ = 0.70 * m.fctMpa / 1.40;
    final faJ = m.fySteelMpa / 1.11;
    final fyJ = m.fyRebarMpa / 1.11;
    final mRdJgj = _plasticMomentPsd(fibers, g.hMm, fcJ, faJ, fyJ).mPlKnm;
    final vRdJgj = (0.7 * ftJ * g.bMm * dEff + (m.fyStirrupMpa / 1.11) * (aSv / sSv) * dEff + 0.58 * faJ * avSt) / 1000.0;

    // 4. TCVN 5574/5575 + SP 266
    final rb = 0.77 * m.fcMpa / 1.30;
    final rbt = 0.75 * m.fctMpa / 1.50;
    final rs = m.fyRebarMpa / 1.15;
    final ry = m.fySteelMpa / 1.05;
    final rsw = 0.80 * m.fyStirrupMpa / 1.15;
    final mRdTcvn = _plasticMomentPsd(fibers, g.hMm, rb, ry, rs).mPlKnm;
    final vRdTcvn = (0.5 * rbt * g.bMm * dEff + 0.75 * rsw * (aSv / sSv) * dEff + 0.58 * ry * avSt) / 1000.0;

    // Weng (2002) Shear-Splitting & Đinh neo EC4 §6.6.3
    final bfBw = g.baMm / math.max(1.0, g.bMm);
    final bNet = math.max(20.0, g.bMm - g.baMm);
    final vSplit = (0.35 * math.sqrt(m.fcMpa) * bNet * dEff + aSv * m.fyStirrupMpa * dEff / sSv) / 1000.0;
    final alphaSt = (cfg.studHeightMm / math.max(1.0, cfg.studDiaMm)) > 4.0
        ? 1.0
        : 0.2 * (cfg.studHeightMm / math.max(1.0, cfg.studDiaMm) + 1.0);
    final pRdStud = math.min(
      0.8 * cfg.studFuMpa * 0.25 * math.pi * cfg.studDiaMm * cfg.studDiaMm / 1.25 / 1000.0,
      0.29 * alphaSt * cfg.studDiaMm * cfg.studDiaMm * math.sqrt(m.fcMpa * m.ecMpa) / 1.25 / 1000.0,
    );
    final vLong = math.min(
      fcd * (g.sectionType == 'SRC_T_SLAB_H' ? g.bfSlabMm * g.hfSlabMm : g.bMm * psdEc4.xPnaMm) / 1000.0,
      fyd * props.aaMm2 / 1000.0,
    );
    final studsReq = (vLong / math.max(1.0, pRdStud)).ceil();
    final studsProv = ((0.5 * L) / math.max(50.0, cfg.studSpacingMm)).floor() * cfg.studRows;
    final deflLim = L / cfg.deflectionLimitRatio;

    final checks = [
      CodeCheckRow(
        codeId: 'EC4',
        title: 'Eurocode 4 (EN 1994-1-1) & SMARTCOCO',
        capacityPrimary: mRdEc4,
        capacitySecondary: vRdEc4,
        urPrimary: mEd / math.max(1.0, mRdEc4),
        urSecondary: vEd / math.max(1.0, vRdEc4),
        urTotal: math.max(mEd / math.max(1.0, mRdEc4), vEd / math.max(1.0, vRdEc4)),
        extraNote: 'x_PNA=${psdEc4.xPnaMm.toStringAsFixed(0)}mm, ρ_MV=${rhoMv.toStringAsFixed(2)}',
        pass: mEd <= mRdEc4 && vEd <= vRdEc4,
      ),
      CodeCheckRow(
        codeId: 'AISC',
        title: 'ANSI/AISC 360-22 (Ch. I — LRFD)',
        capacityPrimary: phiMAisc,
        capacitySecondary: phiVAisc,
        urPrimary: mEd / math.max(1.0, phiMAisc),
        urSecondary: vEd / math.max(1.0, phiVAisc),
        urTotal: math.max(mEd / math.max(1.0, phiMAisc), vEd / math.max(1.0, phiVAisc)),
        extraNote: 'φb=0.90, Mn=${psdAisc.mPlKnm.toStringAsFixed(1)} kN·m',
        pass: mEd <= phiMAisc && vEd <= phiVAisc,
      ),
      CodeCheckRow(
        codeId: 'JGJ138',
        title: 'JGJ 138-2016 (China SRC Ch. 5)',
        capacityPrimary: mRdJgj,
        capacitySecondary: vRdJgj,
        urPrimary: mEd / math.max(1.0, mRdJgj),
        urSecondary: vEd / math.max(1.0, vRdJgj),
        urTotal: math.max(mEd / math.max(1.0, mRdJgj), vEd / math.max(1.0, vRdJgj)),
        extraNote: 'Vc+Vsv+Va (Chồng chập)',
        pass: mEd <= mRdJgj && vEd <= vRdJgj,
      ),
      CodeCheckRow(
        codeId: 'TCVN',
        title: 'TCVN 5574/5575 + SP 266',
        capacityPrimary: mRdTcvn,
        capacitySecondary: vRdTcvn,
        urPrimary: mEd / math.max(1.0, mRdTcvn),
        urSecondary: vEd / math.max(1.0, vRdTcvn),
        urTotal: math.max(mEd / math.max(1.0, mRdTcvn), vEd / math.max(1.0, vRdTcvn)),
        extraNote: 'Rb=${rb.toStringAsFixed(1)}, Ry=${ry.toStringAsFixed(0)} MPa',
        pass: mEd <= mRdTcvn && vEd <= vRdTcvn,
      ),
    ];

    return SrcAnalysisResult(
      config: cfg,
      props: props,
      conf: conf,
      fibers: fibers,
      xNodesMm: xNodes,
      designElems: designElems,
      history: history,
      demandPrimary: mEd,
      demandSecondary: vEd,
      demandFirstOrderM: mEd,
      demandMy2Knm: 0,
      ezEffMm: 0,
      eyEffMm: 0,
      deflDesignMm: desRec.deflMm,
      deflLinearMm: maxDeflLin,
      deflLimitMm: deflLim,
      axialShortMm: 0,
      ultimateLoadKn: ultRec.loadKn,
      ultimateMomentKnm: ultRec.mMaxKnm,
      ductilityMu: ductility,
      pDeltaAmp: 1.0,
      ec4DeltaSteel: (props.aaMm2 * fyd) / math.max(1.0, props.aaMm2 * fyd + props.acMm2 * fcd + props.asMm2 * fsd),
      ec4LambdaZ: 0,
      ec4LambdaY: 0,
      ec4ChiZ: 1,
      ec4ChiY: 1,
      ec4KAmpZ: 1,
      bfBwRatio: bfBw,
      vSplitKn: vSplit,
      studPRdKn: pRdStud,
      studsReqHalf: studsReq,
      studsProvHalf: studsProv,
      laiLiewAna1Kn: 0,
      laiLiewAna2Kn: 0,
      overallPass: checks.first.pass && desRec.deflMm <= deflLim,
      codeChecks: checks,
      mkCurve: mkCurve,
      nmNominalCurve: const [],
      nmDesignCurve: const [],
      ec4Polygon: const [],
      profileXMm: pX,
      profileDeflMm: pDefl,
      profileMKnm: pM,
      profileVKn: pV,
      profileEiRatio: pEi,
      bom: computeBom(cfg, props),
    );
  }

  static List<Point2D> _computeMKCurve(
    List<FiberCell> fibers,
    SectionGeometry g,
    MaterialConfig m,
    ConfinementParams conf,
    double axialKn,
  ) {
    final targetN = -axialKn * 1000.0;
    final maxK = math.max(0.014 / g.hMm, 4.5 * conf.epsCuU / g.hMm);
    final out = <Point2D>[];
    double eps0 = 0.0;
    const nPts = 32;
    for (int i = 0; i <= nPts; i++) {
      final t = i / nPts;
      final kz = maxK * (0.25 * t + 0.75 * t * t);
      // Tìm eps0 cân bằng N
      for (int it = 0; it < 20; it++) {
        final st = evaluateSection(eps0, kz, 0.0, fibers, g, m, conf, true);
        final err = st.nN - targetN;
        if (err.abs() < 50.0) break;
        eps0 += (-err / math.max(1e3, st.d00)).clamp(-0.004, 0.004);
      }
      final st = evaluateSection(eps0, kz, 0.0, fibers, g, m, conf, true);
      out.add(Point2D(kz * 1000.0, st.mzNmm / 1e6));
    }
    return out;
  }

  // ==========================================================================
  // BỘ GIẢI PHI TUYẾN HÌNH HỌC (P–δ) & ĐA TIÊU CHUẨN CỘT BÊ TÔNG CỐT CỨNG
  // ==========================================================================
  static SrcAnalysisResult _solveColumn(SrcMemberConfig cfg) {
    final sec = build2DFiberSection(cfg.geometry, cfg.material);
    final fibers = sec.fibers;
    final props = sec.props;
    final conf = sec.conf;
    final g = cfg.geometry;
    final m = cfg.material;

    final nEd = math.max(1.0, cfg.nEdKn);
    double mz1 = 0, my1 = 0, ezEff = 0, eyEff = 0;
    if (cfg.loadingMode == 'concentric') {
      mz1 = 0;
      my1 = 0;
    } else if (cfg.useEccInput) {
      ezEff = cfg.ezMm;
      eyEff = cfg.loadingMode == 'biaxial' ? cfg.eyMm : 0.0;
      mz1 = nEd * ezEff / 1000.0;
      my1 = nEd * eyEff / 1000.0;
    } else {
      mz1 = cfg.mzEdKnm.abs();
      my1 = cfg.loadingMode == 'biaxial' ? cfg.myEdKnm.abs() : 0.0;
      ezEff = mz1 * 1000.0 / nEd;
      eyEff = my1 * 1000.0 / nEd;
    }

    final lEffZ = cfg.kEffZ * cfg.lengthMm;
    final lEffY = cfg.kEffY * cfg.lengthMm;
    final eta = conf.etaHsc;

    // 1. Eurocode 4 (§6.7.3)
    final fcd = 0.85 * eta * m.fcMpa / m.gammaC;
    final fyd = m.fySteelMpa / m.gammaA;
    final fsd = m.fyRebarMpa / m.gammaS;
    final ecEff = m.ecMpa / (1.0 + 0.5 * m.creepCoeff);
    final nPlRd = (props.aaMm2 * fyd + props.acMm2 * fcd + props.asMm2 * fsd) / 1000.0;
    final nPlRk = (props.aaMm2 * m.fySteelMpa + 0.85 * eta * props.acMm2 * m.fcMpa + props.asMm2 * m.fyRebarMpa) / 1000.0;
    final deltaSt = (props.aaMm2 * fyd / 1000.0) / math.max(1.0, nPlRd);

    final eiEffZ = m.esSteelMpa * props.iaZMm4 + m.esRebarMpa * props.isZMm4 + 0.6 * ecEff * props.icZMm4;
    final eiEffY = m.esSteelMpa * props.iaYMm4 + m.esRebarMpa * props.isYMm4 + 0.6 * ecEff * props.icYMm4;
    final nCrZ = math.pi * math.pi * eiEffZ / (lEffZ * lEffZ) / 1000.0;
    final nCrY = math.pi * math.pi * eiEffY / (lEffY * lEffY) / 1000.0;
    final lamZ = math.sqrt(nPlRk / math.max(1.0, nCrZ));
    final lamY = math.sqrt(nPlRk / math.max(1.0, nCrY));
    final chiZ = _ec3Chi(lamZ, 0.34);
    final chiY = _ec3Chi(lamY, g.sectionType == 'COL_RECT_CROSS_H' ? 0.34 : 0.49);
    final nBRd = math.min(chiZ, chiY) * nPlRd;

    final ei2Z = 0.9 * (m.esSteelMpa * props.iaZMm4 + m.esRebarMpa * props.isZMm4 + 0.5 * ecEff * props.icZMm4);
    final ei2Y = 0.9 * (m.esSteelMpa * props.iaYMm4 + m.esRebarMpa * props.isYMm4 + 0.5 * ecEff * props.icYMm4);
    final nCr2Z = math.pi * math.pi * ei2Z / (lEffZ * lEffZ) / 1000.0;
    final nCr2Y = math.pi * math.pi * ei2Y / (lEffY * lEffY) / 1000.0;
    final betaM = math.max(0.44, 0.66 + 0.44 * cfg.momentRatioR);
    final kAmpZ = math.max(1.0, betaM / math.max(0.08, 1.0 - nEd / math.max(1.0, nCr2Z)));
    final kAmpY = math.max(1.0, betaM / math.max(0.08, 1.0 - nEd / math.max(1.0, nCr2Y)));
    final e0ImpZ = cfg.lengthMm / 200.0;
    final e0ImpY = cfg.lengthMm / (g.sectionType == 'COL_RECT_CROSS_H' ? 200.0 : 150.0);
    final mz2 = kAmpZ * mz1 + (cfg.loadingMode != 'concentric' ? nEd * e0ImpZ / 1000.0 / math.max(0.08, 1.0 - nEd / math.max(1.0, nCr2Z)) : 0.0);
    final my2 = kAmpY * my1 + (cfg.loadingMode == 'biaxial' ? nEd * e0ImpY / 1000.0 / math.max(0.08, 1.0 - nEd / math.max(1.0, nCr2Y)) : 0.0);

    // Đa giác 5 điểm A-E-C-D-B của EC4
    final nPmRd = props.acMm2 * fcd / 1000.0;
    double mMaxZ = 0, mMaxY = 0;
    for (final f in fibers) {
      if (f.kind == 'concrete') {
        mMaxZ += 0.5 * fcd * f.areaMm2 * f.yMm.abs();
        mMaxY += 0.5 * fcd * f.areaMm2 * f.zMm.abs();
      } else {
        final fyU = f.kind.startsWith('steel') ? fyd : fsd;
        mMaxZ += fyU * f.areaMm2 * f.yMm.abs();
        mMaxY += fyU * f.areaMm2 * f.zMm.abs();
      }
    }
    mMaxZ /= 1e6;
    mMaxY /= 1e6;
    final mPlZ = _plasticMomentPsd(fibers, g.hMm, fcd, fyd, fsd, axis: 'z').mPlKnm;
    final mPlY = _plasticMomentPsd(fibers, g.bMm, fcd, fyd, fsd, axis: 'y').mPlKnm;
    final polyZ = [
      Point2D(0.0, nPlRd, 'A'),
      Point2D(0.65 * mPlZ, 0.5 * (nPlRd + nPmRd), 'E'),
      Point2D(mPlZ, nPmRd, 'C'),
      Point2D(math.max(mMaxZ, mPlZ), 0.5 * nPmRd, 'D'),
      Point2D(mPlZ, 0.0, 'B'),
    ];
    final polyY = [
      Point2D(0.0, nPlRd, 'A'),
      Point2D(0.65 * mPlY, 0.5 * (nPlRd + nPmRd), 'E'),
      Point2D(mPlY, nPmRd, 'C'),
      Point2D(math.max(mMaxY, mPlY), 0.5 * nPmRd, 'D'),
      Point2D(mPlY, 0.0, 'B'),
    ];

    double interpPoly(List<Point2D> poly, double nVal) {
      if (nVal >= poly.first.y) return 0.0;
      if (nVal <= poly.last.y) return poly.last.x;
      for (int i = 0; i < poly.length - 1; i++) {
        if (poly[i].y >= nVal && nVal >= poly[i + 1].y) {
          final w = (poly[i].y - nVal) / math.max(1e-9, poly[i].y - poly[i + 1].y);
          return poly[i].x + w * (poly[i + 1].x - poly[i].x);
        }
      }
      return 0.0;
    }

    final alphaM = m.fySteelMpa <= 355.0 ? 0.9 : 0.8;
    final mCapZ = interpPoly(polyZ, nEd);
    final mCapY = interpPoly(polyY, nEd);
    final urNEc4 = nEd / math.max(1.0, nBRd);
    final urMzEc4 = mz2 > 0 ? mz2 / math.max(1e-6, alphaM * mCapZ) : 0.0;
    final urMyEc4 = my2 > 0 ? my2 / math.max(1e-6, alphaM * mCapY) : 0.0;
    final urBiax = cfg.loadingMode == 'biaxial'
        ? (mz2 / math.max(1e-6, mCapZ) + my2 / math.max(1e-6, mCapY))
        : math.max(urMzEc4, urMyEc4);
    final urEc4 = [urNEc4, urMzEc4, urMyEc4, urBiax].reduce(math.max);

    // 2. ANSI/AISC 360-22
    final pNo = (m.fySteelMpa * props.aaMm2 + m.fyRebarMpa * props.asMm2 + 0.85 * m.fcMpa * props.acMm2) / 1000.0;
    final c1 = math.min(0.70, 0.25 + 3.0 * (props.aaMm2 + props.asMm2) / math.max(1.0, props.agMm2));
    final eiAz = m.esSteelMpa * props.iaZMm4 + 0.5 * m.esRebarMpa * props.isZMm4 + c1 * m.ecMpa * props.icZMm4;
    final eiAy = m.esSteelMpa * props.iaYMm4 + 0.5 * m.esRebarMpa * props.isYMm4 + c1 * m.ecMpa * props.icYMm4;
    final peZ = math.pi * math.pi * eiAz / (lEffZ * lEffZ) / 1000.0;
    final peY = math.pi * math.pi * eiAy / (lEffY * lEffY) / 1000.0;
    final peMin = math.min(peZ, peY);
    final ratPe = pNo / math.max(1.0, peMin);
    final pn = ratPe <= 2.25 ? pNo * math.pow(0.658, ratPe).toDouble() : 0.877 * peMin;
    final phiPn = 0.75 * pn;
    final b1Z = math.max(1.0, (0.6 + 0.4 * cfg.momentRatioR) / math.max(0.08, 1.0 - nEd / math.max(1.0, peZ)));
    final b1Y = math.max(1.0, (0.6 + 0.4 * cfg.momentRatioR) / math.max(0.08, 1.0 - nEd / math.max(1.0, peY)));
    final prPc = nEd / math.max(1.0, phiPn);
    final phiMnZ = 0.90 * mPlZ * 1.12;
    final phiMnY = 0.90 * mPlY * 1.12;
    final urAisc = prPc >= 0.2
        ? prPc + (8.0 / 9.0) * (b1Z * mz1 / math.max(1.0, phiMnZ) + b1Y * my1 / math.max(1.0, phiMnY))
        : 0.5 * prPc + (b1Z * mz1 / math.max(1.0, phiMnZ) + b1Y * my1 / math.max(1.0, phiMnY));

    // 3. JGJ 138-2016 + Lai-Liew 2019 + TCVN/SP 266
    final l0B = math.max(lEffZ / math.max(1.0, g.hMm), lEffY / math.max(1.0, g.bMm));
    final phiJgj = l0B <= 8.0 ? 1.0 : math.max(0.32, 1.0 - 0.015 * (l0B - 8.0) - 0.0004 * math.pow(l0B - 8.0, 2));
    final nRdJgj = 0.90 * phiJgj * ((0.76 * m.fcMpa / 1.40) * props.acMm2 + (m.fyRebarMpa / 1.11) * props.asMm2 + (m.fySteelMpa / 1.11) * props.aaMm2) / 1000.0;
    final nRdTcvn = math.min(chiZ, chiY) * ((0.77 * m.fcMpa / 1.30) * props.acMm2 + (m.fyRebarMpa / 1.15) * props.asMm2 + (m.fySteelMpa / 1.05) * props.aaMm2) / 1000.0;
    final acCore = props.acPartConfMm2 + props.acHighConfMm2;
    final lai1 = (0.85 * acCore * m.fcMpa + props.aaMm2 * m.fySteelMpa + props.asMm2 * m.fyRebarMpa) / 1000.0;
    final lai2 = (0.85 * eta * props.acMm2 * m.fcMpa + props.aaMm2 * m.fySteelMpa + props.asMm2 * m.fyRebarMpa) / 1000.0;

    // 4. PTHH Phi tuyến hình học P-δ + Thớ 2D
    final nEl = math.max(6, cfg.nElems);
    final xNodes = List.generate(nEl + 1, (i) => lEffZ * i / nEl);
    final nNodes = xNodes.length;
    final nDofs = 3 * nNodes;
    final eImp = lEffZ / math.max(150.0, cfg.imperfectionRatio);
    final vImp = [for (final x in xNodes) eImp * math.sin(math.pi * x / lEffZ)];
    final fixed = {0, 1, 3 * (nNodes - 1) + 1};
    final free = [for (int i = 0; i < nDofs; i++) if (!fixed.contains(i)) i];

    final fRef = List<double>.filled(nDofs, 0.0);
    fRef[3 * (nNodes - 1)] = -nEd * 1000.0;
    final mTop = nEd * 1000.0 * ezEff;
    fRef[2] = cfg.momentRatioR * mTop;
    fRef[3 * (nNodes - 1) + 2] = -mTop;

    const gpXi = [0.1127016653792583, 0.5, 0.8872983346207417];
    const gpW = [5.0 / 18.0, 8.0 / 18.0, 5.0 / 18.0];

    ({List<double> fInt, List<List<double>> kt, List<ElemSolution> elems}) assembleCol(List<double> dVec) {
      final fInt = List<double>.filled(nDofs, 0.0);
      final kt = List.generate(nDofs, (_) => List<double>.filled(nDofs, 0.0));
      final elems = <ElemSolution>[];
      for (int e = 0; e < nNodes - 1; e++) {
        final le = xNodes[e + 1] - xNodes[e];
        final dofs = [3 * e, 3 * e + 1, 3 * e + 2, 3 * (e + 1), 3 * (e + 1) + 1, 3 * (e + 1) + 2];
        final de = [for (final k in dofs) dVec[k]];
        final fe = List<double>.filled(6, 0.0);
        final ke = List.generate(6, (_) => List<double>.filled(6, 0.0));
        final gps = <SectionState>[];
        final psi = ((de[4] + vImp[e + 1]) - (de[1] + vImp[e])) / le;
        double nAvg = 0;

        for (int gi = 0; gi < 3; gi++) {
          final xi = gpXi[gi];
          final wDx = gpW[gi] * le;
          final bu = [-1.0 / le, 0.0, 0.0, 1.0 / le, 0.0, 0.0];
          final bk = [
            0.0,
            (-6.0 + 12.0 * xi) / (le * le),
            (-4.0 + 6.0 * xi) / le,
            0.0,
            (6.0 - 12.0 * xi) / (le * le),
            (-2.0 + 6.0 * xi) / le,
          ];
          double eps0 = 0.5 * psi * psi, kz = 0;
          for (int i = 0; i < 6; i++) {
            eps0 += bu[i] * de[i];
            kz += bk[i] * de[i];
          }
          final st = evaluateSection(eps0, kz, 0.0, fibers, g, m, conf, true);
          gps.add(st);
          nAvg += gpW[gi] * st.nN;
          for (int i = 0; i < 6; i++) {
            fe[i] += (bu[i] * st.nN + bk[i] * st.mzNmm) * wDx;
            final t0 = st.d00 * bu[i] + st.d01 * bk[i];
            final t1 = st.d01 * bu[i] + st.d11 * bk[i];
            for (int j = 0; j < 6; j++) {
              ke[i][j] += (t0 * bu[j] + t1 * bk[j]) * wDx;
            }
          }
        }
        // Độ cứng hình học P–δ: [k_g(N)]
        final cg = nAvg / (30.0 * le);
        final kg = [
          [36 * cg, 3 * le * cg, -36 * cg, 3 * le * cg],
          [3 * le * cg, 4 * le * le * cg, -3 * le * cg, -le * le * cg],
          [-36 * cg, -3 * le * cg, 36 * cg, -3 * le * cg],
          [3 * le * cg, -le * le * cg, -3 * le * cg, 4 * le * le * cg],
        ];
        final thImp = (vImp[e + 1] - vImp[e]) / le;
        final db = [de[1] + vImp[e], de[2] + thImp, de[4] + vImp[e + 1], de[5] + thImp];
        const bIdx = [1, 2, 4, 5];
        for (int i = 0; i < 4; i++) {
          double fg = 0;
          for (int j = 0; j < 4; j++) {
            fg += kg[i][j] * db[j];
            ke[bIdx[i]][bIdx[j]] += kg[i][j];
          }
          fe[bIdx[i]] += fg;
        }

        for (int i = 0; i < 6; i++) {
          fInt[dofs[i]] += fe[i];
          for (int j = 0; j < 6; j++) {
            kt[dofs[i]][dofs[j]] += ke[i][j];
          }
        }
        elems.add(ElemSolution(
          elemIdx: e,
          x1Mm: xNodes[e],
          x2Mm: xNodes[e + 1],
          lengthMm: le,
          dElem: de,
          fElem: fe,
          gpStates: gps,
        ));
      }
      return (fInt: fInt, kt: kt, elems: elems);
    }

    ({List<double> d, List<ElemSolution> elems, bool ok}) solveColStep(List<double> dInit, double lam) {
      var d = List<double>.from(dInit);
      final fExt = [for (final f in fRef) f * lam];
      final fNorm = math.max(5000.0, _normVec([for (final i in free) fExt[i]]));
      List<ElemSolution> elems = const [];
      for (int it = 0; it < 24; it++) {
        final a = assembleCol(d);
        elems = a.elems;
        final rf = [for (final i in free) fExt[i] - a.fInt[i]];
        if (_normVec(rf) / fNorm < 2.5e-4) return (d: d, elems: elems, ok: true);
        final kff = [for (final r in free) [for (final c in free) a.kt[r][c]]];
        // Bảo vệ mất ổn định (đường chéo suy biến âm)
        for (int i = 0; i < kff.length; i++) {
          if (kff[i][i] <= 0) return (d: dInit, elems: elems, ok: false);
        }
        final dd = _solveLinearSystem(kff, rf);
        if (dd == null) return (d: dInit, elems: elems, ok: false);
        double alpha = 1.0;
        final baseR = _normVec(rf);
        for (int ls = 0; ls < 4; ls++) {
          final dTry = List<double>.from(d);
          for (int i = 0; i < free.length; i++) {
            dTry[free[i]] += alpha * dd[i];
          }
          final aTry = assembleCol(dTry);
          final rTry = [for (final i in free) fExt[i] - aTry.fInt[i]];
          if (_normVec(rTry) <= 1.04 * baseR || alpha <= 0.125) {
            d = dTry;
            break;
          }
          alpha *= 0.5;
        }
      }
      return (d: dInit, elems: elems, ok: false);
    }

    LoadStepRecord colRec(List<double> dVec, List<ElemSolution> els, double lam, bool keep) {
      final mid = nNodes ~/ 2;
      final lat = dVec[3 * mid + 1].abs();
      final axSh = -dVec[3 * (nNodes - 1)];
      double mMid = 0, epsMin = 0, sSt = 0, sRb = 0;
      bool stY = false, rbY = false, ccCr = false;
      for (final el in els) {
        for (final gs in el.gpStates) {
          mMid = math.max(mMid, gs.mzNmm.abs() / 1e6);
          epsMin = math.min(epsMin, gs.epsCMin);
          sSt = math.max(sSt, gs.sigSteelMaxMpa);
          sRb = math.max(sRb, gs.sigRebarMaxMpa);
          stY = stY || gs.steelYielded;
          rbY = rbY || gs.rebarYielded;
          ccCr = ccCr || gs.concreteCrushed;
        }
      }
      final nVal = lam * nEd;
      final m2 = math.max(mMid, nVal * (ezEff + eImp + lat) / 1000.0);
      return LoadStepRecord(
        lambda: lam,
        loadKn: nVal,
        deflMm: lat,
        axialShortMm: axSh,
        mMaxKnm: m2,
        vMaxKn: cfg.vColEdKn * lam,
        eiRatio: 1.0,
        epsCMin: epsMin,
        sigSteelMaxMpa: sSt,
        sigRebarMaxMpa: sRb,
        crackedRatio: 0,
        steelYielded: stY,
        rebarYielded: rbY,
        concreteCrushed: ccCr,
        elemsSnapshot: keep ? els : null,
      );
    }

    final history = <LoadStepRecord>[
      const LoadStepRecord(
        lambda: 0, loadKn: 0, deflMm: 0, axialShortMm: 0, mMaxKnm: 0, vMaxKn: 0,
        eiRatio: 1, epsCMin: 0, sigSteelMaxMpa: 0, sigRebarMaxMpa: 0, crackedRatio: 0,
        steelYielded: false, rebarYielded: false, concreteCrushed: false,
      ),
    ];
    var dCur = List<double>.filled(nDofs, 0.0);
    List<ElemSolution> designElems = assembleCol(dCur).elems;
    final nSteps = math.max(6, cfg.nStepsDesign);
    for (int k = 1; k <= nSteps; k++) {
      final lam = k / nSteps;
      final res = solveColStep(dCur, lam);
      if (!res.ok) break;
      dCur = res.d;
      designElems = res.elems;
      history.add(colRec(dCur, res.elems, lam, true));
    }

    double lam = history.last.lambda;
    double dLam = 0.16;
    for (int step = 0; step < 30; step++) {
      final res = solveColStep(dCur, lam + dLam);
      if (!res.ok) {
        dLam *= 0.5;
        if (dLam < 0.015) break;
        continue;
      }
      lam += dLam;
      dCur = res.d;
      final rec = colRec(dCur, res.elems, lam, false);
      history.add(rec);
      if (rec.epsCMin.abs() > conf.epsCuU * 1.35 || rec.deflMm > lEffZ / 30.0) break;
    }

    final ultRec = history.reduce((a, b) => a.loadKn >= b.loadKn ? a : b);
    final desRec = history.firstWhere((h) => (h.lambda - 1.0).abs() < 1e-4, orElse: () => history.last);

    final pX = <double>[], pDefl = <double>[], pM = <double>[], pN = <double>[], pEi = <double>[];
    for (final el in designElems) {
      final le = el.lengthMm;
      final de = el.dElem;
      for (int gi = 0; gi < 3; gi++) {
        final xi = gpXi[gi];
        final n1 = 1 - 3 * xi * xi + 2 * xi * xi * xi;
        final n2 = le * (xi - 2 * xi * xi + xi * xi * xi);
        final n3 = 3 * xi * xi - 2 * xi * xi * xi;
        final n4 = le * (-xi * xi + xi * xi * xi);
        pX.add(el.x1Mm + xi * le);
        pDefl.add(n1 * de[1] + n2 * de[2] + n3 * de[4] + n4 * de[5]);
        pM.add(el.gpStates[gi].mzNmm.abs() / 1e6);
        pN.add(-el.gpStates[gi].nN / 1000.0);
        pEi.add(1.0);
      }
    }

    // Đường cong tương tác N-M thớ 2D (danh định & thiết kế)
    final nmNom = _computeNmCurve(fibers, g, m, conf, false);
    final nmDes = _computeNmCurve(fibers, g, m, conf, true);

    final checks = [
      CodeCheckRow(
        codeId: 'EC4',
        title: 'Eurocode 4 (EN 1994-1-1 §6.7)',
        capacityPrimary: nBRd,
        capacitySecondary: mCapZ,
        urPrimary: urNEc4,
        urSecondary: math.max(urMzEc4, urBiax),
        urTotal: urEc4,
        extraNote: 'δ=${deltaSt.toStringAsFixed(2)}, λ̄z=${lamZ.toStringAsFixed(2)}, χz=${chiZ.toStringAsFixed(2)}, k=${kAmpZ.toStringAsFixed(2)}',
        pass: urEc4 <= 1.0 && lamZ <= 2.0 && lamY <= 2.0,
      ),
      CodeCheckRow(
        codeId: 'AISC',
        title: 'ANSI/AISC 360-22 (§I2.1 & §I5)',
        capacityPrimary: phiPn,
        capacitySecondary: phiMnZ,
        urPrimary: prPc,
        urSecondary: b1Z * mz1 / math.max(1.0, phiMnZ),
        urTotal: urAisc,
        extraNote: 'C1=${c1.toStringAsFixed(2)}, B1=${b1Z.toStringAsFixed(2)}',
        pass: urAisc <= 1.0,
      ),
      CodeCheckRow(
        codeId: 'JGJ138',
        title: 'JGJ 138-2016 (China SRC Ch. 6)',
        capacityPrimary: nRdJgj,
        capacitySecondary: mPlZ,
        urPrimary: nEd / math.max(1.0, nRdJgj),
        urSecondary: urMzEc4,
        urTotal: math.max(nEd / math.max(1.0, nRdJgj), urMzEc4),
        extraNote: 'φ=${phiJgj.toStringAsFixed(3)}',
        pass: nEd <= nRdJgj,
      ),
      CodeCheckRow(
        codeId: 'TCVN',
        title: 'TCVN 5574/5575 + SP 266',
        capacityPrimary: nRdTcvn,
        capacitySecondary: mPlZ,
        urPrimary: nEd / math.max(1.0, nRdTcvn),
        urSecondary: urMzEc4,
        urTotal: math.max(nEd / math.max(1.0, nRdTcvn), urMzEc4),
        extraNote: 'Lai-Liew HSC: ${lai2.toStringAsFixed(0)} kN',
        pass: nEd <= nRdTcvn,
      ),
    ];

    final pDeltaRatio = mz1 > 1e-2 ? (desRec.mMaxKnm / mz1) : kAmpZ;
    return SrcAnalysisResult(
      config: cfg,
      props: props,
      conf: conf,
      fibers: fibers,
      xNodesMm: xNodes,
      designElems: designElems,
      history: history,
      demandPrimary: nEd,
      demandSecondary: mz2,
      demandFirstOrderM: mz1,
      demandMy2Knm: my2,
      ezEffMm: ezEff,
      eyEffMm: eyEff,
      deflDesignMm: desRec.deflMm,
      deflLinearMm: desRec.deflMm / math.max(1.0, pDeltaRatio),
      deflLimitMm: cfg.lengthMm / 250.0,
      axialShortMm: desRec.axialShortMm,
      ultimateLoadKn: ultRec.loadKn,
      ultimateMomentKnm: ultRec.mMaxKnm,
      ductilityMu: 1.0,
      pDeltaAmp: pDeltaRatio,
      ec4DeltaSteel: deltaSt,
      ec4LambdaZ: lamZ,
      ec4LambdaY: lamY,
      ec4ChiZ: chiZ,
      ec4ChiY: chiY,
      ec4KAmpZ: kAmpZ,
      bfBwRatio: g.baMm / math.max(1.0, g.bMm),
      vSplitKn: 0,
      studPRdKn: 0,
      studsReqHalf: 0,
      studsProvHalf: 0,
      laiLiewAna1Kn: lai1,
      laiLiewAna2Kn: lai2,
      overallPass: checks.first.pass,
      codeChecks: checks,
      mkCurve: _computeMKCurve(fibers, g, m, conf, nEd),
      nmNominalCurve: nmNom,
      nmDesignCurve: nmDes,
      ec4Polygon: polyZ,
      profileXMm: pX,
      profileDeflMm: pDefl,
      profileMKnm: pM,
      profileVKn: pN,
      profileEiRatio: pEi,
      bom: computeBom(cfg, props),
    );
  }

  static List<Point2D> _computeNmCurve(
    List<FiberCell> fibers,
    SectionGeometry g,
    MaterialConfig m,
    ConfinementParams conf,
    bool designFactors,
  ) {
    final matEval = designFactors
        ? m.copyWith(
            fcMpa: m.fcMpa / m.gammaC,
            fySteelMpa: m.fySteelMpa / m.gammaA,
            fyRebarMpa: m.fyRebarMpa / m.gammaS,
          )
        : m;
    final fibEval = designFactors
        ? fibers
            .map((f) => f.kind == 'concrete'
                ? f
                : FiberCell(
                    yMm: f.yMm,
                    zMm: f.zMm,
                    dyMm: f.dyMm,
                    dzMm: f.dzMm,
                    areaMm2: f.areaMm2,
                    kind: f.kind,
                    zone: f.zone,
                    fyMpa: f.kind.startsWith('steel') ? matEval.fySteelMpa : matEval.fyRebarMpa,
                    esMpa: f.esMpa,
                  ))
            .toList()
        : fibers;

    final pts = <Point2D>[];
    double bestN = 0;
    for (int i = 0; i <= 14; i++) {
      final epsU = -conf.epsC0U * (0.85 + 0.08 * i);
      final r = evaluateSection(epsU, 0, 0, fibEval, g, matEval, conf, true);
      if (-r.nN > bestN) bestN = -r.nN;
    }
    pts.add(Point2D(0.0, bestN / 1000.0));

    const ratios = [
      2.2, 1.8, 1.5, 1.25, 1.05, 0.92, 0.80, 0.70, 0.62, 0.55,
      0.48, 0.42, 0.36, 0.30, 0.25, 0.20, 0.15, 0.11, 0.07, 0.04,
    ];
    for (final cr in ratios) {
      final c = cr * g.hMm;
      final kz = conf.epsCuU / math.max(1.0, c);
      final eps0 = kz * (0.5 * g.hMm - c);
      final r = evaluateSection(eps0, kz, 0.0, fibEval, g, matEval, conf, true);
      pts.add(Point2D(r.mzNmm.abs() / 1e6, -r.nN / 1000.0));
    }
    final rT = evaluateSection(0.015, 0, 0, fibEval, g, matEval, conf, true);
    pts.add(Point2D(0.0, -rT.nN / 1000.0));
    return pts;
  }

  // ==========================================================================
  // KHẢO SÁT ĐIỂM BẤT KỲ (x/L, y, z) & PHẪU THUẬT MẶT CẮT KIỂU ANSYS
  // ==========================================================================
  static ({double eps0, double kz, double vShearN}) _interpKinematics(SrcAnalysisResult res, double xNorm) {
    final xC = xNorm.clamp(0.0, 1.0);
    final L = res.xNodesMm.last;
    final xPos = xC * L;
    var el = res.designElems.last;
    for (final e in res.designElems) {
      if (xPos >= e.x1Mm - 1e-6 && xPos <= e.x2Mm + 1e-6) {
        el = e;
        break;
      }
    }
    final le = math.max(1e-6, el.lengthMm);
    final xi = ((xPos - el.x1Mm) / le).clamp(0.0, 1.0);
    final de = el.dElem;
    final eps0 = (-de[0] + de[3]) / le;
    final kz = ((-6 + 12 * xi) / (le * le)) * de[1] +
        ((-4 + 6 * xi) / le) * de[2] +
        ((6 - 12 * xi) / (le * le)) * de[4] +
        ((-2 + 6 * xi) / le) * de[5];
    return (eps0: eps0, kz: kz, vShearN: el.fElem[1]);
  }

  static DissectionResult dissectSection(SrcAnalysisResult res, double xNorm) {
    final kin = _interpKinematics(res, xNorm);
    final cfg = res.config;
    final g = cfg.geometry;
    final m = cfg.material;
    final isBeam = cfg.kind == MemberKind.beam;
    final hwSt = math.max(10.0, g.haMm - 2 * g.tfMm);

    final outFibs = <DissectedFiber>[];
    double nSum = 0, mzSum = 0, mySum = 0;
    double nConc = 0, nSteel = 0, nRebar = 0;
    double mzConc = 0, mzSteel = 0, mzRebar = 0;
    double sMin = double.infinity, sMax = double.negativeInfinity;
    double eMin = double.infinity, eMax = double.negativeInfinity;

    for (final f in res.fibers) {
      final eps = kin.eps0 - f.yMm * kin.kz;
      double sig;
      String stVi, stEn;
      if (f.kind == 'concrete') {
        final r = concreteLaw(eps, m, f.zone, res.conf, true);
        sig = r.sig;
        stVi = r.stVi;
        stEn = r.stEn;
        nConc += -sig * f.areaMm2 / 1000.0;
        mzConc += -sig * f.yMm * f.areaMm2 / 1e6;
      } else {
        final bh = f.kind.startsWith('steel') ? m.hardeningSteel : m.hardeningRebar;
        final r = steelLaw(eps, f.esMpa, f.fyMpa, bh, true);
        sig = r.sig;
        stVi = r.stVi;
        stEn = r.stEn;
        if (f.kind.startsWith('steel')) {
          nSteel += -sig * f.areaMm2 / 1000.0;
          mzSteel += -sig * f.yMm * f.areaMm2 / 1e6;
        } else {
          nRebar += -sig * f.areaMm2 / 1000.0;
          mzRebar += -sig * f.yMm * f.areaMm2 / 1e6;
        }
      }
      final parab = math.max(0.0, 1.0 - math.pow(2.0 * f.yMm / math.max(1.0, g.hMm), 2));
      final double tau;
      if (f.kind == 'steel_web') {
        tau = 0.72 * kin.vShearN.abs() / math.max(1.0, hwSt * g.twMm) * (0.75 + 0.45 * parab);
      } else if (f.kind.startsWith('steel')) {
        tau = 0.15 * kin.vShearN.abs() / math.max(1.0, g.baMm * g.tfMm);
      } else {
        tau = 0.28 * 1.5 * kin.vShearN.abs() / math.max(1.0, g.bMm * g.hMm) * parab;
      }
      final vm = math.sqrt(sig * sig + 3.0 * tau * tau);

      nSum += sig * f.areaMm2;
      mzSum -= sig * f.yMm * f.areaMm2;
      mySum += sig * f.zMm * f.areaMm2;
      if (sig < sMin) sMin = sig;
      if (sig > sMax) sMax = sig;
      if (eps < eMin) eMin = eps;
      if (eps > eMax) eMax = eps;

      outFibs.add(DissectedFiber(
        cell: f,
        epsX: eps,
        sigmaXMpa: sig,
        tauXyMpa: tau,
        sigmaVmMpa: vm,
        stateVi: stVi,
        stateEn: stEn,
      ));
    }

    final xNa = kin.kz.abs() > 1e-11
        ? (0.5 * g.hMm - kin.eps0 / kin.kz).clamp(0.0, g.hMm)
        : (kin.eps0 < 0 ? g.hMm : 0.0);

    // =========================================================================
    // PHÂN TÍCH ỨNG XỬ LIÊN KẾT CỐT CỨNG (THÉP HÌNH) ↔ BÊ TÔNG CỐT THÉP TẠI x/L
    // =========================================================================
    final xNormC = xNorm.clamp(0.0, 1.0);
    final lMm = res.xNodesMm.last;
    final xMm = xNormC * lMm;

    // 1. Tỷ lệ phân chia nội lực giữa Thép hình — Bê tông — Cốt thép thanh
    double steelPct, concPct, rebarPct;
    final eiA = m.esSteelMpa * res.props.iaZMm4;
    final eiC = m.ecMpa * res.props.icZMm4;
    final eiS = m.esRebarMpa * res.props.isZMm4;
    final eiTot = math.max(1.0, eiA + eiC + eiS);

    if (isBeam) {
      final totM = mzSteel.abs() + mzConc.abs() + mzRebar.abs();
      if (totM > 1.0) {
        steelPct = 100.0 * mzSteel.abs() / totM;
        concPct = 100.0 * mzConc.abs() / totM;
        rebarPct = math.max(0.0, 100.0 - steelPct - concPct);
      } else {
        steelPct = 100.0 * eiA / eiTot;
        concPct = 100.0 * eiC / eiTot;
        rebarPct = math.max(0.0, 100.0 - steelPct - concPct);
      }
    } else {
      final totN = nSteel.abs() + nConc.abs() + nRebar.abs();
      if (totN > 1.0) {
        steelPct = 100.0 * nSteel.abs() / totN;
        concPct = 100.0 * nConc.abs() / totN;
        rebarPct = math.max(0.0, 100.0 - steelPct - concPct);
      } else {
        steelPct = 35.0;
        concPct = 55.0;
        rebarPct = 10.0;
      }
    }

    // 2. Chu vi tiếp xúc thép hình – bê tông u_a (mm) & lực trượt dọc mặt tiếp xúc v_L (kN/m)
    final double uBondMm;
    final double tauRd0;
    if (g.sectionType == 'COL_RECT_CFST') {
      uBondMm = math.pi * g.haMm + math.pi * math.max(20.0, g.haMm - 2.0 * g.twMm);
      tauRd0 = 0.55;
    } else if (g.sectionType == 'COL_RECT_CROSS_H') {
      uBondMm = 8.0 * g.baMm + 4.0 * math.max(10.0, g.haMm - 2.0 * g.tfMm) - 6.0 * g.twMm;
      tauRd0 = 0.30;
    } else {
      uBondMm = 4.0 * g.baMm + 2.0 * math.max(10.0, g.haMm - 2.0 * g.tfMm) - 2.0 * g.twMm;
      tauRd0 = 0.30;
    }

    final alphaA = (eiA / eiTot).clamp(0.25, 0.75);
    final zLevM = 0.85 * math.max(g.haMm, 0.70 * g.hMm) / 1000.0;
    final vFlexKnM = (kin.vShearN.abs() / 1000.0) * alphaA / math.max(0.15, zLevM);

    double vIntroKnM = 0.0;
    if (!isBeam) {
      final lIntroMm = math.min(2.0 * g.hMm, lMm / 3.0);
      final distEnd = math.min(xMm, lMm - xMm);
      final phiIntro = math.max(0.0, 1.0 - distEnd / math.max(100.0, lIntroMm));
      vIntroKnM = nSteel.abs() * (1.0 - steelPct / 100.0) / math.max(0.25, lIntroMm / 1000.0) * phiIntro;
    }

    final vInterfaceKnM = vFlexKnM + vIntroKnM;
    final tauBondMpa = vInterfaceKnM / math.max(100.0, uBondMm);
    final tauRdEff = tauRd0 + 0.25 * res.conf.flP;

    final studForceKn = isBeam ? vInterfaceKnM * (cfg.studSpacingMm / 1000.0) / math.max(1, cfg.studRows) : 0.0;
    final studUr = isBeam ? studForceKn / math.max(1.0, res.studPRdKn) : 0.0;
    final splitUr = isBeam ? (kin.vShearN.abs() / 1000.0) / math.max(1.0, res.vSplitKn) : 0.0;

    const kBond = 12.0; // MPa/mm
    final double slipMm;
    final int bondLevel;
    final String bondVi, bondEn;

    if (isBeam) {
      final kStud = math.max(40.0, 0.7 * res.studPRdKn / 0.5);
      slipMm = tauBondMpa <= tauRd0
          ? tauBondMpa / kBond
          : 0.025 + math.max(0.0, studForceKn - 0.25 * res.studPRdKn) / kStud;
      if (studUr > 1.0 || splitUr > 1.0) {
        bondLevel = 2;
        bondVi = 'Cảnh báo trượt / Tách dọc cánh thép';
        bondEn = 'Slip / Flange Splitting Warning';
      } else if (tauBondMpa > tauRd0 || studUr > 0.45) {
        bondLevel = 1;
        bondVi = 'Đinh neo & Ma sát đang chịu trượt tích cực';
        bondEn = 'Mechanical Shear Studs & Friction Active';
      } else {
        bondLevel = 0;
        bondVi = 'Liên kết hoàn toàn — Dính bám đàn hồi';
        bondEn = 'Full Composite Action — Elastic Bond';
      }
    } else {
      slipMm = tauBondMpa <= tauRdEff
          ? tauBondMpa / kBond
          : 0.025 + (tauBondMpa - tauRdEff) / 2.5;
      if (tauBondMpa > tauRdEff) {
        bondLevel = 2;
        bondVi = 'Vượt dính bám tự nhiên — Cần tăng đinh neo / đai dày';
        bondEn = 'Bond Exceeded — Add Studs / Tighter Stirrups';
      } else if (tauBondMpa > 0.55 * tauRdEff || res.conf.flH > 1.0) {
        bondLevel = 1;
        bondVi = 'Ma sát & Giam giữ vòm lõi thép H hoạt động tích cực';
        bondEn = 'Friction & H-Steel Arching Confinement Active';
      } else {
        bondLevel = 0;
        bondVi = 'Liên kết hoàn toàn — Biến dạng tương thích';
        bondEn = 'Full Bond — Strain Compatibility';
      }
    }

    return DissectionResult(
      xNorm: xNormC,
      xMm: xMm,
      eps0: kin.eps0,
      kappaZ: kin.kz,
      kappaY: 0,
      nKn: -nSum / 1000.0,
      mzKnm: mzSum / 1e6,
      myKnm: mySum / 1e6,
      vShearKn: kin.vShearN / 1000.0,
      xNaMm: xNa,
      sigMinMpa: sMin.isFinite ? sMin : -1,
      sigMaxMpa: sMax.isFinite ? sMax : 1,
      epsMin: eMin.isFinite ? eMin : -0.001,
      epsMax: eMax.isFinite ? eMax : 0.001,
      fibers: outFibs,
      nSteelKn: nSteel,
      nConcreteKn: nConc,
      nRebarKn: nRebar,
      mzSteelKnm: mzSteel,
      mzConcreteKnm: mzConc,
      mzRebarKnm: mzRebar,
      steelSharePct: steelPct,
      concreteSharePct: concPct,
      rebarSharePct: rebarPct,
      bondPerimeterMm: uBondMm,
      vInterfaceKnPerM: vInterfaceKnM,
      tauBondMpa: tauBondMpa,
      tauRdMpa: tauRdEff,
      studForceKn: studForceKn,
      studUr: studUr,
      splitUr: splitUr,
      slipMm: slipMm,
      bondStatusLevel: bondLevel,
      bondStateVi: bondVi,
      bondStateEn: bondEn,
    );
  }

  static ProbeResult probePoint(SrcAnalysisResult res, double xNorm, double yMm, double zMm) {
    final dis = dissectSection(res, xNorm);
    final g = res.config.geometry;
    final m = res.config.material;
    final eps = dis.eps0 - yMm * dis.kappaZ;
    final stPart = pointInSteelCore(yMm, zMm, g);
    RebarDot? nearRb;
    for (final rb in res.props.rebars) {
      if (math.sqrt(math.pow(yMm - rb.yMm, 2) + math.pow(zMm - rb.zMm, 2)) <= 0.7 * rb.diaMm) {
        nearRb = rb;
        break;
      }
    }
    double sig, limitMpa;
    String matVi, matEn, zoneVi, zoneEn, stVi, stEn;
    if (stPart != null) {
      final r = steelLaw(eps, m.esSteelMpa, m.fySteelMpa, m.hardeningSteel, true);
      sig = r.sig;
      stVi = r.stVi;
      stEn = r.stEn;
      limitMpa = m.fySteelMpa;
      matVi = stPart == 'steel_flange' ? 'Thép hình cốt cứng (Cánh)' : (stPart == 'steel_web' ? 'Thép hình cốt cứng (Bụng)' : 'Ống thép CFST');
      matEn = stPart == 'steel_flange' ? 'Steel Core (Flange)' : (stPart == 'steel_web' ? 'Steel Core (Web)' : 'CFST Steel Tube');
      zoneVi = 'Lõi thép hình (${m.steelGrade})';
      zoneEn = 'Encased Steel Core (${m.steelGrade})';
    } else if (nearRb != null) {
      final r = steelLaw(eps, m.esRebarMpa, m.fyRebarMpa, m.hardeningRebar, true);
      sig = r.sig;
      stVi = r.stVi;
      stEn = r.stEn;
      limitMpa = m.fyRebarMpa;
      matVi = 'Cốt thép dọc Ø${nearRb.diaMm.toStringAsFixed(0)}';
      matEn = 'Longitudinal Rebar Ø${nearRb.diaMm.toStringAsFixed(0)}';
      zoneVi = 'Cốt thép thanh (${m.rebarGrade})';
      zoneEn = 'Rebar (${m.rebarGrade})';
    } else {
      final z = classifyConcreteZone(yMm, zMm, g);
      final r = concreteLaw(eps, m, z, res.conf, true);
      sig = r.sig;
      stVi = r.stVi;
      stEn = r.stEn;
      final fcEff = 0.85 * res.conf.etaHsc * m.fcMpa;
      limitMpa = z == ConcreteZone.highlyConfined
          ? fcEff * res.conf.kh
          : (z == ConcreteZone.partiallyConfined ? fcEff * res.conf.kp : fcEff);
      matVi = 'Bê tông (${m.concreteGrade})';
      matEn = 'Concrete (${m.concreteGrade})';
      zoneVi = switch (z) {
        ConcreteZone.unconfined => 'Vùng 0 — Vỏ bảo vệ (Không giam giữ)',
        ConcreteZone.partiallyConfined => 'Vùng 1 — Giam giữ cốt đai (Kp=${res.conf.kp.toStringAsFixed(2)})',
        ConcreteZone.highlyConfined => 'Vùng 2 — Giam giữ mạnh lõi thép H (Kh=${res.conf.kh.toStringAsFixed(2)})',
      };
      zoneEn = switch (z) {
        ConcreteZone.unconfined => 'Zone 0 — Unconfined Cover',
        ConcreteZone.partiallyConfined => 'Zone 1 — Partially Confined (Kp=${res.conf.kp.toStringAsFixed(2)})',
        ConcreteZone.highlyConfined => 'Zone 2 — Highly Confined Core (Kh=${res.conf.kh.toStringAsFixed(2)})',
      };
    }

    final hwSt = math.max(10.0, g.haMm - 2 * g.tfMm);
    final parab = math.max(0.0, 1.0 - math.pow(2.0 * yMm / math.max(1.0, g.hMm), 2));
    final vN = dis.vShearKn.abs() * 1000.0;
    final tau = stPart == 'steel_web'
        ? 0.72 * vN / math.max(1.0, hwSt * g.twMm) * (0.75 + 0.45 * parab)
        : (stPart != null
            ? 0.15 * vN / math.max(1.0, g.baMm * g.tfMm)
            : 0.28 * 1.5 * vN / math.max(1.0, g.bMm * g.hMm) * parab);

    return ProbeResult(
      xNorm: dis.xNorm,
      xMm: dis.xMm,
      yMm: yMm,
      zMm: zMm,
      materialVi: matVi,
      materialEn: matEn,
      zoneVi: zoneVi,
      zoneEn: zoneEn,
      epsX: eps,
      sigmaXMpa: sig,
      tauXyMpa: tau,
      sigmaVmMpa: math.sqrt(sig * sig + 3.0 * tau * tau),
      utilRatio: sig.abs() / math.max(1.0, limitMpa),
      stateVi: stVi,
      stateEn: stEn,
      secNKn: dis.nKn,
      secMKnm: dis.mzKnm,
      secVKn: dis.vShearKn,
      xNaMm: dis.xNaMm,
    );
  }
}
