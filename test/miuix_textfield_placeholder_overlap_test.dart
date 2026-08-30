import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MiuixTheme(
  data: MiuixThemeData.light(),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('useLabelAsPlaceholder：输入后提示语隐藏，删光后恢复（回归：覆盖层残留叠加）', (
    tester,
  ) async {
    const label = '例如：主教学楼 / 其他教学楼';
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        MiuixTextField(
          controller: controller,
          label: label,
          useLabelAsPlaceholder: true,
          singleLine: true,
        ),
      ),
    );

    // 空文本 → 提示语作为占位显示。
    expect(find.text(label), findsOneWidget);

    // 输入首个字后覆盖层必须立即消失。修复前该切换不经过悬浮动画
    // （_onTextChanged 无动画 tick），AnimatedBuilder 不重建，
    // 提示语残留并与正文同位叠加。
    controller.text = '主教';
    await tester.pump();
    expect(find.text(label), findsNothing);
    expect(find.text('主教'), findsOneWidget);

    // 删光后提示语恢复。
    controller.clear();
    await tester.pump();
    expect(find.text(label), findsOneWidget);
  });

  testWidgets('默认悬浮模式：输入后标签仍在（悬浮态不受本次修复影响）', (tester) async {
    const label = '名称';
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        MiuixTextField(controller: controller, label: label, singleLine: true),
      ),
    );

    expect(find.text(label), findsOneWidget);

    controller.text = 'A';
    await tester.pumpAndSettle();
    // 悬浮模式标签常驻（悬浮在输入文字上方）。
    expect(find.text(label), findsOneWidget);
    expect(find.text('A'), findsOneWidget);

    controller.clear();
    await tester.pumpAndSettle();
    expect(find.text(label), findsOneWidget);
  });
}
