import Anthropic from "@anthropic-ai/sdk";

/**
 * The one place a model is asked for a day's content. A game that wants its
 * day written rather than derived hands over a prompt and the JSON schema of
 * the answer, and gets the parsed object back or an error -- never a guess.
 * What the object means, whether it is good enough to publish and what to
 * publish when it is not are the game's (see acorn.ts, the first to use it,
 * and docs/agents/turns-and-backend.md, "A day written by a model").
 *
 * The key is ANTHROPIC_API_KEY: a secret on the deployed function, an
 * environment variable anywhere else. Without one there is no model, and
 * available() says so before anybody builds a prompt.
 */

/** The model that writes and the model that reviews. */
export const MODEL = "claude-opus-5-5";

/** A whole day is one long answer, so it is streamed: a request that waited
 *  for all of it would outlive the SDK's own timeout. The ceiling covers the
 *  model's thinking as well as its answer, and an answer cut off at it is a
 *  failed night, so it is set well over what a day needs. */
const MAX_TOKENS = 64000;

export type Effort = "low" | "medium" | "high" | "xhigh" | "max";

export interface Ask {
  /** Who the model is writing for and the rules that never change. */
  system: string;
  /** Today's request. */
  prompt: string;
  /** The JSON schema of the answer; the API holds the model to it. */
  schema: Record<string, unknown>;
  effort?: Effort;
}

export function available(): boolean {
  return (process.env.ANTHROPIC_API_KEY ?? "").trim() !== "";
}

/**
 * One question, one JSON answer. Throws on anything that is not a complete
 * answer in the schema's shape: no key, a refusal, an answer cut off at the
 * token limit, text that does not parse.
 */
export async function ask<T>(a: Ask): Promise<T> {
  if (!available()) throw new Error("no ANTHROPIC_API_KEY");
  const client = new Anthropic({apiKey: process.env.ANTHROPIC_API_KEY!.trim()});
  const stream = client.beta.messages.stream({
    model: MODEL,
    max_tokens: MAX_TOKENS,
    system: a.system,
    messages: [{role: "user", content: a.prompt}],
    thinking: {type: "adaptive"},
    output_config: {
      effort: a.effort ?? "high",
      format: {type: "json_schema", schema: a.schema},
    },
    // A safety classifier's decline is answered by the model Anthropic
    // recommends for it, inside this same call.
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
  });
  const message = await stream.finalMessage();
  if (message.stop_reason !== "end_turn") {
    throw new Error(`model stopped on ${message.stop_reason}`);
  }
  let text = "";
  for (const block of message.content) {
    if (block.type === "text") text += block.text;
  }
  return JSON.parse(text) as T;
}
