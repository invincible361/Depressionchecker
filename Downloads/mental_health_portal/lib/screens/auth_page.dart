import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../services/api.dart';
import '../widgets/common.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final professionalName = TextEditingController();
  final professionalId = TextEditingController();
  final institution = TextEditingController();

  String mode = 'login';
  String professionalRole = 'counsellor';
  bool busy = false;
  bool hidden = true;
  String? message;

  bool get register => mode != 'login';

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    professionalName.dispose();
    professionalId.dispose();
    institution.dispose();
    super.dispose();
  }

  Future<void> authenticate() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (register) {
        final response = await db.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: mode == 'professional'
              ? {
                  'mw_professional_application': {
                    'role': professionalRole,
                    'display_name': professionalName.text.trim(),
                    'professional_id': professionalId.text.trim(),
                    'institution': institution.text.trim(),
                  },
                }
              : null,
        );
        if (mounted && response.session == null) {
          setState(() {
            message = mode == 'professional'
                ? 'Check your email to confirm the account, then sign in. Your application details will be ready for submission.'
                : 'Check your email to confirm your account, then sign in here.';
            mode = 'login';
          });
        }
      } else {
        await db.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Connection failed. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Shell(
        title: register
            ? mode == 'professional'
                ? 'Create a professional account'
                : 'Create a patient account'
            : 'Patient and professional sign-in',
        children: [
          const Notice(screeningNotice),
          const Text(
            'Patients can register directly. Counsellors and psychologists can apply for professional access. An active psychologist verifies each application before it receives access to patient records.',
          ),
          if (message != null) Notice(message!),
          SizedBox(
            width: 500,
            child: Form(
              key: form,
              child: Column(
                children: [
                  if (mode == 'professional') ...[
                    DropdownButtonFormField<String>(
                      value: professionalRole,
                      decoration: const InputDecoration(
                        labelText: 'Professional role',
                      ),
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
                      onChanged: (value) => setState(
                        () => professionalRole = value ?? professionalRole,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: professionalName,
                      decoration: const InputDecoration(
                        labelText: 'Professional name',
                      ),
                      validator: (value) =>
                          mode == 'professional' &&
                                  (value?.trim().length ?? 0) < 2
                              ? 'Enter your name'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: professionalId,
                      decoration: const InputDecoration(
                        labelText: 'Professional registration / licence number',
                      ),
                      validator: (value) =>
                          mode == 'professional' &&
                                  (value?.trim().length ?? 0) < 2
                              ? 'Enter your registration or licence number'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: institution,
                      decoration: const InputDecoration(
                        labelText: 'Clinic, counselling centre or institution',
                      ),
                      validator: (value) =>
                          mode == 'professional' &&
                                  (value?.trim().length ?? 0) < 2
                              ? 'Enter your institution'
                              : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: emailValidator,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: password,
                    obscureText: hidden,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => hidden = !hidden),
                        icon: Icon(
                          hidden ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) => (value?.length ?? 0) < (register ? 12 : 1)
                        ? register
                            ? 'Use at least 12 characters'
                            : 'Enter your password'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : authenticate,
                    child: Text(
                      busy
                          ? 'Please wait…'
                          : mode == 'patient'
                              ? 'Register patient'
                              : mode == 'professional'
                                  ? 'Create professional account'
                                  : 'Sign in',
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              mode = mode == 'login' ? 'patient' : 'login';
                              message = null;
                            }),
                    child: Text(
                      mode == 'login'
                          ? 'New patient? Register'
                          : 'Already registered? Sign in',
                    ),
                  ),
                  if (mode == 'login')
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                                mode = 'professional';
                                message = null;
                              }),
                      icon: const Icon(Icons.medical_information_outlined),
                      label: const Text('Apply for a professional account'),
                    ),
                  if (mode == 'professional')
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                                mode = 'login';
                                message = null;
                              }),
                      child: const Text('Back to sign in'),
                    ),
                ],
              ),
            ),
          ),
          const Notice(supportText),
        ],
      );

}
