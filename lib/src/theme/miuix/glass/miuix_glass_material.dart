// Miuix Flutter 移植版 - GlassMaterial / GlassMaterials
// 源自 compose-miuix-ui/miuix 的 GlassMaterial.kt、GlassMaterials.kt。
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

/// 对应 Kotlin GlassColorBlendMode；顺序与 OS4 blend shader 的 id 一致。
enum MiuixGlassColorBlendMode {
  srcOver,
  plusDarker,
  plusLighter,
  softLight,
  hardLight,
  overlay,
  luminosity,
  colorDodge,
  colorBurn,
}

/// 对应 Kotlin GlassColorLayer，颜色采用非预乘 RGBA。
@immutable
class MiuixGlassColorLayer {
  const MiuixGlassColorLayer(this.color, this.mode);
  final Color color;
  final MiuixGlassColorBlendMode mode;
}

/// 对应 Kotlin GlassMaterial：模糊半径与至多三层独立混色。
@immutable
class MiuixGlassMaterial {
  const MiuixGlassMaterial({
    required this.blurRadius,
    required this.first,
    this.second,
    this.third,
  }) : assert(blurRadius >= 0),
       assert(second != null || third == null);
  final double blurRadius;
  final MiuixGlassColorLayer first;
  final MiuixGlassColorLayer? second;
  final MiuixGlassColorLayer? third;
  List<MiuixGlassColorLayer> get layers => [first, ?second, ?third];
  MiuixGlassMaterial copyWith({double? blurRadius}) => MiuixGlassMaterial(
    blurRadius: blurRadius ?? this.blurRadius,
    first: first,
    second: second,
    third: third,
  );
}

/// 对应 Kotlin GlassMaterials，逐值保留源端的颜色层与 blend mode。
class MiuixGlassMaterials {
  MiuixGlassMaterials._();
  static const puredThinGlassLight = MiuixGlassMaterial(
    blurRadius: 20,
    first: MiuixGlassColorLayer(
      Color(0x05000000),
      MiuixGlassColorBlendMode.plusDarker,
    ),
    second: MiuixGlassColorLayer(
      Color(0x99FFFFFF),
      MiuixGlassColorBlendMode.softLight,
    ),
    third: MiuixGlassColorLayer(
      Color(0x66FFFFFF),
      MiuixGlassColorBlendMode.hardLight,
    ),
  );
  static const puredThinGlassDark = MiuixGlassMaterial(
    blurRadius: 20,
    first: MiuixGlassColorLayer(
      Color(0x1A000000),
      MiuixGlassColorBlendMode.plusDarker,
    ),
    second: MiuixGlassColorLayer(
      Color(0x66565656),
      MiuixGlassColorBlendMode.luminosity,
    ),
    third: MiuixGlassColorLayer(
      Color(0x993F3F3F),
      MiuixGlassColorBlendMode.overlay,
    ),
  );
  static final popupViewGlassLight = puredThinGlassLight.copyWith(
    blurRadius: 60,
  );
  static final popupViewGlassDark = puredThinGlassDark.copyWith(blurRadius: 60);
  static const actionBarMaskLight = MiuixGlassMaterial(
    blurRadius: 40,
    first: MiuixGlassColorLayer(
      Color(0x33F9F9F9),
      MiuixGlassColorBlendMode.overlay,
    ),
    second: MiuixGlassColorLayer(
      Color(0xB3FFFFFF),
      MiuixGlassColorBlendMode.hardLight,
    ),
  );
  static const actionBarMaskDark = MiuixGlassMaterial(
    blurRadius: 60,
    first: MiuixGlassColorLayer(
      Color(0x75000000),
      MiuixGlassColorBlendMode.colorBurn,
    ),
    second: MiuixGlassColorLayer(
      Color(0x52000000),
      MiuixGlassColorBlendMode.srcOver,
    ),
  );
  static MiuixGlassMaterial puredThinGlass(bool isDark) =>
      isDark ? puredThinGlassDark : puredThinGlassLight;
  static MiuixGlassMaterial popupViewGlass(bool isDark) =>
      isDark ? popupViewGlassDark : popupViewGlassLight;
  static MiuixGlassMaterial actionBarMask(bool isDark) =>
      isDark ? actionBarMaskDark : actionBarMaskLight;
}
