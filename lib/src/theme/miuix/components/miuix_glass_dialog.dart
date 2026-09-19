// Miuix Flutter 移植版 - GlassDialog
// 源自 compose-miuix-ui/miuix 的 GlassOverlay.kt。
// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/widgets.dart';
import '../glass/miuix_glass_decoration.dart';
import '../glass/miuix_glass_popup_style.dart';
import '../glass/internal/popup_presenter.dart';

/// 对应 Kotlin GlassDialog。居中玻璃对话框，安全区和软键盘会约束内容可用高度。
///
/// [surfaceBuilder] 替换面板材质（几何、缩放动效与交互不动）；此时通常还要传
/// [scrimUnderlay]（一个建立 `BackdropGroup` 捕获点、且排在压暗蒙层之前的层），
/// 让注入面能以 `grouped` 采到**未压暗**的页面 —— 否则玻璃会把 dialog 自己
/// 那层蒙一起折进去。两者传 null 时行为与不加完全一致。
class MiuixGlassDialog extends GlassPopupWidget {
  const MiuixGlassDialog({
    super.key,
    required bool visible,
    required super.onDismissRequest,
    required super.child,
    super.backdrop,
    super.scrimAlpha,
    super.surfaceBuilder,
    super.scrimUnderlay,
    super.onDismissFinished,
    super.cornerRadius = 28,
    super.sizing = const MiuixGlassPopupSizing(
      maxWidth: 420,
      maxHeight: 100000,
      safeMargin: 24,
    ),
    super.visuals = const MiuixGlassPopupVisuals(
      shadow: MiuixGlassShadows.extraHigh,
      showStroke: false,
    ),
    super.contentPadding = const EdgeInsets.symmetric(
      horizontal: 22,
      vertical: 20,
    ),
  }) : super(show: visible, motion: MiuixGlassPopupMotion.dialog);
}
