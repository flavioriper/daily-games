import {ask} from "./generate";
import type {Thing} from "./theme";

/**
 * The background colour a thing is drawn on, for the night's pictures
 * (hoop.ts, jelly.ts). The reader floods the board from the picture's edge,
 * so a thing with the board's own colour in it (a green frog on a green
 * screen) has its body eaten. The key is therefore chosen for each thing: the
 * one of three that lies farthest from every colour the thing has.
 */

export type Key = "green" | "magenta" | "cyan";

export const KEY_HEX: Record<Key, string> = {green: "#00FF00", magenta: "#FF00FF", cyan: "#00FFFF"};

const KEY_NAME: Record<Key, string> = {green: "green-screen", magenta: "magenta", cyan: "cyan"};

/** The words a drawing's background is asked in. */
export function keyWords(key: Key): string {
  return `a plain flat solid pure ${KEY_NAME[key]} chroma key background (${KEY_HEX[key]}) filling the whole picture edge to edge`;
}

const SYSTEM = `You choose the background colour a small picture of one thing is drawn on, and say whether the thing is a creature.

The background is one of three keys: green (#00FF00), magenta (#FF00FF) or cyan (#00FFFF). The picture is later cut out of it, so the key must be the one farthest from every colour the thing has: a green or teal thing is drawn on magenta, a pink, purple or red thing on cyan or green, a blue thing on green or magenta. Where several fit, take the one farthest from the thing's largest parts.

creature is true for an animal or a character with a face, and false for an object.`;

const SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["key", "creature"],
  properties: {
    key: {type: "string", enum: ["green", "magenta", "cyan"]},
    creature: {type: "boolean"},
  },
};

/** The key by the words of the description alone, for a day the model
 *  cannot be asked. */
function byWords(draw: string): Key {
  const words = draw.toLowerCase();
  if (/\b(green|lime|teal|mint|olive|turquoise)\b/.test(words)) return "magenta";
  if (/\b(pink|magenta|purple|violet|red|rose)\b/.test(words)) return "cyan";
  return "green";
}

/** The key a thing is drawn on, and whether it is a creature (a creature
 *  keeps its face; an object is told it has none). The write model is asked
 *  once; on any error the key comes from the words of `draw` and the thing
 *  is no creature. A theme that says `creature` itself keeps it. */
export async function keyFor(thing: Thing): Promise<{key: Key; creature: boolean}> {
  try {
    const got = await ask<{key: string; creature: boolean}>({
      system: SYSTEM, prompt: thing.draw, schema: SCHEMA, role: "write",
    });
    if (got.key !== "green" && got.key !== "magenta" && got.key !== "cyan") throw new Error(`key ${got.key}`);
    return {key: got.key, creature: thing.creature ?? got.creature === true};
  } catch {
    return {key: byWords(thing.draw), creature: thing.creature ?? false};
  }
}
