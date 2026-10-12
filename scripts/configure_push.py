"""Prepare native Firebase config from the public values also used by Dart.
Usage: python3 scripts/configure_push.py push-config.json
Never pass a Firebase service account or APNs private key to this script.
"""
import json
import plistlib
import sys
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, tostring

root = Path(__file__).resolve().parents[1]
config = json.loads(Path(sys.argv[1] if len(sys.argv) > 1 else 'push-config.json').read_text())
keys = ['FIREBASE_PROJECT_ID', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_ANDROID_APP_ID', 'FIREBASE_ANDROID_API_KEY', 'FIREBASE_IOS_APP_ID', 'FIREBASE_IOS_API_KEY']
if any(not isinstance(config.get(key), str) or not config[key] or 'your-' in config[key] for key in keys):
    raise SystemExit('Fill all public Firebase values before building.')
if 'private_key' in config or 'client_email' in config:
    raise SystemExit('Do not put service account credentials in app configuration.')
resources = Element('resources')
for name, value in {
    'google_app_id': config['FIREBASE_ANDROID_APP_ID'],
    'google_api_key': config['FIREBASE_ANDROID_API_KEY'],
    'gcm_defaultSenderId': config['FIREBASE_MESSAGING_SENDER_ID'],
    'project_id': config['FIREBASE_PROJECT_ID'],
}.items():
    SubElement(resources, 'string', {'name': name, 'translatable': 'false'}).text = value
(root / 'android/app/src/main/res/values/firebase_config.xml').write_bytes(tostring(resources, encoding='utf-8', xml_declaration=True))
with (root / 'ios/Runner/GoogleService-Info.plist').open('wb') as target:
    plistlib.dump({
        'API_KEY': config['FIREBASE_IOS_API_KEY'],
        'GCM_SENDER_ID': config['FIREBASE_MESSAGING_SENDER_ID'],
        'PLIST_VERSION': '1',
        'BUNDLE_ID': 'com.athariyyah.appname',
        'PROJECT_ID': config['FIREBASE_PROJECT_ID'],
        'GOOGLE_APP_ID': config['FIREBASE_IOS_APP_ID'],
        'IS_ADS_ENABLED': False,
        'IS_ANALYTICS_ENABLED': False,
        'IS_GCM_ENABLED': True,
        'IS_SIGNIN_ENABLED': False,
        'IS_APPINVITE_ENABLED': False,
    }, target)
print('Native Firebase configuration prepared. Build with --dart-define-from-file=push-config.json.')
