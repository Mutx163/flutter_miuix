// Miuix Flutter 移植版 - OS4 popup lifecycle
// 源自 compose-miuix-ui/miuix 的 GlassPopup / Transform / Secondary / Dropdown / Overlay。
// OverlayPortal 保留调用处主题，返回栈与退出动画同生共灭。
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../blur/miuix_backdrop.dart';
import '../../components/miuix_glass.dart';
import '../../foundation/miuix_popup_utils.dart';
import '../../theme/miuix_theme.dart';
import '../miuix_glass_decoration.dart';
import '../miuix_glass_material.dart';
import '../miuix_glass_motion.dart';
import '../miuix_glass_popup_anchor.dart';
import '../miuix_glass_popup_style.dart';
import '../miuix_glass_shape.dart';
import 'animation.dart';
import 'popup_layout.dart';

class GlassPopupPresenter extends StatefulWidget {
  const GlassPopupPresenter({
    super.key,
    required this.show,
    required this.onDismissRequest,
    required this.child,
    required this.motion,
    this.anchor,
    this.anchorBounds,
    this.materialAnchor,
    this.anchorContent,
    this.backdrop,
    this.sizing = const MiuixGlassPopupSizing(),
    this.visuals = const MiuixGlassPopupVisuals(),
    this.cornerRadius = 24,
    this.gap = 0,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 8),
    this.simplified = false,
    this.stacked = false,
    this.stackDuration,
    this.stackCurve = Curves.fastOutSlowIn,
    this.stackShrinkFromAnchor = false,
    this.stackPivotBounds,
    this.stackScalesPanel = true,
    this.onScrimTap,
    this.maskColor,
    this.scrimAlpha,
    this.onDismissFinished,
    this.onMeasured,
    this.surfaceBuilder,
  });
  final bool show, simplified, stacked;
  final VoidCallback onDismissRequest;
  final VoidCallback? onDismissFinished;
  final ValueChanged<Size>? onMeasured;
  final Widget child;
  final Widget? anchorContent;
  final MiuixGlassPopupMotion motion;
  final MiuixGlassPopupAnchor? anchor, materialAnchor;
  final Rect? anchorBounds;
  final MiuixBackdrop? backdrop;
  final MiuixGlassPopupSizing sizing;
  final MiuixGlassPopupVisuals visuals;
  final double cornerRadius, gap;
  final EdgeInsets contentPadding;
  final Color? maskColor;
  final double? scrimAlpha;

  /// 「让位」([stacked]) 的补间时长；null = 用包内
  /// [MiuixGlassMotion.secondaryPopup] 弹簧（上游原行为）。
  ///
  /// 弹簧的收敛容差与参数都封在包内，调用方无法把这段让位调到确定性手感
  /// （如 200ms fastOutSlowIn）；要那套手感时传时长 + [stackCurve]。
  final Duration? stackDuration;

  /// [stackDuration] 非 null 时使用的曲线。
  final Curve stackCurve;

  /// 让位缩放是否以**离锚点最近的那个面板角**为支点（上游是以面板中心）。
  ///
  /// 面板从锚点行长出来时，锚点所在的角正是「长出来的那一点」；以它为支点，
  /// 让位期间锚点行在屏幕上几乎不动（二级面板贴在它上面），读起来才是
  /// 「原地缩小」而不是「整体挪走」。
  ///
  /// 只在 [stackPivotBounds] 为空时起作用 —— 那个参数能精确指定支点，比
  /// 「取哪个角」更准（「几乎不动」其实按到角的距离成比例地挪，见该参数）。
  final bool stackShrinkFromAnchor;

  /// 让位缩放的支点由调用方指定：取该矩形（**窗口全局坐标**）的左上角。
  ///
  /// 为什么要它：让位时一级面板里**被点开二级的那一行**必须原地不动（二级
  /// 面板顶部会重复出同名标题行，两份得逐像素重合），而那一行既不在面板
  /// 中心、也未必贴任何一个面板角。[stackShrinkFromAnchor] 只能选角，行离
  /// 角有多少距离就挪多少（实测 200 宽的面板上、行离角 150px 时挪了 9px，
  /// 读起来就是同一行字显示成两份）。把那一行自己的矩形传进来即可归零。
  ///
  /// 传 null（默认）时行为与此前完全一致。
  final Rect? stackPivotBounds;

  /// 让位时**面板（卡片轮廓）本身是否跟着缩**（见
  /// [GlassPopupLayout.stackScalesPanel]，默认 true = 上游原行为）。
  ///
  /// 置 false 时只有内容跟着让位变换走，卡片轮廓与压暗原地不动。用于调用方
  /// 在同一屏里另摆了一块不参与让位的面板、且两块卡片必须边缘对齐的场景。
  final bool stackScalesPanel;

  /// 遮罩（面板外区域）被点击时的回调，**带全局点击位置**；null = 走
  /// [onDismissRequest]（上游原行为）。
  ///
  /// 为什么要位置：弹层里还有一层自己的子面板（如二级菜单）时，「点在一级
  /// 面板里、但在二级之外」应当只收起二级，「点在两个面板之外」才关整窗 ——
  /// 调用方拿坐标和自己面板的矩形一比即可区分。只影响遮罩点击，不影响 ESC、
  /// 返回手势与路由 history；无障碍的 "dismiss barrier" 动作没有坐标，
  /// 走 [onDismissRequest]。
  final void Function(Offset globalPosition)? onScrimTap;

  /// 替换面板材质（保留几何、动效与交互）。
  ///
  /// 与 `MiuixListPopup` / 级联菜单同款约定：回调拿到 `(context, shape, child)`，
  /// 返回的面板会**原样取代**内置的 `MiuixGlassPanel`；[child] 是撑满面板的
  /// 占位（`SizedBox.expand()`），调用方自绘材质面即可。
  ///
  /// 用途：调用方想让弹层材质跟随自己的外观档位（例如全局液态 / 柔光玻璃），
  /// 而不必替换掉 presenter 的形变、二级面板与锚定逻辑。
  /// 传 null 时行为与不加此参数完全一致。
  final MiuixPopupSurfaceBuilder? surfaceBuilder;
  @override
  State<GlassPopupPresenter> createState() => _GlassPopupPresenterState();
}

class _GlassPopupPresenterState extends State<GlassPopupPresenter>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static final _active = <_GlassPopupPresenterState>[];
  final _portal = OverlayPortalController();
  final _controllers = <AnimationController>[];
  late final _bounds = AnimationController.unbounded(vsync: this)
    ..addListener(_repaint);
  late final _center = AnimationController.unbounded(vsync: this)
    ..addListener(_repaint);
  late final _fade = AnimationController.unbounded(vsync: this)
    ..addListener(_repaint);
  late final _content = AnimationController.unbounded(vsync: this)
    ..addListener(_repaint);
  late final _icon = AnimationController.unbounded(vsync: this)
    ..addListener(_repaint);
  late final _back = AnimationController.unbounded(vsync: this)
    ..addListener(_repaint);
  late final _stack = AnimationController.unbounded(vsync: this)
    ..addListener(_repaint);
  LocalHistoryEntry? _history;
  Rect? _openingAnchorBounds;
  FocusNode? _previousFocus;
  bool _present = false,
      _removingHistory = false,
      _dismissRequested = false,
      _previewing = false;
  int _generation = 0;
  bool get _reduce => MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  bool get _hideAnchor =>
      widget.motion == MiuixGlassPopupMotion.transform ||
      widget.motion == MiuixGlassPopupMotion.dropdown;
  void _repaint() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _controllers.addAll([
      _bounds,
      _center,
      _fade,
      _content,
      _icon,
      _back,
      _stack,
    ]);
    // 出生就带着 `stacked` 的弹层（调用方按需挂载、挂上时让位已经成立，二级面板
    // 就是这个用法）：让位进度必须**直接落在目标值**上。
    //
    // `didUpdateWidget` 只在 `stacked` **发生变化**时驱动 `_stack`，而首次 build
    // 不算变化 —— 少了这一刀，`_stack` 会永远停在 0：面板不缩、压暗不画，调用方
    // 传进来的 `stacked` 与 `stackPivotBounds` 全是空转。
    _stack.value = widget.stacked ? 1 : 0;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.show) _transition(true);
    });
  }

  @override
  void didUpdateWidget(GlassPopupPresenter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show != oldWidget.show) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _transition(widget.show);
      });
    }
    if (widget.stacked != oldWidget.stacked) {
      final target = widget.stacked ? 1.0 : 0.0;
      final duration = widget.stackDuration;
      if (duration != null) {
        animateGlassToCurve(
          _stack,
          target,
          duration,
          widget.stackCurve,
          disableAnimations: _reduce,
        );
      } else {
        animateGlassTo(
          _stack,
          target,
          MiuixGlassMotion.secondaryPopup(widget.stacked),
          disableAnimations: _reduce,
        );
      }
    }
  }

  void _removeHistory() {
    _removingHistory = true;
    _history?.remove();
    _history = null;
    _removingHistory = false;
  }

  void _requestDismiss() {
    if (!widget.show || _dismissRequested || widget.stacked) return;
    _dismissRequested = true;
    widget.onDismissRequest();
  }

  /// 遮罩被点击：优先走调用方的 [GlassPopupPresenter.onScrimTap]。
  ///
  /// 与 [_requestDismiss] 的差别只有两点：不做 `stacked` 早退（`onScrimTap` 是
  /// 调用方显式要的动作，且本场景里点的是压在上面那层的遮罩），以及换成
  /// `onScrimTap ?? onDismissRequest`。去重标志 `_dismissRequested` 共用。
  void _requestScrimDismiss(Offset globalPosition) {
    if (!widget.show || _dismissRequested) return;
    _dismissRequested = true;
    final onScrimTap = widget.onScrimTap;
    if (onScrimTap != null) {
      onScrimTap(globalPosition);
    } else {
      widget.onDismissRequest();
    }
  }

  Future<void> _linear(
    AnimationController controller,
    double target,
    int milliseconds,
    int generation, {
    int delay = 0,
  }) async {
    if (delay > 0) await Future<void>.delayed(Duration(milliseconds: delay));
    if (!mounted || generation != _generation) return;
    await controller
        .animateTo(
          target,
          duration: Duration(milliseconds: milliseconds),
          curve: Curves.linear,
        )
        .orCancel;
  }

  Future<void> _transition(bool show) async {
    if (!show && !_present) return;
    final generation = ++_generation;
    _dismissRequested = false;
    if (show) {
      _openingAnchorBounds = widget.anchorBounds ?? widget.anchor?.bounds;
      if (!_present) {
        _previousFocus = FocusManager.instance.primaryFocus;
        _portal.show();
        _present = true;
        _active.add(this);
      }
      if (_history == null) {
        _history = LocalHistoryEntry(
          onRemove: () {
            _history = null;
            if (!_removingHistory) _requestDismiss();
          },
        );
        ModalRoute.of(context)?.addLocalHistoryEntry(_history!);
      }
      if (_hideAnchor) widget.anchor?.contentHidden = true;
    } else {
      _removeHistory();
    }
    final target = show ? 1.0 : 0.0, kind = widget.motion;
    if (_reduce) {
      for (final c in [_bounds, _center, _fade, _content, _icon]) {
        c.value = target;
      }
      if (!show) _finish();
      return;
    }
    final boundsSpring = switch (kind) {
      MiuixGlassPopupMotion.transform => MiuixGlassMotion.transformBounds(show),
      MiuixGlassPopupMotion.dropdown => MiuixGlassMotion.arcBounds(show),
      MiuixGlassPopupMotion.secondary => MiuixGlassMotion.secondaryPopup(show),
      MiuixGlassPopupMotion.dialog =>
        show ? MiuixGlassMotion.dialogEnter : MiuixGlassMotion.dialogExit,
      _ => MiuixGlassMotion.popupMorph,
    };
    final centerSpring = switch (kind) {
      MiuixGlassPopupMotion.transform => MiuixGlassMotion.transformCenter(show),
      MiuixGlassPopupMotion.dropdown => MiuixGlassMotion.arcPosition(show),
      _ => boundsSpring,
    };
    final boundsDone = animateGlassTo(_bounds, target, boundsSpring).orCancel;
    final centerDone = animateGlassTo(_center, target, centerSpring).orCancel;
    try {
      await Future.wait([
        boundsDone,
        centerDone,
        _linear(
          _fade,
          target,
          kind == MiuixGlassPopupMotion.dropdown
              ? (show ? 50 : 200)
              : (kind == MiuixGlassPopupMotion.dialog
                    ? (show ? 80 : 150)
                    : (show ? 200 : 150)),
          generation,
        ),
        _linear(
          _content,
          target,
          kind == MiuixGlassPopupMotion.transform ? 80 : 200,
          generation,
          delay: kind == MiuixGlassPopupMotion.transform && show ? 50 : 0,
        ),
        _linear(
          _icon,
          target,
          80,
          generation,
          delay: kind == MiuixGlassPopupMotion.transform && !show ? 50 : 0,
        ),
      ]);
      if (mounted && generation == _generation && !widget.show) _finish();
    } on TickerCanceled {
      /* Reversal/disposal owns the next completion. */
    }
  }

  void _finish() {
    if (!_present) return;
    final wasTop = _active.isNotEmpty && _active.last == this;
    _portal.hide();
    _present = false;
    _active.remove(this);
    if (_hideAnchor) widget.anchor?.contentHidden = false;
    if (wasTop && (_previousFocus?.context?.mounted ?? false)) {
      _previousFocus?.requestFocus();
    }
    widget.onDismissFinished?.call();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (!_present ||
        !widget.show ||
        widget.stacked ||
        _active.isEmpty ||
        _active.last != this) {
      return false;
    }
    _previewing = true;
    _back.stop();
    _back.value = backEvent.progress;
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (_previewing) _back.value = backEvent.progress.clamp(0, 1);
  }

  @override
  void handleCancelBackGesture() {
    if (!_previewing) return;
    _previewing = false;
    animateGlassTo(
      _back,
      0,
      MiuixGlassMotion.secondaryPopup(true),
      disableAnimations: _reduce,
    );
  }

  @override
  void handleCommitBackGesture() {
    if (!_previewing) return;
    _previewing = false;
    final remaining = 1 - _back.value;
    _bounds.value *= remaining;
    _center.value *= remaining;
    _content.value *= remaining;
    _icon.value *= remaining;
    _back.value = 0;
    _requestDismiss();
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _removeHistory();
    _active.remove(this);
    if (_hideAnchor && widget.anchor != null) {
      final anchor = widget.anchor!;
      // 不在父级销毁过程中通知锚点；所属按钮也将随路由一同卸载。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        anchor.contentHidden = false;
      });
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _overlay(BuildContext context) {
    final c = MiuixTheme.of(context).colors,
        dark = c.background.computeLuminance() < .5;
    final kind = widget.motion, v = widget.visuals;
    final source = (widget.materialAnchor ?? widget.anchor)?.surface;
    final media = MediaQuery.of(context), back = 1 - _back.value.clamp(0, 1);
    final progress = _bounds.value * back, position = _center.value * back;
    final fade = _fade.value.clamp(0.0, 1.0) * back,
        content = _content.value.clamp(0.0, 1.0) * back;
    final icon = _icon.value.clamp(0.0, 1.0) * back;
    final isTransform = kind == MiuixGlassPopupMotion.transform,
        isSecondary = kind == MiuixGlassPopupMotion.secondary;
    final scrim = kind == MiuixGlassPopupMotion.dialog
        ? (widget.scrimAlpha ?? (dark ? .6 : .3)) * fade
        : 0.0;
    final inherited = source != null && (isTransform || isSecondary);
    final radius = switch (kind) {
      MiuixGlassPopupMotion.transform => ui.lerpDouble(
        (_openingAnchorBounds?.shortestSide ?? 48) / 2,
        widget.cornerRadius,
        progress,
      )!,
      MiuixGlassPopupMotion.ordinary || MiuixGlassPopupMotion.dropdown =>
        ui.lerpDouble(4, widget.cornerRadius, progress)!,
      _ => widget.cornerRadius,
    };
    final panelShape = MiuixGlassShape(cornerRadius: math.max(0, radius));
    final panelAlpha =
        kind == MiuixGlassPopupMotion.dropdown &&
            widget.show &&
            progress <= MiuixGlassMotion.arcVisibleFraction
        ? 0.0
        : isTransform
        ? ui.lerpDouble(source?.alpha ?? 1, 1, icon)!.clamp(0.0, 1.0)
        : (kind == MiuixGlassPopupMotion.dropdown ||
                  kind == MiuixGlassPopupMotion.dialog
              ? fade
              : 1.0);
    // 形变动效（`transform`：从卡片/按钮里长出来）期间**不逐帧模糊**内容。
    //
    // 真机实测（25060RK16C，120Hz，每帧预算 8.3ms）：课程卡片弹窗出场每帧渲染
    // 8.9ms（最差 21.4ms）→ 46fps；而机制相同、只是走 `dropdown` 的"下拉小气泡"
    // 只有 4.3~4.8ms → 100fps+。差异就在形变这两处逐帧高斯模糊上（内容 sigma
    // 最大 50/dpr ≈ 19，来源卡片同样量级，且贯穿整段动画）。
    //
    // 去掉后形变轨迹 / 缩放 / 圆角 / 锚点全不变，只是从「糊着长出来」变成
    // 「直接长出来」。想找回一点过渡感就调这个系数（0 = 不模糊，0.2~0.4 轻微）。
    const transformMorphBlurScale = 0.0;
    final blur = isTransform
        ? (1 - content) * 50 / media.devicePixelRatio * transformMorphBlurScale
        : isSecondary
        ? 0.0
        : kind == MiuixGlassPopupMotion.dropdown
        ? (widget.show ? 0.0 : (1 - fade) * 30)
        : kind == MiuixGlassPopupMotion.dialog
        ? 0.0
        : (1 - content) * 40 / media.devicePixelRatio;
    Widget rows = SingleChildScrollView(
      primary: false,
      child: Padding(padding: widget.contentPadding, child: widget.child),
    );
    rows = Opacity(
      opacity: isSecondary
          ? 1
          : isTransform
          ? content
          : fade,
      child: ImageFiltered(
        enabled: blur > .01,
        imageFilter: ui.ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        ),
        child: rows,
      ),
    );
    final interactive = widget.show && !widget.stacked;
    rows = ExcludeFocus(
      excluding: !interactive,
      child: ExcludeSemantics(excluding: !interactive, child: rows),
    );

    Widget? copy;
    if (isTransform &&
        widget.anchorContent != null &&
        (!widget.simplified || !widget.show || _previewing) &&
        icon < .999) {
      // 同 [blur]：来源卡片也不再逐帧模糊 —— 它本来就一边被放大中的面板盖住、
      // 一边按 `Opacity(1 - icon)` 淡出，保持清晰读起来只是"淡出"而不是"化开"。
      final blur =
          50 *
          icon /
          media.devicePixelRatio *
          transformMorphBlurScale;
      copy = ExcludeSemantics(
        child: IgnorePointer(
          child: Opacity(
            opacity: 1 - icon,
            child: ImageFiltered(
              enabled: blur > .01,
              imageFilter: ui.ImageFilter.blur(
                sigmaX: blur,
                sigmaY: blur,
                tileMode: TileMode.decal,
              ),
              child: widget.anchorContent!,
            ),
          ),
        ),
      );
    }
    return IgnorePointer(
      // 收起动画期间（`show` 已置 false、覆盖层还没卸载）让点击穿透到页面。
      //
      // 遮罩在这段窗口里仍在最上层、且是 opaque 命中：用户"点空白关掉、立刻再点
      // 按钮重开"时，第二次点击被这张**正在消失的**旧遮罩吃掉（`_requestDismiss`
      // 已去重，什么也不做），读起来就是"点了没反应、等一会儿才灵"。
      // 收起期只应是视觉过程 —— 与 Flutter 自己的 ModalBarrier 同口径：pop 之后
      // 立刻不再拦截。
      ignoring: !widget.show,
      child: Material(
      type: MaterialType.transparency,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _requestDismiss,
        },
        child: FocusScope(
          autofocus: true,
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Semantics(
                    label: MaterialLocalizations.of(
                      context,
                    ).modalBarrierDismissLabel,
                    button: true,
                    // 无障碍 "dismiss barrier" 动作没有坐标：按标准关闭处理。
                    onTap: _requestDismiss,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      // 有位置回调时用 onTapUp 把坐标交出去（同一手势只处理
                      // 一次，所以此时不能再挂 onTap）。
                      onTapUp: widget.onScrimTap == null
                          ? null
                          : (details) =>
                                _requestScrimDismiss(details.globalPosition),
                      onTap: widget.onScrimTap == null
                          ? () => _requestScrimDismiss(Offset.zero)
                          : null,
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: scrim.clamp(0, 1),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: GlassPopupLayout(
                    motion: kind,
                    sizing: widget.sizing,
                    anchor: widget.anchor,
                    anchorBounds: widget.anchorBounds ?? _openingAnchorBounds,
                    progress: progress,
                    positionProgress: position,
                    cornerRadius: widget.cornerRadius,
                    gap: widget.gap,
                    padding: widget.contentPadding,
                    direction: Directionality.of(context),
                    interactive: widget.show && !widget.stacked,
                    insets: EdgeInsets.fromLTRB(
                      media.viewPadding.left,
                      media.viewPadding.top,
                      media.viewPadding.right,
                      math.max(
                        media.viewPadding.bottom,
                        media.viewInsets.bottom,
                      ),
                    ),
                    stackProgress: _stack.value.clamp(0, 1),
                    stackAnchorPivot: widget.stackShrinkFromAnchor,
                    stackPivotBounds: widget.stackPivotBounds,
                    stackScalesPanel: widget.stackScalesPanel,
                    maskColor:
                        widget.maskColor ??
                        (dark ? Colors.black : Colors.white).withValues(
                          alpha: .4,
                        ),
                    onMeasured: (size) {
                      if (mounted) widget.onMeasured?.call(size);
                    },
                    panel: Opacity(
                      opacity: panelAlpha,
                      child:
                          widget.surfaceBuilder?.call(
                            context,
                            panelShape,
                            const SizedBox.expand(),
                          ) ??
                          MiuixGlassPanel(
                            backdrop: inherited
                                ? (isTransform
                                      ? source.backdrop
                                      : (widget.backdrop ?? source.backdrop))
                                : widget.backdrop,
                            style: inherited ? source.style : v.style,
                            material: inherited
                                ? source.material
                                : (kind == MiuixGlassPopupMotion.dialog
                                      ? v.material
                                      : (v.material ??
                                            MiuixGlassMaterials.popupViewGlass(
                                              dark,
                                            ))),
                            underlayMaterial: inherited
                                ? source.underlay
                                : null,
                            shape: panelShape,
                            alpha: v.alpha,
                            stroke: !v.showStroke
                                ? null
                                : inherited
                                ? source.stroke
                                : (v.stroke ?? MiuixGlassStrokes.forTheme(dark)),
                            shadow: v.shadow,
                            fill: inherited ? source.fill : v.containerColor,
                            shading: kind == MiuixGlassPopupMotion.dialog,
                            child: const SizedBox.expand(),
                          ),
                    ),
                    content: rows,
                    anchorContent: copy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    overlayLocation: OverlayChildLocation.rootOverlay,
    controller: _portal,
    overlayChildBuilder: _overlay,
    child: const SizedBox.shrink(),
  );
}

/// Internal adapter shared by the public, separately named OS4 components.
class GlassPopupWidget extends StatelessWidget {
  const GlassPopupWidget({
    super.key,
    required this.show,
    required this.onDismissRequest,
    required this.child,
    required this.motion,
    this.anchor,
    this.anchorBounds,
    this.materialAnchor,
    this.anchorContent,
    this.backdrop,
    this.sizing = const MiuixGlassPopupSizing(),
    this.visuals = const MiuixGlassPopupVisuals(),
    this.cornerRadius = 24,
    this.gap = 0,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 8),
    this.simplified = false,
    this.stacked = false,
    this.stackDuration,
    this.stackCurve = Curves.fastOutSlowIn,
    this.stackShrinkFromAnchor = false,
    this.stackPivotBounds,
    this.stackScalesPanel = true,
    this.onScrimTap,
    this.maskColor,
    this.scrimAlpha,
    this.onDismissFinished,
    this.onMeasured,
    this.surfaceBuilder,
  }) : assert(
         motion == MiuixGlassPopupMotion.dialog ||
             anchor != null ||
             anchorBounds != null,
       );
  final bool show, simplified, stacked;
  final VoidCallback onDismissRequest;
  final VoidCallback? onDismissFinished;
  final ValueChanged<Size>? onMeasured;
  final Widget child;
  final Widget? anchorContent;
  final MiuixGlassPopupMotion motion;
  final MiuixGlassPopupAnchor? anchor, materialAnchor;
  final Rect? anchorBounds;
  final MiuixBackdrop? backdrop;
  final MiuixGlassPopupSizing sizing;
  final MiuixGlassPopupVisuals visuals;
  final double cornerRadius, gap;
  final EdgeInsets contentPadding;
  final Color? maskColor;
  final double? scrimAlpha;

  /// 让位补间（见 [GlassPopupPresenter.stackDuration]）。
  final Duration? stackDuration;

  /// 让位曲线（见 [GlassPopupPresenter.stackCurve]）。
  final Curve stackCurve;

  /// 让位缩放支点是否取锚点角（见 [GlassPopupPresenter.stackShrinkFromAnchor]）。
  final bool stackShrinkFromAnchor;

  /// 让位缩放的支点矩形（见 [GlassPopupPresenter.stackPivotBounds]）。
  final Rect? stackPivotBounds;

  /// 让位时面板轮廓是否跟着缩（见 [GlassPopupPresenter.stackScalesPanel]）。
  final bool stackScalesPanel;

  /// 遮罩点击回调（见 [GlassPopupPresenter.onScrimTap]）。
  final void Function(Offset globalPosition)? onScrimTap;

  /// 替换面板材质（见 [GlassPopupPresenter.surfaceBuilder]）。
  final MiuixPopupSurfaceBuilder? surfaceBuilder;
  @override
  Widget build(BuildContext context) => GlassPopupPresenter(
    show: show,
    onDismissRequest: onDismissRequest,
    motion: motion,
    anchor: anchor,
    anchorBounds: anchorBounds,
    materialAnchor: materialAnchor,
    anchorContent: anchorContent,
    backdrop: backdrop,
    sizing: sizing,
    visuals: visuals,
    cornerRadius: cornerRadius,
    gap: gap,
    contentPadding: contentPadding,
    simplified: simplified,
    stacked: stacked,
    stackDuration: stackDuration,
    stackCurve: stackCurve,
    stackShrinkFromAnchor: stackShrinkFromAnchor,
    stackPivotBounds: stackPivotBounds,
    stackScalesPanel: stackScalesPanel,
    onScrimTap: onScrimTap,
    maskColor: maskColor,
    scrimAlpha: scrimAlpha,
    onDismissFinished: onDismissFinished,
    onMeasured: onMeasured,
    surfaceBuilder: surfaceBuilder,
    child: child,
  );
}
