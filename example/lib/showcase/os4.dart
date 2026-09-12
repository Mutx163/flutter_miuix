// HyperOS 4 opt-in showcase. Existing pages retain their original styles.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'common.dart';

class Os4Showcase extends StatefulWidget {
  const Os4Showcase({super.key});
  @override
  State<Os4Showcase> createState() => _Os4ShowcaseState();
}

class _Os4ShowcaseState extends State<Os4Showcase> {
  final _backdrop = MiuixLayerBackdrop(),
      _previewBackdrop = MiuixLayerBackdrop();
  final _scroll = ScrollController();
  final _behavior = MiuixExitUntilCollapsedScrollBehavior();
  final _menuAnchor = MiuixGlassPopupAnchor(),
      _rowAnchor = MiuixGlassPopupAnchor(),
      _ordinaryAnchor = MiuixGlassPopupAnchor(),
      _styleAnchor = MiuixGlassPopupAnchor();
  bool _menu = false,
      _secondary = false,
      _ordinary = false,
      _styles = false,
      _dialog = false,
      _search = false,
      _joined = false,
      _neutral = false,
      _navVisible = true,
      _scrolled = false;
  int _tab = 0, _nav = 0, _preset = 7;
  Rect? _secondaryBounds;
  String _message = '滚动页面，观察顶栏和标签材质的显隐。';
  final _presets = MiuixGlassStyles.values.entries.toList();
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final v = _scroll.hasClients && _scroll.offset > 0;
    if (v != _scrolled) setState(() => _scrolled = v);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _behavior.state.dispose();
    _backdrop.dispose();
    _previewBackdrop.dispose();
    for (final a in [_menuAnchor, _rowAnchor, _ordinaryAnchor, _styleAnchor]) {
      a.dispose();
    }
    super.dispose();
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: MiuixText(title, fontWeight: FontWeight.w600),
        ),
        MiuixCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final theme = MiuixTheme.of(context),
        dark = theme.colors.background.computeLuminance() < .5;
    final embedded = ShowcaseEmbedded.of(context);
    return Material(
      color: theme.colors.surface,
      child: Stack(
        children: [
          MiuixScaffold(
            contentWindowInsets: embedded ? EdgeInsets.zero : null,
            topBar: MiuixGlassTopAppBar(
              title: 'HyperOS 4',
              subtitle: 'Glass · 独立启用，不覆盖旧组件',
              backdrop: _backdrop,
              scrollBehavior: _behavior,
              isContentScrolled: _scrolled,
              titleAlpha: _search ? 0 : 1,
              defaultWindowInsetsPadding: !embedded,
              navigationIcon: Navigator.of(context).canPop() && !embedded
                  ? MiuixGlassIconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: '返回',
                      child: MiuixIcon(vector: MiuixIcons.os4.chevronBackward),
                    )
                  : null,
              actions: [
                MiuixGlassIconButton(
                  onPressed: () => setState(() => _search = true),
                  tooltip: '搜索',
                  child: MiuixIcon(vector: MiuixIcons.os4.search),
                ),
                const SizedBox(width: 8),
                MiuixGlassIconButton(
                  anchor: _menuAnchor,
                  onPressed: () => setState(() => _menu = true),
                  tooltip: '变形菜单',
                  child: const Icon(Icons.more_horiz),
                ),
              ],
              bottomContent: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: _joined
                    ? MiuixGlassSegmentedTabRow(
                        tabs: const ['组件', '材质', '图标'],
                        selectedIndex: _tab,
                        onSelect: (i) => setState(() => _tab = i),
                      )
                    : MiuixGlassTabRow(
                        tabs: const ['组件', '材质', '图标'],
                        selectedIndex: _tab,
                        onSelect: (i) => setState(() => _tab = i),
                        height: _neutral ? 35 : 40,
                        colors: _neutral
                            ? MiuixGlassTabRowDefaults.neutralColors(context)
                            : null,
                      ),
              ),
            ),
            bottomBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: MiuixGlassNavigationBar(
                      backdrop: _backdrop,
                      visible: _navVisible,
                      selectedIndex: _nav,
                      onSelect: (i) => setState(() => _nav = i),
                      items: [
                        const MiuixGlassNavigationItem(
                          icon: Icon(Icons.home_outlined),
                          label: '首页',
                        ),
                        MiuixGlassNavigationItem(
                          icon: MiuixIcon(
                            vector: MiuixIcons.os4.create,
                            size: 28,
                          ),
                          label: '创作',
                        ),
                        MiuixGlassNavigationItem(
                          icon: MiuixIcon(
                            vector: MiuixIcons.os4.image,
                            size: 28,
                          ),
                          label: '图库',
                        ),
                        MiuixGlassNavigationItem(
                          icon: MiuixIcon(
                            vector: MiuixIcons.os4.settings,
                            size: 28,
                          ),
                          label: '设置',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            content: (padding) => MiuixLayerBackdropCapture(
              backdrop: _backdrop,
              child: ColoredBox(
                color: theme.colors.surface,
                child: MiuixScrollBehaviorListener(
                  behavior: _behavior,
                  child: ListView(
                    controller: _scroll,
                    padding:
                        padding +
                        const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _section('交互与布局', [
                                MiuixText(_message),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    MiuixButton(
                                      onPressed: () =>
                                          setState(() => _joined = !_joined),
                                      child: Text(
                                        _joined ? '使用独立标签' : '使用连体标签',
                                      ),
                                    ),
                                    MiuixButton(
                                      onPressed: () =>
                                          setState(() => _neutral = !_neutral),
                                      child: const Text('切换中性色'),
                                    ),
                                    MiuixButton(
                                      onPressed: () => setState(
                                        () => _navVisible = !_navVisible,
                                      ),
                                      child: const Text('导航显隐'),
                                    ),
                                  ],
                                ),
                                MiuixText('当前标签 ${_tab + 1} · 导航 ${_nav + 1}'),
                              ]),
                              _section('玻璃材质 · 35 组源端 token', [
                                SizedBox(
                                  height: 220,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: MiuixLayerBackdropCapture(
                                            backdrop: _previewBackdrop,
                                            child: const CustomPaint(
                                              painter: _GlassWallpaper(),
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: SizedBox(
                                            width: 230,
                                            height: 132,
                                            child: MiuixGlassPanel(
                                              backdrop: _previewBackdrop,
                                              style: _presets[_preset].value,
                                              // 和上游真实 OS4 表面一致：栏/弹层/对话框都带
                                              // pured-thin 材质（20dp 模糊 + SoftLight 等颜色层）。
                                              // material 为 null 时只有折射着色，按原版说法“读起来
                                              // 像个洞而不是面板”，看不出柔光玻璃。
                                              material:
                                                  MiuixGlassMaterials.puredThinGlass(
                                                    dark,
                                                  ),
                                              stroke:
                                                  MiuixGlassStrokes.forTheme(
                                                    dark,
                                                  ),
                                              shape: const MiuixGlassShape(
                                                cornerRadius: 32,
                                              ),
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    MiuixIcon(
                                                      vector:
                                                          MiuixIcons.os4.image,
                                                      size: 36,
                                                      tint: Colors.white,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    const MiuixText(
                                                      'OS4 Glass',
                                                      color: Colors.white,
                                                      fontSize: 24,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                MiuixGlassAnchor(
                                  anchor: _styleAnchor,
                                  child: MiuixButton(
                                    onPressed: () =>
                                        setState(() => _styles = true),
                                    child: Text(_presets[_preset].key),
                                  ),
                                ),
                                const MiuixText(
                                  '预览使用独立 backdrop；采样组件不在自己捕获的子树内。'
                                  '面板带 pured-thin 材质，token 只改折射与着色。',
                                ),
                              ]),
                              _section('弹层', [
                                MiuixGlassAnchor(
                                  anchor: _ordinaryAnchor,
                                  child: MiuixButton(
                                    onPressed: () =>
                                        setState(() => _ordinary = true),
                                    child: const Text('普通玻璃菜单'),
                                  ),
                                ),
                                MiuixButton(
                                  onPressed: () =>
                                      setState(() => _dialog = true),
                                  child: const Text('玻璃对话框'),
                                ),
                                const MiuixText(
                                  '右上角按钮演示按钮→菜单形变；进入“更多选项”查看二级菜单。',
                                ),
                              ]),
                              _section('OS4 符号图标 · 176 × 5 字重', [
                                for (final weight in MiuixIconWeight.values)
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 84,
                                        child: Text(weight.name),
                                      ),
                                      for (final name in [
                                        'search',
                                        'create',
                                        'image',
                                        'settings',
                                      ])
                                        Expanded(
                                          child: MiuixIcon(
                                            vector: MiuixIcons.os4.byName(
                                              name,
                                              weight,
                                            )!,
                                            size: 26,
                                          ),
                                        ),
                                    ],
                                  ),
                              ]),
                              for (var i = 0; i < 5; i++)
                                _section('滚动采样 ${i + 1}', [
                                  MiuixText(
                                    '背景颜色和文字经过栏位时会参与模糊与混色。',
                                    color: theme.colors.onSurfaceVariantSummary,
                                  ),
                                  Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.withValues(
                                            alpha: .2 + i * .1,
                                          ),
                                          Colors.purple.withValues(
                                            alpha: .15 + i * .08,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          MiuixGlassPopup(
            show: _ordinary,
            anchor: _ordinaryAnchor,
            backdrop: _backdrop,
            onDismissRequest: () => setState(() => _ordinary = false),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MiuixGlassPopupItem(
                  text: '普通菜单操作',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () => setState(() {
                    _ordinary = false;
                    _message = '已执行普通菜单操作';
                  }),
                ),
                const MiuixGlassPopupItem(
                  text: '不可用操作',
                  enabled: false,
                  onPressed: null,
                ),
              ],
            ),
          ),
          MiuixGlassTransformPopup(
            show: _menu,
            anchor: _menuAnchor,
            anchorContent: const Center(child: Icon(Icons.more_horiz)),
            simplified: true,
            stacked: _secondary,
            backdrop: _backdrop,
            onDismissRequest: () => setState(() => _menu = false),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MiuixGlassPopupItem(
                  text: '新建',
                  icon: MiuixIcon(vector: MiuixIcons.os4.create),
                  onPressed: () => setState(() {
                    _menu = false;
                    _message = '已新建';
                  }),
                ),
                MiuixGlassAnchor(
                  anchor: _rowAnchor,
                  child: MiuixGlassPopupItem(
                    text: '更多选项',
                    summary: '展开二级面板',
                    showArrow: true,
                    arrowRotation: _secondary ? -90 : 0,
                    onPressed: () {
                      _secondaryBounds = _rowAnchor.bounds;
                      setState(() => _secondary = true);
                    },
                  ),
                ),
                MiuixGlassPopupItem(
                  text: '关闭',
                  onPressed: () => setState(() => _menu = false),
                ),
              ],
            ),
          ),
          if (_secondaryBounds != null)
            MiuixGlassSecondaryPopup(
              show: _secondary,
              anchorBounds: _secondaryBounds,
              materialAnchor: _menuAnchor,
              backdrop: _backdrop,
              onDismissRequest: () => setState(() => _secondary = false),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MiuixGlassPopupItem(
                    text: '返回上级',
                    showArrow: true,
                    arrowRotation: -90,
                    onPressed: () => setState(() => _secondary = false),
                  ),
                  for (final label in ['仅 Wi-Fi', '始终允许', '从不'])
                    MiuixGlassPopupItem(
                      text: label,
                      onPressed: () => setState(() {
                        _secondary = false;
                        _message = label;
                      }),
                    ),
                ],
              ),
            ),
          MiuixGlassDropdownPopup(
            show: _styles,
            anchor: _styleAnchor,
            backdrop: _backdrop,
            onDismissRequest: () => setState(() => _styles = false),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _presets.length; i++)
                  MiuixGlassPopupItem(
                    text: _presets[i].key,
                    selected: i == _preset,
                    onPressed: () => setState(() {
                      _preset = i;
                      _styles = false;
                    }),
                  ),
              ],
            ),
          ),
          MiuixGlassDialog(
            visible: _dialog,
            backdrop: _backdrop,
            onDismissRequest: () => setState(() => _dialog = false),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiuixText(
                  'HyperOS 4',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                const SizedBox(height: 12),
                const MiuixText('新的玻璃材质与组件可以按需启用。原有界面与组件默认样式保持不变。'),
                const SizedBox(height: 20),
                MiuixButton(
                  onPressed: () => setState(() => _dialog = false),
                  child: const Text('知道了'),
                ),
              ],
            ),
          ),
          _GlassSearchExample(
            visible: _search,
            onDismiss: () => setState(() => _search = false),
          ),
        ],
      ),
    );
  }
}

// 高对比壁纸，对应上游 demo 的照片背景。OS4 材质的三层里两层是白色 SoftLight /
// HardLight，只会把背景往白里抬；背景本身若是浅色渐变，过完材质就只剩一块死白，
// 玻璃的层次全被压没。有暗部才看得出模糊和折射。
class _GlassWallpaper extends CustomPainter {
  const _GlassWallpaper();
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF101436), Color(0xFF6B2A7A), Color(0xFFC85A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
    );
    const blobs = [
      (.12, .22, .30, Color(0xFF4FC3F7)),
      (.34, .74, .24, Color(0xFF1A0B2E)),
      (.55, .30, .28, Color(0xFFFFE082)),
      (.78, .66, .32, Color(0xFF7B1FA2)),
      (.95, .18, .22, Color(0xFFFFFFFF)),
    ];
    for (final (x, y, r, color) in blobs) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * y),
        size.shortestSide * r,
        Paint()..color = color.withValues(alpha: .85),
      );
    }
    // 一道窄高光和一块深色带，给折射和模糊留出可辨认的边界。
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .46, size.width, size.height * .06),
      Paint()..color = Colors.white.withValues(alpha: .9),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .82, size.width, size.height * .18),
      Paint()..color = Colors.black.withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(_GlassWallpaper oldDelegate) => false;
}

// Search remains an example, matching the upstream module boundary.
class _GlassSearchExample extends StatefulWidget {
  const _GlassSearchExample({required this.visible, required this.onDismiss});
  final bool visible;
  final VoidCallback onDismiss;
  @override
  State<_GlassSearchExample> createState() => _GlassSearchExampleState();
}

class _GlassSearchExampleState extends State<_GlassSearchExample>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  final _focus = FocusNode();
  final _query = TextEditingController();
  @override
  void didUpdateWidget(_GlassSearchExample oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _query.clear();
      _animation.forward();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.visible) _focus.requestFocus();
      });
    } else {
      _focus.unfocus();
      _animation.reverse();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _focus.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.visible,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) widget.onDismiss();
    },
    child: AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        if (!widget.visible && _animation.value == 0) {
          return const SizedBox.shrink();
        }
        final c = MiuixTheme.of(context).colors,
            p = const _SearchSpringCurve()
                .transform(_animation.value)
                .clamp(0.0, 1.0);
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: !widget.visible,
            child: Opacity(
              opacity: p,
              child: Material(
                color: c.surface,
                child: SafeArea(
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape):
                          widget.onDismiss,
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Transform.translate(
                            offset: Offset(0, 32 * (1 - p)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _query,
                                    focusNode: _focus,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      hintText: '搜索 OS4 图标',
                                      filled: true,
                                      fillColor: c.surfaceContainer,
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: MiuixIcon(
                                          vector: MiuixIcons.os4.search,
                                        ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: widget.onDismiss,
                                  child: const Text('取消'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: GridView.count(
                              crossAxisCount: 4,
                              children: [
                                for (final name in MiuixIcons.os4.names.where(
                                  (n) => n.toLowerCase().contains(
                                    _query.text.toLowerCase(),
                                  ),
                                ))
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      MiuixIcon(
                                        vector: MiuixIcons.os4.byName(name)!,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: c.onSurface,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _SearchSpringCurve extends Curve {
  const _SearchSpringCurve();
  @override
  double transformInternal(double t) {
    final omega = 2 * math.pi / .75,
        decay = -.98 * omega,
        frequency = omega * math.sqrt(1 - .98 * .98);
    return 1 +
        math.exp(decay * t) *
            (-math.cos(frequency * t) +
                (decay / frequency) * math.sin(frequency * t));
  }
}
