// Miuix Flutter 移植版 - Glass / GlassPanel / GlassSurface
// 源自 compose-miuix-ui/miuix 的 Glass.kt、GlassPanel.kt 与 internal/GlassUniforms.kt。
// 背景先低分辨率高斯模糊/混色，再运行源端折射 shader；轮廓、高光和阴影全分辨率绘制。
// SPDX-License-Identifier: Apache-2.0
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../blur/miuix_backdrop.dart';
import '../glass/miuix_glass_decoration.dart';
import '../glass/miuix_glass_material.dart';
import '../glass/miuix_glass_shape.dart';
import '../glass/miuix_glass_style.dart';
import '../glass/miuix_glass_styles.dart';
import '../glass/internal/miuix_glass_uniforms.dart';
import '../foundation/miuix_popup_utils.dart';
import '../theme/miuix_theme.dart';

/// 对应 Kotlin GlassDefaults。
class MiuixGlassDefaults {
  MiuixGlassDefaults._();
  static const cornerRadius = 24.0;
  static const smoothing = 1.0;
  static const sourceDensity = 3.0;
  static MiuixGlassStyle style(BuildContext context) =>
      MiuixGlassStyles.forTheme(
        MiuixTheme.of(context).colors.background.computeLuminance() < .5,
      );
}

/// 预加载 OS4 shader。可在首屏之前 await；绘制对象各自持有并释放 FragmentShader。
class MiuixGlassRendering {
  MiuixGlassRendering._();
  static final Map<String, ui.FragmentProgram> _programs = {};
  static Future<void>? _loading;
  static bool get isLoaded => _programs.length == miuixGlassUniforms.length;
  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    for (final name in miuixGlassUniforms.keys) {
      final asset = 'shaders/miuix_os4_$name.frag';
      ui.FragmentProgram program;
      try {
        program = await ui.FragmentProgram.fromAsset(
          'packages/flutter_miuix/$asset',
        );
      } catch (_) {
        program = await ui.FragmentProgram.fromAsset(asset);
      }
      _programs[name] = program;
    }
  }
}

/// 对应 Kotlin Modifier.glass。必须放在 backdrop 捕获子树之外，防止反馈采样。
///
/// 无 backdrop 或 shader 不可用时保留纯色轮廓、阴影及可绘制的高光，不伪装成折射效果。
/// [shading] 为 false 时使用 OS4 栏/菜单的 MaterialToken，而非仿生折射 GlassToken。
class MiuixGlass extends StatefulWidget {
  const MiuixGlass({
    super.key,
    this.backdrop,
    this.style,
    this.material,
    this.underlayMaterial,
    this.shape = const MiuixGlassShape(),
    this.alpha = 1,
    this.tint,
    this.fill,
    this.stroke,
    this.shadow,
    this.shading = true,
    this.enabled = true,
    required this.child,
  }) : assert(alpha >= 0 && alpha <= 1);
  final MiuixBackdrop? backdrop;
  final MiuixGlassStyle? style;
  final MiuixGlassMaterial? material, underlayMaterial;
  final MiuixGlassShape shape;
  final double alpha;
  final Color? tint, fill;
  final MiuixGlassStroke? stroke;
  final MiuixGlassShadow? shadow;
  final bool shading, enabled;
  final Widget child;
  @override
  State<MiuixGlass> createState() => _MiuixGlassState();
}

class _MiuixGlassState extends State<MiuixGlass> {
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _ready = MiuixGlassRendering.isLoaded;
    if (_ready) return;
    MiuixGlassRendering.load().then(
      (_) {
        if (mounted) setState(() => _ready = true);
      },
      onError: (Object error, StackTrace stack) {
        // Unsupported backends still get an accessible solid surface.
        assert(() {
          debugPrint('Miuix OS4 shader fallback: $error');
          return true;
        }());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MiuixTheme.of(context).colors;
    final fill =
        widget.fill ??
        (colors.background.computeLuminance() < .5
            ? const Color(0xFF2C2C2C)
            : const Color(0xFFFFFFFF));
    return _GlassRenderWidget(
      config: widget,
      ready: _ready,
      style: widget.style ?? MiuixGlassDefaults.style(context),
      fill: fill,
      direction: Directionality.of(context),
      dpr: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: widget.shape),
        child: widget.child,
      ),
    );
  }
}

/// 对应 Kotlin Modifier.glassPanel，默认附带 Regular 阴影。
class MiuixGlassPanel extends MiuixGlass {
  const MiuixGlassPanel({
    super.key,
    super.backdrop,
    super.style,
    super.material,
    super.underlayMaterial,
    super.shape,
    super.alpha,
    super.tint,
    super.fill,
    super.stroke,
    super.shadow = MiuixGlassShadows.regular,
    super.shading,
    super.enabled,
    required super.child,
  });
}

/// 对应 Kotlin glassSurface，供已有级联菜单的 surfaceBuilder 注入 OS4 表面。
MiuixPopupSurfaceBuilder miuixGlassSurface({
  MiuixBackdrop? backdrop,
  MiuixGlassStyle? style,
  MiuixGlassMaterial? material,
  Color? fill,
  MiuixGlassStroke? stroke,
  MiuixGlassShadow? shadow = MiuixGlassShadows.floating,
  double alpha = 1,
}) => (context, shape, child) {
  final radius = shape is RoundedRectangleBorder ? shape.borderRadius : null;
  final dark = MiuixTheme.of(context).colors.background.computeLuminance() < .5;
  return MiuixGlassPanel(
    backdrop: backdrop,
    style: style,
    material: material ?? MiuixGlassMaterials.popupViewGlass(dark),
    shape: shape is MiuixGlassShape
        ? shape
        : MiuixGlassShape(borderRadius: radius),
    fill: fill,
    stroke: stroke ?? MiuixGlassStrokes.forTheme(dark),
    shadow: shadow,
    alpha: alpha,
    shading: false,
    child: child,
  );
};

class _GlassRenderWidget extends SingleChildRenderObjectWidget {
  const _GlassRenderWidget({
    required this.config,
    required this.ready,
    required this.style,
    required this.fill,
    required this.direction,
    required this.dpr,
    required super.child,
  });
  final MiuixGlass config;
  final bool ready;
  final MiuixGlassStyle style;
  final Color fill;
  final TextDirection direction;
  final double dpr;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGlass(this);
  @override
  void updateRenderObject(BuildContext context, _RenderGlass renderObject) =>
      renderObject.update(this);
}

class _RenderGlass extends RenderProxyBox {
  _RenderGlass(this.data);
  _GlassRenderWidget data;
  final _shaders = <String, ui.FragmentShader>{};
  ui.Image? _texture;
  Object? _textureKey;
  MiuixBackdrop? get backdrop => data.config.backdrop;
  void update(_GlassRenderWidget value) {
    if (attached && backdrop != value.config.backdrop) {
      backdrop?.removeListener(markNeedsPaint);
      value.config.backdrop?.addListener(markNeedsPaint);
    }
    data = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    backdrop?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    backdrop?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    for (final s in _shaders.values) {
      s.dispose();
    }
    _texture?.dispose();
    super.dispose();
  }

  @override
  Rect get paintBounds {
    final shadow = data.config.shadow;
    return super.paintBounds.inflate(
      shadow == null
          ? 0
          : (shadow.radius +
                    math.max(shadow.offsetX.abs(), shadow.offsetY.abs())) /
                3,
    );
  }

  ui.FragmentShader shader(String key) => _shaders.putIfAbsent(
    key,
    () => MiuixGlassRendering._programs[key]!.fragmentShader(),
  );
  void uniform(String key, String name, List<double> values) {
    final s = shader(key), start = miuixGlassUniforms[key]![name]!;
    for (var i = 0; i < values.length; i++) {
      s.setFloat(start + i, values[i]);
    }
  }

  void silhouette(String key, double scale) {
    final r = data.config.shape.resolve(data.direction),
        half = size.shortestSide / 2;
    uniform(key, 'in_size', [size.width * scale, size.height * scale]);
    uniform(
      key,
      'in_radii',
      [
        r.topLeft.x,
        r.topRight.x,
        r.bottomRight.x,
        r.bottomLeft.x,
      ].map((r) => r.clamp(0, half) * scale).toList(),
    );
    uniform(key, 'in_smoothing', [data.config.shape.smoothing]);
  }

  void bind(String key, ui.Image image) {
    shader(key).setImageSampler(0, image);
    uniform(key, 'u_textureSize', [
      image.width.toDouble(),
      image.height.toDouble(),
    ]);
  }

  ui.Image blend(ui.Image image, MiuixGlassMaterial material, double alpha) {
    bind('blend', image);
    final layers = material.layers;
    for (var i = 0; i < 3; i++) {
      final color = i < layers.length
          ? layers[i].color
          : const Color(0x00000000);
      uniform('blend', 'in_blend$i', [
        color.r,
        color.g,
        color.b,
        color.a * alpha,
      ]);
    }
    uniform('blend', 'in_blendMode', [
      for (var i = 0; i < 3; i++)
        i < layers.length ? layers[i].mode.index.toDouble() : 0,
      layers.length.toDouble(),
    ]);
    final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Paint()..shader = shader('blend'),
    );
    final picture = recorder.endRecording();
    final result = picture.toImageSync(image.width, image.height);
    picture.dispose();
    return result;
  }

  ui.Image prepare(double padding, double ratio) {
    final cfg = data.config, source = backdrop!, image = source.snapshot!;
    final global = localToGlobal(Offset.zero),
        origin = global - source.globalOffset!;
    final blur = cfg.material?.blurRadius ?? data.style.blur.small / 3;
    final key = (
      image,
      origin,
      size,
      ratio,
      blur,
      cfg.material,
      cfg.underlayMaterial,
      cfg.alpha,
    );
    if (_textureKey == key && _texture != null) return _texture!;
    final width = math.max(1, ((size.width + 2 * padding) * ratio).ceil());
    final height = math.max(1, ((size.height + 2 * padding) * ratio).ceil());
    final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
    canvas.scale(ratio);
    final dest = Rect.fromLTWH(
      -origin.dx + padding,
      -origin.dy + padding,
      image.width / source.pixelRatio,
      image.height / source.pixelRatio,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dest,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: blur * .45,
          sigmaY: blur * .45,
          tileMode: TileMode.clamp,
        ),
    );
    // mikcb patch (perf): 不跑 glass 着色器时，把叠色直接画进同一张画布 —— 一次回读
    // 顶掉上游的两次。
    //
    // 上游这里是「先 toImageSync 出模糊底，再逐个 material 走 blend 着色器 +
    // toImageSync」：一块玻璃面每帧两次同步 GPU 回读 + 两次离屏分配，而缓存键含
    // 元素位置与尺寸，入场/位移动画逐帧不命中 —— 真机实测弹层入场渲染线程
    // 9~20ms 对 8.2ms 预算。
    //
    // blend 着色器是上游 GLASS_COLOR_BLEND_SHADER 的逐字移植：每层做
    // `mix(d, B(d,s), a)`，而 softLight / hardLight / overlay / luminosity /
    // colorDodge / colorBurn 的 B 都是标准（PDF）公式，与 Skia 同名混合模式一致。
    // 因此按同样顺序、用 Canvas 的 blendMode 画在模糊底上，结果逐像素相同。
    //
    // 两个前提（都按前提收口，不满足就走上游原路）：
    // * `!cfg.shading` —— 着色器档位要靠 padding 区的像素做边缘光学，而叠色在
    //   padding 的透明区会与着色器分支（`src.a <= 0` 原样返回）产生差异；
    //   非着色器档位只贴内框，padding 不上屏，无此问题。
    // * 每层都有 Skia 对应模式 —— plusDarker / plusLighter 是上游自写公式
    //   （`d ± a·(1-s)`），Skia 没有对应模式（深色档的 first 层就是 plusDarker）。
    if (!cfg.shading) {
      final layers = <(MiuixGlassColorLayer, double)>[
        for (final material in [cfg.underlayMaterial, cfg.material])
          if (material != null)
            for (final layer in material.layers)
              (
                layer,
                identical(material, cfg.underlayMaterial) ? 1.0 : cfg.alpha,
              ),
      ];
      final modes = [
        for (final entry in layers) _canvasBlendModeOf(entry.$1.mode),
      ];
      if (modes.every((mode) => mode != null)) {
        // 画布此刻带着 `canvas.scale(ratio)`，纹理整幅对应 width/ratio 逻辑单位。
        final whole = Rect.fromLTWH(
          0,
          0,
          width / ratio,
          height / ratio,
        );
        for (var i = 0; i < layers.length; i++) {
          final (layer, alpha) = layers[i];
          canvas.drawRect(
            whole,
            Paint()
              ..color = layer.color.withValues(
                alpha: layer.color.a * alpha,
              )
              ..blendMode = modes[i]!,
          );
        }
        final picture = recorder.endRecording();
        final merged = picture.toImageSync(width, height);
        picture.dispose();
        _texture?.dispose();
        _texture = merged;
        _textureKey = key;
        return merged;
      }
    }
    final picture = recorder.endRecording();
    var result = picture.toImageSync(width, height);
    picture.dispose();
    for (final material in [cfg.underlayMaterial, cfg.material]) {
      if (material == null) continue;
      final next = blend(
        result,
        material,
        identical(material, cfg.underlayMaterial) ? 1 : cfg.alpha,
      );
      result.dispose();
      result = next;
    }
    _texture?.dispose();
    _texture = result;
    _textureKey = key;
    return result;
  }

  void glassUniforms(ui.Image texture, double padding, double ratio) {
    final s = data.style, cfg = data.config;
    bind('glass', texture);
    silhouette('glass', ratio);
    uniform('glass', 'in_pad', [padding * ratio, padding * ratio]);
    uniform('glass', 'in_maxCoord', [texture.width - .5, texture.height - .5]);
    uniform('glass', 'in_alphaEdge', [
      (s.inner.alpha * cfg.alpha).clamp(0, 1),
      math.max(s.edge.width / 3, 1 / data.dpr) * ratio,
      s.edge.thickness / 3 * ratio,
      s.edge.reflectOffset / 3 * ratio,
    ]);
    uniform('glass', 'in_iorRefl', [
      s.refract.ior,
      s.reflect.strength,
      s.reflect.lighten,
      s.inner.colorPow,
    ]);
    final tint = cfg.tint ?? s.inner.tint;
    uniform('glass', 'in_tint', [
      tint.r,
      tint.g,
      tint.b,
      cfg.tint?.a ?? s.inner.tintStrength,
    ]);
    uniform('glass', 'in_whiteMixBg', [
      s.inner.colorWhite,
      s.inner.colorMix,
      s.background.saturation,
      s.background.brightness,
    ]);
    uniform('glass', 'in_darker', [
      s.blend.darkerStart,
      s.blend.darkerEnd,
      s.blend.darker,
      s.inner.bottom,
    ]);
    uniform('glass', 'in_lightDir', [
      s.light.directionX,
      s.light.directionY,
      s.light.directionZ,
      s.light.angleRange * math.pi,
    ]);
    uniform('glass', 'in_lightAmt', [
      s.light.intensity,
      s.light.oppositeIntensity,
      s.blend.amount,
      3 * ratio,
    ]);
    uniform('glass', 'in_lumCurve', [
      s.blend.curveA,
      s.blend.curveB,
      s.blend.curveC,
      s.blend.curveD,
    ]);
    uniform('glass', 'in_satBri', [
      s.blend.saturation,
      s.blend.brightness,
      s.background.burn,
      s.background.unShade.clamp(0, 1),
    ]);
    final reach = s.blur.big / 3 * ratio;
    uniform('glass', 'in_edgePow', [
      math.max(s.edge.pow, .01),
      math.min(reach, texture.width / 2),
      math.min(reach, texture.height / 2),
      (reach / math.max(size.longestSide * ratio / 2, 1)).clamp(0, 1),
    ]);
  }

  void light(String name, MiuixGlassStrokeLight light) {
    final dx = light.x - .5, dy = light.y - .7, dz = light.z;
    final len = math.max(math.sqrt(dx * dx + dy * dy + dz * dz), 1e-6),
        c = light.color;
    uniform('stroke', name, [dx / len, dy / len, dz / len, c.a]);
    uniform('stroke', '${name}Color', [c.r, c.g, c.b, 0]);
  }

  void drawShader(
    Canvas canvas,
    String key,
    Offset offset,
    Rect rect,
    double scale, {
    BlendMode blendMode = BlendMode.srcOver,
  }) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(1 / scale);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = shader(key)
        ..blendMode = blendMode,
    );
    canvas.restore();
  }

  void _drawStroke(Canvas canvas, Offset offset, double dpr) {
    final cfg = data.config;
    final shapePath = cfg.shape.getOuterPath(
      offset & size,
      textDirection: data.direction,
    );
    final stroke = cfg.stroke;
    if (stroke != null) {
      if (data.ready) {
        silhouette('stroke', dpr);
        uniform('stroke', 'in_halfViewFloor', [
          (size.width * dpr / 2).floorToDouble(),
          (size.height * dpr / 2).floorToDouble(),
        ]);
        uniform('stroke', 'in_strokeBand', [
          (stroke.width * dpr + .5).clamp(
            .5,
            math.max(.5, size.shortestSide * dpr / 2),
          ),
          math.max(stroke.bevel * dpr + .5, .5),
        ]);
        final c = stroke.color;
        uniform('stroke', 'in_strokeColor', [c.r, c.g, c.b, c.a]);
        uniform('stroke', 'in_strokeAlpha', [cfg.alpha]);
        light('in_light1', stroke.primary);
        light('in_light2', stroke.secondary);
        drawShader(
          canvas,
          'stroke',
          offset,
          Offset.zero & (size * dpr),
          dpr,
          blendMode: BlendMode.plus,
        );
      } else {
        canvas.drawPath(
          shapePath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke.width
            ..color = stroke.color.withValues(
              alpha: stroke.color.a * cfg.alpha,
            ),
        );
      }
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final cfg = data.config,
        canvas = context.canvas,
        rect = offset & size,
        dpr = data.dpr;
    if (size.isEmpty || !cfg.enabled || cfg.alpha <= 0) {
      super.paint(context, offset);
      return;
    }
    final shapePath = cfg.shape.getOuterPath(
          rect,
          textDirection: data.direction,
        ),
        shadow = cfg.shadow;
    if (shadow != null) {
      if (data.ready) {
        silhouette('shadow', dpr);
        final reach = math.max(shadow.radius * dpr / 3, 1.0),
            ox = shadow.offsetX * dpr / 3,
            oy = shadow.offsetY * dpr / 3;
        uniform('shadow', 'in_shadowOffset', [ox, oy]);
        uniform('shadow', 'in_shadowShape', [reach, shadow.dispersion]);
        final c = shadow.color;
        uniform('shadow', 'in_shadowColor', [c.r, c.g, c.b, c.a * cfg.alpha]);
        drawShader(
          canvas,
          'shadow',
          offset,
          Rect.fromLTWH(
            -reach + ox,
            -reach + oy,
            size.width * dpr + reach * 2,
            size.height * dpr + reach * 2,
          ),
          dpr,
        );
      } else {
        canvas.drawPath(
          shapePath.shift(Offset(shadow.offsetX / 3, shadow.offsetY / 3)),
          Paint()
            ..color = shadow.color.withValues(alpha: shadow.color.a * cfg.alpha)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              math.max(shadow.radius / 9, .01),
            ),
        );
      }
    }
    canvas.saveLayer(rect, Paint());
    // 形状硬裁剪：材质本体（模糊快照 + 染色层）是**按整块 rect 画**进去的，圆角
    // 全靠后面那步 `mask` shader（`BlendMode.dstIn`）裁出来 —— 那步没生效时
    // 面板会以**整块矩形**出现：真机在柔光档点开弹层的瞬间，圆圈外面露出一块
    // 亮方形（重新编译后 shader 已加载就看不到，属同一类「首帧未遮罩」）。
    // 这里先按形状路径硬裁一道，材质永远不可能越出形状；描边与 mask 都画在这层
    // 裁剪之外，所以 rim 高光与边缘 AA 不受影响。
    canvas.save();
    canvas.clipPath(shapePath);
    if (data.ready &&
        backdrop?.snapshot != null &&
        backdrop?.globalOffset != null) {
      // mikcb patch (perf): 不跑 glass 着色器的档位（柔光 / 磨砂，`shading: false`）
      // 用更低的离屏倍率。
      //
      // 离屏内容先被 σ = blurRadius × 0.45 模糊过（柔光档 σ≈27），只会被
      // `drawImageRect` 原样贴上屏 —— 多录的像素进不了最终画面，只抬高每帧的
      // 离屏目标与模糊的片元数。这与上游给采样比例写下的理由是同一条。
      // dpr/4→dpr/6（本机 0.69→0.46）把面积降到 44%。
      //
      // 跑着色器的档位不动：那里 `ratio` 还决定边缘光学的采样尺度，降它等于改观感。
      final ratio = cfg.shading
          ? (dpr / 4).clamp(.5, 1.0)
          : (dpr / 6).clamp(.34, 1.0);
      final blur = cfg.material?.blurRadius ?? data.style.blur.small / 3;
      final padding = math.max(blur * 1.5, 24.0),
          image = prepare(padding, ratio);
      if (cfg.shading) {
        glassUniforms(image, padding, ratio);
        drawShader(
          canvas,
          'glass',
          offset - Offset(padding, padding),
          Rect.fromLTWH(
            padding * ratio,
            padding * ratio,
            size.width * ratio,
            size.height * ratio,
          ),
          ratio,
        );
      } else {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(
            padding * ratio,
            padding * ratio,
            size.width * ratio,
            size.height * ratio,
          ),
          rect,
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
    } else {
      canvas.drawPath(
        shapePath,
        Paint()..color = data.fill.withValues(alpha: data.fill.a * cfg.alpha),
      );
    }
    canvas.restore(); // 结束上面的形状硬裁剪（描边与 mask 不受它影响）
    _drawStroke(canvas, offset, dpr);
    if (data.ready) {
      silhouette('mask', dpr);
      drawShader(
        canvas,
        'mask',
        offset,
        Offset.zero & (size * dpr),
        dpr,
        blendMode: BlendMode.dstIn,
      );
    }
    canvas.restore();
    if (data.ready && cfg.shading && data.style.background.unShade < .999) {
      final style = data.style, color = cfg.tint ?? data.style.inner.tint;
      silhouette('rim', dpr);
      uniform('rim', 'in_rimEdge', [
        (style.edge.width * dpr / 3).clamp(
          1.0,
          math.max(1.0, size.shortestSide * dpr / 2),
        ),
        math.max(style.edge.pow, .01),
        cfg.alpha,
        0,
      ]);
      uniform('rim', 'in_lightDir', [
        style.light.directionX,
        style.light.directionY,
        style.light.directionZ,
        style.light.angleRange * math.pi,
      ]);
      uniform('rim', 'in_lightAmt', [
        style.light.intensity,
        style.light.oppositeIntensity,
        0,
        0,
      ]);
      uniform('rim', 'in_surface', [color.r, color.g, color.b, 1]);
      drawShader(
        canvas,
        'rim',
        offset,
        Offset.zero & (size * dpr),
        dpr,
        blendMode: BlendMode.plus,
      );
    }
    super.paint(context, offset);
  }
}

/// mikcb patch (perf): 上游混合模式 → Skia 同名混合模式。
///
/// 返回 null 表示「Skia 没有语义一致的对应模式」，调用方据此退回上游的两段式
/// 路径。`plusDarker` / `plusLighter` 就是这一类：着色器里它们是自写公式
/// `clamp(d ± a·s)`（plusDarker 实为 `d - a·(1-s)`，即 linear burn），
/// Skia 的 `BlendMode.plus` / `darken` 都不是这个语义。
///
/// `luminosity` 对应的 `setLum` / `clipColor` 是标准非分离式混合定义，与 Skia
/// 的实现同源；softLight / hardLight / overlay / colorDodge / colorBurn 同理。
BlendMode? _canvasBlendModeOf(MiuixGlassColorBlendMode mode) => switch (mode) {
  MiuixGlassColorBlendMode.srcOver => BlendMode.srcOver,
  MiuixGlassColorBlendMode.softLight => BlendMode.softLight,
  MiuixGlassColorBlendMode.hardLight => BlendMode.hardLight,
  MiuixGlassColorBlendMode.overlay => BlendMode.overlay,
  MiuixGlassColorBlendMode.luminosity => BlendMode.luminosity,
  MiuixGlassColorBlendMode.colorDodge => BlendMode.colorDodge,
  MiuixGlassColorBlendMode.colorBurn => BlendMode.colorBurn,
  MiuixGlassColorBlendMode.plusDarker ||
  MiuixGlassColorBlendMode.plusLighter => null,
};
