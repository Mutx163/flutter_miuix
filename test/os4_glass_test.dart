import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_miuix/miuix.dart';

Widget app(Widget child) => MiuixSystemTheme(
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await MiuixGlassRendering.load();
  });
  test('OS4 保留 35 组 token 与 176 个五字重图标', () {
    expect(MiuixGlassStyles.values.length, 35);
    expect(MiuixIcons.os4.names.length, 176);
    for (final name in MiuixIcons.os4.names) {
      for (final weight in MiuixIconWeight.values) {
        final icon = MiuixIcons.os4.byName(name, weight)!;
        expect(icon.paths, isNotEmpty);
        final metrics = icon.paths.single.build().computeMetrics().toList();
        expect(metrics, isNotEmpty, reason: '$name / $weight');
        expect(
          metrics.every((m) => m.isClosed),
          isTrue,
          reason: '$name / $weight',
        );
      }
    }
    expect(MiuixIcons.os4.chevronBackward.autoMirror, isTrue);
    expect(MiuixIcons.os4.search.autoMirror, isFalse);
  });
  testWidgets('捕获子树不重绘时 backdrop 坐标仍跟随布局变化', (tester) async {
    // 捕获节点是重绘边界：内容不变时它被移动只会更新图层变换，不会再 paint。
    // 坐标必须在读取时算，否则消费者会按旧原点采样快照（表面被切成一半有背景、一半全透）。
    final backdrop = MiuixLayerBackdrop();
    addTearDown(backdrop.dispose);
    var top = 0.0;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  top: top,
                  width: 200,
                  height: 100,
                  child: MiuixLayerBackdropCapture(
                    backdrop: backdrop,
                    child: const ColoredBox(color: Color(0xFF2196F3)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = backdrop.globalOffset;
    final snapshot = backdrop.snapshot;
    expect(before, isNotNull);
    update(() => top = 120);
    await tester.pumpAndSettle();
    expect(
      identical(backdrop.snapshot, snapshot),
      isTrue,
      reason: '前提：内容没变，捕获子树不应重绘，快照仍是旧的',
    );
    expect(backdrop.globalOffset!.dy - before!.dy, 120);
  });
  testWidgets('独立标签、连体标签和图标按钮可交互', (tester) async {
    var selected = 0, taps = 0;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => Center(
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MiuixGlassTabRow(
                    tabs: const ['A', 'B'],
                    selectedIndex: selected,
                    onSelect: (i) => setState(() => selected = i),
                  ),
                  MiuixGlassSegmentedTabRow(
                    tabs: const ['C', 'D'],
                    selectedIndex: selected,
                    onSelect: (i) => setState(() => selected = i),
                  ),
                  MiuixGlassIconButton(
                    onPressed: () => taps++,
                    child: const Icon(Icons.search),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(selected, 0);
    await tester.tap(find.byType(MiuixGlassIconButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('玻璃导航允许拖拽、动态缩减项目与显隐', (tester) async {
    var selected = 0, visible = true;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Center(
              child: SizedBox(
                width: 320,
                child: MiuixGlassNavigationBar(
                  visible: visible,
                  items: const [
                    MiuixGlassNavigationItem(
                      icon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    MiuixGlassNavigationItem(
                      icon: Icon(Icons.settings),
                      label: 'Settings',
                    ),
                  ],
                  selectedIndex: selected,
                  onSelect: (i) => setState(() => selected = i),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(MiuixGlassNavigationBar));
    final gesture = await tester.startGesture(
      Offset(bar.left + 50, bar.center.dy),
    );
    await gesture.moveTo(Offset(bar.right - 50, bar.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, 1);
    update(() => visible = false);
    await tester.pumpAndSettle();
    update(() => visible = true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('普通弹窗关闭后恢复底层触摸，支持重复打开和 Escape', (tester) async {
    var show = false, taps = 0, actions = 0;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Stack(
              children: [
                Center(
                  child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('underneath'),
                  ),
                ),
                MiuixGlassPopup(
                  show: show,
                  onDismissRequest: () => setState(() => show = false),
                  anchorBounds: const Rect.fromLTWH(150, 100, 44, 44),
                  child: MiuixGlassPopupItem(
                    text: 'Action',
                    onPressed: () {
                      actions++;
                      setState(() => show = false);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    for (var i = 0; i < 2; i++) {
      update(() => show = true);
      await tester.pumpAndSettle();
      expect(find.text('Action'), findsOneWidget);
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      expect(find.text('Action'), findsNothing);
      await tester.tap(find.text('underneath'));
      await tester.pump();
    }
    expect(actions, 2);
    expect(taps, 2);
    update(() => show = true);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(show, isFalse);
    expect(find.text('Action'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
