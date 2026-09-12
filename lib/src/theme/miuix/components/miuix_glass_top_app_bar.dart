// Miuix Flutter 移植版 - GlassTopAppBar
// 源自 compose-miuix-ui/miuix 的 GlassTopAppBar.kt。
// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/widgets.dart';
import '../blur/miuix_backdrop.dart';
import '../glass/miuix_glass_material.dart';
import '../glass/miuix_glass_motion.dart';
import '../glass/miuix_glass_style.dart';
import '../glass/internal/bar_scope.dart';
import '../theme/miuix_theme.dart';
import 'miuix_blur_top_app_bar.dart';
import 'miuix_glass.dart';
import 'miuix_top_app_bar.dart';

/// 对应 Kotlin GlassTopAppBarDefaults。
class MiuixGlassTopAppBarDefaults {
  MiuixGlassTopAppBarDefaults._();
  static const horizontalPadding = 12.0,
      largeTitleBlurRadius = 12.0,
      buttonSize = 44.0,
      pressedContentAlpha = .6,
      bandOverhang = 28.0;
  static LinearGradient bandBrush(Color color) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0, .45, .58, .72, .86, 1],
    colors: [
      color,
      color,
      color.withValues(alpha: .82),
      color.withValues(alpha: .58),
      color.withValues(alpha: .34),
      color.withValues(alpha: 0),
    ],
  );
}

/// 对应 Kotlin GlassTopAppBar。操作区使用 MiuixGlassIconButton，旧顶栏保持不变。
/// [isContentScrolled] 传入列表是否离开顶部，避免标题锁定折叠后材质不能复位。
class MiuixGlassTopAppBar extends StatelessWidget {
  const MiuixGlassTopAppBar({
    super.key,
    required this.title,
    this.backdrop,
    this.largeTitle,
    this.subtitle = '',
    this.scrollBehavior,
    this.isContentScrolled,
    this.style,
    this.alpha = 1,
    this.titleAlpha = 1,
    this.buttonSize = 44,
    this.largeTitleBlurRadius = 12,
    this.bandOverhang = 28,
    this.bandBrush,
    this.defaultWindowInsetsPadding = true,
    this.navigationIcon,
    this.actions = const [],
    this.bottomContent,
  });
  final String title, subtitle;
  final String? largeTitle;
  final MiuixBackdrop? backdrop;
  final MiuixScrollBehavior? scrollBehavior;
  final bool? isContentScrolled;
  final MiuixGlassStyle? style;
  final double alpha,
      titleAlpha,
      buttonSize,
      largeTitleBlurRadius,
      bandOverhang;
  final Gradient? bandBrush;
  final bool defaultWindowInsetsPadding;
  final Widget? navigationIcon, bottomContent;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    Widget buildBar(BuildContext context) {
      final dark =
          MiuixTheme.of(context).colors.background.computeLuminance() < .5;
      final floating =
          isContentScrolled ??
          (scrollBehavior?.state.contentOffset.isNegative ?? true);
      final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      return TweenAnimationBuilder<double>(
        duration: disabled ? Duration.zero : MiuixGlassMotion.topBarButtonFloat,
        tween: Tween(begin: floating ? 1 : 0, end: floating ? 1 : 0),
        builder: (context, value, child) => GlassBarScope(
          backdrop: backdrop,
          material: MiuixGlassMaterials.puredThinGlass(
            dark,
          ).copyWith(blurRadius: dark ? 63.25 : 44.72),
          underlay: MiuixGlassMaterials.actionBarMask(dark),
          style: style ?? MiuixGlassDefaults.style(context),
          progress: (value * alpha).clamp(0, 1),
          buttonSize: buttonSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                bottom: -bandOverhang,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    duration: disabled
                        ? Duration.zero
                        : MiuixGlassMotion.topBarMask,
                    tween: Tween(
                      begin: floating ? 1 : 0,
                      end: floating ? 1 : 0,
                    ),
                    builder: (context, p, _) => Opacity(
                      opacity: p.clamp(0, 1),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient:
                              bandBrush ??
                              MiuixGlassTopAppBarDefaults.bandBrush(
                                MiuixTheme.of(context).colors.surface,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              MiuixBlurTopAppBar(
                title: title,
                largeTitle: largeTitle,
                subtitle: subtitle,
                titleAlpha: titleAlpha,
                largeTitleBlurRadius: largeTitleBlurRadius,
                color: const Color(0x00000000),
                scrollBehavior: scrollBehavior,
                defaultWindowInsetsPadding: defaultWindowInsetsPadding,
                navigationIconPadding: 12,
                actionIconPadding: 12,
                clipBehavior: Clip.none,
                navigationIcon: navigationIcon,
                actions: actions,
                bottomContent: bottomContent,
              ),
            ],
          ),
        ),
      );
    }

    final state = scrollBehavior?.state;
    return state == null
        ? buildBar(context)
        : ListenableBuilder(
            listenable: state,
            builder: (context, _) => buildBar(context),
          );
  }
}
