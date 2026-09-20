// Miuix Flutter 移植版 - GlassSecondaryPopup
// 源自 compose-miuix-ui/miuix 的 GlassSecondaryPopup.kt。
// SPDX-License-Identifier: Apache-2.0
import '../glass/miuix_glass_popup_style.dart';
import '../glass/internal/popup_presenter.dart';

/// 对应 Kotlin GlassSecondaryPopup。从菜单行展开二级面板；materialAnchor 可共享一级菜单材质。
/// 保持组件挂载并切换 show，让退出动画完成后自动清除弹层和返回记录。
///
/// ── 让位（`stacked` 那一族）也开放给二级面板（本 fork 补丁） ──
/// 上游只让一级（`MiuixGlassTransformPopup`）参与让位，二级面板的让位开关整族都
/// 没有暴露，于是**两块面板各缩各的**：一级绕自己的锚点角缩 5%，二级原地不动。
/// 两块面板同宽同边（二级锚在一级某一行上）时，缩过的那块左边缘比二级多退 5%
/// 板宽 —— 读起来就是「只有一半缩了」。
///
/// 让二级也能传同一组参数后，调用方可以给两块**同一个支点**（`stackPivotBounds`
/// 取二级锚点行的右上角，也就是一级面板的右上角），两块一起缩，整个菜单读起来
/// 是一个整体在退。
///
/// ⚠️ 二级面板的缺省支点规则（`stackShrinkFromAnchor`）取「离锚点最近的面板角」，
/// 而二级的锚点行在它自己的**左上角** —— 直接开 `stackShrinkFromAnchor` 会朝左上
/// 缩，与一级的右上角相反。要两块一致，请用 `stackPivotBounds` 显式指定支点。
class MiuixGlassSecondaryPopup extends GlassPopupWidget {
  const MiuixGlassSecondaryPopup({
    super.key,
    required super.show,
    required super.onDismissRequest,
    required super.child,
    super.anchor,
    super.anchorBounds,
    super.materialAnchor,
    super.backdrop,
    super.sizing,
    super.visuals,
    super.cornerRadius,
    super.contentPadding,
    super.stacked,
    super.stackDuration,
    super.stackCurve,
    super.stackShrinkFromAnchor,
    super.stackPivotBounds,
    super.stackScalesPanel,
    super.stackLocksInput,
    super.onScrimTap,
    super.maskColor,
    super.scrimAlpha,
    super.onDismissFinished,
    super.onMeasured,
    super.surfaceBuilder,
  }) : super(motion: MiuixGlassPopupMotion.secondary);
}
