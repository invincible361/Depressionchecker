import 'package:flutter/material.dart';

import '../core/scoring.dart';

class Questionnaire extends StatelessWidget {
  final String title;
  final List<String> questions;
  final List<int?> answers;
  final int? difficulty;
  final bool disabled;
  final void Function(int, int) onAnswer;
  final ValueChanged<int> onDifficulty;
  const Questionnaire({
    super.key,
    required this.title,
    required this.questions,
    required this.answers,
    required this.difficulty,
    required this.onAnswer,
    required this.onDifficulty,
    this.disabled = false,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 23),
      ),
      const Text(
        'Over the last 2 weeks, how often have you been bothered by the following problems?',
      ),
      for (var i = 0; i < questions.length; i++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ${questions[i]}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var j = 0; j < 4; j++)
                      ChoiceChip(
                        label: Text(responseLabels[j]),
                        selected: answers[i] == j,
                        onSelected: disabled ? null : (_) => onAnswer(i, j),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      const Text(
        'If you checked any problems, how difficult have these made it to do your work, take care of things at home, or get along with others? If none, choose Not difficult at all.',
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var j = 0; j < 4; j++)
            ChoiceChip(
              label: Text(difficultyLabels[j]),
              selected: difficulty == j,
              onSelected: disabled ? null : (_) => onDifficulty(j),
            ),
        ],
      ),
      const SizedBox(height: 24),
    ],
  );
}
