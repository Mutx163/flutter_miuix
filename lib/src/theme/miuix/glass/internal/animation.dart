// Miuix Flutter 移植版 - 可中断 OS4 弹簧
// 源自 compose-miuix-ui/miuix 的 GlassMotion.kt。
// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/widgets.dart';
import 'package:flutter/physics.dart';
import '../miuix_glass_motion.dart';

TickerFuture animateGlassTo(
  AnimationController controller,
  double target,
  SpringDescription spring, {
  bool disableAnimations = false,
}) {
  if (disableAnimations) {
    controller.value = target;
    return TickerFuture.complete();
  }
  return controller.animateWith(
    SpringSimulation(
      spring,
      controller.value,
      target,
      controller.velocity,
      tolerance: const Tolerance(distance: .0015, velocity: .0015),
    ),
  );
}

/// [animateGlassTo] 的曲线/时长版本：给「让位」这类**有确定终点的位移**用。
///
/// 弹簧版（[animateGlassTo]）适合交给物理收敛，但它的收敛容差写死在
/// [Tolerance] 里、弹簧参数也只能由包内 motion 表给，调用方无法把一段让位
/// 动作调到「200ms fastOutSlowIn」这种确定性手感。这个函数走
/// [AnimationController.animateTo]，行为与包内 `_linear()` 同源。
TickerFuture animateGlassToCurve(
  AnimationController controller,
  double target,
  Duration duration,
  Curve curve, {
  bool disableAnimations = false,
}) {
  if (disableAnimations) {
    controller.value = target;
    return TickerFuture.complete();
  }
  return controller.animateTo(target, duration: duration, curve: curve);
}

/// 内部弹簧构建器：重定向时保留当前速度，不重新从端点启动。
class GlassSpringBuilder extends StatefulWidget {
  const GlassSpringBuilder({
    super.key,
    required this.value,
    required this.builder,
    this.spring,
    this.initialValue,
    this.child,
  });
  final double value;
  final double? initialValue;
  final SpringDescription? spring;
  final Widget Function(BuildContext, double, Widget?) builder;
  final Widget? child;
  @override
  State<GlassSpringBuilder> createState() => _GlassSpringBuilderState();
}

class _GlassSpringBuilderState extends State<GlassSpringBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: widget.initialValue ?? widget.value,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.value != widget.value) _animate();
  }

  @override
  void didUpdateWidget(GlassSpringBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _animate();
  }

  void _animate() => animateGlassTo(
    _controller,
    widget.value,
    widget.spring ?? MiuixGlassMotion.standard,
    disableAnimations: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) =>
        widget.builder(context, _controller.value, child),
  );
}
