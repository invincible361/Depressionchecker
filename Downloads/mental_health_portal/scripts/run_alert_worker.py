#!/usr/bin/env python3
"""Trusted backend worker: escalate overdue requests and deliver generic notifications.
Requires SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY; optional MW_ALERT_WEBHOOK,
MW_WEBHOOK_TOKEN. No student response, name, contact or diagnosis is sent.
Webhook integration must map recipient_id to the intended professional.
"""
import json
import os
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from urllib.parse import urlparse


def require_origin(value):
    p=urlparse(value)
    if p.scheme!='https' or not p.hostname or p.path not in ('','/') or p.query or p.fragment:
        raise ValueError('SUPABASE_URL must be an HTTPS origin.')
    return value.rstrip('/')


def main():
    origin=require_origin(os.environ['SUPABASE_URL'])
    secret=os.environ['SUPABASE_SERVICE_ROLE_KEY']
    webhook=os.environ.get('MW_ALERT_WEBHOOK')
    webhook_token=os.environ.get('MW_WEBHOOK_TOKEN')
    if webhook and urlparse(webhook).scheme!='https':
        raise ValueError('Webhook must use HTTPS.')

    def api(path,payload=None,method=None):
        req=urllib.request.Request(origin+path,data=None if payload is None else json.dumps(payload).encode(),
            method=method or ('GET' if payload is None else 'POST'),headers={
                'apikey':secret,'Authorization':'Bearer '+secret,'Content-Type':'application/json'})
        with urllib.request.urlopen(req,timeout=20) as response:
            raw=response.read()
            return json.loads(raw) if raw else None

    print('Alert worker running. Keep this on a trusted always-on host. Stop with Ctrl+C.')
    if not webhook:
        print('No webhook configured: escalation runs; notification delivery remains pending.')
    while True:
        try:
            api('/rest/v1/rpc/mw_escalate_alerts',{})
            if webhook:
                rows=api('/rest/v1/mw_notifications?delivered_at=is.null&attempts=lt.20&order=created_at.asc&limit=50')
                for row in rows:
                    if row['recipient_id'] is None:
                        # Keep unassigned records visible. The active escalation or claim
                        # request will create/update a notification with a named recipient.
                        continue
                    change={'attempts':row['attempts']+1}
                    try:
                        # Recheck alert: don't send obsolete requests after acknowledgement.
                        active=api('/rest/v1/mw_alerts?id=eq.'+row['alert_id']+'&select=status,reviewer_id')
                        if not active or active[0]['status'] in ('acknowledged','resolved'):
                            change.update(delivered_at=datetime.now(timezone.utc).isoformat(),last_error='suppressed_after_review')
                        else:
                            event={'event_id':row['id'],'kind':row['kind'],'recipient_id':row['recipient_id'],
                                'message':'A MindCare case needs professional review. Open the secure dashboard.'}
                            req=urllib.request.Request(webhook,data=json.dumps(event).encode(),method='POST',headers={
                                'Content-Type':'application/json','Idempotency-Key':row['id'],
                                **({'Authorization':'Bearer '+webhook_token} if webhook_token else {})})
                            with urllib.request.urlopen(req,timeout=15) as response:
                                response.read()
                            change.update(delivered_at=datetime.now(timezone.utc).isoformat(),last_error=None)
                    except Exception:
                        change['last_error']='delivery_failed'
                    api('/rest/v1/mw_notifications?id=eq.'+row['id'],change,'PATCH')
        except Exception:
            print('Worker cycle failed; check connection and backend credentials. Retrying.')
        time.sleep(30)

if __name__=='__main__':
    try:
        main()
    except KeyboardInterrupt:
        print('Worker stopped.')
