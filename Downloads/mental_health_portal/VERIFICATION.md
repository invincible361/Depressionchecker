# Verification record

- Before the professional-registration update, the two original Supabase migrations were executed in PGlite, a real PostgreSQL engine in WebAssembly, using a synthetic Auth schema.
- **48 database checks passed on the prior v2 schema** for score totals, age limits, immutable submissions, missing answers, role escalation prevention, record isolation, private/shared notes, medical-field restrictions, referrals, safety flags, escalation, acknowledgement/resolution, appointment visibility, notification privacy, staff deactivation and consultation requests.
- The new `004_staff_registration.sql` migration and its approval checks are included in the current source, but have **not been executed** in this environment.
- The first version of migration 004 revoked existing browser RPC grants; the current 004 only restricts its own new functions. `005_restore_app_grants.sql` repairs projects that ran that earlier migration.
- **32 standalone Dart scoring checks passed**, including score boundaries, the worked examples, missing/invalid answers, routine referral thresholds and safety/professional overrides.
- The earlier app sources were Dart-formatted and parsed before the current registration UI changes. The updated Dart code has not been analyzed or formatted here. Relative imports resolve. Python provisioning and worker scripts passed syntax checks.

**Not run:** Flutter analysis, Flutter widget tests, the release web build and live Supabase Auth integration. The environment initially had no Flutter SDK. An attempted SDK bootstrap/version check was stopped by automatic approval review because it attempted cloud-instance metadata access. No bypass or further Flutter execution was attempted. Run the included Flutter commands on a trusted local installation or CI before deployment.

Local PostgreSQL tests mock only the Auth identity functions; they do not substitute for staging tests against the actual service. No live Supabase project, professional credentials, webhook or Netlify deployment was created during authoring.

## Row naming correction

The database map alias was changed to `DbRecord` to avoid collisions with Flutter's `Row` and `DataRow` widgets. Source checks do not constitute a Flutter analysis or build.

`SessionGate` also now updates its stored future inside a synchronous `setState` callback to address the async callback error in the uploaded log.
