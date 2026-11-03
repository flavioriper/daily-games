// google.ts: the local admin page's reach into Google (GA4 and Firestore),
// with this Mac's own Application Default Credentials, so there is no key
// and no OAuth client. Runs only inside `next dev`.
import { execFile } from "node:child_process";
import { promisify } from "node:util";

export const PROJECT = "daily-games-420bf";
export const SCOPE_FIX =
  "gcloud auth application-default login --scopes=openid,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/analytics.readonly";

const run = promisify(execFile);
let cached: { token: string; until: number } | null = null;

export class GoogleError extends Error {
  constructor(message: string, readonly status: number, readonly fix?: string) {
    super(message);
  }
}

export async function token(): Promise<string> {
  if (cached && cached.until > Date.now()) return cached.token;
  try {
    const { stdout } = await run("gcloud", ["auth", "application-default", "print-access-token"]);
    cached = { token: stdout.trim(), until: Date.now() + 5 * 60_000 };
    return cached.token;
  } catch (e) {
    const why = String((e as { stderr?: string }).stderr ?? "").trim().split("\n").slice(-3).join(" ");
    throw new GoogleError(`gcloud couldn't give this Mac's Application Default Credentials a token. ${why}`, 401, SCOPE_FIX);
  }
}

/** Which Google account the credentials are, and whether they carry Analytics. */
export async function whoAmI(): Promise<{ email: string; analytics: boolean } | null> {
  try {
    const t = await token();
    const r = await fetch(`https://oauth2.googleapis.com/tokeninfo?access_token=${t}`);
    const j = (await r.json()) as { email?: string; scope?: string };
    return { email: j.email ?? "unknown account", analytics: (j.scope ?? "").includes("analytics") };
  } catch {
    return null;
  }
}

export async function call<T>(url: string, body?: unknown): Promise<T> {
  const t = await token();
  const res = await fetch(url, {
    method: body === undefined ? "GET" : "POST",
    headers: {
      Authorization: `Bearer ${t}`,
      "x-goog-user-project": PROJECT,
      ...(body === undefined ? {} : { "Content-Type": "application/json" }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    cache: "no-store",
  });
  const j = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg: string = j?.error?.message ?? `HTTP ${res.status}`;
    let fix: string | undefined;
    if (/insufficient authentication scopes|ACCESS_TOKEN_SCOPE_INSUFFICIENT/i.test(msg)) fix = SCOPE_FIX;
    else if (/has not been used|is disabled|SERVICE_DISABLED/i.test(msg)) {
      const api = url.includes("analyticsdata") ? "analyticsdata.googleapis.com" : url.includes("analyticsadmin") ? "analyticsadmin.googleapis.com" : "";
      if (api) fix = `gcloud services enable ${api} --project ${PROJECT}`;
    } else if (res.status === 401) {
      cached = null;
      fix = SCOPE_FIX;
    }
    throw new GoogleError(msg, res.status, fix);
  }
  return j as T;
}

// ---- Firestore (read only) ----

const memo = new Map<string, { at: number; value: unknown }>();
/** Keeps a production read for a few minutes, so a reload is not a full GET. */
export async function remember<T>(key: string, ms: number, get: () => Promise<T>): Promise<T> {
  const hit = memo.get(key);
  if (hit && Date.now() - hit.at < ms) return hit.value as T;
  const value = await get();
  memo.set(key, { at: Date.now(), value });
  return value;
}

type FsDoc = { name: string; fields?: Record<string, { stringValue?: string; integerValue?: string }> };

/** Every document of a collection, its `json` field parsed. */
export async function collectionJson<T>(collection: string): Promise<T[]> {
  const out: T[] = [];
  let page = "";
  do {
    const r = await call<{ documents?: FsDoc[]; nextPageToken?: string }>(
      `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/${collection}?pageSize=300${page ? `&pageToken=${page}` : ""}`,
    );
    for (const d of r.documents ?? []) {
      const raw = d.fields?.json?.stringValue;
      if (raw) {
        try {
          out.push(JSON.parse(raw) as T);
        } catch {
          /* a bad row is skipped, as the phone skips it */
        }
      }
    }
    page = r.nextPageToken ?? "";
  } while (page);
  return out;
}

// ---- GA4 ----

const DATA = "https://analyticsdata.googleapis.com/v1beta";
const ADMIN = "https://analyticsadmin.googleapis.com/v1beta";

export type Property = { id: string; name: string };

export async function property(): Promise<Property> {
  return remember("ga-property", 30 * 60_000, async () => {
    const pinned = process.env.GA4_PROPERTY_ID;
    type Summary = { propertySummaries?: { property: string; displayName: string }[] };
    const r = await call<{ accountSummaries?: Summary[] }>(`${ADMIN}/accountSummaries?pageSize=200`);
    const all = (r.accountSummaries ?? []).flatMap((a) =>
      (a.propertySummaries ?? []).map((p) => ({ id: p.property.replace("properties/", ""), name: p.displayName })),
    );
    const pick =
      (pinned && all.find((p) => p.id === pinned)) ||
      (pinned ? { id: pinned, name: `property ${pinned}` } : null) ||
      all.find((p) => /daily|peeplet/i.test(p.name)) ||
      all[0];
    if (!pick) throw new GoogleError("This account can read no Google Analytics property.", 404);
    return pick;
  });
}

export async function registered(prop: string): Promise<{ dims: Set<string>; mets: Set<string> }> {
  const [d, m] = await Promise.all([
    call<{ customDimensions?: { parameterName: string }[] }>(`${ADMIN}/properties/${prop}/customDimensions?pageSize=200`),
    call<{ customMetrics?: { parameterName: string }[] }>(`${ADMIN}/properties/${prop}/customMetrics?pageSize=200`),
  ]);
  return {
    dims: new Set((d.customDimensions ?? []).map((x) => x.parameterName)),
    mets: new Set((m.customMetrics ?? []).map((x) => x.parameterName)),
  };
}

export type Row = { dims: string[]; mets: number[] };

export async function report(prop: string, body: Record<string, unknown>): Promise<Row[]> {
  type R = { rows?: { dimensionValues?: { value: string }[]; metricValues?: { value: string }[] }[] };
  const r = await call<R>(`${DATA}/properties/${prop}:runReport`, { limit: 10000, ...body });
  return (r.rows ?? []).map((row) => ({
    dims: (row.dimensionValues ?? []).map((v) => v.value),
    mets: (row.metricValues ?? []).map((v) => Number(v.value)),
  }));
}
