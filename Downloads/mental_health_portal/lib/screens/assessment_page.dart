import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/scoring.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import '../widgets/questionnaire.dart';

class AssessmentPage extends StatefulWidget {
  final DbRecord? draft;
  const AssessmentPage({super.key, this.draft});
  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  late final String id;
  late List<int?> phq, gad;
  int? phqDifficulty, gadDifficulty;
  List<String> phqQuestions = [], gadQuestions = [];
  bool concern = false,
      safetyLatched = false,
      busy = false,
      loading = true,
      dirty = false;
  int queued = 0;
  String? error, receipt;
  String saved = 'Your responses will save as a draft when you answer.';
  Timer? debounce;
  Future<void> pending = Future<void>.value();
  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    id = draft?['id'] as String? ?? const Uuid().v4();
    phq = draft == null
        ? List<int?>.filled(9, null)
        : List<int?>.from(draft['phq']);
    gad = draft == null
        ? List<int?>.filled(7, null)
        : List<int?>.from(draft['gad']);
    phqDifficulty = draft?['phq_difficulty'] as int?;
    gadDifficulty = draft?['gad_difficulty'] as int?;
    concern = draft?['other_concern'] == true;
    safetyLatched = draft?['safety_flag'] == true;
    load();
  }

  Future<void> load() async {
    try {
      final rows = await Api.questions();
      final p = List<String>.from(
        rows.firstWhere((r) => r['code'] == 'PHQ9')['questions'],
      );
      final g = List<String>.from(
        rows.firstWhere((r) => r['code'] == 'GAD7')['questions'],
      );
      if (p.length != 9 || g.length != 7)
        throw StateError('Invalid questionnaire definitions');
      if (mounted)
        setState(() {
          phqQuestions = p;
          gadQuestions = g;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Questionnaires could not load. Check the v2 seed file and connection.',
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  DbRecord payload(bool submit) => {
    'p_id': id,
    'p_phq': List<int?>.from(phq),
    'p_gad': List<int?>.from(gad),
    'p_phq_difficulty': phqDifficulty,
    'p_gad_difficulty': gadDifficulty,
    'p_other_concern': concern,
    'p_submit': submit,
  };
  void changed({bool immediate = false}) {
    dirty = true;
    if ((phq[8] ?? 0) > 0 || concern) safetyLatched = true;
    debounce?.cancel();
    if (immediate) {
      save();
    } else {
      debounce = Timer(const Duration(milliseconds: 450), () {
        save();
      });
    }
  }

  Future<DbRecord?> save({bool submit = false}) {
    final data = payload(submit);
    queued++;
    if (mounted) setState(() => saved = 'Saving draft…');
    // Serialize snapshots so a slow earlier write cannot overwrite newer answers.
    final request = pending.then((_) => Api.saveAssessment(data));
    pending = request.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return request.then<DbRecord?>(
      (response) {
        queued--;
        if (mounted)
          setState(() {
            dirty = queued > 0 || (debounce?.isActive ?? false);
            saved = queued > 0 ? 'Saving draft…' : 'Saved securely';
            error = null;
          });
        return response;
      },
      onError: (Object _, StackTrace __) {
        queued--;
        if (mounted)
          setState(() {
            dirty = true;
            saved = 'Not saved';
            error = 'Saving failed. Check your connection and press Save draft or Submit to retry.';
          });
        return null;
      },
    );
  }

  Future<void> submit() async {
    debounce?.cancel();
    if (score(phq, 9) == null ||
        score(gad, 7) == null ||
        phqDifficulty == null ||
        gadDifficulty == null) {
      await save();
      if (mounted)
        setState(
          () => error = 'Answer all 16 questions and both difficulty questions. Missing answers are not zero.',
        );
      return;
    }
    setState(() => busy = true);
    final result = await save(submit: true);
    if (mounted)
      setState(() {
        busy = false;
        if (result != null) receipt = pathwayLabel(result['pathway'] as String);
      });
  }

  Future<bool> leave() async {
    debounce?.cancel();
    if (receipt != null || !dirty && queued == 0) return true;
    final result = await save();
    return result != null;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: receipt != null || (!dirty && queued == 0),
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      if (await leave() && mounted) {
        setState(() {
          dirty = false;
          queued = 0;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Shell(
      title: receipt == null ? 'Your two-week check-in' : 'Check-in saved',
      children: [
        if (receipt != null) ...[
          Notice(
            'Current recommendation: $receipt. Your care team must assess your needs. Contact the institution for appointment and response arrangements.',
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Return to dashboard'),
          ),
        ] else ...[
          const Notice(
            'Drafts save to your account as you answer. Saved safety concerns create a review request even before submission. '
            'Changing an answer later does not cancel an existing safety review.',
          ),
          Text(saved),
          if (queued > 0) const LinearProgressIndicator(),
          if (error != null) Notice(error!, urgent: true),
          if (loading) const Busy(),
          if (!loading && phqQuestions.isEmpty)
            FilledButton(
              onPressed: () {
                setState(() {
                  loading = true;
                  error = null;
                });
                load();
              },
              child: const Text('Retry'),
            ),
          if (phqQuestions.isNotEmpty) ...[
            Questionnaire(
              title: 'PHQ-9',
              questions: phqQuestions,
              answers: phq,
              difficulty: phqDifficulty,
              disabled: busy,
              onAnswer: (i, v) => setState(() {
                phq[i] = v;
                changed(immediate: i == 8 && v > 0);
              }),
              onDifficulty: (v) => setState(() {
                phqDifficulty = v;
                changed();
              }),
            ),
            Questionnaire(
              title: 'GAD-7',
              questions: gadQuestions,
              answers: gad,
              difficulty: gadDifficulty,
              disabled: busy,
              onAnswer: (i, v) => setState(() {
                gad[i] = v;
                changed();
              }),
              onDifficulty: (v) => setState(() {
                gadDifficulty = v;
                changed();
              }),
            ),
            CheckboxListTile(
              value: concern,
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      concern = v ?? false;
                      changed(immediate: concern);
                    }),
              title: const Text(
                'I have another safety concern I would like a professional to assess.',
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () {
                          debounce?.cancel();
                          save();
                        },
                  child: const Text('Save draft'),
                ),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy ? 'Submitting…' : 'Submit check-in'),
                ),
              ],
            ),
          ],
        ],
        if (safetyLatched)
          const Notice(
            'A safety concern has been indicated. Do not wait for the form to save or a professional to open the dashboard if you need immediate help.',
            urgent: true,
          ),
        const Notice(supportText),
      ],
    ),
  );
}
