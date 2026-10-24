-- Run only if you already applied the earlier 004 migration and now see
-- "permission denied for function mw_role". Restores the checked browser RPCs.
begin;

grant execute on function public.mw_role(),public.mw_can_read(uuid),public.mw_total(integer[]),public.mw_valid_answers(integer[],integer,boolean) to authenticated;
grant execute on function public.mw_save_profile(text,integer,text,boolean),public.mw_save_assessment(uuid,integer[],integer[],integer,integer,boolean,boolean),public.mw_queue(),public.mw_request_consultation(),public.mw_claim(uuid),public.mw_staff_directory(),public.mw_add_review(uuid,text,text,text,text),public.mw_refer(uuid,uuid,text),public.mw_appointment(uuid,timestamptz,text),public.mw_appointment_status(uuid,text),public.mw_ack_alert(uuid),public.mw_resolve_alert(uuid,text),public.mw_disposition(uuid,text,text) to authenticated;
grant execute on function public.mw_my_staff_application(),public.mw_submit_staff_application(text,text,text,text) to authenticated;
grant execute on function public.mw_pending_staff_applications(),public.mw_review_staff_application(uuid,boolean,text) to authenticated;

commit;
