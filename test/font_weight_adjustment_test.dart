import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_miuix/miuix.dart';

void main() {
  test('adjustFontWeight clamps and shifts a role weight', () {
    expect(adjustFontWeight(FontWeight.w400, 200), FontWeight.w600);
    expect(adjustFontWeight(FontWeight.w700, 300), FontWeight.w900);
    expect(adjustFontWeight(FontWeight.w100, -200), FontWeight.w100);
  });

  testWidgets('MiuixText applies the theme adjustment to explicit weight', (
    tester,
  ) async {
    await tester.pumpWidget(
      MiuixTheme(
        data: MiuixThemeData.light(fontWeightAdjustment: 200),
        child: const MaterialApp(home: MiuixText('Adjusted')),
      ),
    );

    final text = tester.widget<Text>(find.text('Adjusted'));
    expect(text.style?.fontWeight, isNull);

    await tester.pumpWidget(
      MiuixTheme(
        data: MiuixThemeData.light(fontWeightAdjustment: 200),
        child: const MaterialApp(
          home: MiuixText('Adjusted', fontWeight: FontWeight.w400),
        ),
      ),
    );

    final adjusted = tester.widget<Text>(find.text('Adjusted'));
    expect(adjusted.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('BasicComponent exposes an overridable title weight', (
    tester,
  ) async {
    await tester.pumpWidget(
      MiuixTheme(
        data: MiuixThemeData.light(fontWeightAdjustment: 100),
        child: const MaterialApp(
          home: MiuixBasicComponent(
            title: 'Title',
            titleFontWeight: FontWeight.w400,
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Title'));
    expect(title.style?.fontWeight, FontWeight.w500);
  });
}
