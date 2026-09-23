// Miuix Flutter 移植版 - GlassPopupAnchor
// 源自 compose-miuix-ui/miuix 的 GlassTransformPopup.kt。
// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/widgets.dart';
import '../blur/miuix_backdrop.dart';
import 'miuix_glass_material.dart';
import 'miuix_glass_style.dart';
import 'miuix_glass_decoration.dart';

/// 对应 Kotlin GlassPopupAnchor。用 MiuixGlassAnchor 或图标按钮的 anchor 参数绑定。
/// 调用方创建并 dispose，不能把同一 anchor 绑定到两个控件。
class MiuixGlassPopupAnchor extends ChangeNotifier {
  final GlobalKey key = GlobalKey(debugLabel: 'MiuixGlassPopupAnchor');
  bool _hidden = false;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 视觉上隐藏锚点内容：形变 / 下拉弹层入场后，这颗球由弹层自己的形变副本
  /// 扮演（见 `GlassPopupPresenter._hideAnchor`）。
  ///
  /// ⚠️ **本标志只管视觉，不再屏蔽输入**（本 fork 于 2026-09-23 拆开）。
  /// 原先它连 [IgnorePointer] 一起给，而这个标志要等收起动画**播完**
  /// （presenter 的 `_finish`）才复位 —— 于是整段收起动画期间锚点既看不见、
  /// 又点不动：用户「点空白收起菜单、马上再点按钮重开」时第二下点击被静默
  /// 丢掉，读起来就是「点了没反应，要等一会儿才灵」。
  ///
  /// 为什么不干脆让隐藏提前复位：视觉得等动画播完才交接，否则真球会与正在
  /// 飞回的副本同时出现。收起期只应是视觉过程 —— 输入与视觉拆开即可。
  ///
  /// 不会因此多出「点到隐形按钮」的窗口：弹层在的时候输入全归覆盖层
  /// （满屏遮罩），锚点本来也收不到点击。
  bool get contentHidden => _hidden;
  set contentHidden(bool value) {
    if (_disposed || _hidden == value) return;
    _hidden = value;
    notifyListeners();
  }

  /// 窗口全局坐标；弹层会转换到自己的 Overlay 坐标系。
  Rect? get bounds {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  /// 图标按钮发布的共享表面，不要求调用方重复配置。
  MiuixGlassAnchorSurface? surface;
}

/// 对应上游锚点携带的 button surface 配置。
@immutable
class MiuixGlassAnchorSurface {
  const MiuixGlassAnchorSurface({
    required this.backdrop,
    required this.style,
    required this.material,
    this.underlay,
    this.stroke,
    this.fill,
    required this.alpha,
  });
  final MiuixBackdrop? backdrop;
  final MiuixGlassStyle style;
  final MiuixGlassMaterial material;
  final MiuixGlassMaterial? underlay;
  final MiuixGlassStroke? stroke;
  final Color? fill;
  final double alpha;
}

/// 对应 Kotlin glassPopupAnchor / glassPopupAnchorValue。
class MiuixGlassAnchor extends StatelessWidget {
  const MiuixGlassAnchor({
    super.key,
    required this.anchor,
    required this.child,
  });
  final MiuixGlassPopupAnchor anchor;
  final Widget child;
  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: anchor.key,
    child: ListenableBuilder(
      listenable: anchor,
      child: child,
      // 隐藏只是视觉交接，输入不跟着交出去（理由见
      // [MiuixGlassPopupAnchor.contentHidden]）：收起动画期间这颗按钮必须
      // 立刻能再被点到，否则第二次点击会被整段动画吃掉。
      builder: (context, child) =>
          Opacity(opacity: anchor.contentHidden ? 0 : 1, child: child),
    ),
  );
}
