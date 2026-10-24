# MindCare v2 — Student, Psychologist and Psychiatrist

Flutter web project for college students aged **18–25**, using Supabase for authentication, private records, server scoring and role-controlled professional workflows. The code is separated into screens, widgets, shared helpers and a central API service.

## Included behavior

**Student:** persistent email/password account, consent and profile, PHQ-9/GAD-7, saved/resumable drafts, submission, separate score history, resources, optional consultation requests, shared guidance and appointments. Students cannot read private clinical notes or other students' records.

**Psychologist:** assigned/shared cases, severity distribution charts, original answers, longitudinal score bars, psychological assessment and counselling notes, student-visible goals/guidance, appointments, psychiatry referrals and safety review actions.

**Psychiatrist:** assigned/referred cases, relevant clinical history, medical assessment, clinician-entered diagnosis and medication records, shared plans, appointments and safety disposition. Psychologists cannot write the medical fields through either the UI or database API. No diagnosis, prescription or medication recommendation is generated automatically.

**Professional registration:** a professional can create an account from the sign-in page and submit their role, registration number and institution. The account stays a student-level account with no access to patient records until an already-approved psychiatrist verifies the application and approves it from the psychiatrist dashboard. The first psychiatrist must be provisioned by a trusted administrator with the setup script below.

**Safety workflow:** saving Q9 > 0 or another concern flags even incomplete drafts, creates one review request per assessment and assigns a named reviewer when an eligible professional is available. Professionals can acknowledge, record the assessment outcome and resolve a request. Emergency disposition is recorded only by a professional. A worker/optional SQL schedule escalates overdue unacknowledged requests to psychiatry. A configurable webhook supports actual notification delivery; case dashboards show pending/delivered status and retries.

## 1. Requirements

- Flutter stable, at least 3.24, with Dart >=3.5.
- A Supabase project and public publishable/anon key.
- Python 3 for local professional provisioning and the optional alert worker.
- Node.js only if you want the standalone PostgreSQL tests; it is not needed by the Flutter application.

## 2. Apply the v2 database files

In Supabase SQL Editor, run **in order, once**:

1. `supabase/001_schema.sql`
2. `supabase/002_questionnaires.sql`
3. `supabase/004_staff_registration.sql`

These create prefixed `mw_` tables and do not drop or change the previous prototype tables. Use a fresh project if desired. Initial migrations intentionally fail on already-created objects instead of silently overwriting clinical data. Use a reviewed follow-up migration for future schema changes.

If you already ran an earlier copy of `004_staff_registration.sql` and see `permission denied for function mw_role`, run `supabase/005_restore_app_grants.sql` once. It restores the checked browser RPC permissions. Do not rerun migrations 001 or 002 on an existing database.

Your original `doctors`, `assessments` and anonymous submissions remain untouched. They are **not automatically imported** into v2 because anonymous/self-reported email records cannot safely establish a persistent student's identity. Existing Auth accounts can be reused.

Supabase Authentication settings:

- Enable Email authentication and student signups.
- Enable email confirmation for real use and configure working SMTP.
- Anonymous sign-in is no longer used by this version.
- Set Authentication → URL Configuration → Site URL to your final site URL.
- Provision the first psychiatrist as below; that reviewer can approve later professional applications. Editable user metadata cannot grant professional access.

## 3. Create professional credentials

After applying SQL, create the first psychiatrist account on a trusted computer. This is the bootstrap reviewer; later professionals can request access in the app:

```bash
python3 scripts/create_professional.py
```

Choose `psychologist` or `psychiatrist`, enter the display name, and either supply an existing Auth user UUID or create a user with a real email and your own password of at least 12 characters. The service-role key is prompted invisibly, used locally and never written to the Flutter configuration.

Use this only for the first psychiatrist or when an administrator needs to restore access. To reuse an existing Auth account, enter its Auth user UUID. No default working credentials or Supabase project are included in this archive.

Alternatively, an administrator can bootstrap the first psychiatrist after creating a confirmed Auth account:

```sql
insert into public.mw_staff(user_id, role, display_name)
values ('AUTH_USER_UUID', 'psychologist', 'Professional Name');
```

Use `psychiatrist` for a psychiatrist. Disable access by setting `active=false`; reassign active cases and alerts before disabling the only reviewer. Database permissions change immediately; already-rendered information remains visible until refresh/sign-out. Professional accounts have an in-app **Change password** action.

## 4. Configure and run

Copy `config.example.json` to `config.json` and fill the Supabase URL and **public publishable/anon key**. You may reuse your previous public configuration. Never put a service-role/secret key in Dart or a web build.

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run -d chrome --dart-define-from-file=config.json
```

You can use `--dart-define-from-file=config.example.json` instead if that is the file you populated. The app starts in a setup screen when configuration is absent.

Register a student with a separate email, confirm the account, complete the profile/consent and submit a synthetic test assessment. A professional can choose **Apply for a professional account**, confirm their email if prompted, submit their credentials, then wait for an existing psychiatrist to approve. After approval, sign out and sign back in to load the professional dashboard.

## 5. Rules implemented on the server

Each answer uses 0–3 over the previous two weeks. PHQ-9 sums nine answers (0–27); GAD-7 sums seven answers (0–21). They are never combined. Difficulty ratings are separate. Missing answers remain null; submission requires all 16 answers and both difficulty fields.

PHQ-9 bands: 0–4 minimal; 5–9 mild; 10–14 moderate; 15–19 moderately severe; 20–27 severe.
GAD-7 bands: 0–4 minimal; 5–9 mild; 10–14 moderate; 15–21 severe.

Proposed referral protocol, requiring clinical approval:

1. A professional identifying acute danger records the emergency pathway and initiates the institution's emergency arrangements directly.
2. Saved Q9 > 0 or another concern creates a prompt safety assessment request, even for an incomplete form.
3. Incomplete forms without known safety concerns remain drafts.
4. Completed P >=15 or G >=15 routes to psychiatry.
5. Otherwise P >=5 or G >=5 routes to psychology.
6. Otherwise resources and optional consultation are offered.

Professional referral/disposition can override routine thresholds with a documented reason. Active safety/emergency pathways are not cleared by a new low score. Existing psychiatry assignment is not downgraded by a student submission; a professional records disposition. Resolving a safety alert records its outcome but does not silently downgrade the care pathway.

A saved safety flag is retained even if a draft answer changes. One assessment has one alert, which professionals resolve with a documented assessment outcome. An already-resolved alert is not repeatedly reopened by autosaves of that same assessment; new concerns after assessment should be reported directly and through a **new check-in**. A zero Q9 response does not rule out risk; a positive answer alone does not establish imminent danger.

A student can see their own saved scores and care pathway. Drafts may show an individual scale total when that scale is complete, but are excluded from trend/distribution charts until full submission.

## 6. Assignments and access

The backend assigns an eligible active professional by least existing membership count when a case needs review. Safety cases prefer psychology, with psychiatry fallback. Severe cases and overdue safety requests use psychiatry. This is a simple workload heuristic, not an on-call availability guarantee.

When no eligible professional exists, the case remains in an **unassigned pseudonymous queue**. Eligible professionals can claim it; full records are hidden until assignment. Psychologists retain access when they refer to a psychiatrist so both can coordinate care. Disposition changes do not remove existing memberships. Administrators should review memberships and service staffing regularly.

All browser writes use checked RPCs. There are no browser INSERT/UPDATE/DELETE grants on clinical tables. Professional applications are private; a verified active psychiatrist approves or rejects them through a role-checked RPC. Student clinical records remain visible only to the student and assigned/shared professionals. Notification delivery and escalation scheduling use trusted backend credentials.

Profiles are self-reported; the app verifies the account email according to Supabase settings, not student enrollment or a professional's qualifications. The psychiatrist reviewing applications must verify professional credentials through the appropriate official channel before approval.

## 7. Activate safety escalation and notifications

The default **15-minute acknowledgement deadline is a demonstration configuration**, not a validated clinical response standard. Your clinical team must choose coverage, deadline and escalation arrangements. Configure it in SQL:

```sql
update public.mw_settings set alert_minutes = 15 where id = 1;
```

This applies to newly created alerts. To escalate when the browser is closed, choose either:

- Run `scripts/run_alert_worker.py` continuously on a trusted always-on backend. It calls the escalation RPC every 30 seconds and can deliver notifications.
- Enable Supabase `pg_cron` and run `supabase/003_optional_cron.sql` once. Cron escalates database requests; it does not deliver messages. Use the worker for delivery if needed.

Worker environment variables:

```text
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=YOUR_BACKEND_ONLY_SECRET
MW_ALERT_WEBHOOK=https://YOUR_TRUSTED_NOTIFICATION_ENDPOINT
MW_WEBHOOK_TOKEN=YOUR_PRIVATE_WEBHOOK_TOKEN
```

Set these using your host's secret configuration, then run:

```bash
python3 scripts/run_alert_worker.py
```

The webhook receives `event_id`, `kind`, `recipient_id` and a generic message. It receives no student name, answers, diagnosis or contact data. Your endpoint must map recipient UUID to the correct professional, authenticate the request and deliver through your chosen channel. It must deduplicate `event_id`/`Idempotency-Key`: retries are at least once. Use one worker instance. Delivery retries stop after 20 failed attempts and remain visible for manual intervention. Acknowledged/resolved requests suppress obsolete notifications.

If no webhook/worker is configured, the UI and database requests work but **external notifications are not delivered**. Unassigned alerts need human staffing intervention; no service can notify a nonexistent reviewer. Escalation is a one-time handoff to psychiatry, not an unlimited automatic escalation ladder.

The app does not call emergency services, guarantee monitoring, send student appointment email reminders, or prescribe treatment. Students receive an explicit instruction not to wait for the app when they need immediate help. Appointment details are visible inside the student dashboard.

## 8. Verification

See `VERIFICATION.md` for checks run on this exact source. Reproducible local PostgreSQL tests:

```bash
cd qa
npm install
npm test
```

These use PGlite (real PostgreSQL in WebAssembly) with mocked Supabase Auth helper functions and synthetic users. They do not touch a live Supabase project. Run live staging tests with Supabase Auth and exercise the actual UI before deployment.

Also run the included Flutter scoring/widget tests. `.github/workflows/flutter.yml` supplies CI analysis, tests and a compile-only web build. A real deployment build must receive your public configuration.

## 9. Netlify deployment

```bash
flutter build web --release --dart-define-from-file=config.json
cp web/_redirects build/web/_redirects
```

Upload **build/web** through the existing Netlify site's Deploys page. Set Supabase Site URL to the Netlify/custom domain. The database and optional alert worker remain separate from Netlify static hosting.

## 10. Files to edit

- `lib/main.dart`: bootstrap, theme and session routing.
- `lib/screens/`: authentication, profile, student dashboard, questionnaires, professional dashboard, case review and methodology.
- `lib/widgets/`: shared layout, questionnaires and charts.
- `lib/services/api.dart`: database/API access.
- `lib/core/scoring.dart`: presentation-side scoring and testable routing; SQL remains authoritative.
- `supabase/`: schema, RLS policies, questionnaire seed and optional cron.
- `scripts/`: credential provisioning, alert worker and standalone scoring verification.
- `qa/`: database integration tests.
- `docs/ARCHITECTURE.md`: system flow and state/permission explanation.

All APIs operate on the latest stored questionnaire version 1. Keep definitions immutable for historical interpretation. Future questionnaire/rule changes require explicit versioned migrations. Record retention, deletion, backups, staff coverage, clinical policy and consent wording must be agreed by the institution; no compliance certification is claimed.

## References

- PHQ-9 scoring and Q9 follow-up: https://www.hiv.uw.edu/page/mental-health-screening/phq-9
- GAD-7: Spitzer et al., 2006. https://doi.org/10.1001/archinte.166.10.1092
- NIMH Adult ASQ Toolkit: https://www.nimh.nih.gov/research/research-conducted-at-nimh/asq-toolkit-materials/adults-asq-toolkit
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security

PHQ-9/GAD-7 screen symptoms; they do not diagnose every mental health condition. The routing thresholds are the proposed service protocol from your brief, not instrument-prescribed treatment decisions.
