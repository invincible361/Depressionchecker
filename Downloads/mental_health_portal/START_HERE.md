# Start here

This is a complete Flutter web source project, not just a replacement lib folder.

1. Extract this folder and open `mindcare_v2` in your editor.
2. In Supabase SQL Editor, run `supabase/001_schema.sql`, `supabase/002_questionnaires.sql`, then `supabase/004_staff_registration.sql`, once each. These coexist with your original prototype tables.
   If you already applied an earlier `004` and see `permission denied for function mw_role`, run `supabase/005_restore_app_grants.sql` once.
3. Enable Email signup and configure email confirmation. This version uses persistent student accounts instead of anonymous sign-in.
4. On a trusted computer, run `python3 scripts/create_professional.py` to bootstrap the first psychiatrist. They can approve later professional applications in the psychiatrist dashboard.
5. Copy `config.example.json` to `config.json` and fill your existing Supabase URL and public key.
6. Run:

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run -d chrome --dart-define-from-file=config.json
```

Register a separate student account, complete consent/profile and test the check-in workflow with synthetic answers. Later professionals can apply from the sign-in page; the bootstrap psychiatrist must verify and approve them before dashboard access is granted.

The README explains scoring, roles, private notes, referrals, professional registration, appointments, upgrade behavior and optional alert delivery. Review `VERIFICATION.md` and `docs/STAGING_CHECKS.md` before deploying. Run Flutter analysis/build and the database checks locally before deployment; the new registration flow has not been run against a live Supabase project.

For Netlify, build locally and upload `build/web`:

```bash
flutter build web --release --dart-define-from-file=config.json
cp web/_redirects build/web/_redirects
```

Configure the trusted backend worker or optional pg_cron separately if using overdue safety escalation. A flag in the dashboard does not automatically send a message or contact emergency services.
