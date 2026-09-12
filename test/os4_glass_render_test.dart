import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_miuix/miuix.dart';
// Exercise the shipped example without a circular dev dependency on its package.
// ignore: avoid_relative_lib_imports
import '../example/lib/showcase/os4.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await MiuixGlassRendering.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    const font = String.fromEnvironment('MIUIX_QA_FONT');
    if (font.isNotEmpty) {
      final bytes = await File(font).readAsBytes();
      await (FontLoader(
        'Os4QA',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  testWidgets('真实 backdrop 可绘制折射、材质层与更新后的背景', (tester) async {
    final backdrop = MiuixLayerBackdrop(), key = GlobalKey();
    Color background = Colors.blue;
    late StateSetter update;
    await tester.pumpWidget(
      MiuixTheme(
        data: MiuixThemeData.light(),
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Center(
                  child: RepaintBoundary(
                    key: key,
                    child: SizedBox(
                      width: 320,
                      height: 220,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: MiuixLayerBackdropCapture(
                              backdrop: backdrop,
                              child: ColoredBox(color: background),
                            ),
                          ),
                          Positioned(
                            left: 40,
                            top: 50,
                            width: 110,
                            height: 110,
                            child: MiuixGlassPanel(
                              backdrop: backdrop,
                              style: MiuixGlassStyles.commonSmallThin,
                              stroke: MiuixGlassStrokes.middleLight,
                              child: const SizedBox.expand(),
                            ),
                          ),
                          Positioned(
                            left: 170,
                            top: 50,
                            width: 110,
                            height: 110,
                            child: MiuixGlassPanel(
                              backdrop: backdrop,
                              shading: false,
                              material: MiuixGlassMaterials.puredThinGlassLight,
                              stroke: MiuixGlassStrokes.middleLight,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(backdrop.snapshot, isNotNull);
    Future<Uint8List> pixels() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      if (const bool.fromEnvironment('MIUIX_WRITE_QA')) {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/os4_qa').create(recursive: true);
        await File(
          'build/os4_qa/debug_material.png',
        ).writeAsBytes(png!.buffer.asUint8List());
      }
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    }

    final first = (await tester.runAsync(pixels))!;
    final center = (100 * 320 + 220) * 4;
    expect(
      first[center] + first[center + 1] + first[center + 2],
      greaterThan(0),
    );
    expect(
      first.sublist(center, center + 3),
      isNot([255, 255, 255]),
      reason: 'Must sample the blue backdrop, not solid fallback',
    );
    update(() => background = Colors.red);
    await tester.pumpAndSettle();
    final second = (await tester.runAsync(pixels))!;
    expect(
      second.sublist(center, center + 3),
      isNot(first.sublist(center, center + 3)),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    backdrop.dispose();
  });
  for (final dark in [false, true]) {
    testWidgets('OS4 展示页真实渲染与菜单交互：dark=$dark', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MiuixTheme(
          data: dark ? MiuixThemeData.dark() : MiuixThemeData.light(),
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
                fontFamily: 'Os4QA',
              ),
              home: const Os4Showcase(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Future<void> capture(String name) async {
        if (!const bool.fromEnvironment('MIUIX_WRITE_QA')) return;
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await Directory('build/os4_qa').create(recursive: true);
        await File(
          'build/os4_qa/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      }

      await tester.runAsync(() => capture(dark ? 'dark' : 'light'));
      await tester.tap(find.byTooltip('变形菜单'));
      await tester.pumpAndSettle();
      expect(find.text('更多选项'), findsOneWidget);
      await tester.tap(find.text('更多选项'));
      await tester.pumpAndSettle();
      expect(find.text('返回上级'), findsOneWidget);
      await tester.runAsync(() => capture(dark ? 'dark_menu' : 'light_menu'));
      await tester.tap(find.text('返回上级'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'search');
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
