// A day's documents read as the phone reads them: one anonymous identity,
// signed up once and refreshed after (core/backend.gd does the same).

// The game's own client key and project (core/backend.gd).
const API_KEY = "AIzaSyCwpr8lI-wwJ_CE74KxjKZt_6HQdKGaNxc";
const PROJECT = "daily-games-420bf";
const DOCS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const KEPT = "day_viewer.refresh";

function stored() {
  try {
    return localStorage.getItem(KEPT) ?? "";
  } catch {
    return "";
  }
}

function store(token) {
  try {
    localStorage.setItem(KEPT, token);
  } catch {
    // a private window keeps nothing: the next load signs up again
  }
}

async function refresh(token) {
  const res = await fetch(`https://securetoken.googleapis.com/v1/token?key=${API_KEY}`, {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(token)}`,
  });
  if (!res.ok) return res.status >= 400 && res.status < 500 ? null : Promise.reject(new Error(`refresh ${res.status}`));
  const d = await res.json();
  store(d.refresh_token);
  return d.id_token;
}

async function signUp() {
  const res = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({returnSecureToken: true}),
  });
  if (!res.ok) throw new Error(`sign up ${res.status}`);
  const d = await res.json();
  store(d.refreshToken);
  return d.idToken;
}

let idToken = null;

async function token() {
  if (idToken !== null) return idToken;
  const kept = stored();
  idToken = (kept ? await refresh(kept) : null) ?? await signUp();
  // An id token lives an hour; the next read after that refreshes.
  setTimeout(() => { idToken = null; }, 50 * 60 * 1000);
  return idToken;
}

/** `days/<day>/turns/*` by name, each one's `json` parsed. */
export async function readDay(day) {
  const res = await fetch(`${DOCS}/days/${day}/turns?pageSize=50`, {
    headers: {Authorization: `Bearer ${await token()}`},
  });
  if (!res.ok) throw new Error(`days/${day}: ${res.status}`);
  const out = {};
  for (const doc of (await res.json()).documents ?? []) {
    const json = doc.fields?.json?.stringValue;
    if (json !== undefined) out[doc.name.split("/").pop()] = JSON.parse(json);
  }
  return out;
}

export function todayUtc() {
  const d = new Date();
  return d.getUTCFullYear() * 10000 + (d.getUTCMonth() + 1) * 100 + d.getUTCDate();
}

export function shiftDay(day, by) {
  const d = new Date(Date.UTC(Math.floor(day / 10000), Math.floor(day / 100) % 100 - 1, day % 100 + by));
  return d.getUTCFullYear() * 10000 + (d.getUTCMonth() + 1) * 100 + d.getUTCDate();
}
