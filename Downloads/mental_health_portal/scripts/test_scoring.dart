// Standalone scoring verification: dart --enable-asserts scripts/test_scoring.dart
import '../lib/core/scoring.dart';

void main() {
  var checks = 0;
  void check(bool value, String label) {
    if (!value) throw StateError('FAIL: $label');
    checks++;
  }

  for (final entry in {
    0: 'Minimal',
    4: 'Minimal',
    5: 'Mild',
    9: 'Mild',
    10: 'Moderate',
    14: 'Moderate',
    15: 'Moderately severe',
    19: 'Moderately severe',
    20: 'Severe',
    27: 'Severe',
  }.entries) {
    check(phqSeverity(entry.key) == entry.value, 'PHQ boundary ${entry.key}');
  }
  for (final entry in {
    0: 'Minimal',
    4: 'Minimal',
    5: 'Mild',
    9: 'Mild',
    10: 'Moderate',
    14: 'Moderate',
    15: 'Severe',
    21: 'Severe',
  }.entries) {
    check(gadSeverity(entry.key) == entry.value, 'GAD boundary ${entry.key}');
  }
  check(score([2, 2, 2, 1, 1, 1, 1, 0, 0], 9) == 10, 'PHQ worked calculation');
  check(score([2, 2, 2, 2, 1, 1, 0], 7) == 10, 'GAD worked calculation');
  check(score(List<int?>.filled(9, null), 9) == null, 'Missing not zero');
  check(score(List<int?>.filled(9, 4), 9) == null, 'Invalid answers');
  check(score(List<int?>.filled(8, 0), 9) == null, 'Length validation');
  check(pathway(2, 1) == 'resources', 'Minimal pathway');
  check(pathway(14, 8) == 'psychologist', 'Moderate pathway');
  check(pathway(15, 7) == 'psychiatrist', 'PHQ threshold');
  check(pathway(2, 15) == 'psychiatrist', 'GAD threshold');
  check(pathway(1, 0, safety: true) == 'safety', 'Safety override');
  check(
    pathway(null, null, safety: true) == 'safety',
    'Incomplete safety override',
  );
  check(pathway(null, 6) == 'incomplete', 'Incomplete pathway');
  check(
    pathway(2, 1, override: true) == 'psychiatrist',
    'Professional override',
  );
  check(
    pathway(1, 1, acute: true) == 'emergency',
    'Assessed acute danger override',
  );
  print('PASS: $checks scoring and referral checks');
}
