-- OPTIONAL: enable pg_cron in Supabase Dashboard > Database > Extensions first.
-- This escalates overdue pending alerts; it does NOT deliver messages.
-- Run ONCE after setting the clinic-approved deadline in mw_settings.
select cron.schedule('mindcare-escalate-safety-alerts','* * * * *',
 $$select public.mw_escalate_alerts();$$);
-- Delivery requires scripts/run_alert_worker.py and a configured trusted webhook.
-- Inspect: select * from cron.job where jobname='mindcare-escalate-safety-alerts';
