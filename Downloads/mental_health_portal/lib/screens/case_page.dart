import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/scoring.dart';
import '../core/format.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import '../widgets/charts.dart';

class CasePage extends StatefulWidget {
  final DbRecord patient;
  final String role;
  const CasePage({super.key, required this.patient, required this.role});
  @override
  State<CasePage> createState() => _CasePageState();
}

class _CasePageState extends State<CasePage> {
  late Future<List<List<DbRecord>>> future;
  final note = TextEditingController(),
      guidance = TextEditingController(),
      diagnosis = TextEditingController(),
      medication = TextEditingController();
  final reason = TextEditingController(),
      location = TextEditingController(),
      resolution = TextEditingController(),
      dispositionReason = TextEditingController();
  String? target, message;
  String disposition = 'counsellor';
  DateTime? appointment;
  bool busy = false;
  String get studentId => widget.patient['user_id'] as String;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    final next = Future.wait([
      Api.assessments(studentId),
      Api.read('mw_reviews', studentId: studentId),
      Api.read('mw_care_plans', studentId: studentId),
      Api.read('mw_referrals', studentId: studentId),
      Api.read('mw_appointments', studentId: studentId),
      Api.read('mw_alerts', studentId: studentId),
      Api.directory(),
      Api.questions(),
      Api.read('mw_audit', studentId: studentId),
      Api.read('mw_cases', studentId: studentId),
      Api.read('mw_notifications'),
    ]);
    setState(() {
      future = next;
    });
  }
  @override
  void dispose() {
    for (final c in [
      note,
      guidance,
      diagnosis,
      medication,
      reason,
      location,
      resolution,
      dispositionReason,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> perform(
    String function,
    DbRecord params, {
    VoidCallback? after,
  }) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await Api.action(function, params);
      if (mounted) {
        after?.call();
        setState(() => message = 'Saved.');
        refresh();
      }
    } catch (_) {
      if (mounted)
        setState(
          () => message = 'Action could not be completed. Check required fields, permissions and active safety alerts, then retry.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController c, String label, {int lines = 3}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: lines,
          decoration: InputDecoration(labelText: label),
        ),
      );
  Future<void> chooseTime() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time != null && mounted)
      setState(
        () => appointment = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ),
      );
  }

  Future<void> emergency() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record emergency pathway'),
        content: const Text(
          'This records your professional disposition. It does not contact emergency services. Initiate your institution’s emergency protocol directly and document your reason below before confirming.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Record disposition'),
          ),
        ],
      ),
    );
    if (yes == true && mounted)
      await perform('mw_disposition', {
        'p_student': studentId,
        'p_pathway': 'emergency',
        'p_reason': dispositionReason.text.trim(),
      });
  }

  @override
  Widget build(BuildContext context) => Shell(
    title: 'Case review',
    actions: [
      IconButton(
        tooltip: 'Refresh',
        onPressed: refresh,
        icon: const Icon(Icons.refresh),
      ),
    ],
    children: [
      // Revalidate membership before revealing even the profile passed from the previous screen.
      FutureBuilder<List<List<DbRecord>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Busy();
          if (snapshot.hasError || snapshot.data![9].isEmpty)
            return const Notice(
              'Case unavailable. Your assignment or session may have changed.',
              urgent: true,
            );
          final data = snapshot.data!;
          final assessments = data[0],
              reviews = data[1],
              plans = data[2],
              referrals = data[3],
              appointments = data[4],
              alerts = data[5],
              staff = data[6],
              questions = data[7],
              audit = data[8];
          reviews.sort(
            (a, b) => (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            ),
          );
          final psychologists = staff
              .where((staffMember) => staffMember['role'] == 'psychologist')
              .toList();
          final pQuestions = List<String>.from(
            questions.firstWhere((q) => q['code'] == 'PHQ9')['questions'],
          );
          final gQuestions = List<String>.from(
            questions.firstWhere((q) => q['code'] == 'GAD7')['questions'],
          );
          String staffName(dynamic id) {
            final names = staff.where((s) => s['user_id'] == id);
            return names.isEmpty
                ? 'Unassigned or inactive'
                : names.first['display_name'] as String;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.patient['name'] as String,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Age ${widget.patient['age']} · ${widget.patient['email']} · ${widget.patient['contact']}',
              ),
              Notice(
                'Pathway: ${pathwayLabel(data[9].first['pathway'] as String)} · ${data[9].first['status']}',
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Notice(message!),
                ),
              if (busy) const LinearProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Safety review requests',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              if (alerts.isEmpty)
                const Text(
                  'No saved safety review requests. Absence of a flag does not rule out risk.',
                ),
              for (final a in alerts)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${a['status']} · reviewer: ${staffName(a['reviewer_id'])}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Created ${dateLabel(a['created_at'])} · acknowledgement due ${dateLabel(a['due_at'])}',
                        ),
                        if (a['acknowledged_at'] != null)
                          Text(
                            'Acknowledged ${dateLabel(a['acknowledged_at'])} by ${staffName(a['acknowledged_by'])}',
                          ),
                        if (a['resolution'] != null)
                          Text('Assessment outcome: ${a['resolution']}'),
                        for (final n in data[10].where(
                          (n) => n['alert_id'] == a['id'],
                        ))
                          Text(
                            'Notification ${n['kind']}: ${n['delivered_at'] != null
                                ? 'delivered or suppressed'
                                : (n['attempts'] as int) >= 20
                                ? 'delivery failed — manual action needed'
                                : 'pending'} · attempts ${n['attempts']}${n['last_error'] == null ? '' : ' · ${n['last_error']}'}',
                          ),
                        if (a['status'] != 'resolved') ...[
                          Wrap(
                            spacing: 10,
                            children: [
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => perform('mw_ack_alert', {
                                        'p_id': a['id'],
                                      }),
                                child: const Text('Acknowledge review'),
                              ),
                              FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => perform('mw_resolve_alert', {
                                        'p_id': a['id'],
                                        'p_resolution': resolution.text.trim(),
                                      }, after: resolution.clear),
                                child: const Text('Record outcome and resolve'),
                              ),
                            ],
                          ),
                          const Text(
                            'Enter the assessment outcome in the field below before resolving.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              field(
                resolution,
                'Safety assessment outcome and follow-up actions',
              ),
              const SizedBox(height: 16),
              HistoryChart(rows: assessments),
              for (final a in assessments.reversed)
                Card(
                  child: ExpansionTile(
                    title: Text(
                      '${a['submitted_at'] == null ? 'Draft' : 'Submitted'} · ${dateLabel(a['created_at'])}',
                    ),
                    subtitle: Text(
                      'PHQ-9: ${a['phq_score'] ?? 'Incomplete'} · ${phqSeverity(a['phq_score'] as int?)}'
                      '\nGAD-7: ${a['gad_score'] ?? 'Incomplete'} · ${gadSeverity(a['gad_score'] as int?)}',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Consent version ${widget.patient['consent_version']} · questionnaire ${a['questionnaire_version']} · rules ${a['rule_version']}',
                            ),
                            ResponseChart(
                              questions: pQuestions,
                              answers: List<int?>.from(a['phq']),
                            ),
                            Text(
                              'PHQ difficulty: ${a['phq_difficulty'] == null ? 'Unanswered' : difficultyLabels[a['phq_difficulty'] as int]}',
                            ),
                            const SizedBox(height: 18),
                            ResponseChart(
                              questions: gQuestions,
                              answers: List<int?>.from(a['gad']),
                            ),
                            Text(
                              'GAD difficulty: ${a['gad_difficulty'] == null ? 'Unanswered' : difficultyLabels[a['gad_difficulty'] as int]}',
                            ),
                            Text(
                              'Other safety concern: ${a['other_concern']} · safety flag retained: ${a['safety_flag']}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Record professional review',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              field(
                note,
                widget.role == 'counsellor'
                    ? 'Private counselling notes'
                    : 'Private psychological assessment and formulation',
              ),
              if (widget.role == 'psychologist') ...[
                field(diagnosis, 'Psychological formulation'),
                field(medication, 'Care plan considerations'),
              ],
              field(
                guidance,
                widget.role == 'counsellor'
                    ? 'Patient-visible guidance and counselling goals'
                    : 'Patient-visible psychological support plan and follow-up',
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => perform(
                        'mw_add_review',
                        {
                          'p_student': studentId,
                          'p_note': note.text.trim(),
                          'p_guidance': guidance.text.trim(),
                          'p_diagnosis': diagnosis.text.trim(),
                          'p_medication': medication.text.trim(),
                        },
                        after: () {
                          note.clear();
                          guidance.clear();
                          diagnosis.clear();
                          medication.clear();
                        },
                      ),
                child: const Text('Save review'),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Confidential clinical notes'),
                children: [
                  for (final r in reviews)
                    ListTile(
                      title: Text(r['private_note'] as String),
                      subtitle: Text(
                        '${staffName(r['author_id'])} · ${dateLabel(r['created_at'])}'
                        '${r['diagnosis'] == null ? '' : '\nDiagnosis: ${r['diagnosis']}'}${r['medication'] == null ? '' : '\nMedication: ${r['medication']}'}',
                      ),
                    ),
                ],
              ),
              ExpansionTile(
                title: const Text('Shared guidance history'),
                children: [
                  for (final r in plans)
                    ListTile(
                      title: Text(r['guidance'] as String),
                      subtitle: Text(dateLabel(r['created_at'])),
                    ),
                ],
              ),
              if (widget.role == 'counsellor') ...[
                const SizedBox(height: 20),
                const Text(
                  'Refer to a psychologist',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                if (psychologists.isEmpty)
                  const Notice(
                    'No active psychologist is available. Contact the service administrator.',
                  ),
                DropdownButtonFormField<String>(
                  value: psychologists.any((staffMember) =>
                          staffMember['user_id'] == target)
                      ? target
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Choose psychologist',
                  ),
                  isExpanded: true,
                  items: psychologists
                      .map(
                        (staffMember) => DropdownMenuItem<String>(
                          value: staffMember['user_id'] as String,
                          child: Text(staffMember['display_name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: busy ? null : (value) => setState(() => target = value),
                ),
                const SizedBox(height: 12),
                field(reason, 'Private referral reason'),
                FilledButton(
                  onPressed: busy || target == null
                      ? null
                      : () => perform('mw_refer', {
                            'p_student': studentId,
                            'p_to': target,
                            'p_reason': reason.text.trim(),
                          }, after: reason.clear),
                  child: const Text('Send referral'),
                ),
              ],
              ExpansionTile(
                title: const Text('Referral history'),
                children: [
                  for (final r in referrals)
                    ListTile(
                      title: Text(r['reason'] as String),
                      subtitle: Text(
                        'To ${staffName(r['to_id'])} · ${dateLabel(r['created_at'])}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Appointments',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              OutlinedButton(
                onPressed: busy ? null : chooseTime,
                child: Text(
                  appointment == null
                      ? 'Choose appointment time'
                      : dateLabel(appointment!.toUtc().toIso8601String()),
                ),
              ),
              field(location, 'Location or meeting instructions', lines: 2),
              FilledButton(
                onPressed: busy || appointment == null
                    ? null
                    : () => perform(
                        'mw_appointment',
                        {
                          'p_student': studentId,
                          'p_time': appointment!.toUtc().toIso8601String(),
                          'p_location': location.text.trim(),
                        },
                        after: () {
                          location.clear();
                          appointment = null;
                        },
                      ),
                child: const Text('Schedule appointment'),
              ),
              for (final a in appointments)
                Card(
                  child: ListTile(
                    title: Text(
                      '${dateLabel(a['starts_at'])} · ${a['status']}',
                    ),
                    subtitle: Text(
                      '${a['location']} · ${staffName(a['staff_id'])}',
                    ),
                    trailing: a['status'] != 'scheduled'
                        ? null
                        : PopupMenuButton<String>(
                            enabled: !busy,
                            onSelected: (v) => perform(
                              'mw_appointment_status',
                              {'p_id': a['id'], 'p_status': v},
                            ),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'completed',
                                child: Text('Mark completed'),
                              ),
                              PopupMenuItem(
                                value: 'cancelled',
                                child: Text('Cancel appointment'),
                              ),
                            ],
                          ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Professional disposition',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Resolve active safety requests before recording a routine pathway. Emergency disposition records your decision; contact emergency services directly when needed.',
              ),
              field(dispositionReason, 'Assessment and disposition reason'),
              DropdownButtonFormField<String>(
                value: disposition,
                decoration: const InputDecoration(labelText: 'Routine pathway'),
                items: const [
                  DropdownMenuItem(
                    value: 'resources',
                    child: Text('Resources'),
                  ),
                  DropdownMenuItem(
                    value: 'counsellor',
                    child: Text('Counsellor'),
                  ),
                  DropdownMenuItem(
                    value: 'psychologist',
                    child: Text('Psychologist'),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (v) => setState(() => disposition = v!),
              ),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => perform('mw_disposition', {
                            'p_student': studentId,
                            'p_pathway': disposition,
                            'p_reason': dispositionReason.text.trim(),
                          }, after: dispositionReason.clear),
                    child: const Text('Save routine disposition'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : emergency,
                    child: const Text('Record emergency pathway'),
                  ),
                ],
              ),
              ExpansionTile(
                title: const Text('Case audit history'),
                children: [
                  for (final a in audit)
                    ListTile(
                      title: Text(a['action'] as String),
                      subtitle: Text(dateLabel(a['created_at'])),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    ],
  );
}
