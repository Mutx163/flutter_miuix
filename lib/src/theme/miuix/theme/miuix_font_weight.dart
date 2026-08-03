// Miuix Flutter 移植版 - 系统字重适配
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

import 'miuix_text_styles.dart';

/// Android 无障碍“粗体文本”对应的字重增量。
const int kMiuixBoldTextFontWeightDelta = 300;

TextStyle _applyTextStyleDelta(TextStyle style, int delta) =>
    style.withMiuixWeight(delta);

/// 将系统字重增量应用到整套 Miuix 语义文本样式。
MiuixTextStyles applyFontWeightDelta(MiuixTextStyles styles, int delta) {
  if (delta == 0) {
    return styles;
  }
  return styles.copy(
    main: _applyTextStyleDelta(styles.main, delta),
    paragraph: _applyTextStyleDelta(styles.paragraph, delta),
    body1: _applyTextStyleDelta(styles.body1, delta),
    body2: _applyTextStyleDelta(styles.body2, delta),
    button: _applyTextStyleDelta(styles.button, delta),
    footnote1: _applyTextStyleDelta(styles.footnote1, delta),
    footnote2: _applyTextStyleDelta(styles.footnote2, delta),
    headline1: _applyTextStyleDelta(styles.headline1, delta),
    headline2: _applyTextStyleDelta(styles.headline2, delta),
    subtitle: _applyTextStyleDelta(styles.subtitle, delta),
    title1: _applyTextStyleDelta(styles.title1, delta),
    title2: _applyTextStyleDelta(styles.title2, delta),
    title3: _applyTextStyleDelta(styles.title3, delta),
    title4: _applyTextStyleDelta(styles.title4, delta),
  );
}
