# Staging walkthrough

Use synthetic accounts and data. Do not collect real screening responses until the institution approves the service workflow and access tests pass in its actual Supabase project.

1. Apply `001_schema.sql`, `002_questionnaires.sql` and `004_staff_registration.sql`. Bootstrap one psychiatrist with the trusted script. Register a second clinician through **Apply for a professional account**, confirm the email, and submit a request.
2. Confirm the applicant remains unable to access clinical tables and the psychiatrist sees only the pending application in the registration panel. Reject one synthetic request and verify the applicant sees the decision note. Submit a new synthetic request, approve it, then sign in again and confirm the account opens the requested professional dashboard.
3. Submit as student A with PHQ [2,2,2,1,1,1,1,0,0] and GAD [2,2,2,2,1,1,0]. Confirm separate totals 10 and 10, psychologist pathway and automatic assignment.
4. Student B cannot read A's profile, responses, guidance or appointments. Attempt API requests directly, not only navigation.
5. Assigned psychologist sees the original answers, separate totals and trends. Unassigned psychologist cannot read or write A's clinical records. The student's editable Auth metadata must not grant professional access.
6. Record a private therapy assessment and separate shared goals. Only the goals appear in the student dashboard. Psychologist requests containing diagnosis/medication fields must fail at the database.
7. Refer to psychiatry with a reason. The psychiatrist can now see the assigned case and relevant clinical history. The psychologist retains shared access.
8. Start another draft as A. Leave other answers empty and save Q9=1. Confirm a safety request is created with a null total, a named reviewer (if staff exists), deadline and outbox row. Change Q9 to zero and verify the saved review flag remains.
9. Run the backend worker or configured pg_cron. Set a synthetic pending request deadline in the past with the SQL Editor and verify escalation to psychiatry. Verify webhook delivery status, deliberate delivery failure and retry, and acknowledgement stopping overdue escalation. Never shorten production deadlines merely for a test.
10. Acknowledge the request and record a detailed assessment outcome. Routine disposition must fail until active requests are resolved. Record disposition afterwards. A new low screening score must not silently clear an active safety/emergency pathway.
11. Record emergency disposition only as an assigned professional. Confirm the UI says it does not contact emergency services. Verify a student cannot invoke this RPC. The institution must separately rehearse its actual emergency response process.
12. Schedule an appointment in local time. Student sees its correctly converted local time and location. Complete or cancel it from the assigned professional account.
13. Record a psychiatrist assessment and medical plan. Students cannot read private diagnosis/medication fields. All clinical changes have audit entries.
14. Sign out from a case screen and use browser back. No cached case route should remain navigable. Test session expiry, staff deactivation and assignment changes.
15. Test lost connectivity: unsaved draft warning, retry without duplicate assessments, correct answer ordering during rapid clicks, browser back waiting for save, and submitted records remaining immutable.
16. Temporarily disable eligible staff in staging. An eligible professional sees only a pseudonymous unassigned queue until claiming. Confirm the claim assigns the reviewer and notification recipient. Restore staff and verify ownership.

Referral thresholds, the acknowledgement deadline, clinical notes policy, outbox hosting, reviewer availability, retention, deletion and contact procedures must have named institutional owners. A dashboard flag by itself does not demonstrate a functioning safety service.
