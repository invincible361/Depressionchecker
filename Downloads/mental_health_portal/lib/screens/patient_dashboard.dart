import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import '../widgets/charts.dart';
import 'assessment_page.dart';

class PatientDashboard extends StatefulWidget {
  final DbRecord profile;
  const PatientDashboard({super.key, required this.profile});
  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  late Future<List<List<DbRecord>>> future;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    final id = db.auth.currentUser!.id;
    final next = Future.wait([
      Api.assessments(id),
      Api.read('mw_cases', studentId: id),
      Api.read('mw_care_plans', studentId: id),
      Api.read('mw_appointments', studentId: id),
    ]);
    setState(() {
      future = next;
    });
  }

  Future<void> open([DbRecord? draft]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => AssessmentPage(draft: draft)),
    );
    if (mounted) refresh();
  }

  Future<void> requestConsultation() async {
    try {
      await Api.action('mw_request_consultation', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Consultation requested. Contact your institution to confirm timing.',
            ),
          ),
        );
        refresh();
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Request failed. Please retry or contact the institution.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Shell(
    title: 'Welcome, ${widget.profile['name']}',
    actions: [
      const ChangePasswordButton(),
      IconButton(
        tooltip: 'Refresh',
        onPressed: refresh,
        icon: const Icon(Icons.refresh),
      ),
      TextButton(
        onPressed: () async {
          await db.auth.signOut();
        },
        child: const Text('Sign out'),
      ),
    ],
    children: [
      const Notice(screeningNotice),
      FutureBuilder<List<List<DbRecord>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Busy();
          if (snapshot.hasError)
            return Notice(
              'Could not load your records. Check your connection and refresh.',
              urgent: true,
            );
          final data = snapshot.data!;
          final assessments = data[0],
              cases = data[1],
              plans = data[2],
              appointments = data[3];
          plans.sort(
            (a, b) => (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            ),
          );
          appointments.sort(
            (a, b) =>
                (a['starts_at'] as String).compareTo(b['starts_at'] as String),
          );
          final drafts = assessments
              .where((r) => r['submitted_at'] == null)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cases.isNotEmpty)
                Notice(
                  'Current care pathway: ${pathwayLabel(cases.first['pathway'] as String)}',
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => open(),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Start a new check-in'),
                  ),
                  for (final draft in drafts)
                    OutlinedButton(
                      onPressed: () => open(draft),
                      child: Text(
                        'Resume draft · ${dateLabel(draft['created_at'])}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              HistoryChart(rows: assessments),
              const SizedBox(height: 20),
              const Text(
                'Appointments',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              if (appointments.isEmpty)
                const Text(
                  'No appointments have been scheduled. Contact your institution to request a consultation.',
                ),
              for (final row in appointments)
                Card(
                  child: ListTile(
                    title: Text(dateLabel(row['starts_at'])),
                    subtitle: Text('${row['location']} · ${row['status']}'),
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'Guidance from your care team',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              if (plans.isEmpty)
                const Text(
                  'Professional guidance will appear here after review.',
                ),
              for (final plan in plans)
                Card(
                  child: ListTile(
                    title: Text(plan['guidance'] as String),
                    subtitle: Text(dateLabel(plan['created_at'])),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: requestConsultation,
                icon: const Icon(Icons.support_agent),
                label: const Text('Request a consultation'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Wellbeing resources',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Keep regular sleep and meal routines, take manageable study breaks, connect with trusted people, '
                'and contact your campus counselling service when you would like support. You can request support even with low screening scores.',
              ),
            ],
          );
        },
      ),
      const Notice(supportText),
    ],
  );
}
