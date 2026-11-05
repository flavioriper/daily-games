"""Firebase ID token check for the call socket. Offline for anything malformed; no token is ever logged."""
import re
import threading
import time

from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

PROJECT = "daily-games-420bf"
CLOCK_SKEW = 10  # seconds of iat/exp slack for a just-refreshed token on a slightly lagging clock
FETCH_TIMEOUT = 5.0  # the certificate fetch; the library default is 120 s, longer than any phone waits for its hello
MAX_AGE = re.compile(r"max-age=(\d+)")


class Unauthorized(Exception):
    pass


class CachedRequest(google_requests.Request):
    """One requests session for the process, a short timeout, and GET answers (Google's signing certificates) kept for
    their Cache-Control max-age, so a hello does not fetch them again. Thread safe: verify runs in worker threads."""

    def __init__(self, clock=time.monotonic):
        super().__init__()
        self.clock = clock
        self._cache: dict[str, tuple[float, object]] = {}
        self._lock = threading.Lock()

    def __call__(self, url, method="GET", body=None, headers=None, timeout=None, **kwargs):
        timeout = FETCH_TIMEOUT if timeout is None else min(timeout, FETCH_TIMEOUT)
        if method != "GET" or body is not None:
            return super().__call__(url, method=method, body=body, headers=headers, timeout=timeout, **kwargs)
        with self._lock:
            hit = self._cache.get(url)
        if hit is not None and hit[0] > self.clock():
            return hit[1]
        response = super().__call__(url, method=method, body=body, headers=headers, timeout=timeout, **kwargs)
        if response.status == 200:
            m = MAX_AGE.search((response.headers or {}).get("cache-control", "") or "")
            if m and int(m.group(1)) > 0:
                with self._lock:
                    self._cache[url] = (self.clock() + int(m.group(1)), response)
        return response


_request = CachedRequest()


def verify(token: str, project: str = PROJECT) -> str:
    """The Firebase uid behind `token`, or raise Unauthorized. Signature, expiry and audience (the project) are checked."""
    if not isinstance(token, str) or token.count(".") != 2 or not all(token.split(".")):
        raise Unauthorized("malformed token")  # a JWT has three parts; do not fetch certificates for anything else
    try:
        claims = id_token.verify_firebase_token(token, _request, audience=project, clock_skew_in_seconds=CLOCK_SKEW)
    except Exception as e:  # bad signature, expired, wrong audience, certificates unreachable
        raise Unauthorized(type(e).__name__) from None
    claims = claims or {}
    if claims.get("iss") != f"https://securetoken.google.com/{project}":
        raise Unauthorized("wrong issuer")
    uid = claims.get("sub")
    if not isinstance(uid, str) or not uid:
        raise Unauthorized("no uid")
    return uid
