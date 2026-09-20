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
  Matrix4 get panelTransform {
    final local = Matrix4.identity()
      ..translateByDouble(frame.rect.left, frame.rect.top, 0, 1);
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
    panel.layout(BoxConstraints.tight(frame.rect.size), parentUsesSize: true);
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
    // 让位时面板轮廓是否跟着缩（见 [GlassPopupLayout.stackScalesPanel]）。
    //
    // 跟着缩（上游原行为）：面板、内容、压暗同处一个让位变换下 —— 整块卡片
    // 朝支点缩进去。
    //
    // 不跟着缩：面板轮廓与压暗原地不动，只有内容单独套一层让位变换，读起来
    // 是「卡片不动、里面的行朝支点退了一小步」。这一支不再给面板套变换层，
    // 面板材质（可能带背景滤镜）的采样区因此就是**未缩**的那块轮廓，与画出来
    // 的卡片一致。
    if (data.stackScalesPanel) {
      context.pushTransform(needsCompositing, offset, stackTransform, (
        context,
        offset,
      ) {
        context.paintChild(panel, offset + frame.rect.topLeft);
        _paintContent(context, offset, contentLocalTransform);
        _paintStackMask(context, offset);
      });
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

  /// 画内容：先按**面板轮廓**裁，再套 [transform]（内容缩放，面板不跟着让位
  /// 缩时 [transform] 里还折了让位变换）。
  void _paintContent(
    PaintingContext context,
    Offset offset,
    Matrix4 transform,
  ) {
    context.pushClipRRect(
      needsCompositing,
      offset,
      frame.rect,
      RRect.fromRectAndRadius(frame.rect, Radius.circular(frame.cornerRadius)),
      (context, offset) => context.pushTransform(
        needsCompositing,
        offset,
        transform,
        (context, offset) => context.paintChild(content, offset),
      ),
      clipBehavior: Clip.antiAlias,
    );
  }

  /// 让位期间的压暗，盖在面板轮廓上（跟不跟着缩与面板一致，见 [paint]）。
  void _paintStackMask(PaintingContext context, Offset offset) {
    if (data.stackProgress <= 0) return;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        frame.rect.shift(offset),
        Radius.circular(frame.cornerRadius),
      ),
      Paint()
        ..color = data.maskColor.withValues(
          alpha: data.maskColor.a * data.stackProgress,
        ),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!data.interactive || !frame.rect.contains(position)) return false;
    return result.addWithPaintTransform(
      transform: contentTransform,
      position: position,
      hitTest: (result, position) =>
          content.hitTest(result, position: position),
    );
  }

  @override
  bool hitTestSelf(Offset position) => frame.rect.contains(position);
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
