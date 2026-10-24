import 'package:flutter_test/flutter_test.dart';
import '../lib/core/scoring.dart';

void main() {
  test('Incomplete and invalid answers are never zero-filled', () {
    expect(score([0, 0, null, 0, 0, 0, 0, 0, 0], 9), isNull);
    expect(score([0, 0, 4, 0, 0, 0, 0, 0, 0], 9), isNull);
    expect(score([0, 0], 9), isNull);
    expect(score(List<int?>.filled(9, 0), 9), 0);
    expect(score(List<int?>.filled(9, 3), 9), 27);
    expect(score(List<int?>.filled(7, 3), 7), 21);
  });
  test('Severity boundaries', () {
    for (final e in {
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
      expect(phqSeverity(e.key), e.value);
    }
    for (final e in {
      0: 'Minimal',
      4: 'Minimal',
      5: 'Mild',
      9: 'Mild',
      10: 'Moderate',
      14: 'Moderate',
      15: 'Severe',
      21: 'Severe',
    }.entries) {
      expect(gadSeverity(e.key), e.value);
    }
  });
  test('Documented synthetic cases and safety overrides', () {
    expect(pathway(2, 1), 'resources');
    expect(pathway(14, 8), 'psychologist');
    expect(pathway(15, 7), 'psychiatrist');
    expect(pathway(2, 15), 'psychiatrist');
    expect(pathway(1, 0, safety: true), 'safety');
    expect(pathway(null, null, safety: true), 'safety');
    expect(pathway(null, 6), 'incomplete');
    expect(pathway(2, 1, override: true), 'psychiatrist');
    expect(pathway(1, 1, acute: true), 'emergency');
    expect(score([2, 2, 2, 1, 1, 1, 1, 0, 0], 9), 10);
    expect(score([2, 2, 2, 2, 1, 1, 0], 7), 10);
  });
}
