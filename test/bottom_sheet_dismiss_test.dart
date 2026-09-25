// 回归测试：MiuixOverlayBottomSheet 关闭后必须真正移除遮罩层。
//
// 历史 bug：退出动画用 AnimationController.animateWith(SpringSimulation)，
// 弹簧收敛到 0 时状态是 completed 而非 dismissed，导致监听 dismissed 的收尾
// 逻辑永不触发，_popupController.dismiss() 不被调用，全屏 opaque 遮罩层残留
// 并吞掉所有点击 —— 表现为"点开底部弹窗后整页卡死、无法返回"。
//
// 本测试验证：show 置 false 并动画结束后，弹窗内容被移除，且底层内容可再次点击。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_miuix/miuix.dart';

void main() {
  testWidgets('OverlayBottomSheet 关闭后移除遮罩，底层重新可点击', (tester) async {
    var showSheet = false;
    var backgroundTaps = 0;

    await tester.pumpWidget(
      MiuixSystemTheme(
        child: Builder(
          builder: (context) {
            final theme = MiuixTheme.of(context);
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(brightness: theme.brightness),
              home: StatefulBuilder(
                builder: (context, setState) {
                  return MiuixScaffold(
                    content: (padding) => Stack(
                      children: [
                        // 底层的可点击区域：遮罩残留时它会被吞掉点击。
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => backgroundTaps++,
                            child: const SizedBox.expand(),
                          ),
                        ),
                        Center(
                          child: MiuixButton(
                            onPressed: () => setState(() => showSheet = true),
                            child: const Text('打开'),
                          ),
                        ),
                        MiuixOverlayBottomSheet(
                          show: showSheet,
                          title: '操作',
                          onDismissRequest: () =>
                              setState(() => showSheet = false),
                          content: MiuixButton(
                            onPressed: () => setState(() => showSheet = false),
                            child: const Text('确定'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    // 打开弹窗。
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('确定'), findsOneWidget, reason: '弹窗应已显示');

    // 点击弹窗内按钮触发关闭（对应用户"点击操作列表"的场景）。
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    // 关键断言 1：弹窗内容被移除（说明 dismiss() 确实被调用）。
    expect(find.text('确定'), findsNothing, reason: '关闭后弹窗内容应被移除');

    // 关键断言 2：底层区域重新可点击（说明残留遮罩已消失，页面未卡死）。
    await tester.tap(find.text('打开')); // 落在背景 GestureDetector 之上的按钮
    await tester.pumpAndSettle();
    // 再次能打开弹窗，进一步证明交互恢复正常。
    expect(find.text('确定'), findsOneWidget, reason: '关闭后应能再次打开，页面未卡死');
  });

  // 回归测试：WindowBottomSheet 的窗口层子树由 sourceContext 单独构建，参数变化后
  // 要显式标脏；但**父级 setState 触发的重建会走到 didUpdateWidget**，那里直接
  // markNeedsBuild 会被框架判为 "setState() or markNeedsBuild() called during
  // build"（Overlay 变体的 entry 为 null 所以从没暴露）。这里钉住 Window 变体。
  testWidgets('WindowBottomSheet：父级 setState 切换 show 不在构建期标脏', (tester) async {
    var showSheet = false;

    await tester.pumpWidget(
      MiuixSystemTheme(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MiuixButton(
                        onPressed: () => setState(() => showSheet = true),
                        child: const Text('打开'),
                      ),
                      MiuixWindowBottomSheet(
                        show: showSheet,
                        onDismissRequest: () =>
                            setState(() => showSheet = false),
                        content: MiuixButton(
                          onPressed: () => setState(() => showSheet = false),
                          child: const Text('确定'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('确定'), findsOneWidget, reason: '弹窗应已显示');
    expect(tester.takeException(), isNull, reason: '父级 setState 不该在构建期标脏');

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('确定'), findsNothing, reason: '关闭后窗口层应被移除');
    expect(tester.takeException(), isNull);
  });

  // 回归测试：**收起动画一开始**就得把输入还给底层，不能等弹簧数学收敛。
  //
  // 历史 bug：退出用弹簧模拟，蒙层与窗口层要等 TickerFuture 完成才移除；而弹簧
  // 收敛到容差 1e-4 需要很久 —— 实测面板约 320ms 就滑出屏幕，状态到约 832ms 才
  // 收尾。中间那 500ms 里全屏蒙层仍是最上层的 opaque 命中区，用户「关掉弹窗、
  // 马上点下一个」的第二下被静默吃掉（表现为"点了没反应，要等一会儿"）。
  testWidgets('WindowBottomSheet：收起动画期间底层立刻能点到', (tester) async {
    var showSheet = false, backgroundTaps = 0;

    await tester.pumpWidget(
      MiuixSystemTheme(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Stack(
                  children: [
                    // 底层可点区：收起动画进行中，它就该立刻重新收得到点击。
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => backgroundTaps++,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Center(
                      child: MiuixButton(
                        onPressed: () => setState(() => showSheet = true),
                        child: const Text('打开'),
                      ),
                    ),
                    MiuixWindowBottomSheet(
                      show: showSheet,
                      onDismissRequest: () =>
                          setState(() => showSheet = false),
                      content: MiuixButton(
                        onPressed: () => setState(() => showSheet = false),
                        child: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('确定'), findsOneWidget, reason: '弹窗应已显示');

    // 收起：这里**不用** pumpAndSettle —— 要的就是"动画还没走完"的那一帧。
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.text('确定'),
      findsOneWidget,
      reason: '退场动画还没走完，面板与蒙层都还在树上（只是不该再吃输入）',
    );

    // 屏幕上方那块空白（不在面板范围内）此时应该已经还给页面。
    await tester.tapAt(const Offset(200, 40));
    await tester.pump();
    expect(backgroundTaps, 1, reason: '一开始收起，底层就该立刻能点到');

    await tester.pumpAndSettle();
    expect(find.text('确定'), findsNothing, reason: '收完仍然要正常清场');
    expect(tester.takeException(), isNull);
  });

  // 回归测试：**往上拖把手，面板一位都不动**。
  //
  // 历史 bug：面板高度由内容决定（Column(mainAxisSize: min) 外面只套了 maxHeight
  // 的 ConstrainedBox），上面根本没有可展开的空间，可 onVerticalDragUpdate 在
  // `next < 0` 时给的是 0.1 阻尼而不是钳到 0 —— 面板于是以十分之一速度往上漂，
  // 底沿离开屏幕，下面露出一条压暗蒙层（真机口径「拉着杆子往上拉，拉上去下面变成
  // 空白」）。
  testWidgets('WindowBottomSheet：往上拖把手面板不离开屏幕底沿', (tester) async {
    var showSheet = false;
    var dismissRequests = 0;

    await tester.pumpWidget(
      MiuixSystemTheme(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Center(
                  child: MiuixButton(
                    onPressed: () => setState(() => showSheet = true),
                    child: const Text('打开'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    // 常驻的 WindowBottomSheet 自己往根覆盖层插条目（与本仓承载壳同一形态），
    // 所以它从一开始就在树里，`show` 只是翻开关。
    await tester.pumpWidget(
      MiuixSystemTheme(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Stack(
                  children: [
                    MiuixButton(
                      onPressed: () => setState(() => showSheet = true),
                      child: const Text('打开'),
                    ),
                    MiuixWindowBottomSheet(
                      show: showSheet,
                      onDismissRequest: () {
                        dismissRequests++;
                        setState(() => showSheet = false);
                      },
                      content: const SizedBox(
                        key: ValueKey('panel-content'),
                        width: 200,
                        height: 120,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byType(MiuixWindowBottomSheet), findsOneWidget);

    // 面板里那块内容：它的下沿原本就贴着屏幕底沿。
    final content = find.byKey(const ValueKey('panel-content'));
    expect(content, findsOneWidget);
    final resting = tester.getRect(content);
    expect(
      resting.bottom,
      moreOrLessEquals(
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
        epsilon: 0.5,
      ),
      reason: '前置条件：面板贴底，底沿 = 屏幕底沿',
    );

    // 把手是面板顶部那条 24dp 横条（无标题时下面还有 18dp 的空行）。
    final handle = Offset(resting.center.dx, resting.top - 30);
    final gesture = await tester.startGesture(handle);
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -220));
    await tester.pump();

    expect(
      tester.getRect(content).bottom,
      moreOrLessEquals(resting.bottom, epsilon: 0.5),
      reason: '面板底沿必须一直贴着屏幕底沿，往上拖不许把它抬起来',
    );
    expect(
      tester.getRect(content).top,
      moreOrLessEquals(resting.top, epsilon: 0.5),
      reason: '内容也不许跟着往上走',
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(dismissRequests, 0, reason: '往上拖不是「收起」手势');
    expect(content, findsOneWidget, reason: '面板必须还在');
    expect(tester.takeException(), isNull);
  });
}
