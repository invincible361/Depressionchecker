-- Professional self-registration is an application, not a role grant.
-- An already-approved psychiatrist must review each application.
begin;

create table public.mw_staff_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id),
  requested_role text not null check (requested_role in ('psychologist','psychiatrist')),
  display_name text not null check (length(trim(display_name)) between 2 and 100),
  professional_id text not null check (length(trim(professional_id)) between 2 and 100),
  institution text not null check (length(trim(institution)) between 2 and 160),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  decision_note text,
  reviewed_by uuid references public.mw_staff(user_id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.mw_staff_applications enable row level security;
revoke all on table public.mw_staff_applications from public, anon, authenticated;
grant all on table public.mw_staff_applications to service_role;

create function public.mw_submit_staff_application(
  p_role text, p_name text, p_professional_id text, p_institution text
) returns void language plpgsql security definer set search_path='' as $$
declare existing_status text;
begin
  if auth.uid() is null or public.mw_role() <> 'student' then
    raise exception 'Sign in with a personal account before applying';
  end if;
  if p_role not in ('psychologist','psychiatrist') then
    raise exception 'Choose a professional role';
  end if;
  if not exists (select 1 from auth.users where id=auth.uid()) then
    raise exception 'Account not found';
  end if;
  if exists (select 1 from public.mw_staff where user_id=auth.uid()) then
    raise exception 'Professional account already exists';
  end if;
  select status into existing_status from public.mw_staff_applications
    where user_id=auth.uid() for update;
  if existing_status='pending' or existing_status='approved' then
    raise exception 'An application is already active or approved';
  end if;
  insert into public.mw_staff_applications(user_id,requested_role,display_name,professional_id,institution)
  values(auth.uid(),p_role,trim(p_name),trim(p_professional_id),trim(p_institution))
  on conflict(user_id) do update set
    requested_role=excluded.requested_role, display_name=excluded.display_name,
    professional_id=excluded.professional_id, institution=excluded.institution,
    status='pending', decision_note=null, reviewed_by=null, reviewed_at=null,
    created_at=now()
  where public.mw_staff_applications.status='rejected';
end $$;

create function public.mw_my_staff_application()
returns table(requested_role text,display_name text,professional_id text,institution text,status text,decision_note text,created_at timestamptz)
language sql stable security definer set search_path='' as $$
  select a.requested_role,a.display_name,a.professional_id,a.institution,a.status,a.decision_note,a.created_at
  from public.mw_staff_applications a where a.user_id=auth.uid();
$$;

create function public.mw_pending_staff_applications()
returns table(id uuid,user_id uuid,email text,requested_role text,display_name text,professional_id text,institution text,created_at timestamptz)
language sql stable security definer set search_path='' as $$
  select a.id,a.user_id,u.email::text,a.requested_role,a.display_name,a.professional_id,a.institution,a.created_at
  from public.mw_staff_applications a join auth.users u on u.id=a.user_id
  where a.status='pending' and public.mw_role()='psychiatrist'
  order by a.created_at,a.id;
$$;

create function public.mw_review_staff_application(p_id uuid,p_approve boolean,p_note text default '')
returns void language plpgsql security definer set search_path='' as $$
declare a public.mw_staff_applications;
begin
  if public.mw_role()<>'psychiatrist' then raise exception 'Active psychiatrist approval required'; end if;
  select * into a from public.mw_staff_applications where id=p_id for update;
  if not found or a.status<>'pending' then raise exception 'Application is no longer pending'; end if;
  if p_approve then
    insert into public.mw_staff(user_id,role,display_name,active)
    values(a.user_id,a.requested_role,a.display_name,true)
    on conflict(user_id) do nothing;
    if not exists(select 1 from public.mw_staff where user_id=a.user_id and role=a.requested_role and active) then
      raise exception 'Could not grant the requested professional role';
    end if;
    update public.mw_staff_applications set status='approved',reviewed_by=auth.uid(),reviewed_at=now(),decision_note=null
      where id=p_id;
    insert into public.mw_audit(actor_id,action) values(auth.uid(),'professional_application_approved');
  else
    if length(trim(coalesce(p_note,'')))<3 then raise exception 'Add a short reason for rejection'; end if;
    update public.mw_staff_applications set status='rejected',reviewed_by=auth.uid(),reviewed_at=now(),decision_note=trim(p_note)
      where id=p_id;
    insert into public.mw_audit(actor_id,action) values(auth.uid(),'professional_application_rejected');
  end if;
end $$;

-- Restrict only the new functions. Do not alter the existing MindCare RPC grants.
revoke all on function public.mw_submit_staff_application(text,text,text,text) from public,anon,authenticated;
revoke all on function public.mw_my_staff_application() from public,anon,authenticated;
revoke all on function public.mw_pending_staff_applications() from public,anon,authenticated;
revoke all on function public.mw_review_staff_application(uuid,boolean,text) from public,anon,authenticated;
grant execute on function public.mw_my_staff_application(),public.mw_submit_staff_application(text,text,text,text) to authenticated;
grant execute on function public.mw_pending_staff_applications(),public.mw_review_staff_application(uuid,boolean,text) to authenticated;

commit;
