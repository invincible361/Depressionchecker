import 'package:flutter/material.dart';

import '../services/api.dart';
import '../widgets/common.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback onSaved;
  const ProfilePage({super.key, required this.onSaved});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      age = TextEditingController(),
      contact = TextEditingController();
  bool consent = false, busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    age.dispose();
    contact.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || !consent) {
      setState(() => error = 'Complete the details and consent to continue.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Api.saveProfile(
        name.text.trim(),
        int.parse(age.text),
        contact.text.trim(),
      );
      if (mounted) widget.onSaved();
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Profile could not be saved. Check the details, schema and connection.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Shell(
    title: 'Patient details and consent',
    actions: [
      TextButton(
        onPressed: () async {
          await db.auth.signOut();
        },
        child: const Text('Sign out'),
      ),
    ],
    children: [
      const Notice(
        'We store your account, details and responses for assigned professionals to review. Saved drafts may create safety-review requests. '
        'Clinical notes remain restricted. Ask your institution about retention, deletion, response hours and emergency arrangements.',
      ),
      if (error != null) Notice(error!, urgent: true),
      Text('Email: ${db.auth.currentUser?.email ?? ''}'),
      Form(
        key: form,
        child: Column(
          children: [
            TextFormField(
              controller: name,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  (v?.trim().length ?? 0) < 2 ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age 18–25'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 18 || n > 25
                    ? 'This program is for ages 18–25'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: contact,
              maxLength: 24,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact number'),
              validator: (v) =>
                  RegExp(r'^[+0-9 ()-]{7,24}$').hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Enter a valid contact number',
            ),
            CheckboxListTile(
              value: consent,
              onChanged: (v) => setState(() => consent = v ?? false),
              title: const Text(
                'I agree to share my details and responses with my assigned care team.',
              ),
            ),
          ],
        ),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(busy ? 'Saving…' : 'Save and continue'),
      ),
    ],
  );
}
