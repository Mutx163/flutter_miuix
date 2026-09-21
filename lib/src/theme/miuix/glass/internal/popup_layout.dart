// Miuix Flutter 移植版 - OS4 弹层单次测量与形变布局
// 源自 compose-miuix-ui/miuix 的 GlassPopupSurface.kt。
// SPDX-License-Identifier: Apache-2.0
import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../miuix_glass_popup_anchor.dart';
import '../miuix_glass_popup_style.dart';

class GlassPopupLayout extends MultiChildRenderObjectWidget {
  GlassPopupLayout({
    super.key,
    required Widget panel,
    required Widget content,
    Widget? anchorContent,
    required this.motion,
    required this.sizing,
    required this.progress,
    required this.positionProgress,
    required this.cornerRadius,
    required this.insets,
    required this.direction,
    this.anchor,
    this.anchorBounds,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.gap = 0,
    this.interactive = true,
    this.onMeasured,
    this.stackProgress = 0,
    this.stackAnchorPivot = false,
    this.stackPivotBounds,
    this.stackScalesPanel = true,
    this.maskColor = const Color(0x66000000),
  }) : super(children: [panel, content, ?anchorContent]);
  final MiuixGlassPopupMotion motion;
  final MiuixGlassPopupSizing sizing;
  final MiuixGlassPopupAnchor? anchor;
  final Rect? anchorBounds;
  final double progress, positionProgress, cornerRadius, gap, stackProgress;
  final EdgeInsets insets, padding;
  final TextDirection direction;
  final bool interactive;
  final ValueChanged<Size>? onMeasured;
  final Color maskColor;

  /// 让位缩放的支点是否取「离锚点最近的面板角」（缺省 = 面板中心）。
  ///
  /// 面板通常从锚点（触发按钮 / 被点的行）长出来，锚点所在的那个角就是
  /// 「长出来的那一点」；以它为支点缩放，锚点处的内容在屏幕上几乎不动 ——
  /// 读起来是「原地缩小」。以中心为支点则会整体向内挪。
  ///
  /// 只在 [stackPivotBounds] 为空时起作用。
  final bool stackAnchorPivot;

  /// 让位缩放的支点**由调用方指定**：取这个矩形（**窗口全局坐标**）的左上角。
  ///
  /// 与非空时的 [stackAnchorPivot] 只差一件事：支点不再受「面板角」这个几何
  /// 前提限制。典型场景是一级菜单里被点开二级的那一行 —— 让位时该行必须
  /// 原地不动，而它既不在面板中心、也未必贴任何一个角（见
  /// `stackAnchorPivot` 之上那条注释说的「几乎不动」，其实按到角的距离成比例
  /// 地挪）。把那一行自己的矩形传进来，行原地不动，二级面板顶部重复出来的
  /// 同名标题行才能与它逐像素重合。
  ///
  /// 传 null（默认）时行为与此前完全一致。
  final Rect? stackPivotBounds;

  /// 让位时**面板（卡片轮廓）本身是否跟着缩**（默认 true = 上游原行为）。
  ///
  /// 置 false 时只有**内容**跟着让位变换走，面板轮廓与压暗原地不动。
  ///
  /// 为什么需要它：面板通常不是孤立的一块 —— 调用方可能在同一屏里摆两块
  /// 面板，其中一块（如二级面板）按另一块的某一行锚定、且自己不参与让位。
  /// 这时若让位连卡片一起缩，两块卡片的边缘就会差出一个「板宽 × 让位幅度」
  /// 的错位（200 宽的面板上是 10px），接缝处读起来像"只缩了一半"。
  /// 只缩内容时卡片轮廓原地不动，与相邻面板对齐，层次感由压暗交代。
  ///
  /// 代价：内容缩进去后，面板轮廓会比内容宽出 / 高出一截（左边与下边留出
  /// 空隙），这是这条路的固有观感，不是缺陷。
  final bool stackScalesPanel;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlassPopupLayout(this);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderGlassPopupLayout).update(this);
}

class _PopupParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderGlassPopupLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PopupParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PopupParentData> {
  _RenderGlassPopupLayout(this.data);
  GlassPopupLayout data;
  late MiuixGlassPopupFrame frame;
  Rect anchor = Rect.zero;
  Size? _measured;

  /// [GlassPopupLayout.stackPivotBounds] 换算到本节点局部坐标后的矩形（见
  /// [stackPivot]）。每次布局现算：它来自另一棵子树的窗口坐标，而本节点的
  /// 祖先链可能在两次布局之间变过。
  Rect? _stackPivotLocal;

  /// 面板实际布局矩形（让位时 = [frame.rect] 朝 [stackPivot] 缩过之后的那块）。
  ///
  /// 让位缩放走**布局尺寸**而不是 paint 变换：液态玻璃按子节点布局尺寸 +
  /// `localToGlobal` 画形状，paint 变变换带不动它；布局缩了，玻璃就按缩后
  /// 的真实矩形画，与内容同一套几何。内容仍用 paint 变换缩（避免按窄宽度
  /// 重排文字导致「内部结构变了」）。
  Rect _panelRect = Rect.zero;

  RenderBox get panel => firstChild!;
  RenderBox get content => childAfter(panel)!;
  RenderBox? get copy => childAfter(content);
  /// 让位缩放的支点，按优先级取：调用方指定的 [GlassPopupLayout.stackPivotBounds]
  /// 的左上角 → [GlassPopupLayout.stackAnchorPivot] 时「离锚点最近的面板角」 →
  /// 面板中心。
  Offset get stackPivot {
    final rect = frame.rect;
    final custom = _stackPivotLocal;
    if (custom != null) return custom.topLeft;
    if (!data.stackAnchorPivot) return rect.center;
    return Offset(
      anchor.center.dx <= rect.center.dx ? rect.left : rect.right,
      anchor.center.dy <= rect.center.dy ? rect.top : rect.bottom,
    );
  }

  Matrix4 get stackTransform {
    final pivot = stackPivot;
    return Matrix4.identity()
      ..translateByDouble(pivot.dx, pivot.dy, 0, 1)
      ..scaleByDouble(
        1 - .05 * data.stackProgress,
        1 - .05 * data.stackProgress,
        1,
        1,
      )
      ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1);
  }
  double get contentScale => data.motion == MiuixGlassPopupMotion.secondary
      ? 1
      : math.min(1, frame.rect.width / math.max(content.size.width, .01));
  /// 内容自身的变换：`[面板左上角平移] → [内容缩放]`，**不含**让位变换。
  ///
  /// 让位变换套在哪一层由 [paint] 决定：面板跟着缩时套在外层（连面板与压暗
  /// 一起），面板不缩时折进内容这一层（见 [contentTransform]）。
  Matrix4 get contentLocalTransform => Matrix4.identity()
    ..translateByDouble(frame.rect.left, frame.rect.top, 0, 1)
    ..scaleByDouble(contentScale, contentScale, 1, 1);

  /// 内容连同让位变换。面板不跟着缩时，内容这一层要自己套上它（见 [paint]）。
  Matrix4 get contentTransform => stackTransform..multiply(contentLocalTransform);

  /// 面板的绘制变换：跟着让位时 = 让位变换 + 面板左上角平移；不跟着时只剩
  /// 平移 —— 面板轮廓原地不动（见 [paint] 的两个分支）。
  /// 面板的绘制变换：布局级让位时面板矩形已是缩过的，绘制只平移；
  /// 否则按是否叠 paint 让位变换决定（见 [paint]）。
  Matrix4 get panelTransform {
    final rect = _panelRect == Rect.zero ? frame.rect : _panelRect;
    final local = Matrix4.identity()
      ..translateByDouble(rect.left, rect.top, 0, 1);
    if (data.stackScalesPanel && data.stackProgress > 0) {
      return local;
    }
    return data.stackScalesPanel ? (stackTransform..multiply(local)) : local;
  }
  Matrix4 get copyTransform {
    final s = frame.rect.width / math.max(anchor.width, .01);
    return stackTransform
      ..translateByDouble(
        frame.rect.center.dx - anchor.width * s / 2,
        frame.rect.center.dy - anchor.height * s / 2,
        0,
        1,
      )
      ..scaleByDouble(s, s, 1, 1);
  }

  void update(GlassPopupLayout value) {
    data = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PopupParentData) {
      child.parentData = _PopupParentData();
    }
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final margin = data.sizing.safeMargin;
    final left = math.min(size.width, data.insets.left + margin),
        top = math.min(size.height, data.insets.top + margin);
    final bounds = Rect.fromLTRB(
      left,
      top,
      math.max(left, size.width - data.insets.right - margin),
      math.max(top, size.height - data.insets.bottom - margin),
    );
    final maxWidth = math.min(data.sizing.maxWidth, bounds.width);
    content.layout(
      BoxConstraints(
        minWidth: math.min(data.sizing.minWidth, maxWidth),
        maxWidth: maxWidth,
        maxHeight: math.min(data.sizing.maxHeight, bounds.height),
      ),
      parentUsesSize: true,
    );
    // 锚点在弹出前的帧末采样，不在布局阶段读取另一棵子树的 size。
    final global = data.anchorBounds;
    anchor = global == null
        ? Rect.fromCenter(center: bounds.center, width: 1, height: 1)
        : Rect.fromPoints(
            globalToLocal(global.topLeft),
            globalToLocal(global.bottomRight),
          );
    // 同 [anchor]：让位支点也是窗口坐标，同处换算。
    final pivot = data.stackPivotBounds;
    _stackPivotLocal = pivot == null
        ? null
        : Rect.fromPoints(
            globalToLocal(pivot.topLeft),
            globalToLocal(pivot.bottomRight),
          );
    frame = miuixGlassPopupFrame(
      motion: data.motion,
      anchor: anchor,
      end: content.size,
      bounds: bounds,
      progress: data.progress,
      positionProgress: data.positionProgress,
      cornerRadius: data.cornerRadius,
      gap: data.gap,
      padding: data.padding,
      direction: data.direction,
    );
    // 让位：面板按布局朝支点等比缩小（整卡轮廓 + 玻璃同一矩形）。
    _panelRect = frame.rect;
    if (data.stackScalesPanel && data.stackProgress > 0) {
      final s = 1.0 - 0.05 * data.stackProgress.clamp(0.0, 1.0);
      final p = stackPivot;
      final r = frame.rect;
      _panelRect = Rect.fromLTRB(
        p.dx + (r.left - p.dx) * s,
        p.dy + (r.top - p.dy) * s,
        p.dx + (r.right - p.dx) * s,
        p.dy + (r.bottom - p.dy) * s,
      );
    }
    panel.layout(BoxConstraints.tight(_panelRect.size), parentUsesSize: true);
    copy?.layout(BoxConstraints.tight(anchor.size), parentUsesSize: true);
    if (_measured != content.size) {
      _measured = content.size;
      final measured = content.size;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (attached) data.onMeasured?.call(measured);
      });
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // 让位（stackScalesPanel）：面板**布局矩形**已缩过（见 performLayout），
    // 玻璃按缩后尺寸画；内容用 contentTransform（含 stack 缩放）视觉对齐，
    // 不按窄宽度重排。不要再对面板套一层 paint stackTransform —— 那是
    // 「内容在动、玻璃板不动」的老路。
    if (data.stackScalesPanel) {
      context.paintChild(panel, offset + _panelRect.topLeft);
      _paintContent(context, offset, contentTransform);
      _paintStackMask(context, offset);
    } else {
      context.paintChild(panel, offset + frame.rect.topLeft);
      _paintContent(context, offset, contentTransform);
      _paintStackMask(context, offset);
    }
    if (copy != null) {
      context.pushTransform(
        needsCompositing,
        offset,
        copyTransform,
        (context, offset) => context.paintChild(copy!, offset),
      );
    }
  }

  /// 画内容：按**当前面板矩形**裁，再套 [transform]。
  void _paintContent(
    PaintingContext context,
    Offset offset,
    Matrix4 transform,
  ) {
    final rect = data.stackScalesPanel ? _panelRect : frame.rect;
    final radius =
        frame.cornerRadius *
        (data.stackScalesPanel && data.stackProgress > 0
            ? (1.0 - 0.05 * data.stackProgress.clamp(0.0, 1.0))
            : 1.0);
    context.pushClipRRect(
      needsCompositing,
      offset,
      rect,
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      (context, offset) => context.pushTransform(
        needsCompositing,
        offset,
        transform,
        (context, offset) => context.paintChild(content, offset),
      ),
      clipBehavior: Clip.antiAlias,
    );
  }

  /// 让位期间的压暗，画在**缩后**的面板矩形上。
  void _paintStackMask(PaintingContext context, Offset offset) {
    if (data.stackProgress <= 0) return;
    final rect = data.stackScalesPanel ? _panelRect : frame.rect;
    final radius =
        frame.cornerRadius *
        (data.stackScalesPanel
            ? (1.0 - 0.05 * data.stackProgress.clamp(0.0, 1.0))
            : 1.0);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(offset), Radius.circular(radius)),
      Paint()
        ..color = data.maskColor.withValues(
          alpha: data.maskColor.a * data.stackProgress,
        ),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final rect = data.stackScalesPanel ? _panelRect : frame.rect;
    if (!data.interactive || !rect.contains(position)) return false;
    return result.addWithPaintTransform(
      transform: contentTransform,
      position: position,
      hitTest: (result, position) =>
          content.hitTest(result, position: position),
    );
  }

  @override
  bool hitTestSelf(Offset position) =>
      (data.stackScalesPanel ? _panelRect : frame.rect).contains(position);
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (child == content) {
      transform.multiply(contentTransform);
    } else if (child == copy) {
      transform.multiply(copyTransform);
    } else {
      transform.multiply(panelTransform);
    }
  }
}
