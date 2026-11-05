"""The owner's real Gmail and Calendar over plain async HTTP. Sync Google clients stall a voice turn, and a call only needs a handful of REST endpoints."""
import base64
import html
import os
import re
import time
import uuid
from email.message import EmailMessage

import httpx

TOKEN_URL = "https://oauth2.googleapis.com/token"
GMAIL = "https://gmail.googleapis.com/gmail/v1/users/me"
CALENDAR = "https://www.googleapis.com/calendar/v3/calendars/primary"
SCOPES = ["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send", "https://www.googleapis.com/auth/calendar.events"]
BODY_CHARS = 1500  # enough to summarise aloud, not enough to dump a thread


def token_env(slug: str) -> str:
    """The env var and secret name a persona's refresh token lives under: dana -> GOOGLE_REFRESH_TOKEN_DANA, blunt-boyd -> GOOGLE_REFRESH_TOKEN_BLUNT_BOYD."""
    return "GOOGLE_REFRESH_TOKEN_" + re.sub(r"[^A-Z0-9]", "_", slug.upper())


class GoogleError(Exception):
    pass


def header(message: dict, name: str) -> str:
    return next((h["value"] for h in message.get("payload", {}).get("headers", []) if h["name"].lower() == name), "")


def plain_body(payload: dict) -> str:
    """The first text/plain part, else the first text/html part stripped of tags."""
    def walk(part: dict, mime: str) -> str:
        data = part.get("body", {}).get("data")
        if part.get("mimeType") == mime and data:
            return base64.urlsafe_b64decode(data + "=" * (-len(data) % 4)).decode("utf-8", "replace")
        return next((text for p in part.get("parts", []) if (text := walk(p, mime))), "")

    text = walk(payload, "text/plain")
    if not text:
        text = html.unescape(re.sub(r"(?is)<(style|script).*?</\1>|<[^>]+>", " ", walk(payload, "text/html")))
    return re.sub(r"\s+", " ", text).strip()


def raw_email(to: str, subject: str, body: str) -> str:
    m = EmailMessage()
    m["To"], m["Subject"] = to, subject
    m.set_content(body)
    return base64.urlsafe_b64encode(m.as_bytes()).decode()


class Google:
    def __init__(self, client_id: str, client_secret: str, refresh_token: str, http: httpx.AsyncClient | None = None):
        self.client_id, self.client_secret, self.refresh_token = client_id, client_secret, refresh_token
        self.http = http or httpx.AsyncClient(timeout=8)
        self._token, self._until = "", 0.0

    @classmethod
    def for_persona(cls, slug: str) -> "Google | None":
        """One Google account per persona: its token is GOOGLE_REFRESH_TOKEN_<SLUG>. A token without a suffix is never used, so no persona can borrow another's mailbox."""
        if not slug:
            return None
        keys = [os.environ.get(k, "").strip() for k in ("GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET", token_env(slug))]
        return cls(*keys) if all(keys) else None

    async def _access(self) -> str:
        if time.time() < self._until:
            return self._token
        r = await self.http.post(TOKEN_URL, data={"client_id": self.client_id, "client_secret": self.client_secret, "refresh_token": self.refresh_token, "grant_type": "refresh_token"})
        if r.status_code != 200:
            raise GoogleError(f"token refresh failed ({r.status_code})")
        j = r.json()
        self._token, self._until = j["access_token"], time.time() + j.get("expires_in", 3600) - 60
        return self._token

    async def _call(self, method: str, url: str, **kw) -> dict:
        r = await self.http.request(method, url, headers={"Authorization": f"Bearer {await self._access()}"}, **kw)
        if r.status_code >= 300:
            raise GoogleError(f"Google said {r.status_code}")
        return r.json() if r.content else {}

    async def events(self, start: str, end: str, limit: int = 25) -> list[dict]:
        j = await self._call("GET", f"{CALENDAR}/events", params={"timeMin": start, "timeMax": end, "singleEvents": "true", "orderBy": "startTime", "maxResults": limit})
        return [{"title": e.get("summary", "(no title)"), "start": e["start"].get("dateTime") or e["start"].get("date"), "end": e["end"].get("dateTime") or e["end"].get("date"), "all_day": "date" in e["start"], "busy": e.get("transparency") != "transparent" and e.get("status") != "cancelled", "attendees": [a["email"] for a in e.get("attendees", [])][:6]} for e in j.get("items", [])]

    async def create_event(self, title: str, start: str, end: str, tz: str, attendees: list[str], description: str) -> dict:
        body = {"summary": title, "description": description, "start": {"dateTime": start, "timeZone": tz}, "end": {"dateTime": end, "timeZone": tz}, "attendees": [{"email": a} for a in attendees], "conferenceData": {"createRequest": {"requestId": uuid.uuid4().hex, "conferenceSolutionKey": {"type": "hangoutsMeet"}}}}
        e = await self._call("POST", f"{CALENDAR}/events", params={"sendUpdates": "all", "conferenceDataVersion": 1}, json=body)
        return {"title": e.get("summary"), "start": e["start"].get("dateTime"), "link": e.get("htmlLink"), "meet": e.get("hangoutLink"), "attendees": attendees}

    async def search_mail(self, query: str, limit: int = 5) -> list[dict]:
        found = (await self._call("GET", f"{GMAIL}/messages", params={"q": query, "maxResults": limit})).get("messages", [])
        out = []
        for m in found:
            j = await self._call("GET", f"{GMAIL}/messages/{m['id']}", params=[("format", "metadata"), ("metadataHeaders", "From"), ("metadataHeaders", "Subject"), ("metadataHeaders", "Date")])
            out.append({"id": m["id"], "from": header(j, "from"), "subject": header(j, "subject"), "date": header(j, "date"), "snippet": html.unescape(j.get("snippet", ""))})
        return out

    async def read_mail(self, message_id: str) -> dict:
        j = await self._call("GET", f"{GMAIL}/messages/{message_id}", params={"format": "full"})
        return {"from": header(j, "from"), "to": header(j, "to"), "subject": header(j, "subject"), "date": header(j, "date"), "body": plain_body(j.get("payload", {}))[:BODY_CHARS]}

    async def send_mail(self, to: str, subject: str, body: str) -> dict:
        j = await self._call("POST", f"{GMAIL}/messages/send", json={"raw": raw_email(to, subject, body)})
        return {"id": j.get("id")}
