-- MindCare v2. New mw_ tables coexist with the original prototype.
-- Run this initial migration ONCE in Supabase SQL Editor.
begin;
create table public.mw_staff (
 user_id uuid primary key references auth.users(id),
 role text not null check(role in ('psychologist','psychiatrist')),
 display_name text not null, active boolean not null default true
);
create table public.mw_profiles (
 user_id uuid primary key references auth.users(id), name text not null check(length(trim(name)) between 2 and 100),
 age integer not null check(age between 18 and 25), contact text not null check(contact ~ '^[+0-9 ()-]{7,24}$'),
 email text not null, consent_at timestamptz not null default now(), consent_version text not null default '1'
);
create table public.mw_questionnaires (
 code text primary key, version integer not null default 1 check(version=1), title text not null, questions text[] not null,
 check((code='PHQ9' and cardinality(questions)=9) or(code='GAD7' and cardinality(questions)=7))
);
create function public.mw_role() returns text language sql stable security definer set search_path='' as $$
 select case when auth.uid() is null then 'guest' when coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then 'guest'
 else coalesce((select role from public.mw_staff where user_id=auth.uid() and active),'student') end;
$$;
create table public.mw_cases (
 student_id uuid primary key references public.mw_profiles(user_id),
 pathway text not null default 'resources' check(pathway in ('resources','psychologist','psychiatrist','safety','emergency')),
 status text not null default 'open' check(status in ('open','in_care','follow_up','closed')),
 updated_at timestamptz not null default now()
);
create table public.mw_case_members (
 student_id uuid references public.mw_cases(student_id), staff_id uuid references public.mw_staff(user_id),
 assigned_at timestamptz not null default now(), primary key(student_id,staff_id)
);
create function public.mw_can_read(p_student uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.mw_role() in ('psychologist','psychiatrist') and exists(
 select 1 from public.mw_case_members where student_id=p_student and staff_id=auth.uid());
$$;
create function public.mw_valid_answers(a integer[], n integer, complete_ boolean default false)
 returns boolean language sql immutable set search_path='' as $$
 select coalesce(array_ndims(a)=1 and array_lower(a,1)=1 and cardinality(a)=n and
 not exists(select 1 from unnest(a) x where x<0 or x>3 or (complete_ and x is null)),false);
$$;
create function public.mw_total(a integer[]) returns integer language sql immutable set search_path='' as $$
 select case when a is null or array_position(a,null) is not null then null else (select sum(x)::integer from unnest(a) x) end;
$$;
create function public.mw_route(p integer,g integer,s boolean,acute boolean default false,override_ boolean default false)
 returns text language sql immutable set search_path='' as $$
 select case when acute then 'emergency' when s then 'safety' when p is null or g is null then 'incomplete'
 when override_ or p>=15 or g>=15 then 'psychiatrist' when p>=5 or g>=5 then 'psychologist' else 'resources' end;
$$;
create table public.mw_assessments (
 id uuid primary key, student_id uuid not null references public.mw_profiles(user_id),
 phq integer[] not null default array_fill(null::integer,array[9]) check(public.mw_valid_answers(phq,9)),
 gad integer[] not null default array_fill(null::integer,array[7]) check(public.mw_valid_answers(gad,7)),
 phq_difficulty integer check(phq_difficulty between 0 and 3), gad_difficulty integer check(gad_difficulty between 0 and 3),
 other_concern boolean not null default false, safety_flag boolean not null default false,
 phq_score integer generated always as(public.mw_total(phq)) stored,
 gad_score integer generated always as(public.mw_total(gad)) stored,
 submitted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 questionnaire_version integer not null default 1 check(questionnaire_version=1), rule_version text not null default '1',
 check(submitted_at is null or (public.mw_valid_answers(phq,9,true) and public.mw_valid_answers(gad,7,true)
 and phq_difficulty is not null and gad_difficulty is not null))
);
create index mw_assessments_student on public.mw_assessments(student_id,created_at desc);
create table public.mw_alerts (
 id uuid primary key default gen_random_uuid(), assessment_id uuid unique not null references public.mw_assessments(id),
 student_id uuid not null references public.mw_cases(student_id), reviewer_id uuid references public.mw_staff(user_id),
 status text not null default 'pending' check(status in ('pending','acknowledged','escalated','resolved')),
 created_at timestamptz not null default now(), due_at timestamptz not null,
 acknowledged_at timestamptz, acknowledged_by uuid references public.mw_staff(user_id), escalated_at timestamptz,
 resolution text, resolved_at timestamptz
);
create table public.mw_reviews (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.mw_cases(student_id),
 author_id uuid not null references public.mw_staff(user_id), private_note text not null check(length(trim(private_note)) between 1 and 10000),
 diagnosis text, medication text, created_at timestamptz not null default now()
);
create table public.mw_care_plans (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.mw_cases(student_id),
 author_id uuid not null references public.mw_staff(user_id), guidance text not null check(length(trim(guidance)) between 1 and 5000),
 created_at timestamptz not null default now()
);
create table public.mw_referrals (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.mw_cases(student_id),
 from_id uuid not null references public.mw_staff(user_id), to_id uuid references public.mw_staff(user_id),
 reason text not null check(length(trim(reason)) between 1 and 5000), created_at timestamptz not null default now()
);
create table public.mw_appointments (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.mw_cases(student_id),
 staff_id uuid not null references public.mw_staff(user_id), starts_at timestamptz not null,
 status text not null default 'scheduled' check(status in ('scheduled','completed','cancelled')),
 location text not null check(length(trim(location)) between 1 and 500), created_at timestamptz not null default now()
);
create table public.mw_audit (
 id bigint generated always as identity primary key, actor_id uuid, student_id uuid,
 action text not null, created_at timestamptz not null default now()
);
create table public.mw_notifications (
 id uuid primary key default gen_random_uuid(), alert_id uuid not null references public.mw_alerts(id),
 recipient_id uuid references public.mw_staff(user_id), kind text not null,
 created_at timestamptz not null default now(), delivered_at timestamptz,
 attempts integer not null default 0, last_error text
);
create table public.mw_settings (
 id integer primary key check(id=1), alert_minutes integer not null default 15 check(alert_minutes between 1 and 1440)
);
insert into public.mw_settings(id) values(1);

-- Enable RLS and strip default Supabase client grants from every new table.
do $$ declare t text; begin
 foreach t in array array['mw_staff','mw_profiles','mw_questionnaires','mw_cases','mw_case_members','mw_assessments','mw_alerts','mw_reviews','mw_care_plans','mw_referrals','mw_appointments','mw_audit','mw_notifications','mw_settings'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 execute format('grant all on public.%I to service_role',t);
 end loop;
end $$;
grant select on public.mw_questionnaires to authenticated;
create policy mw_questionnaire_read on public.mw_questionnaires for select to authenticated using(public.mw_role()<>'guest');
grant select on public.mw_profiles,public.mw_cases,public.mw_case_members,public.mw_assessments,public.mw_care_plans,public.mw_appointments to authenticated;
create policy mw_profile_read on public.mw_profiles for select to authenticated using(user_id=auth.uid() or public.mw_can_read(user_id));
create policy mw_case_read on public.mw_cases for select to authenticated using(student_id=auth.uid() or public.mw_can_read(student_id));
create policy mw_member_read on public.mw_case_members for select to authenticated using(public.mw_can_read(student_id));
create policy mw_assessment_read on public.mw_assessments for select to authenticated using(student_id=auth.uid() or public.mw_can_read(student_id));
create policy mw_plan_read on public.mw_care_plans for select to authenticated using(student_id=auth.uid() or public.mw_can_read(student_id));
create policy mw_appointment_read on public.mw_appointments for select to authenticated using(student_id=auth.uid() or public.mw_can_read(student_id));
grant select on public.mw_reviews,public.mw_referrals,public.mw_alerts,public.mw_audit to authenticated;
create policy mw_review_read on public.mw_reviews for select to authenticated using(public.mw_can_read(student_id));
create policy mw_referral_read on public.mw_referrals for select to authenticated using(public.mw_can_read(student_id));
create policy mw_alert_read on public.mw_alerts for select to authenticated using(public.mw_can_read(student_id));
create policy mw_audit_read on public.mw_audit for select to authenticated using(public.mw_can_read(student_id));
grant select on public.mw_notifications to authenticated;
create policy mw_notification_read on public.mw_notifications for select to authenticated using(exists(select 1 from public.mw_alerts a where a.id=alert_id and public.mw_can_read(a.student_id)));

create function public.mw_save_profile(p_name text,p_age integer,p_contact text,p_consent boolean) returns void
 language plpgsql security definer set search_path='' as $$
declare mail text;
begin
 if public.mw_role()<>'student' or p_consent is distinct from true then raise exception 'Student sign-in and consent required'; end if;
 select email into mail from auth.users where id=auth.uid();
 insert into public.mw_profiles(user_id,name,age,contact,email) values(auth.uid(),trim(p_name),p_age,trim(p_contact),mail)
 on conflict(user_id) do update set name=excluded.name,age=excluded.age,contact=excluded.contact;
 insert into public.mw_cases(student_id) values(auth.uid()) on conflict do nothing;
end $$;

-- Internal helpers: never executable by browser roles.
create function public.mw_pick_staff(p_role text) returns uuid language sql security definer set search_path='' as $$
 select s.user_id from public.mw_staff s left join public.mw_case_members m on m.staff_id=s.user_id
 where s.active and s.role=p_role group by s.user_id order by count(m.student_id),s.user_id limit 1;
$$;
create function public.mw_assign(p_student uuid,p_path text) returns uuid language plpgsql security definer set search_path='' as $$
declare target uuid; role_ text;
begin
 role_:=case when p_path in ('psychiatrist','emergency') then 'psychiatrist' else 'psychologist' end;
 select s.user_id into target from public.mw_case_members m join public.mw_staff s on s.user_id=m.staff_id
 where m.student_id=p_student and s.role=role_ and s.active order by m.assigned_at limit 1;
 if target is null then target:=public.mw_pick_staff(role_); end if;
 if target is null and p_path='safety' then target:=public.mw_pick_staff('psychiatrist'); end if;
 if target is not null then insert into public.mw_case_members(student_id,staff_id) values(p_student,target) on conflict do nothing; end if;
 return target;
end $$;

create function public.mw_save_assessment(p_id uuid,p_phq integer[],p_gad integer[],p_phq_difficulty integer,p_gad_difficulty integer,p_other_concern boolean,p_submit boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.mw_assessments; owner_ uuid; reviewer uuid; route_ text; alert_ uuid; safety_ boolean; review_needed boolean;
begin
 if public.mw_role()<>'student' or not exists(select 1 from public.mw_profiles where user_id=auth.uid()) then raise exception 'Complete student profile first'; end if;
 -- Serialize all submissions for a student and all writes to a given draft.
 perform 1 from public.mw_cases where student_id=auth.uid() for update;
 insert into public.mw_assessments(id,student_id) values(p_id,auth.uid()) on conflict do nothing;
 select * into a from public.mw_assessments where id=p_id for update;
 if a.student_id is distinct from auth.uid() then raise exception 'Access denied' using errcode='42501'; end if;
 if a.submitted_at is not null then
  return jsonb_build_object('id',a.id,'submitted',true,'pathway',(select pathway from public.mw_cases where student_id=auth.uid()));
 end if;
 safety_:=a.safety_flag or coalesce(p_phq[9]>0,false) or coalesce(p_other_concern,false);
 update public.mw_assessments set phq=p_phq,gad=p_gad,phq_difficulty=p_phq_difficulty,gad_difficulty=p_gad_difficulty,
 other_concern=coalesce(p_other_concern,false),safety_flag=safety_,updated_at=now(),submitted_at=case when p_submit then now() else null end
 where id=p_id returning * into a;
 review_needed:=a.safety_flag and not exists(select 1 from public.mw_alerts where assessment_id=p_id and status='resolved');
 route_:=public.mw_route(a.phq_score,a.gad_score,review_needed);
 if a.submitted_at is not null or review_needed then
  -- Keep active safety/emergency pathways until a professional explicitly resolves them.
  if exists(select 1 from public.mw_alerts where student_id=auth.uid() and status<>'resolved') then route_:='safety'; end if;
  if (select pathway from public.mw_cases where student_id=auth.uid())='emergency' then route_:='emergency';
  elsif (select pathway from public.mw_cases where student_id=auth.uid())='psychiatrist' and route_ in ('resources','psychologist') then route_:='psychiatrist'; end if;
  update public.mw_cases set pathway=route_,status='open',updated_at=now() where student_id=auth.uid();
  if route_<>'resources' then reviewer:=public.mw_assign(auth.uid(),route_); end if;
 end if;
 if review_needed then
  insert into public.mw_alerts(assessment_id,student_id,reviewer_id,due_at)
  values(p_id,auth.uid(),reviewer,now()+make_interval(mins=>(select alert_minutes from public.mw_settings where id=1)))
  on conflict(assessment_id) do nothing returning id into alert_;
  if alert_ is not null then
   insert into public.mw_notifications(alert_id,recipient_id,kind) values(alert_,reviewer,'safety_review');
   insert into public.mw_audit(actor_id,student_id,action) values(auth.uid(),auth.uid(),'safety_flag_created');
  end if;
 end if;
 if p_submit then insert into public.mw_audit(actor_id,student_id,action) values(auth.uid(),auth.uid(),'assessment_submitted'); end if;
 return jsonb_build_object('id',a.id,'submitted',a.submitted_at is not null,'pathway',route_);
end $$;

create function public.mw_request_consultation() returns void language plpgsql security definer set search_path='' as $$
declare path_ text;
begin
 if public.mw_role()<>'student' then raise exception 'Student sign-in required'; end if;
 select pathway into path_ from public.mw_cases where student_id=auth.uid() for update;
 if path_ is null then raise exception 'Complete your profile first'; end if;
 if path_='resources' then path_:='psychologist'; end if;
 update public.mw_cases set pathway=path_,status='open',updated_at=now() where student_id=auth.uid();
 perform public.mw_assign(auth.uid(),path_);
 insert into public.mw_audit(actor_id,student_id,action) values(auth.uid(),auth.uid(),'consultation_requested');
end $$;

create function public.mw_queue() returns table(student_id uuid,pathway text,updated_at timestamptz)
language sql security definer set search_path='' as $$
 select c.student_id,c.pathway,c.updated_at from public.mw_cases c
 where public.mw_role() in ('psychologist','psychiatrist') and c.status<>'closed' and
 (c.pathway='safety' or (c.pathway='emergency' and public.mw_role()='psychiatrist') or c.pathway=public.mw_role())
 and not exists(select 1 from public.mw_case_members m join public.mw_staff s on s.user_id=m.staff_id
 where m.student_id=c.student_id and s.active and (s.role=public.mw_role() or c.pathway='safety'))
 order by case when c.pathway in ('safety','emergency') then 0 else 1 end,c.updated_at;
$$;
create function public.mw_claim(p_student uuid) returns void language plpgsql security definer set search_path='' as $$
declare path_ text;
begin
 select pathway into path_ from public.mw_cases where student_id=p_student for update;
 if public.mw_role() not in ('psychologist','psychiatrist') or
 not (path_=public.mw_role() or path_='safety' or (path_='emergency' and public.mw_role()='psychiatrist')) then raise exception 'Case not eligible'; end if;
 if exists(select 1 from public.mw_case_members m join public.mw_staff s on s.user_id=m.staff_id
 where m.student_id=p_student and s.active and s.role=public.mw_role() and s.user_id<>auth.uid()) then raise exception 'Already assigned'; end if;
 insert into public.mw_case_members(student_id,staff_id) values(p_student,auth.uid()) on conflict do nothing;
 update public.mw_alerts set reviewer_id=auth.uid() where student_id=p_student and reviewer_id is null and status<>'resolved';
 update public.mw_notifications n set recipient_id=auth.uid() from public.mw_alerts a where n.alert_id=a.id and a.student_id=p_student and n.recipient_id is null and a.status<>'resolved';
 insert into public.mw_audit(actor_id,student_id,action) values(auth.uid(),p_student,'case_claimed');
end $$;
create function public.mw_staff_directory() returns table(user_id uuid,role text,display_name text)
language sql stable security definer set search_path='' as $$
 select user_id,role,display_name from public.mw_staff where active and public.mw_role() in ('psychologist','psychiatrist');
$$;
create function public.mw_add_review(p_student uuid,p_note text,p_guidance text,p_diagnosis text default '',p_medication text default '')
returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.mw_can_read(p_student) then raise exception 'Access denied'; end if;
 if public.mw_role()<>'psychiatrist' and (length(trim(coalesce(p_diagnosis,'')))>0 or length(trim(coalesce(p_medication,'')))>0) then raise exception 'Psychiatrist role required for medical fields'; end if;
 insert into public.mw_reviews(student_id,author_id,private_note,diagnosis,medication)
 values(p_student,auth.uid(),trim(p_note),nullif(trim(p_diagnosis),''),nullif(trim(p_medication),''));
 if length(trim(coalesce(p_guidance,'')))>0 then insert into public.mw_care_plans(student_id,author_id,guidance) values(p_student,auth.uid(),trim(p_guidance)); end if;
 update public.mw_cases set status='in_care',updated_at=now() where student_id=p_student;
 insert into public.mw_audit(actor_id,student_id,action) values(auth.uid(),p_student,'review_recorded');
end $$;
create function public.mw_refer(p_student uuid,p_to uuid,p_reason text) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.mw_cases where student_id=p_student for update;
 if not public.mw_can_read(p_student) then raise exception 'Access denied'; end if;
 if not exists(select 1 from public.mw_staff where user_id=p_to and active and role='psychiatrist') then raise exception 'Choose an active psychiatrist'; end if;
 insert into public.mw_case_members(student_id,staff_id) values(p_student,p_to) on conflict do nothing;
 insert into public.mw_referrals(student_id,from_id,to_id,reason) values(p_student,auth.uid(),p_to,trim(p_reason));
 update public.mw_cases set pathway=case when pathway in ('safety','emergency') then pathway else 'psychiatrist' end,updated_at=now() where student_id=p_student;
 insert into public.mw_audit(actor_id,student_id,action) values(auth.uid(),p_student,'psychiatrist_referral');
end $$;
create function public.mw_appointment(p_student uuid,p_time timestamptz,p_location text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.mw_can_read(p_student) or p_time is null or p_time<=now() then raise exception 'Assigned professional and future time required'; end if;
 insert into public.mw_appointments(student_id,staff_id,starts_at,location) values(p_student,auth.uid(),p_time,trim(p_location));
 insert into public.mw_audit(actor_id,student_id,action) values(auth.uid(),p_student,'appointment_created');
end $$;
create function public.mw_appointment_status(p_id uuid,p_status text) returns void language plpgsql security definer set search_path='' as $$
declare stu uuid;
begin
 select student_id into stu from public.mw_appointments where id=p_id;
 if not public.mw_can_read(stu) or p_status not in ('completed','cancelled') then raise exception 'Access denied'; end if;
 update public.mw_appointments set status=p_status where id=p_id;
 insert into public.mw_audit(actor_id,student_id,action) values(auth.uid(),stu,'appointment_'||p_status);
end $$;
create function public.mw_ack_alert(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare stu uuid;
begin
 select student_id into stu from public.mw_alerts where id=p_id for update;
 if not public.mw_can_read(stu) then raise exception 'Access denied'; end if;
 update public.mw_alerts set status='acknowledged',acknowledged_at=now(),acknowledged_by=auth.uid()
 where id=p_id and status in ('pending','escalated');
 insert into public.mw_audit(actor_id,student_id,action) values(auth.uid(),stu,'alert_acknowledged');
end $$;
create function public.mw_resolve_alert(p_id uuid,p_resolution text) returns void language plpgsql security definer set search_path='' as $$
declare stu uuid;
begin
 select student_id into stu from public.mw_alerts where id=p_id for update;
 if not public.mw_can_read(stu) or length(trim(coalesce(p_resolution,'')))<5 then raise exception 'Assessment outcome required'; end if;
 update public.mw_alerts set status='resolved',resolution=trim(p_resolution),resolved_at=now() where id=p_id;
 insert into public.mw_audit(actor_id,student_id,action) values(auth.uid(),stu,'alert_resolved');
 -- Pathway stays safety/emergency until an explicit documented disposition is recorded.
end $$;
create function public.mw_disposition(p_student uuid,p_pathway text,p_reason text) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.mw_cases where student_id=p_student for update;
 if not public.mw_can_read(p_student) or p_pathway not in ('resources','psychologist','psychiatrist','emergency') or length(trim(coalesce(p_reason,'')))<5 then raise exception 'Assigned professional and documented reason required'; end if;
 if p_pathway<>'emergency' and exists(select 1 from public.mw_alerts where student_id=p_student and status<>'resolved') then raise exception 'Resolve active safety assessments first'; end if;
 if (select pathway from public.mw_cases where student_id=p_student)='emergency' and public.mw_role()<>'psychiatrist' and p_pathway<>'emergency' then raise exception 'Psychiatrist must close emergency disposition'; end if;
 update public.mw_cases set pathway=p_pathway,status='follow_up',updated_at=now() where student_id=p_student;
 if p_pathway<>'resources' then perform public.mw_assign(p_student,p_pathway); end if;
 insert into public.mw_reviews(student_id,author_id,private_note) values(p_student,auth.uid(),'Disposition: '||p_pathway||'. '||trim(p_reason));
 insert into public.mw_audit(actor_id,student_id,action) values(auth.uid(),p_student,'disposition_'||p_pathway);
end $$;

create function public.mw_escalate_alerts() returns integer language plpgsql security definer set search_path='' as $$
declare a record; target uuid; n integer:=0;
begin
 for a in select * from public.mw_alerts where status='pending' and due_at<=now() for update skip locked loop
  target:=public.mw_assign(a.student_id,'psychiatrist');
  update public.mw_alerts set status='escalated',escalated_at=now(),reviewer_id=coalesce(target,reviewer_id) where id=a.id;
  insert into public.mw_notifications(alert_id,recipient_id,kind) values(a.id,target,'overdue_safety_review');
  insert into public.mw_audit(student_id,action) values(a.student_id,'unacknowledged_alert_escalated');
  n:=n+1;
 end loop;
 return n;
end $$;

-- All mw_ functions default-denied, then expose a small checked API.
do $$ declare f record; begin
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on p.pronamespace=n.oid
 where n.nspname='public' and p.proname like 'mw\_%' escape '\' loop
 execute format('revoke all on function %s from public,anon,authenticated',f.sig);
 execute format('grant execute on function %s to service_role',f.sig);
 end loop;
end $$;
grant execute on function public.mw_role(),public.mw_can_read(uuid),public.mw_total(integer[]),public.mw_valid_answers(integer[],integer,boolean) to authenticated;
grant execute on function public.mw_save_profile(text,integer,text,boolean),public.mw_save_assessment(uuid,integer[],integer[],integer,integer,boolean,boolean),public.mw_queue(),public.mw_request_consultation(),public.mw_claim(uuid),public.mw_staff_directory(),public.mw_add_review(uuid,text,text,text,text),public.mw_refer(uuid,uuid,text),public.mw_appointment(uuid,timestamptz,text),public.mw_appointment_status(uuid,text),public.mw_ack_alert(uuid),public.mw_resolve_alert(uuid,text),public.mw_disposition(uuid,text,text) to authenticated;
grant usage,select on sequence public.mw_audit_id_seq to service_role;
commit;
