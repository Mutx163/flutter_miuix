import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledInput extends StatefulWidget {
  const _ControlledInput();

  @override
  State<_ControlledInput> createState() => _ControlledInputState();
}

class _ControlledInputState extends State<_ControlledInput> {
  String _query = '';
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return MiuixTheme(
      data: MiuixThemeData.light(),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: MiuixInputField(
              query: _query,
              onQueryChange: (value) => setState(() => _query = value),
              onSearch: (_) {},
              expanded: _expanded,
              onExpandedChange: (value) => setState(() => _expanded = value),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'parent rebuilds during IME composing without replacing composing text',
    (tester) async {
      await tester.pumpWidget(const _ControlledInput());
      await tester.showKeyboard(find.byType(MiuixInputField));
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ji',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();

      final editableTextState = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(editableTextState.textEditingValue.text, 'ji');
      expect(
        editableTextState.textEditingValue.composing,
        const TextRange(start: 0, end: 2),
      );
    },
  );
}
