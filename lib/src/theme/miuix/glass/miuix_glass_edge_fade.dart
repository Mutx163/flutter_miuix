import 'package:flutter/widgets.dart';

/// 玻璃「边缘高光」的显示强度（0..1），随弹层开合渐变。
///
/// 二级面板开合时几何在变，但着色器的 rim 是按完整强度画的 —— 真机读成
/// 「高光突然出现/消失」。宿主（GlassPopupPresenter）在二级动画期间挂上
/// 本作用域，液态面把 `rimStrength` 乘上 [fade]，高光与文字同节奏渐显渐隐。
///
/// 无作用域时视为 1.0（静止态行为不变）。
class MiuixGlassEdgeFade extends InheritedWidget {
  const MiuixGlassEdgeFade({
    super.key,
    required this.fade,
    required super.child,
  });

  final double fade;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MiuixGlassEdgeFade>()?.fade ??
      1.0;

  @override
  bool updateShouldNotify(MiuixGlassEdgeFade oldWidget) => fade != oldWidget.fade;
}
