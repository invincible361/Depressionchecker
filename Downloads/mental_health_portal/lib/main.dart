import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants.dart';
import 'services/api.dart';
import 'widgets/common.dart';
import 'screens/auth_page.dart';
import 'screens/profile_page.dart';
import 'screens/patient_dashboard.dart';
import 'screens/professional_dashboard.dart';
import 'screens/staff_application_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  var configured = false;
  if (url.isNotEmpty && key.isNotEmpty && !url.contains('YOUR_PROJECT')) {
    try {
      await Supabase.initialize(url: url, anonKey: key);
      configured = true;
    } catch (_) {
      /* Setup screen below. */
    }
  }
  runApp(
    MaterialApp(
      title: 'MindCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: brand),
        scaffoldBackgroundColor: const Color(0xFFF5F8F7),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: configured
          ? const SessionGate()
          : const Shell(
              title: 'Connect your project',
              children: [
                Notice(
                  'Set your Supabase URL and public key in config.json, then run with --dart-define-from-file=config.json. Apply the current Supabase SQL migrations first. See README.md.',
                ),
              ],
            ),
    ),
  );
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  StreamSubscription<AuthState>? subscription;
  late Future<DbRecord> access;
  @override
  void initState() {
    super.initState();
    access = load();
    subscription = db.auth.onAuthStateChange.listen((event) {
      if (mounted &&
          (event.event == AuthChangeEvent.signedIn ||
              event.event == AuthChangeEvent.signedOut)) {
        // Remove detail routes on logout as well as the underlying dashboard.
        if (event.session == null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const SessionGate()),
            (_) => false,
          );
          return;
        }
        setState(() {
          access = load();
        });
      }
    });
  }

  Future<DbRecord> load() async {
    if (db.auth.currentUser == null) return {'role': 'guest'};
    final role = await Api.role();
    if (role == 'patient') {
      final application = await Api.staffApplicationStatus();
      if (application != null) return {'role': role, 'application': application};
      final metadata = db.auth.currentUser!.userMetadata ?? {};
      final draft = metadata['mw_professional_application'];
      if (draft is Map) return {'role': role, 'applicationDraft': Map<String, dynamic>.from(draft)};
    }
    return {
      'role': role,
      'profile': role == 'patient' ? await Api.profile() : null,
    };
  }

  void refresh() {
    setState(() {
      access = load();
    });
  }
  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DbRecord>(
    future: access,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Scaffold(body: Busy());
      if (snapshot.hasError)
        return Shell(
          title: 'Connection unavailable',
          children: [
            const Notice(
              'Check the v2 schema, your configuration and connection.',
            ),
            FilledButton(onPressed: refresh, child: const Text('Retry')),
            TextButton(
              onPressed: () async {
                await db.auth.signOut();
              },
              child: const Text('Sign out'),
            ),
          ],
        );
      final role = snapshot.data?['role'] as String? ?? 'guest';
      if (role == 'guest') return const AuthPage();
      if (role == 'patient' && snapshot.data?['application'] is DbRecord) {
        return StaffApplicationPage(
          application: snapshot.data!['application'] as DbRecord,
          onRefresh: refresh,
        );
      }
      if (role == 'patient' && snapshot.data?['applicationDraft'] is DbRecord) {
        return StaffApplicationPage(
          draft: snapshot.data!['applicationDraft'] as DbRecord,
          onRefresh: refresh,
        );
      }
      if (role == 'patient' && snapshot.data?['profile'] == null)
        return ProfilePage(onSaved: refresh);
      if (role == 'patient')
        return PatientDashboard(profile: DbRecord.from(snapshot.data!['profile']));
      return ProfessionalDashboard(role: role);
    },
  );
}
