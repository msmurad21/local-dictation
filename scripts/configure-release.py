#!/usr/bin/env python3
"""Apply public release configuration to a staging bundle; never embed private keys."""
import base64
import os
import plistlib
import sys
from pathlib import Path
from urllib.parse import urlsplit

path = Path(sys.argv[1])
info = plistlib.loads(path.read_bytes())
feed = os.environ.get('APPCAST_URL', '')
key = os.environ.get('SPARKLE_PUBLIC_KEY', '')
release = os.environ.get('RELEASE_BUILD') == '1'
if feed or key or release:
    url = urlsplit(feed)
    if url.scheme != 'https' or not url.hostname or url.username or url.password:
        raise SystemExit('APPCAST_URL must be an HTTPS URL without credentials.')
    try:
        valid_key = len(base64.b64decode(key, validate=True)) == 32
    except ValueError:
        valid_key = False
    if not valid_key:
        raise SystemExit('SPARKLE_PUBLIC_KEY must be the 32-byte base64 public Ed25519 key.')
    info.update(SUFeedURL=feed, SUPublicEDKey=key)
if release and not os.environ.get('CODE_SIGN_IDENTITY', '').startswith('Developer ID Application:'):
    raise SystemExit('Release builds require a Developer ID Application signing identity.')
for env, field in [('APP_VERSION', 'CFBundleShortVersionString'), ('BUILD_NUMBER', 'CFBundleVersion')]:
    if value := os.environ.get(env):
        if not all(part.isdigit() for part in value.split('.')):
            raise SystemExit(f'{env} must be a numeric version.')
        info[field] = value
path.write_bytes(plistlib.dumps(info))
