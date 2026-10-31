import Anthropic from "@anthropic-ai/sdk";
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
 *   VERTEX_TOKEN_COMMAND  a command that prints a token, run for each
 *                         drawing (a login's token outlives no long run)
 *
 *   ANTHROPIC_API_KEY     when set, an "anthropic/..." model is asked of
 *                         Anthropic's own API (askAnthropic) and not
 *                         OpenRouter; every other model stays on OpenRouter
 *
 * The writer is Haiku and the reviewer Opus, both Anthropic's since
 * 2026-10-14 (the user's call: it was a reviewer of another maker, since one
 * of the writer's family can share its mistakes). `off` as
 * DAILY_MODEL means there is no model, as does a missing key or running
 * against the emulator suite; available() says so before anybody builds a
 * prompt.
 */

export const DEFAULT_MODEL = "anthropic/claude-haiku-5.5";
/** Opus reads every quiz and jelly since 2026-10-14 (the user: "use the
 *  opus to check quiz and jelly"), through Anthropic's own API; it was
 *  openai/gpt-6-luna, picked so the reviewer was not of the writer's family. */
export const DEFAULT_REVIEW_MODEL = "anthropic/claude-opus-5.5";
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
  /** A model by name, over the role's. */
  model?: string;
}

/** What the requests of this process have cost so far, in US dollars, by
 *  OpenRouter's own count (`usage.cost`). */
let spent = 0;
/** Tokens Anthropic's API reported (cost() prices them at ANTHROPIC_PRICE,
 *  which is not what a bill says: the bench prints these as well). */
const used = {input: 0, output: 0};
export function cost(): number {
  return spent;
}
export function tokens(): {input: number; output: number} {
  return {...used};
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

function anthropicKey(): string {
  return (process.env.ANTHROPIC_API_KEY ?? "").trim();
}

function bedrockKey(): string {
  return (process.env.AWS_BEARER_TOKEN_BEDROCK ?? "").trim();
}

export function available(): boolean {
  if (modelFor() === "off") return false;
  // A key for OpenRouter or Anthropic, a Google Cloud project for Vertex's
  // models, a Bedrock API key for Amazon's: any one is a model to ask.
  if (key() === "" && anthropicKey() === "" && vertexProject() === "" && bedrockKey() === "") return false;
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
      "X-Title": "Peeplet: Daily Puzzles",
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
  const model = a.model ?? modelFor(a.role);
  const direct = anthropicModel(model);
  if (direct !== null) return askAnthropic<T>(direct, a);
  // The clouds' own models, by prefix (the labs of 2026-10-30, when the
  // Anthropic balance ran out: Google's on Vertex AI for the Google Cloud
  // credits, Amazon's on Bedrock for the AWS credits).
  if (model.startsWith("vertex/")) return askGemini<T>(model.slice("vertex/".length), a);
  if (model.startsWith("bedrock/")) return askNova<T>(model.slice("bedrock/".length), a);
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

/** Anthropic's own id for an OpenRouter "anthropic/..." name when its key
 *  is set ("anthropic/claude-opus-5.5" is "claude-opus-5-5"), else null. */
export function anthropicModel(model: string): string | null {
  if (anthropicKey() === "" || !model.startsWith("anthropic/")) return null;
  return model.slice("anthropic/".length).replace(/\./g, "-");
}

/** US dollars a million tokens in and out, Anthropic's list prices
 *  (2026-10), so cost() still counts what is asked here. */
const ANTHROPIC_PRICE: Record<string, [number, number]> = {
  "claude-opus-5-5": [4, 20],
  "claude-sonnet-5-5": [2, 10],
  "claude-haiku-5-5": [0.1, 0.5],
};

let anthropic: Anthropic | null = null;

/** ask(), of Anthropic's API: the schema held by structured outputs, the
 *  pictures as base64 images, and a decline by a safety classifier rerun
 *  on the model the API picks for it (server-side fallback, the Opus
 *  models only). */
async function askAnthropic<T>(model: string, a: Ask): Promise<T> {
  anthropic ??= new Anthropic({apiKey: anthropicKey(), timeout: TIMEOUT_MS});
  const images = (a.images ?? []).map((url) => {
    const got = /^data:(image\/(?:png|jpeg|gif|webp));base64,(.+)$/s.exec(url);
    if (got === null) throw new Error("a picture that is not a data: URL");
    return {type: "image" as const, source: {type: "base64" as const, media_type: got[1] as "image/png", data: got[2]}};
  });
  const opus = model.startsWith("claude-opus");
  const stream = anthropic.beta.messages.stream({
    model,
    max_tokens: 32000,
    system: a.system,
    messages: [{role: "user", content: [...images, {type: "text", text: a.prompt}]}],
    output_config: {effort: "medium", format: {type: "json_schema", schema: a.schema}},
    ...(opus ? {betas: ["server-side-fallback-2026-07-01"], fallbacks: "default" as const} : {}),
  });
  const out = await stream.finalMessage();
  const price = ANTHROPIC_PRICE[out.model] ?? ANTHROPIC_PRICE[model] ?? [0, 0];
  used.input += out.usage.input_tokens;
  used.output += out.usage.output_tokens;
  spent += (out.usage.input_tokens * price[0] + out.usage.output_tokens * price[1]) / 1e6;
  if (out.stop_reason !== "end_turn") throw new Error(`${model} stopped on ${out.stop_reason}`);
  const text = out.content.map((b) => b.type === "text" ? b.text : "").join("");
  return jsonIn(text) as T;
}

/** US dollars a million tokens in and out for the clouds' own models
 *  (Google's list 2026-10-28, Amazon's), so cost() counts the labs. */
const GEMINI_PRICE: Record<string, [number, number]> = {
  "gemini-4-argon": [2, 10],
  "gemini-3.1-pro-preview": [2, 12],
  "gemini-3.8-flash": [0.75, 3.75],
  "gemini-3.6-flash": [0.75, 3.75],
  "gemini-3.5-flash-lite": [0.3, 2.5],
  "gemini-2.5-pro": [1.25, 10],
  "gemini-2.5-flash": [0.3, 2.5],
};
const NOVA_PRICE: Record<string, [number, number]> = {
  "nova-2-lite": [0.3, 2.5],
  "nova-pro": [0.8, 3.2],
  "nova-lite": [0.06, 0.24],
};

/** How long one Gemini request is waited for before it is asked again. */
const GEMINI_TRY_MS = 90000;

/** The schema told in words, for a model that cannot be held to one. */
function schemaTold(a: Ask): string {
  return `${a.system}\n\nAnswer with one JSON object and nothing else, in exactly this JSON schema:\n${JSON.stringify(a.schema)}`;
}

/** A data: URL's kind and bytes, as the clouds' APIs want them apart. */
function dataUrl(url: string): {mime: string; format: string; data: string} {
  const got = /^data:(image\/(png|jpeg|gif|webp));base64,(.+)$/s.exec(url);
  if (got === null) throw new Error("a picture that is not a data: URL");
  return {mime: got[1], format: got[2], data: got[3]};
}

/** ask(), of a Gemini on Vertex AI ("vertex/gemini-4-argon"): the schema
 *  held by responseJsonSchema, the pictures inline, thinking at the medium
 *  level, and when the schema is refused (HTTP 400) plain JSON with the
 *  schema told. Thought tokens are output tokens on the bill. */
async function askGemini<T>(model: string, a: Ask): Promise<T> {
  const parts = [...(a.images ?? []).map((u) => {
    const d = dataUrl(u);
    return {inlineData: {mimeType: d.mime, data: d.data}};
  }), {text: a.prompt}];
  const body = (held: boolean) => ({
    systemInstruction: {parts: [{text: held ? a.system : schemaTold(a)}]},
    contents: [{role: "user", parts}],
    generationConfig: {
      responseMimeType: "application/json",
      maxOutputTokens: 32000,
      thinkingConfig: {thinkingLevel: "MEDIUM"},
      ...(held ? {responseJsonSchema: a.schema} : {}),
    },
  });
  const url = `https://aiplatform.googleapis.com/v1/projects/${vertexProject()}/locations/global/publishers/google/models/${model}:generateContent`;
  // The global endpoint now and then holds a request for minutes with no
  // byte sent (2026-10-30: one in four of a trivial question), while the
  // same question answers in seconds asked again: a request is given 90 s
  // and asked three times before it is a failure.
  const send = async (b: unknown) => {
    for (let attempt = 0; ; attempt++) {
      try {
        return await fetch(url, {
          method: "POST",
          headers: {"Authorization": `Bearer ${await vertexToken()}`, "Content-Type": "application/json"},
          body: JSON.stringify(b),
          signal: AbortSignal.timeout(GEMINI_TRY_MS),
        });
      } catch (e) {
        if (attempt >= 2 || !/Timeout|abort/i.test(String((e as Error)?.name ?? e))) throw e;
        console.error(`${model}: no answer in ${GEMINI_TRY_MS / 1000} s; asked again`);
      }
    }
  };
  let held = true;
  let res = await send(body(true));
  if (res.status === 400) {
    console.error(`${model}: the schema was refused (${(await res.text()).slice(0, 160)}); asked for JSON`);
    held = false;
    res = await send(body(false));
  }
  // Vertex answers 429 ("Resource exhausted") to a project's bursts, as it
  // does the drawings (drawOnVertex): asked again after a wait, it answers.
  for (let wait = 20; res.status === 429 && wait <= 80; wait *= 2) {
    await new Promise((r) => setTimeout(r, wait * 1000));
    res = await send(body(held));
  }
  if (!res.ok) throw new Error(`${model}: HTTP ${res.status} ${(await res.text()).slice(0, 400)}`);
  const out = await res.json() as {
    candidates?: {finishReason?: string; content?: {parts?: {text?: string; thought?: boolean}[]}}[];
    usageMetadata?: {promptTokenCount?: number; candidatesTokenCount?: number; thoughtsTokenCount?: number}};
  const u = out.usageMetadata ?? {};
  const inTok = u.promptTokenCount ?? 0;
  const outTok = (u.candidatesTokenCount ?? 0) + (u.thoughtsTokenCount ?? 0);
  const price = GEMINI_PRICE[model] ?? [0, 0];
  used.input += inTok;
  used.output += outTok;
  spent += (inTok * price[0] + outTok * price[1]) / 1e6;
  const c = out.candidates?.[0];
  if (c?.finishReason !== "STOP") throw new Error(`${model} stopped on ${c?.finishReason ?? "nothing"}`);
  const text = (c.content?.parts ?? []).filter((p) => p.thought !== true).map((p) => p.text ?? "").join("");
  return jsonIn(text) as T;
}

/** ask(), of an Amazon Nova on Bedrock ("bedrock/global.amazon.nova-2-lite-v1:0",
 *  the global profile: the regional one answers 4096 tokens at most): the
 *  schema held by a forced tool, which Nova decodes under the schema's
 *  grammar, the pictures as bytes, reasoning at the medium effort; when
 *  the tool is refused (HTTP 400) plain JSON with the schema told. Signed
 *  with the Bedrock API key in AWS_BEARER_TOKEN_BEDROCK, in AWS_REGION. */
async function askNova<T>(model: string, a: Ask): Promise<T> {
  const region = (process.env.AWS_REGION ?? "").trim() || "us-east-1";
  const images = (a.images ?? []).map((u) => {
    const d = dataUrl(u);
    return {image: {format: d.format, source: {bytes: d.data}}};
  });
  const body = (held: boolean) => ({
    system: [{text: held ? a.system : schemaTold(a)}],
    messages: [{role: "user", content: [...images, {text: a.prompt}]}],
    inferenceConfig: {maxTokens: MAX_TOKENS},
    additionalModelRequestFields: {reasoningConfig: {type: "enabled", maxReasoningEffort: "medium"}},
    ...(held ? {toolConfig: {
      tools: [{toolSpec: {name: "answer", description: "The one answer, in its schema.", inputSchema: {json: a.schema}}}],
      toolChoice: {tool: {name: "answer"}},
    }} : {}),
  });
  const url = `https://bedrock-runtime.${region}.amazonaws.com/model/${model}/converse`;
  const send = (b: unknown) => fetch(url, {
    method: "POST",
    headers: {"Authorization": `Bearer ${bedrockKey()}`, "Content-Type": "application/json"},
    body: JSON.stringify(b),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  let held = true;
  let res = await send(body(true));
  // Nova now and then answers a forced tool with malformed output (seen
  // 2026-10-30 on a one-line question): asked once more before giving up
  // on the tool.
  if (res.ok && /"stopReason":"malformed_(model_output|tool_use)"/.test(await res.clone().text())) {
    console.error(`${model}: malformed answer to the tool; asked again`);
    res = await send(body(true));
  }
  if (res.status === 400) {
    console.error(`${model}: the tool was refused (${(await res.text()).slice(0, 160)}); asked for JSON`);
    held = false;
    res = await send(body(false));
  }
  if (res.status === 429) {
    await new Promise((r) => setTimeout(r, 20000));
    res = await send(body(held));
  }
  if (!res.ok) throw new Error(`${model}: HTTP ${res.status} ${(await res.text()).slice(0, 400)}`);
  const out = await res.json() as {
    stopReason?: string;
    output?: {message?: {content?: {text?: string; toolUse?: {input?: unknown}}[]}};
    usage?: {inputTokens?: number; outputTokens?: number}};
  const inTok = out.usage?.inputTokens ?? 0;
  const outTok = out.usage?.outputTokens ?? 0;
  const price = Object.entries(NOVA_PRICE).find(([k]) => model.includes(k))?.[1] ?? [0, 0];
  used.input += inTok;
  used.output += outTok;
  spent += (inTok * price[0] + outTok * price[1]) / 1e6;
  const content = out.output?.message?.content ?? [];
  const tool = content.find((b) => b.toolUse !== undefined)?.toolUse?.input;
  if (held) {
    if (out.stopReason === "tool_use" && tool !== undefined && typeof tool === "object") return tool as T;
    // Malformed twice: plain JSON, the schema told, as the last resort.
    console.error(`${model} stopped on ${out.stopReason ?? "nothing"} without the answer; asked for JSON`);
    const plain = await send(body(false));
    if (!plain.ok) throw new Error(`${model}: HTTP ${plain.status} ${(await plain.text()).slice(0, 400)}`);
    const p = await plain.json() as typeof out;
    used.input += p.usage?.inputTokens ?? 0;
    used.output += p.usage?.outputTokens ?? 0;
    spent += ((p.usage?.inputTokens ?? 0) * price[0] + (p.usage?.outputTokens ?? 0) * price[1]) / 1e6;
    if (p.stopReason !== "end_turn") throw new Error(`${model} stopped on ${p.stopReason ?? "nothing"}`);
    return jsonIn((p.output?.message?.content ?? []).map((b) => b.text ?? "").join("")) as T;
  }
  if (out.stopReason !== "end_turn") throw new Error(`${model} stopped on ${out.stopReason ?? "nothing"}`);
  return jsonIn(content.map((b) => b.text ?? "").join("")) as T;
}

/** Vertex AI's name for the image model, which has no maker's prefix. */
export const DEFAULT_VERTEX_IMAGE_MODEL = "gemini-2.5-flash-image";

function vertexProject(): string {
  return (process.env.VERTEX_PROJECT ?? "").trim();
}

/** The model the boards whose pictures are shapes draw with (Yarn Hoop's
 *  low-poly, Gumdrop's stickers; DAILY_SHAPES_MODEL): flash on Vertex,
 *  whose quota is not the pixel pictures' (gemini-3-pro-image answered 429
 *  for an hour after a day's drawings, 2026-10-16), and which draws flat
 *  facets and stickers as cleanly. */
export function shapesModel(): string {
  return (process.env.DAILY_SHAPES_MODEL ?? "").trim() ||
    (vertexProject() !== "" ? DEFAULT_VERTEX_IMAGE_MODEL : DEFAULT_IMAGE_MODEL);
}

export function imageModel(): string {
  return (process.env.DAILY_IMAGE_MODEL ?? "").trim() ||
    (vertexProject() !== "" ? DEFAULT_VERTEX_IMAGE_MODEL : DEFAULT_IMAGE_MODEL);
}

/** A token Vertex AI takes: the one handed in, or the process's own
 *  identity's (the function's service account when deployed). An API key is
 *  refused there ("API keys are not supported by this API", 2026-10-13). */
async function vertexToken(): Promise<string> {
  // A login's token lives an hour, and gcloud hands out the one it holds:
  // a run on this Mac names the command that prints one, asked each drawing.
  const command = (process.env.VERTEX_TOKEN_COMMAND ?? "").trim();
  if (command !== "") {
    const {execSync} = await import("child_process");
    return execSync(command, {encoding: "utf8"}).trim();
  }
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
async function drawOnVertex(prompt: string, model = imageModel(), o: DrawOptions = {}): Promise<Drawing> {
  let res = await askVertex(model, prompt, o);
  // The bigger image models answer 429 to a project's first requests in a
  // row (2026-10-14, gemini-3-pro-image): asked again after a wait, they draw.
  for (let wait = 20; res.status === 429 && wait <= 80; wait *= 2) {
    await new Promise((r) => setTimeout(r, wait * 1000));
    res = await askVertex(model, prompt, o);
  }
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

/** A square picture unless told (gemini-3-pro-image answers 1408 by 768
 *  when not), with `o.images` laid before the words. */
async function askVertex(model: string, prompt: string, o: DrawOptions = {}): Promise<Response> {
  const shown = (o.images ?? []).map((d) => ({inlineData: {mimeType: d.mime, data: d.bytes.toString("base64")}}));
  return fetch(
    `https://aiplatform.googleapis.com/v1/projects/${vertexProject()}/locations/global/publishers/google/models/${model}:generateContent`, {
      method: "POST",
      headers: {"Authorization": `Bearer ${await vertexToken()}`, "Content-Type": "application/json"},
      body: JSON.stringify({
        contents: [{role: "user", parts: [...shown, {text: prompt}]}],
        generationConfig: {responseModalities: ["TEXT", "IMAGE"], imageConfig: {aspectRatio: o.aspect ?? "1:1"}},
      }),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
}

/** What a drawing is asked with besides its words: pictures the model is
 *  shown (a style to keep, a drawing to redraw) and the shape it answers
 *  in ("21:9"; Vertex only, OpenRouter's models draw what they draw). */
export interface DrawOptions {
  images?: Drawing[];
  aspect?: string;
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
export async function draw(prompt: string, model = imageModel(), o: DrawOptions = {}): Promise<Drawing> {
  if (!available()) throw new Error("no model");
  if (vertexProject() !== "") return drawOnVertex(prompt, model, o);
  const content = o.images === undefined ? prompt : [{type: "text", text: prompt},
    ...o.images.map((d) => ({type: "image_url", image_url: {url: `data:${d.mime};base64,${d.bytes.toString("base64")}`}}))];
  const res = await post({model, modalities: ["image", "text"], messages: [{role: "user", content}]});
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
