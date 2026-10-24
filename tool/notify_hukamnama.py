"""Sends the daily Hukamnama notification when BaniDB has a new one.

Run every few minutes by .github/workflows/notifier.yml. It reads the latest
Hukamnama from BaniDB and, if its date is newer than the one recorded in
notifier/last-sent.txt, sends its first line to every app user subscribed to
the Firebase Cloud Messaging topic, then records the date.

The Gurbani text is sent exactly as BaniDB returns it.

Environment:
  FIREBASE_SERVICE_ACCOUNT  service account JSON (repository secret)
  DRY_RUN=1                 print the notification; don't send or record it
"""

import datetime as dt
import json
import os
import sys
import urllib.request
from pathlib import Path

BANIDB_URL = "https://api.banidb.com/v2/hukamnamas"
TOPIC = "daily-hukamnama"
STATE_FILE = Path("notifier/last-sent.txt")
FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

# Lines at the very start of a shabad that are headings (raag, author,
# "Salok", the Mool Mantar opening) rather than the first line of the shabad.
HEADING_MARKERS = ("ੴ", "ਮਹਲਾ", "ਮਃ", "ਸਲੋਕ", "ਪਉੜੀ", "ਭਗਤ", "ਛੰਤ", "ਅਸਟਪਦੀ", "ਡਖਣੇ")


def fetch_latest() -> dict:
    request = urllib.request.Request(BANIDB_URL, headers={"User-Agent": "daily-hukamnama-notifier"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def hukam_date(body: dict) -> dt.date:
    g = body["date"]["gregorian"]
    return dt.date(int(g["year"]), int(g["month"]), int(g["date"]))


def first_shabad(body: dict) -> dict:
    shabads = body.get("shabads") or []
    if not shabads:
        raise ValueError("Hukamnama has no shabads")
    return shabads[0]


def first_line(shabad: dict) -> str:
    """The first line of the shabad, skipping leading heading lines."""
    lines = [
        (v.get("verse") or {}).get("unicode", "").strip()
        for v in shabad.get("verses") or []
    ]
    lines = [line for line in lines if line]
    if not lines:
        raise ValueError("Hukamnama has no Gurmukhi text")
    for line in lines:
        if not any(marker in line for marker in HEADING_MARKERS):
            return line
    return lines[0]


def title_for(shabad: dict) -> str:
    ang = (shabad.get("shabadInfo") or {}).get("pageNo")
    return f"Today's Hukamnama · Ang {ang}" if ang else "Today's Hukamnama"


def send(service_account: dict, title: str, body: str, date: dt.date) -> None:
    from google.auth.transport.requests import AuthorizedSession
    from google.oauth2 import service_account as sa

    credentials = sa.Credentials.from_service_account_info(service_account, scopes=[FCM_SCOPE])
    session = AuthorizedSession(credentials)
    url = f"https://fcm.googleapis.com/v1/projects/{service_account['project_id']}/messages:send"
    message = {
        "message": {
            "topic": TOPIC,
            "notification": {"title": title, "body": body},
            "data": {"date": date.isoformat()},
            "android": {
                "priority": "high",
                "ttl": "43200s",
                "collapse_key": "hukamnama",
                "notification": {
                    "channel_id": "hukamnama",
                    "tag": "hukamnama",
                    "color": "#C9A24A",
                    "icon": "ic_notification",
                    "sound": "default",
                    "default_sound": True,
                    "notification_priority": "PRIORITY_HIGH",
                },
            },
        }
    }
    response = session.post(url, json=message, timeout=30)
    if response.status_code != 200:
        raise RuntimeError(f"FCM error {response.status_code}: {response.text}")
    print("Sent:", response.json().get("name"))


def main() -> int:
    body = fetch_latest()
    date = hukam_date(body)
    last = STATE_FILE.read_text().strip() if STATE_FILE.exists() else ""
    if last >= date.isoformat():
        print(f"No new Hukamnama (latest {date}, already sent {last}).")
        return 0

    shabad = first_shabad(body)
    title, line = title_for(shabad), first_line(shabad)
    print(f"New Hukamnama for {date}: {title} / {line}")

    # Don't announce an old Hukamnama, e.g. the first time this runs.
    stale = (dt.date.today() - date).days > 1
    if os.environ.get("DRY_RUN") == "1":
        print("Dry run: not sending or recording.")
        return 0
    if stale:
        print("Hukamnama is more than a day old: recording it without sending.")
    else:
        secret = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "").strip()
        if not secret:
            print("::warning::FIREBASE_SERVICE_ACCOUNT is not set; notification not sent.")
            return 0
        send(json.loads(secret), title, line, date)

    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(date.isoformat() + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
