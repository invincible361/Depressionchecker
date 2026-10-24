import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../services/api.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'case_page.dart';

class ProfessionalDashboard extends StatefulWidget {
  final String role;
  const ProfessionalDashboard({super.key, required this.role});

  @override
  State<ProfessionalDashboard> createState() => _ProfessionalDashboardState();
}

class _ProfessionalDashboardState extends State<ProfessionalDashboard> {
  late Future<List<List<DbRecord>>> future;
  String search = '';
  bool safetyOnly = false;
  bool busy = false;
  String? message;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    final next = Future.wait([
      Api.read('mw_cases'),
      Api.read('mw_profiles'),
      Api.read('mw_assessments'),
      Api.read('mw_alerts'),
      Api.queue(),
      widget.role == 'psychologist'
          ? Api.pendingStaffApplications()
          : Future.value(<DbRecord>[]),
    ]);
    setState(() => future = next);
  }

  Future<void> reviewApplicant(String id, {required bool approve}) async {
    var note = '';
    if (!approve) {
      final controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject professional request'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason to share with applicant',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Reject request'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (result == null) return;
      note = result;
      if (note.length < 3) {
        if (mounted) setState(() => message = 'Enter a short rejection reason.');
        return;
      }
    }

    setState(() {
      busy = true;
      message = null;
    });
    try {
      await Api.reviewStaffApplication(id: id, approve: approve, note: note);
      if (mounted) {
        setState(
          () => message = approve
              ? 'Professional account approved.'
              : 'Professional request rejected.',
        );
        refresh();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Could not review the request. Refresh and confirm it is still pending.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> claim(String id) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await Api.action('mw_claim', {'p_student': id});
      if (mounted) refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Case could not be claimed. It may already be assigned; refresh the queue.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(DbRecord profile) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CasePage(patient: profile, role: widget.role),
      ),
    );
    if (mounted) refresh();
  }

  String get roleTitle => widget.role == 'psychologist'
      ? 'Psychologist dashboard'
      : 'Counsellor dashboard';

  @override
  Widget build(BuildContext context) => Shell(
        title: roleTitle,
        actions: [
          const ChangePasswordButton(),
          IconButton(
            tooltip: 'Refresh',
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
          ),
          TextButton(
            onPressed: () async => db.auth.signOut(),
            child: const Text('Sign out'),
          ),
        ],
        children: [
          Notice(
            widget.role == 'counsellor'
                ? 'Review patients assigned to counselling, record counselling notes and shared guidance, and refer a patient to a psychologist when specialist review is needed.'
                : 'Review referred, high-severity and escalated cases; record psychological assessment and care planning; approve professional account requests.',
          ),
          const Text(
            'Safety flags require assessment, not an automatic conclusion of imminent danger. Refresh to load new records. Only assigned or shared cases are visible.',
          ),
          if (message != null) Notice(message!, urgent: true),
          FutureBuilder<List<List<DbRecord>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Busy();
              }
              if (snapshot.hasError) {
                return const Notice(
                  'Could not load cases. Check your role, connection and database setup.',
                  urgent: true,
                );
              }
              final data = snapshot.data!;
              final cases = data[0];
              final profiles = data[1];
              final assessments = data[2];
              final alerts = data[3];
              final queue = data[4];
              final applications = data[5];
              final latest = <String, DbRecord>{};
              for (final record
                  in assessments.where((record) => record['submitted_at'] != null)) {
                final id = record['student_id'] as String;
                if (latest[id] == null ||
                    (record['created_at'] as String).compareTo(
                          latest[id]!['created_at'] as String,
                        ) >
                        0) {
                  latest[id] = record;
                }
              }
              final filtered = cases.where((caseRecord) {
                final matches = profiles.where(
                  (profile) => profile['user_id'] == caseRecord['student_id'],
                );
                if (matches.isEmpty) return false;
                final profile = matches.first;
                return (!safetyOnly ||
                        caseRecord['pathway'] == 'safety' ||
                        caseRecord['pathway'] == 'emergency') &&
                    '${profile['name']} ${profile['email']}'
                        .toLowerCase()
                        .contains(search.toLowerCase());
              }).toList()
                ..sort(
                  (a, b) => (b['updated_at'] as String)
                      .compareTo(a['updated_at'] as String),
                );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.role == 'psychologist') ...[
                    const Text(
                      'Professional account requests',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Notice(
                      'Verify the applicant’s professional registration and institution through the appropriate official channel before approving dashboard access.',
                    ),
                    if (applications.isEmpty)
                      const Text('No pending professional requests.'),
                    for (final applicant in applications)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${applicant['display_name']} · ${applicant['requested_role']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text('Email: ${applicant['email']}'),
                              Text(
                                'Registration: ${applicant['professional_id']}',
                              ),
                              Text('Institution: ${applicant['institution']}'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilledButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () => reviewApplicant(
                                              applicant['id'] as String,
                                              approve: true,
                                            ),
                                    icon: const Icon(
                                      Icons.verified_user_outlined,
                                    ),
                                    label: const Text('Approve access'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () => reviewApplicant(
                                              applicant['id'] as String,
                                              approve: false,
                                            ),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Reject'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const Divider(height: 32),
                  ],
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Metric('Assigned patients', '${cases.length}'),
                      Metric(
                        'Open safety alerts',
                        '${alerts.where((alert) => alert['status'] != 'resolved').length}',
                      ),
                      Metric(
                        'Escalated alerts',
                        '${alerts.where((alert) => alert['status'] == 'escalated').length}',
                      ),
                      Metric('Unassigned queue', '${queue.length}'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      Distribution(rows: latest.values.toList(), phq: true),
                      Distribution(rows: latest.values.toList(), phq: false),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search assigned patients by name or email',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => search = value),
                  ),
                  FilterChip(
                    label: const Text('Safety and emergency cases'),
                    selected: safetyOnly,
                    onSelected: (value) => setState(() => safetyOnly = value),
                  ),
                  if (filtered.isEmpty)
                    const Notice(
                      'No assigned cases match this view. Eligible unassigned cases appear below.',
                    ),
                  for (final caseRecord in filtered)
                    Builder(
                      builder: (_) {
                        final profile = profiles.firstWhere(
                          (candidate) =>
                              candidate['user_id'] == caseRecord['student_id'],
                        );
                        final assessment = latest[caseRecord['student_id']];
                        return Card(
                          child: ListTile(
                            title: Text(profile['name'] as String),
                            subtitle: Text(
                              '${pathwayLabel(caseRecord['pathway'] as String)} · ${caseRecord['status']}'
                              '${assessment == null ? '\nNo completed assessment yet' : '\nPHQ-9 ${assessment['phq_score']}/27 · GAD-7 ${assessment['gad_score']}/21'}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => open(profile),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Unassigned case queue',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Only a pseudonymous case code and pathway are shown until a professional claims the case.',
                  ),
                  if (queue.isEmpty)
                    const Text('No eligible unassigned cases.'),
                  for (final caseRecord in queue)
                    Card(
                      child: ListTile(
                        title: Text(
                          'Case ${(caseRecord['student_id'] as String).substring(0, 8)}',
                        ),
                        subtitle: Text(
                          '${pathwayLabel(caseRecord['pathway'] as String)} · ${dateLabel(caseRecord['updated_at'])}',
                        ),
                        trailing: FilledButton(
                          onPressed: busy
                              ? null
                              : () => claim(caseRecord['student_id'] as String),
                          child: const Text('Claim case'),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );

}
