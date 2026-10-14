/**
 * The one place a model is asked for a day's content. A game that wants its
 * day written rather than derived hands over a prompt and the JSON schema of
 * the answer, and gets the parsed object back or an error -- never a guess.
 * What the object means, whether it is good enough to publish and what to
 * publish when it is not are the game's (see acorn.ts, the first to use it,
 * and docs/agents/turns-and-backend.md, "A day written by a model").
 *
 * The model is asked through OpenRouter's chat endpoint, which speaks one
 * dialect for every maker's models, so which model writes is a name:
 *
 *   OPENROUTER_API_KEY    the key: a secret on the deployed function, an
 *                         environment variable anywhere else
 *   DAILY_MODEL           the model that writes
 *   DAILY_REVIEW_MODEL    the model that reviews
 *   DAILY_IMAGE_MODEL     the model that draws (draw(), for pictures.ts)
 *   VERTEX_PROJECT        when set, draw() asks Vertex AI in that Google
 *                         Cloud project and not OpenRouter, so the pictures
 *                         are billed there (the project with the credits)
 *   VERTEX_ACCESS_TOKEN   a token to ask Vertex with; without one the
 *                         process's own Google identity is used
 *
 * The two defaults are cheap models of different makers on purpose: a
 * reviewer from the writer's own family shares its mistakes. `off` as
 * DAILY_MODEL means there is no model, as does a missing key or running
 * against the emulator suite; available() says so before anybody builds a
 * prompt.
 */

export const DEFAULT_MODEL = "anthropic/claude-haiku-5.5";
export const DEFAULT_REVIEW_MODEL = "openai/gpt-6-luna";
export const DEFAULT_IMAGE_MODEL = "google/gemini-3.1-flash-lite-image";
const ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";

/** The most one answer may run to, thinking included where a model thinks.
 *  A game asks for a day in pieces well under this (acorn.ts: a band a
 *  request): an answer cut off at the ceiling is a failed request. */
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
  /** Pictures shown with the request, as data: URLs. */
  images?: string[];
}

/** What the requests of this process have cost so far, in US dollars, by
 *  OpenRouter's own count (`usage.cost`). */
let spent = 0;
export function cost(): number {
  return spent;
}
function count(out: {usage?: {cost?: number}}): void {
  spent += Number(out.usage?.cost) || 0;
}

function key(): string {
  return (process.env.OPENROUTER_API_KEY ?? "").trim();
}

export function modelFor(role: Role = "write"): string {
  if (role === "review") {
    return (process.env.DAILY_REVIEW_MODEL ?? "").trim() || DEFAULT_REVIEW_MODEL;
  }
  return (process.env.DAILY_MODEL ?? "").trim() || DEFAULT_MODEL;
}

export function available(): boolean {
  if (modelFor() === "off" || key() === "") return false;
  return (process.env.FIRESTORE_EMULATOR_HOST ?? "") === "";
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
  return fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${key()}`,
      "Content-Type": "application/json",
      "X-Title": "Peeplet Daily",
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
}

/**
 * One question, one JSON answer. Throws on anything that is not a complete
 * answer: no model, no key, a refusal by the endpoint, an answer cut
 * off at the token limit, text with no JSON in it.
 */
export async function ask<T>(a: Ask): Promise<T> {
  if (!available()) throw new Error("no model");
  const model = modelFor(a.role);
  const told = `${a.system}\n\nAnswer with one JSON object and nothing else, in exactly this JSON schema:\n${JSON.stringify(a.schema)}`;
  const base = {
    model,
    max_tokens: MAX_TOKENS,
    messages: [{role: "system", content: told}, {
      role: "user",
      content: a.images === undefined ? a.prompt : [
        {type: "text", text: a.prompt},
        ...a.images.map((url) => ({type: "image_url", image_url: {url}})),
      ],
    }],
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
  const out = await res.json() as {
    choices?: {finish_reason?: string; message?: {content?: string}}[]; usage?: {cost?: number}};
  count(out);
  const choice = out.choices?.[0];
  if (choice?.finish_reason !== "stop") {
    throw new Error(`${model} stopped on ${choice?.finish_reason}`);
  }
  return jsonIn(choice.message?.content ?? "") as T;
}

/** Vertex AI's name for the image model, which has no maker's prefix. */
export const DEFAULT_VERTEX_IMAGE_MODEL = "gemini-2.5-flash-image";

function vertexProject(): string {
  return (process.env.VERTEX_PROJECT ?? "").trim();
}

export function imageModel(): string {
  return (process.env.DAILY_IMAGE_MODEL ?? "").trim() ||
    (vertexProject() !== "" ? DEFAULT_VERTEX_IMAGE_MODEL : DEFAULT_IMAGE_MODEL);
}

/** A token Vertex AI takes: the one handed in, or the process's own
 *  identity's (the function's service account when deployed). An API key is
 *  refused there ("API keys are not supported by this API", 2026-10-13). */
async function vertexToken(): Promise<string> {
  const given = (process.env.VERTEX_ACCESS_TOKEN ?? "").trim();
  if (given !== "") return given;
  const {GoogleAuth} = await import("google-auth-library");
  const token = await new GoogleAuth({scopes: ["https://www.googleapis.com/auth/cloud-platform"]}).getAccessToken();
  if (!token) throw new Error("no Google identity to ask Vertex AI with");
  return token;
}

/** draw(), asked of Vertex AI: the same model family, Google's own dialect,
 *  the picture in `candidates[0].content.parts[].inlineData`. What it cost
 *  is not in the answer, so cost() does not count it. */
async function drawOnVertex(prompt: string): Promise<Drawing> {
  const model = imageModel();
  const res = await fetch(
    `https://aiplatform.googleapis.com/v1/projects/${vertexProject()}/locations/global/publishers/google/models/${model}:generateContent`, {
      method: "POST",
      headers: {"Authorization": `Bearer ${await vertexToken()}`, "Content-Type": "application/json"},
      body: JSON.stringify({
        contents: [{role: "user", parts: [{text: prompt}]}],
        generationConfig: {responseModalities: ["TEXT", "IMAGE"]},
      }),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  if (!res.ok) {
    throw new Error(`vertex ${model}: HTTP ${res.status} ${(await res.text()).slice(0, 400)}`);
  }
  const out = await res.json() as {
    candidates?: {content?: {parts?: {inlineData?: {mimeType?: string; data?: string}}[]}}[]};
  for (const part of out.candidates?.[0]?.content?.parts ?? []) {
    if (part.inlineData?.data) {
      return {mime: part.inlineData.mimeType ?? "image/png", bytes: Buffer.from(part.inlineData.data, "base64")};
    }
  }
  throw new Error(`vertex ${model} drew nothing`);
}

export interface Drawing {
  /** "image/jpeg" or "image/png". */
  mime: string;
  bytes: Buffer;
}

/**
 * One request, one picture. An image model is asked for both kinds of
 * output and answers beside the text, not in it: read off a real answer on
 * 2026-10-13, the picture is `message.images[0].image_url.url`, a data: URL,
 * and `content` is null. Throws on anything that is not a picture.
 */
export async function draw(prompt: string): Promise<Drawing> {
  if (!available()) throw new Error("no model");
  if (vertexProject() !== "") return drawOnVertex(prompt);
  const model = imageModel();
  const res = await post({model, modalities: ["image", "text"], messages: [{role: "user", content: prompt}]});
  if (!res.ok) {
    throw new Error(`${model}: HTTP ${res.status} ${(await res.text()).slice(0, 400)}`);
  }
  const out = await res.json() as {
    choices?: {message?: {images?: {image_url?: {url?: string}}[]}}[]; usage?: {cost?: number}};
  count(out);
  const url = out.choices?.[0]?.message?.images?.[0]?.image_url?.url ?? "";
  const got = /^data:(image\/[a-z]+);base64,(.+)$/s.exec(url);
  if (got === null) throw new Error(`${model} drew nothing`);
  return {mime: got[1], bytes: Buffer.from(got[2], "base64")};
}
