import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/scoring.dart';
import '../core/format.dart';
import '../services/api.dart';

class HistoryChart extends StatelessWidget {
  final List<DbRecord> rows;
  const HistoryChart({super.key, required this.rows});
  @override
  Widget build(BuildContext context) {
    final complete = rows.where((r) => r['submitted_at'] != null).toList()
      ..sort(
        (a, b) =>
            (a['created_at'] as String).compareTo(b['created_at'] as String),
      );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Score history',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Separate PHQ-9 and GAD-7 scales. Each row is a submitted assessment; drafts are excluded.',
            ),
            if (complete.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('No submitted assessments yet.'),
              ),
            for (final row in complete) ...[
              const SizedBox(height: 16),
              Text(dateLabel(row['submitted_at'])),
              _bar('PHQ-9', row['phq_score'] as int, 27, brand),
              _bar('GAD-7', row['gad_score'] as int, 21, Colors.indigo),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bar(String label, int value, int max, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 100, child: Text('$label $value/$max')),
        Expanded(
          child: LinearProgressIndicator(
            value: value / max,
            color: color,
            minHeight: 10,
          ),
        ),
      ],
    ),
  );
}

class ResponseChart extends StatelessWidget {
  final List<String> questions;
  final List<int?> answers;
  const ResponseChart({
    super.key,
    required this.questions,
    required this.answers,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < questions.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${i + 1}. ${questions[i]}'),
              Text(
                answers[i] == null
                    ? 'Unanswered'
                    : '${answers[i]} · ${responseLabels[answers[i]!]}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (answers[i] != null)
                LinearProgressIndicator(value: answers[i]! / 3, minHeight: 7),
            ],
          ),
        ),
    ],
  );
}

class Distribution extends StatelessWidget {
  final List<DbRecord> rows;
  final bool phq;
  const Distribution({super.key, required this.rows, required this.phq});
  @override
  Widget build(BuildContext context) {
    final classify = phq ? phqSeverity : gadSeverity;
    final key = phq ? 'phq_score' : 'gad_score';
    final values = rows
        .where((r) => r['submitted_at'] != null && r[key] != null)
        .toList();
    final labels = phq
        ? ['Minimal', 'Mild', 'Moderate', 'Moderately severe', 'Severe']
        : ['Minimal', 'Mild', 'Moderate', 'Severe'];
    return SizedBox(
      width: 480,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${phq ? 'PHQ-9' : 'GAD-7'} severity distribution',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Text('Latest submitted assessment per assigned patient'),
              for (final label in labels) ...[
                const SizedBox(height: 12),
                Text(
                  '$label · ${values.where((r) => classify(r[key] as int) == label).length}',
                ),
                LinearProgressIndicator(
                  value: values.isEmpty
                      ? 0
                      : values
                                .where((r) => classify(r[key] as int) == label)
                                .length /
                            values.length,
                  minHeight: 10,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
