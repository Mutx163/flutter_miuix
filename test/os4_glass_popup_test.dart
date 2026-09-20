import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_miuix/src/theme/miuix/glass/internal/popup_presenter.dart';

Widget app(Widget child, {MediaQueryData? media}) => MiuixTheme(
  data: MiuixThemeData.light(),
  child: MaterialApp(
    builder: media == null
        ? null
        : (context, child) => MediaQuery(data: media, child: child!),
    home: Scaffold(body: child),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(MiuixGlassRendering.load);
  test('菜单终点、RTL 二级定位与物理像素拖拽上限', () {
    for (final kind in MiuixGlassPopupMotion.values) {
      final frame = miuixGlassPopupFrame(
        motion: kind,
        anchor: const Rect.fromLTWH(290, 450, 44, 44),
        end: const Size(200, 160),
        bounds: const Rect.fromLTWH(12, 24, 336, 400),
        progress: 1,
        positionProgress: 1,
      );
      expect(frame.rect.width, closeTo(200, .001));
      expect(frame.rect.height, closeTo(160, .001));
      expect(frame.rect.top, greaterThanOrEqualTo(24));
      expect(frame.rect.bottom, lessThanOrEqualTo(424));
    }
    final rtl = miuixGlassPopupFrame(
      motion: MiuixGlassPopupMotion.secondary,
      anchor: const Rect.fromLTWH(180, 90, 100, 44),
      end: const Size(200, 160),
      bounds: const Rect.fromLTWH(12, 24, 336, 600),
      progress: 1,
      positionProgress: 1,
      direction: TextDirection.rtl,
    );
    expect(rtl.rect.left, 80);
    final drag = miuixGlassNavigationDragTarget(
      left: 100,
      width: 60,
      containerWidth: 320,
      delta: 50,
      changedItem: false,
      devicePixelRatio: 3,
    );
    expect(drag.left, 80);
    expect(drag.right, 160);
    expect(drag.following, isTrue);
    expect(
      miuixGlassNavigationIndicatorBounds(-100, 500, 320, 3),
      const Offset(3, 317),
    );
    expect(
      MiuixGlassMotion.navIndicator.stiffness,
      closeTo(math.pow(2 * math.pi / .4, 2), 1e-8),
    );
    expect(() => MiuixGlassMotion.springOf(1, 0), throwsArgumentError);
  });
  testWidgets('变形弹窗快速反向、返回与卸载后恢复锚点', (tester) async {
    final anchor = MiuixGlassPopupAnchor();
    var show = false, mountedPopup = true;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: MiuixGlassIconButton(
                    anchor: anchor,
                    onPressed: () => setState(() => show = true),
                    child: const Icon(Icons.more_horiz),
                  ),
                ),
                const Center(child: Text('route-stays')),
                if (mountedPopup)
                  MiuixGlassTransformPopup(
                    show: show,
                    anchor: anchor,
                    anchorContent: const Icon(Icons.more_horiz),
                    onDismissRequest: () => setState(() => show = false),
                    child: MiuixGlassPopupItem(
                      text: 'Transform action',
                      onPressed: () => setState(() => show = false),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() => show = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    update(() => show = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    update(() => show = true);
    await tester.pumpAndSettle();
    expect(find.text('Transform action'), findsOneWidget);
    expect(anchor.contentHidden, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(show, isFalse);
    expect(anchor.contentHidden, isFalse);
    expect(find.text('route-stays'), findsOneWidget);
    update(() => show = true);
    await tester.pumpAndSettle();
    update(() => mountedPopup = false);
    await tester.pumpAndSettle();
    expect(anchor.contentHidden, isFalse);
    expect(find.text('Transform action'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    anchor.dispose();
  });
  testWidgets('预测性返回取消保留弹窗，完成只发出一次关闭请求', (tester) async {
    final anchor = MiuixGlassPopupAnchor();
    var show = false, dismissals = 0;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Stack(
              children: [
                MiuixGlassIconButton(
                  anchor: anchor,
                  onPressed: () {},
                  child: const Icon(Icons.more_horiz),
                ),
                MiuixGlassTransformPopup(
                  show: show,
                  anchor: anchor,
                  anchorContent: const Icon(Icons.more_horiz),
                  onDismissRequest: () {
                    dismissals++;
                    setState(() => show = false);
                  },
                  child: const Text('preview menu'),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() => show = true);
    await tester.pumpAndSettle();
    final observer =
        tester.state(find.byType(GlassPopupPresenter))
            as WidgetsBindingObserver;
    PredictiveBackEvent event(double progress) => PredictiveBackEvent.fromMap({
      'progress': progress,
      'swipeEdge': 0,
      'touchOffset': <Object?>[1.0, 100.0],
    });
    expect(observer.handleStartBackGesture(event(0)), isTrue);
    observer.handleUpdateBackGestureProgress(event(.7));
    await tester.pump();
    observer.handleCancelBackGesture();
    await tester.pumpAndSettle();
    expect(show, isTrue);
    expect(dismissals, 0);
    expect(observer.handleStartBackGesture(event(0)), isTrue);
    observer.handleUpdateBackGestureProgress(event(.8));
    await tester.pump();
    observer.handleCommitBackGesture();
    await tester.pumpAndSettle();
    expect(show, isFalse);
    expect(dismissals, 1);
    expect(anchor.contentHidden, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    anchor.dispose();
  });
  testWidgets('下拉菜单限制于安全区与键盘之上，超长内容可滚动', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const media = MediaQueryData(
      size: Size(360, 640),
      viewPadding: EdgeInsets.only(top: 24, bottom: 20),
      viewInsets: EdgeInsets.only(bottom: 300),
    );
    var show = true;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => MiuixGlassDropdownPopup(
            show: show,
            anchorBounds: const Rect.fromLTWH(290, 510, 44, 44),
            onDismissRequest: () => setState(() => show = false),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 30; i++)
                  MiuixGlassPopupItem(text: 'Choice $i', onPressed: () {}),
              ],
            ),
          ),
        ),
        media: media,
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(MiuixGlassPanel));
    expect(rect.left, greaterThanOrEqualTo(12));
    expect(rect.right, lessThanOrEqualTo(348));
    expect(rect.top, greaterThanOrEqualTo(36));
    expect(rect.bottom, lessThanOrEqualTo(328));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(show, isFalse);
  });
  testWidgets('禁用菜单项不响应，reduced motion 关闭不会残留遮罩', (tester) async {
    var show = false, taps = 0;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MiuixGlassDialog(
              visible: show,
              onDismissRequest: () => setState(() => show = false),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MiuixGlassPopupItem(
                    text: 'disabled',
                    enabled: false,
                    onPressed: () => taps++,
                  ),
                  TextButton(
                    onPressed: () => setState(() => show = false),
                    child: const Text('done'),
                  ),
                ],
              ),
            );
          },
        ),
        media: const MediaQueryData(disableAnimations: true),
      ),
    );
    update(() => show = true);
    await tester.pumpAndSettle();
    final panel = tester.widget<MiuixGlassPanel>(find.byType(MiuixGlassPanel));
    expect(panel.stroke, isNull);
    expect(panel.material, isNull);
    await tester.tap(find.text('disabled'));
    expect(taps, 0);
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    expect(find.text('done'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('旧级联图标菜单透传自定义表面且旧调用继续工作', (tester) async {
    var surfaces = 0, taps = 0;
    await tester.pumpWidget(
      MiuixSystemTheme(
        child: MaterialApp(
          home: MiuixScaffold(
            content: (_) => Center(
              child: MiuixOverlayIconCascadingDropdownMenu.entries(
                entries: [
                  MiuixDropdownEntry(
                    items: [
                      MiuixDropdownItem(
                        text: 'legacy action',
                        onClick: () => taps++,
                      ),
                    ],
                  ),
                ],
                surfaceBuilder: (context, shape, child) {
                  surfaces++;
                  return DecoratedBox(
                    decoration: ShapeDecoration(
                      color: Colors.pink,
                      shape: shape,
                    ),
                    child: child,
                  );
                },
                child: const Icon(Icons.more_horiz),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MiuixIconButton));
    await tester.pumpAndSettle();
    expect(surfaces, greaterThan(0));
    await tester.tap(find.text('legacy action'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('让位可只缩内容：面板轮廓原地不动，行仍朝支点退让', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final anchor = MiuixGlassPopupAnchor();
    var show = false, stacked = false, scalesPanel = true;
    late StateSetter update;
    const panelKey = ValueKey('panel');
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: MiuixGlassIconButton(
                    anchor: anchor,
                    onPressed: () {},
                    child: const Icon(Icons.more_horiz),
                  ),
                ),
                MiuixGlassTransformPopup(
                  show: show,
                  anchor: anchor,
                  anchorContent: const Icon(Icons.more_horiz),
                  // 宽度锁死 200（minWidth 与 maxWidth 同值）：面板轮廓与内容
                  // 同宽，让位时行贴面板左边缘，退让幅度可算（5% × 板宽）。
                  sizing: const MiuixGlassPopupSizing(maxWidth: 200),
                  stacked: stacked,
                  stackDuration: const Duration(milliseconds: 200),
                  stackShrinkFromAnchor: true,
                  stackScalesPanel: scalesPanel,
                  onDismissRequest: () {},
                  surfaceBuilder: (context, shape, child) => ColoredBox(
                    key: panelKey,
                    color: const Color(0xFF808080),
                    child: child,
                  ),
                  child: const SizedBox(
                    width: 200,
                    height: 240,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('row'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() => show = true);
    await tester.pumpAndSettle();
    final panelOpen = tester.getRect(find.byKey(panelKey));
    final rowOpen = tester.getRect(find.text('row'));
    // 入场弹簧收敛在 1 之前一点点（上游容差，实测板宽 199.97 而非 200），
    // 所以下面所有「5% 板宽」的期望值都从**实测板宽**推，不写死 10 / 12。
    expect(panelOpen.width, closeTo(200, .1));
    expect(rowOpen.left, closeTo(panelOpen.left, .01));

    // 上游原行为：面板跟着缩。支点是右上角，所以右边与上边不动，左边与下边收。
    update(() => stacked = true);
    await tester.pumpAndSettle();
    final panelShrunk = tester.getRect(find.byKey(panelKey));
    expect(panelShrunk.right, closeTo(panelOpen.right, .01));
    expect(panelShrunk.top, closeTo(panelOpen.top, .01));
    expect(
      panelShrunk.left - panelOpen.left,
      closeTo(panelOpen.width * .05, .01),
    );
    expect(
      panelOpen.bottom - panelShrunk.bottom,
      closeTo(panelOpen.height * .05, .01),
    );

    // 只缩内容：面板轮廓逐像素回到未让位时的位置，行仍朝支点退让 5% 板宽。
    update(() => scalesPanel = false);
    await tester.pumpAndSettle();
    final panelFixed = tester.getRect(find.byKey(panelKey));
    final rowFixed = tester.getRect(find.text('row'));
    expect(panelFixed.left, closeTo(panelOpen.left, .01));
    expect(panelFixed.top, closeTo(panelOpen.top, .01));
    expect(panelFixed.right, closeTo(panelOpen.right, .01));
    expect(panelFixed.bottom, closeTo(panelOpen.bottom, .01));
    expect(rowFixed.left - rowOpen.left, closeTo(panelOpen.width * .05, .01));
    expect(rowFixed.top, lessThan(rowOpen.top));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    anchor.dispose();
  });
  testWidgets('二级面板也能让位：支点由调用方给定时朝那个点缩', (tester) async {
    // 本 fork 补丁：上游只让一级参与让位，二级面板原地不动 —— 两块同宽同边的
    // 面板叠在一起时，缩过的那块左边缘比二级多退 5% 板宽，读起来「只有一半缩了」。
    // 这条钉的是二级也能被 `stacked` 驱动，且支点由 `stackPivotBounds` 说了算。
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var show = false, stacked = false;
    late StateSetter update;
    const panelKey = ValueKey('secondary-panel');
    // 锚点行（二级面板贴着它长出来）。支点取它的右上角 —— 实际用法里就是
    // 一级面板的右上角，两块面板因此绕**同一个点**缩。
    const anchorBounds = Rect.fromLTWH(100, 300, 200, 44);
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MiuixGlassSecondaryPopup(
              show: show,
              anchorBounds: anchorBounds,
              sizing: const MiuixGlassPopupSizing(maxWidth: 200),
              stacked: stacked,
              stackDuration: const Duration(milliseconds: 200),
              stackPivotBounds: Rect.fromLTWH(
                anchorBounds.right,
                anchorBounds.top,
                0,
                0,
              ),
              // 二级面板是浮在前面的亮面，不能再叠压暗（上游亮色主题的缺省
              // 遮罩是白罩，会把二级面板照亮）。
              maskColor: Colors.transparent,
              onDismissRequest: () {},
              surfaceBuilder: (context, shape, child) => ColoredBox(
                key: panelKey,
                color: const Color(0xFF808080),
                child: child,
              ),
              child: const SizedBox(
                width: 200,
                height: 240,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('row'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() => show = true);
    await tester.pumpAndSettle();
    final panelOpen = tester.getRect(find.byKey(panelKey));
    // 支点必须正好落在面板右上角，否则下面「右边与上边不动」就不成立。
    expect(panelOpen.right, closeTo(anchorBounds.right, 1));
    expect(panelOpen.top, closeTo(anchorBounds.top, 1));

    update(() => stacked = true);
    await tester.pumpAndSettle();
    final shrunk = tester.getRect(find.byKey(panelKey));
    expect(shrunk.right, closeTo(panelOpen.right, .5));
    expect(shrunk.top, closeTo(panelOpen.top, .5));
    expect(
      shrunk.left - panelOpen.left,
      closeTo(panelOpen.width * .05, .5),
      reason: '左边朝支点退 5% 板宽（与一级面板同一支点时，两块左边缘才对得齐）',
    );
    expect(
      panelOpen.bottom - shrunk.bottom,
      closeTo(panelOpen.height * .05, .5),
    );

    // 收起复原。
    update(() => stacked = false);
    await tester.pumpAndSettle();
    final restored = tester.getRect(find.byKey(panelKey));
    expect(restored.left, closeTo(panelOpen.left, .5));
    expect(restored.bottom, closeTo(panelOpen.bottom, .5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('出生即让位的弹层直接落在让位态，不会停在未让位', (tester) async {
    // `didUpdateWidget` 只在 `stacked` 变化时驱动让位进度，首次 build 不算变化。
    // 调用方按需挂载二级面板时（挂上那一刻让位已经成立），少了 initState 那一刀
    // 就会「传了 stacked 却没缩」—— 静默失效，看树也看不出来。
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const panelKey = ValueKey('born-stacked-panel');
    const anchorBounds = Rect.fromLTWH(100, 300, 200, 44);
    Widget build({required bool stacked}) => MiuixGlassSecondaryPopup(
      show: true,
      anchorBounds: anchorBounds,
      sizing: const MiuixGlassPopupSizing(maxWidth: 200),
      stacked: stacked,
      stackDuration: const Duration(milliseconds: 200),
      stackPivotBounds: Rect.fromLTWH(
        anchorBounds.right,
        anchorBounds.top,
        0,
        0,
      ),
      maskColor: Colors.transparent,
      onDismissRequest: () {},
      surfaceBuilder: (context, shape, child) =>
          ColoredBox(key: panelKey, color: const Color(0xFF808080), child: child),
      child: const SizedBox(width: 200, height: 240),
    );

    await tester.pumpWidget(app(build(stacked: false)));
    await tester.pumpAndSettle();
    final open = tester.getRect(find.byKey(panelKey));

    // 换一棵树挂载：这一次出生就带着 stacked。
    await tester.pumpWidget(app(build(stacked: true)));
    await tester.pumpAndSettle();
    final bornStacked = tester.getRect(find.byKey(panelKey));
    expect(
      bornStacked.left - open.left,
      closeTo(open.width * .05, .5),
      reason: '出生即 stacked 的弹层必须直接落在让位态',
    );
    expect(bornStacked.right, closeTo(open.right, .5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('让位只借视觉：stackLocksInput 为假时内容与返回键仍归自己', (tester) async {
    // `stacked` 在上游语义里是「本面板被压在下面（让位）」，顺手把输入也让出去是
    // 对的 —— 上面压着的那块接管了点击与返回键。
    //
    // 但浮在上面那块面板有时也要借让位变换（两块同宽同边、不一起缩就露接缝，
    // 见 MiuixGlassSecondaryPopup 的说明）。它要是连输入一起让出去，二级面板的
    // 行就全点不动了：点击落到遮罩上，读起来变成「点哪都只是收起二级」。
    // `stackLocksInput: false` 就是「只借视觉、输入还归自己」。
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const anchorBounds = Rect.fromLTWH(100, 300, 200, 44);
    var taps = 0, dismisses = 0;

    Future<void> mount({required bool locksInput}) async {
      taps = 0;
      dismisses = 0;
      await tester.pumpWidget(
        app(
          MiuixGlassSecondaryPopup(
            show: true,
            anchorBounds: anchorBounds,
            sizing: const MiuixGlassPopupSizing(maxWidth: 200),
            stacked: true,
            stackDuration: const Duration(milliseconds: 200),
            stackPivotBounds: Rect.fromLTWH(
              anchorBounds.right,
              anchorBounds.top,
              0,
              0,
            ),
            stackLocksInput: locksInput,
            maskColor: Colors.transparent,
            onDismissRequest: () => dismisses++,
            child: SizedBox(
              width: 200,
              height: 240,
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('row'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mount(locksInput: false);
    await tester.tap(find.text('row'));
    await tester.pump();
    expect(taps, 1, reason: '只借让位视觉的面板，内容必须照旧可点');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(dismisses, 1, reason: '返回键也必须还能关这一层');

    // 对照：上游原行为（默认 true）下，让位就是真的让出去 —— 内容不吃点击。
    await mount(locksInput: true);
    await tester.tap(find.text('row'), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0, reason: '默认让位连输入一起让出（上游原行为）');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('弹窗关闭期间不能通过键盘再次激活菜单项', (tester) async {
    var show = true, taps = 0;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            return MiuixGlassPopup(
              show: show,
              anchorBounds: const Rect.fromLTWH(200, 100, 44, 44),
              onDismissRequest: () => setState(() => show = false),
              child: MiuixGlassPopupItem(
                text: 'keyboard action',
                onPressed: () {
                  taps++;
                  setState(() => show = false);
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 16));
    expect(taps, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.text('keyboard action'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
