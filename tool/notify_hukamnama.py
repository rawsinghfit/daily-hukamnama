"""Sends the daily Hukamnama notification when BaniDB has a new one.

Run by .github/workflows/notifier.yml. It reads the latest Hukamnama from
BaniDB and, if its date is newer than the one recorded in
notifier/last-sent.txt, sends its first line to every app user subscribed to
the Firebase Cloud Messaging topic, then records the date.

GitHub often starts scheduled runs hours late, so each run can keep watching
BaniDB (WATCH_MINUTES) until today's Hukamnama appears.

The Gurbani text is sent exactly as BaniDB returns it.

Environment:
  FIREBASE_SERVICE_ACCOUNT  service account JSON (repository secret)
  DRY_RUN=1                 print the notification; don't send or record it
  WATCH_MINUTES=N           keep checking every 2 minutes for up to N minutes
                            until today's Hukamnama (India date) has been sent
"""

import datetime as dt
import json
import os
import sys
import time
import urllib.request
from pathlib import Path

BANIDB_URL = "https://api.banidb.com/v2/hukamnamas"
TOPIC = "daily-hukamnama"
STATE_FILE = Path("notifier/last-sent.txt")
FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
INDIA = dt.timezone(dt.timedelta(hours=5, minutes=30))
CHECK_EVERY = 120  # seconds

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


def last_sent() -> str:
    return STATE_FILE.read_text().strip() if STATE_FILE.exists() else ""


def india_today() -> dt.date:
    return dt.datetime.now(INDIA).date()


def check_once() -> None:
    """Sends and records the latest Hukamnama if it hasn't been sent yet."""
    body = fetch_latest()
    date = hukam_date(body)
    last = last_sent()
    if last >= date.isoformat():
        print(f"No new Hukamnama (latest {date}, already sent {last}).", flush=True)
        return

    shabad = first_shabad(body)
    title, line = title_for(shabad), first_line(shabad)
    print(f"New Hukamnama for {date}: {title} / {line}", flush=True)

    # Don't announce an old Hukamnama, e.g. the first time this runs.
    stale = (india_today() - date).days > 1
    if os.environ.get("DRY_RUN") == "1":
        print("Dry run: not sending or recording.")
        return
    if stale:
        print("Hukamnama is more than a day old: recording it without sending.")
    else:
        secret = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "").strip()
        if not secret:
            print("::warning::FIREBASE_SERVICE_ACCOUNT is not set; notification not sent.")
            return
        send(json.loads(secret), title, line, date)

    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(date.isoformat() + "\n")


def main() -> int:
    watch = int(os.environ.get("WATCH_MINUTES") or 0)
    if watch <= 0 or os.environ.get("DRY_RUN") == "1":
        check_once()
        return 0

    deadline = time.monotonic() + watch * 60
    while True:
        if last_sent() >= india_today().isoformat():
            print(f"Today's Hukamnama ({last_sent()}) has been sent.")
            return 0
        try:
            check_once()
        except Exception as error:  # BaniDB hiccups shouldn't end the watch
            print(f"::warning::Check failed: {error}", flush=True)
        if last_sent() >= india_today().isoformat() or time.monotonic() + CHECK_EVERY > deadline:
            return 0
        time.sleep(CHECK_EVERY)


if __name__ == "__main__":
    sys.exit(main())
