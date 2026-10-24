const responseLabels = [
  'Not at all',
  'Several days',
  'More than half the days',
  'Nearly every day',
];
const difficultyLabels = [
  'Not difficult at all',
  'Somewhat difficult',
  'Very difficult',
  'Extremely difficult',
];
int? score(List<int?> answers, int expected) {
  if (answers.length != expected ||
      answers.any((v) => v == null || v < 0 || v > 3))
    return null;
  return answers.fold<int>(0, (sum, value) => sum + value!);
}

String phqSeverity(int? value) {
  if (value == null) return 'Incomplete';
  if (value < 5) return 'Minimal';
  if (value < 10) return 'Mild';
  if (value < 15) return 'Moderate';
  if (value < 20) return 'Moderately severe';
  return 'Severe';
}

String gadSeverity(int? value) {
  if (value == null) return 'Incomplete';
  if (value < 5) return 'Minimal';
  if (value < 10) return 'Mild';
  if (value < 15) return 'Moderate';
  return 'Severe';
}

String pathway(
  int? p,
  int? g, {
  bool safety = false,
  bool acute = false,
  bool override = false,
}) {
  if (acute) return 'emergency';
  if (safety) return 'safety';
  if (p == null || g == null) return 'incomplete';
  if (override || p >= 15 || g >= 15) return 'psychologist';
  if (p >= 5 || g >= 5) return 'counsellor';
  return 'resources';
}
