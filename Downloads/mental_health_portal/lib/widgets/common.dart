import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../services/api.dart';
import '../screens/methodology_page.dart';

class Shell extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  const Shell({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('MindCare'),
      actions: [
        IconButton(
          tooltip: 'Scoring and workflow',
          icon: const Icon(Icons.info_outline),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const MethodologyPage()),
          ),
        ),
        ...actions,
      ],
    ),
    body: SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 20),
                for (final child in children) ...[
                  child,
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class Notice extends StatelessWidget {
  final String text;
  final bool urgent;
  const Notice(this.text, {super.key, this.urgent = false});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: urgent ? const Color(0xFFFFEAE3) : const Color(0xFFE4F2EE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: const TextStyle(height: 1.4)),
  );
}

class Busy extends StatelessWidget {
  const Busy({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator()),
  );
}

class Metric extends StatelessWidget {
  final String label, value;
  const Metric(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 230,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 28, color: brand)),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class ChangePasswordButton extends StatelessWidget {
  const ChangePasswordButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Change password',
    icon: const Icon(Icons.password),
    onPressed: () async {
      final controller = TextEditingController();
      String? newPassword;
      try {
        newPassword = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Change password'),
            content: TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText: 'Use at least 12 characters',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (controller.text.length >= 12)
                    Navigator.pop(dialogContext, controller.text);
                },
                child: const Text('Update'),
              ),
            ],
          ),
        );
      } finally {
        // Wait for the closing dialog animation before disposing its controller.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        controller.dispose();
      }
      if (newPassword == null) return;
      try {
        await db.auth.updateUser(UserAttributes(password: newPassword));
        if (context.mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Password updated.')));
      } catch (_) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Password could not be changed. Reauthenticate and retry; check your password policy.',
              ),
            ),
          );
      }
    },
  );
}
