import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/questionnaire.dart';

void main() {
  testWidgets(
    'Question choices report index/value and unanswered stays unselected',
    (tester) async {
      int? selectedIndex, selectedValue, difficulty;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Questionnaire(
                title: 'Test',
                questions: const ['Question one'],
                answers: const [null],
                difficulty: null,
                onAnswer: (i, v) {
                  selectedIndex = i;
                  selectedValue = v;
                },
                onDifficulty: (v) => difficulty = v,
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .every((c) => !c.selected),
        true,
      );
      await tester.tap(find.text('Several days'));
      expect(selectedIndex, 0);
      expect(selectedValue, 1);
      await tester.ensureVisible(find.text('Somewhat difficult'));
      await tester.tap(find.text('Somewhat difficult'));
      expect(difficulty, 1);
    },
  );
}
