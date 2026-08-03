import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_miuix/miuix.dart';

void main() {
  group('adjustFontWeight', () {
    test('adjustment 0 preserves the original weight, including null', () {
      expect(adjustFontWeight(null, 0), isNull);
      expect(adjustFontWeight(FontWeight.w400, 0), FontWeight.w400);
      expect(adjustFontWeight(FontWeight.bold, 0), FontWeight.bold);
    });

    test('positive adjustment shifts each weight by one hundred', () {
      expect(adjustFontWeight(null, 100), FontWeight.w500);
      expect(adjustFontWeight(FontWeight.w400, 100), FontWeight.w500);
      expect(adjustFontWeight(FontWeight.w600, 100), FontWeight.w700);
      expect(adjustFontWeight(FontWeight.w700, 100), FontWeight.w800);
    });

    test('adjustment clamps to the supported font weight range', () {
      expect(adjustFontWeight(FontWeight.w900, 100), FontWeight.w900);
      expect(adjustFontWeight(FontWeight.w800, 300), FontWeight.w900);
      expect(adjustFontWeight(FontWeight.w200, -300), FontWeight.w100);
    });

    test('negative adjustment makes text lighter', () {
      expect(adjustFontWeight(FontWeight.w400, -100), FontWeight.w300);
    });

    test('TextStyle extension applies the adjustment to its own weight', () {
      expect(
        const TextStyle(
          fontWeight: FontWeight.w600,
        ).withMiuixWeight(100).fontWeight,
        FontWeight.w700,
      );
    });
  });

  group('MiuixText follows the theme adjustment', () {
    Future<FontWeight?> weightOf(
      WidgetTester tester,
      int adjustment, {
      FontWeight? explicit,
      TextStyle? style,
    }) async {
      await tester.pumpWidget(
        MiuixTheme(
          data: MiuixThemeData.light(fontWeightAdjustment: adjustment),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MiuixText('Adjusted', fontWeight: explicit, style: style),
          ),
        ),
      );
      return tester.widget<Text>(find.byType(Text)).style?.fontWeight;
    }

    testWidgets('adjustment 0 keeps an unspecified weight null', (
      tester,
    ) async {
      expect(await weightOf(tester, 0), isNull);
    });

    testWidgets('adjustment applies to an unspecified base weight', (
      tester,
    ) async {
      expect(await weightOf(tester, 100), FontWeight.w500);
    });

    testWidgets('adjustment applies to an explicit weight', (tester) async {
      expect(
        await weightOf(tester, 100, explicit: FontWeight.w600),
        FontWeight.w700,
      );
    });

    testWidgets('adjustment applies to a weight supplied by the base style', (
      tester,
    ) async {
      expect(
        await weightOf(
          tester,
          100,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        FontWeight.w700,
      );
    });
  });

  group('MiuixSystemTheme follows MediaQuery boldText', () {
    Future<int> adjustmentOf(
      WidgetTester tester, {
      bool boldText = false,
      int? explicit,
    }) async {
      late int adjustment;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(boldText: boldText),
          child: MiuixSystemTheme(
            fontWeightAdjustment: explicit,
            child: Builder(
              builder: (context) {
                adjustment = MiuixTheme.of(context).fontWeightAdjustment;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return adjustment;
    }

    testWidgets('boldText enabled adds one weight step', (tester) async {
      expect(await adjustmentOf(tester, boldText: true), 100);
    });

    testWidgets('boldText disabled leaves the adjustment at zero', (
      tester,
    ) async {
      expect(await adjustmentOf(tester), 0);
    });

    testWidgets('explicit adjustment overrides boldText', (tester) async {
      expect(await adjustmentOf(tester, boldText: true, explicit: 0), 0);
    });
  });
}
