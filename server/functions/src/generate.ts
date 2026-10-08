import {GoogleAuth} from "google-auth-library";

/**
 * The one place a model is asked for a day's content. A game that wants its
 * day written rather than derived hands over a prompt and the JSON schema of
 * the answer, and gets the parsed object back or an error -- never a guess.
 * What the object means, whether it is good enough to publish and what to
 * publish when it is not are the game's (see acorn.ts, the first to use it,
 * and docs/agents/turns-and-backend.md, "A day written by a model").
 *
 * The model is one Vertex AI serves from the project itself, so its cost is
 * the project's Google Cloud bill and there is no key to keep: the function
 * signs in as its own identity (which needs the Vertex AI User role,
 * tools/vertex_identity.sh), and a person's `gcloud auth application-default
 * login` does the same for a dry run. It is asked through Vertex's
 * OpenAI-compatible chat endpoint, which serves the open models (OpenAI's
 * gpt-oss among them) and Gemini alike, so which model writes is a name:
 *
 *   DAILY_MODEL           the model that writes ("openai/gpt-oss-120b-maas")
 *   DAILY_REVIEW_MODEL    the model that reviews (the writer, when unset)
 *   DAILY_MODEL_REGION    where it is asked ("us-central1"; "global" works
 *                         for the models served there)
 *
 * `off` as DAILY_MODEL means there is no model, as does running against the
 * emulator suite; available() says so before anybody builds a prompt.
 */

export const DEFAULT_MODEL = "openai/gpt-oss-120b-maas";
const DEFAULT_REGION = "us-central1";

/** The most one answer may run to. A game asks for a day in pieces well
 *  under this (acorn.ts: a band a request), since the cheap models' ceilings
 *  are low and an answer cut off at one is a failed request. */
const MAX_TOKENS = 16000;
/** A request that has not answered by now is given up on. */
const TIMEOUT_MS = 240000;

export type Role = "write" | "review";

export interface Ask {
  /** Who the model is writing for and the rules that never change. */
  system: string;
  /** Today's request. */
  prompt: string;
  /** The JSON schema of the answer. The endpoint is asked to hold the model
   *  to it; a model that cannot be held is asked for JSON and told the
   *  schema, and the caller validates what comes back either way. */
  schema: Record<string, unknown>;
  /** Which of the two models answers. */
  role?: Role;
}

function project(): string {
  return (process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? "").trim();
}

export function modelFor(role: Role = "write"): string {
  const writer = (process.env.DAILY_MODEL ?? "").trim() || DEFAULT_MODEL;
  if (role === "write") return writer;
  return (process.env.DAILY_REVIEW_MODEL ?? "").trim() || writer;
}

export function available(): boolean {
  if (modelFor() === "off") return false;
  const p = project();
  if (p === "" || p.startsWith("demo-")) return false;
  return (process.env.FIRESTORE_EMULATOR_HOST ?? "") === "";
}

function endpoint(): string {
  const region = (process.env.DAILY_MODEL_REGION ?? "").trim() || DEFAULT_REGION;
  const host = region === "global" ? "aiplatform.googleapis.com" : `${region}-aiplatform.googleapis.com`;
  return `https://${host}/v1/projects/${project()}/locations/${region}/endpoints/openapi/chat/completions`;
}

let auth: GoogleAuth | undefined;

async function token(): Promise<string> {
  auth ??= new GoogleAuth({scopes: ["https://www.googleapis.com/auth/cloud-platform"]});
  const t = await auth.getAccessToken();
  if (!t) throw new Error("no Google credentials");
  return t;
}

/** The JSON in a model's answer: the whole of it, or what stands between
 *  its first brace and its last when the model wrapped it in a fence. */
export function jsonIn(text: string): unknown {
  const from = text.indexOf("{");
  const to = text.lastIndexOf("}");
  if (from < 0 || to <= from) throw new Error("no JSON in the answer");
  return JSON.parse(text.slice(from, to + 1));
}

async function post(body: Record<string, unknown>): Promise<Response> {
  return fetch(endpoint(), {
    method: "POST",
    headers: {"Authorization": `Bearer ${await token()}`, "Content-Type": "application/json"},
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
}

/**
 * One question, one JSON answer. Throws on anything that is not a complete
 * answer: no model, no credentials, a refusal by the endpoint, an answer cut
 * off at the token limit, text with no JSON in it.
 */
export async function ask<T>(a: Ask): Promise<T> {
  if (!available()) throw new Error("no model");
  const model = modelFor(a.role);
  const told = `${a.system}\n\nAnswer with one JSON object and nothing else, in exactly this JSON schema:\n${JSON.stringify(a.schema)}`;
  const base = {
    model,
    max_tokens: MAX_TOKENS,
    messages: [{role: "system", content: told}, {role: "user", content: a.prompt}],
  };
  let res = await post({
    ...base,
    response_format: {type: "json_schema", json_schema: {name: "answer", strict: true, schema: a.schema}},
  });
  if (res.status === 400) {
    // A model the endpoint cannot hold to a schema: plain JSON, and the
    // schema it was told above.
    res = await post({...base, response_format: {type: "json_object"}});
  }
  if (!res.ok) {
    throw new Error(`${model}: HTTP ${res.status} ${(await res.text()).slice(0, 400)}`);
  }
  const out = await res.json() as {choices?: {finish_reason?: string; message?: {content?: string}}[]};
  const choice = out.choices?.[0];
  if (choice?.finish_reason !== "stop") {
    throw new Error(`${model} stopped on ${choice?.finish_reason}`);
  }
  return jsonIn(choice.message?.content ?? "") as T;
}
