"""Firebase ID token check for the call socket. Offline for anything malformed; no token is ever logged."""
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

PROJECT = "daily-games-420bf"
CLOCK_SKEW = 10  # seconds of iat/exp slack for a just-refreshed token on a slightly lagging clock


class Unauthorized(Exception):
    pass


def verify(token: str, project: str = PROJECT) -> str:
    """The Firebase uid behind `token`, or raise Unauthorized. Signature, expiry and audience (the project) are checked."""
    if not isinstance(token, str) or token.count(".") != 2 or not all(token.split(".")):
        raise Unauthorized("malformed token")  # a JWT has three parts; do not fetch certificates for anything else
    try:
        claims = id_token.verify_firebase_token(token, google_requests.Request(), audience=project, clock_skew_in_seconds=CLOCK_SKEW)
    except Exception as e:  # bad signature, expired, wrong audience, certificates unreachable
        raise Unauthorized(type(e).__name__) from None
    claims = claims or {}
    if claims.get("iss") != f"https://securetoken.google.com/{project}":
        raise Unauthorized("wrong issuer")
    uid = claims.get("sub")
    if not isinstance(uid, str) or not uid:
        raise Unauthorized("no uid")
    return uid
