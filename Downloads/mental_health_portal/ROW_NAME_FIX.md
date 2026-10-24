# Fix for the Flutter data-row naming collision

The database map alias is now `DbRecord`, so it does not conflict with Flutter's `Row` layout widget or `DataRow` table widget. Flutter layout calls remain unchanged.

This archive also includes professional self-registration and approval. For an existing v2 project, back up `lib`, copy the included `lib` folder, and run the new `supabase/004_staff_registration.sql` migration after `001_schema.sql` and `002_questionnaires.sql` have already been applied. Keep your configured public Supabase JSON and pubspec.yaml.

Bootstrap one psychiatrist using `scripts/create_professional.py`. They can then review and approve later psychologist or psychiatrist requests in the dashboard. A request alone does not grant access to student data.

Stop the running app and run from your project folder:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run -d chrome --dart-define-from-file=config.example.json
```

Use your own populated config filename if it differs. The test files now use relative local imports so they also work when your package is named `mental_health_portal`.

The source names were checked for consistency and the archive was checked for integrity. A full Flutter analysis/build and live Supabase integration test have not been run in the authoring environment.
