import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api.dart';
import '../widgets/common.dart';

class StaffApplicationPage extends StatefulWidget {
  final DbRecord? application;
  final DbRecord? draft;
  final VoidCallback onRefresh;

  const StaffApplicationPage({
    super.key,
    this.application,
    this.draft,
    required this.onRefresh,
  });

  @override
  State<StaffApplicationPage> createState() => _StaffApplicationPageState();
}

class _StaffApplicationPageState extends State<StaffApplicationPage> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: (widget.application?['display_name'] ??
            widget.draft?['display_name'] ??
            '')
        .toString(),
  );
  late final professionalId = TextEditingController(
    text: (widget.application?['professional_id'] ??
            widget.draft?['professional_id'] ??
            '')
        .toString(),
  );
  late final institution = TextEditingController(
    text: (widget.application?['institution'] ??
            widget.draft?['institution'] ??
            '')
        .toString(),
  );
  late String role = (widget.application?['requested_role'] ??
          widget.draft?['role'] ??
          'counsellor')
      .toString();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    professionalId.dispose();
    institution.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Api.submitStaffApplication(
        role: role,
        name: name.text.trim(),
        professionalId: professionalId.text.trim(),
        institution: institution.text.trim(),
      );
      widget.onRefresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not submit the request. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.application?['status'] as String?;
    final waiting = status == 'pending';
    return Shell(
      title: 'Professional account request',
      actions: [
        TextButton(
          onPressed: () async => db.auth.signOut(),
          child: const Text('Sign out'),
        ),
      ],
      children: [
        const Notice(
          'Professional access requires approval by an active psychologist. Submitting this form does not grant access to patient records.',
        ),
        if (waiting) ...[
          const Card(
            child: ListTile(
              leading: Icon(Icons.hourglass_top),
              title: Text('Request pending review'),
              subtitle: Text(
                'An active psychologist must verify and approve your details.',
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh approval status'),
          ),
        ] else ...[
          if (status == 'rejected')
            Notice(
              'Your previous request was not approved: ${widget.application?['decision_note'] ?? 'Please review your details and submit again.'}',
              urgent: true,
            ),
          if (error != null) Notice(error!, urgent: true),
          SizedBox(
            width: 560,
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Applying for'),
                    items: const [
                      DropdownMenuItem(
                        value: 'counsellor',
                        child: Text('Counsellor'),
                      ),
                      DropdownMenuItem(
                        value: 'psychologist',
                        child: Text('Psychologist'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => role = value ?? role),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Professional name',
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter your name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: professionalId,
                    decoration: const InputDecoration(
                      labelText: 'Professional registration / licence number',
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter your registration or licence number'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: institution,
                    decoration: const InputDecoration(
                      labelText: 'Clinic, counselling centre or institution',
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter your institution'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: busy ? null : submit,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: Text(busy ? 'Submitting…' : 'Submit for review'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
