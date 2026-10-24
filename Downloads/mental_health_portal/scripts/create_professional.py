#!/usr/bin/env python3
"""Run locally, never in the Flutter app. Provisions existing/new auth users."""
import getpass
import json
import urllib.request
import urllib.error
from urllib.parse import urlparse
from uuid import UUID


def main():
    origin=input('Supabase HTTPS project origin: ').strip().rstrip('/')
    parsed=urlparse(origin)
    if parsed.scheme!='https' or not parsed.hostname or parsed.path or parsed.query or parsed.fragment:
        raise ValueError('Use the HTTPS project origin without a path.')
    secret=getpass.getpass('Secret service-role key (hidden): ')
    role=input('Role (psychologist/psychiatrist): ').strip()
    if role not in ('psychologist','psychiatrist'):
        raise ValueError('Choose psychologist or psychiatrist.')
    name=input('Display name: ').strip()
    if not name:
        raise ValueError('Display name is required.')

    def api(path, payload):
        req=urllib.request.Request(origin+path,data=json.dumps(payload).encode(),method='POST',headers={
            'apikey':secret,'Authorization':'Bearer '+secret,'Content-Type':'application/json',
            'Prefer':'resolution=merge-duplicates,return=representation',
        })
        with urllib.request.urlopen(req,timeout=30) as response:
            raw=response.read()
            return json.loads(raw) if raw else None

    uid=input('Existing Auth user UUID, or Enter to create a user: ').strip()
    if uid:
        uid=str(UUID(uid))
    else:
        email=input('Professional email: ').strip()
        password=getpass.getpass('Choose password (at least 12 characters): ')
        if len(password)<12 or password!=getpass.getpass('Confirm password: '):
            raise ValueError('Password too short or confirmation differs.')
        user=api('/auth/v1/admin/users',{'email':email,'password':password,'email_confirm':True})
        uid=user.get('id') or user.get('user',{}).get('id')
        if not uid:
            raise RuntimeError('Auth response missing user ID.')
    try:
        api('/rest/v1/mw_staff',{'user_id':uid,'role':role,'display_name':name,'active':True})
    except Exception:
        print('Auth user exists, but provisioning failed. Apply v2 SQL first, then retry with this existing UUID:',uid)
        raise
    print('Professional access provisioned. Sign in with the account email/password. UUID:',uid)

if __name__=='__main__':
    try:
        main()
    except urllib.error.HTTPError as exc:
        raise SystemExit(f'Provisioning failed (HTTP {exc.code}). Check the key, schema and existing email.')
