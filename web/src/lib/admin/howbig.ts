// howbig.ts: How Big? as the game has it now, for the local admin page.
// Specs from ui/registry.gd and puzzles/how_big_state.gd, the bundled library
// from content/how_big*.json, the night's pool from Firestore `things/`, and
// the players from GA4 (the events the game already sends).
import { collectionJson, property, registered, remember, report, type Row } from "./google";
import { en, gdConst, read, registry } from "./repo";

export const ID = "how_big";

export type Shape = { w: number; h: number; loops: number[][] };
export type Thing = {
  id: string;
  name: string;
  kind: string;
  size_m: number;
  measure: string;
  what: string;
  from: number;
  to: number;
  fact: string;
  source: string;
  shape: Shape | null;
  born?: number;
  credit?: string;
};

export function specs() {
  const entry = registry().find((e) => e.id === ID);
  const src = read("puzzles/how_big_state.gd");
  const c = <T,>(n: string) => gdConst<T>(src, n);
  const levels = [...(entry?.block.matchAll(/\{"difficulty": (\d), "name": "(\w+)", "line": "(\w+)"\}/g) ?? [])].map(
    (m) => ({ d: Number(m[1]), name: m[2], line: en(m[3]) }),
  );
  const field = (f: string) => entry?.block.match(new RegExp(`^\\t\\t"${f}": "([^"]*)"`, "m"))?.[1] ?? "";
  return {
    title: entry?.title ?? "How Big?",
    skill: entry?.skill ?? "",
    footer: field("footer"),
    blurb: en(field("blurb")),
    motto: en(field("motto")),
    // The game fills %d with the band's rounds; here it reads "5 (7 on Insane)".
    rules: [en("HB_RULES").replace("%d", "5 (7 on Insane)").replace(/%%/g, "%"), en("HB_RULES_TAPE"), en("HB_RULES_LADDER")]
      .filter((x) => !x.startsWith("HB_"))
      .join("\n\n"),
    script: field("script"),
    levels,
    rounds: c<number[]>("ROUNDS") ?? [],
    hints: c<number[]>("HINTS_BY") ?? [],
    hearts: c<number[]>("HEARTS_BY") ?? [],
    spread: c<number[][]>("SPREAD") ?? [],
    curve: c<number[][]>("CURVE") ?? [],
    grades: (c<[number, string][]>("GRADES") ?? []).map(([at, key]) => ({ at, word: en(key) })),
    starAt: c<number[]>("STAR_AT") ?? [],
    missRatio: c<number>("MISS_RATIO"),
    runFrom: c<number>("RUN_FROM"),
    likeFrom: c<number>("LIKE_FROM"),
    lot: c<number>("LOT"),
  };
}

export function library(): Thing[] {
  const items = (JSON.parse(read("content/how_big.json")) as { items: Record<string, unknown>[] }).items;
  const shapes = JSON.parse(read("content/how_big_shapes.json")) as Record<string, Shape>;
  return items.map((t) => ({
    id: String(t.id),
    name: en(String(t.label)) || String(t.name_en),
    kind: String(t.kind),
    size_m: Number(t.size_m),
    measure: String(t.measure),
    what: String(t.what_en ?? ""),
    from: Number(t.from),
    to: Number(t.to),
    fact: String(t.fact_en ?? ""),
    source: String(t.source ?? ""),
    shape: shapes[String(t.id)] ?? null,
  }));
}

type PoolRow = {
  id: string;
  kind?: string;
  size_m: number;
  measure: string;
  from: number;
  to: number;
  source: string;
  born: number;
  credit: string;
  shape: Shape;
  name?: Record<string, string>;
  names?: Record<string, string>;
  fact?: Record<string, string> | string;
  facts?: Record<string, string>;
  what?: Record<string, string> | string;
  [k: string]: unknown;
};

const word = (v: unknown): string => {
  if (typeof v === "string") return v;
  if (v && typeof v === "object") return String((v as Record<string, string>).en ?? Object.values(v)[0] ?? "");
  return "";
};

/** The night's kept things (server/functions/src/things.ts), newest first. */
export async function pool(): Promise<Thing[]> {
  const rows = await remember("things", 5 * 60_000, () => collectionJson<PoolRow>("things"));
  return rows
    .map((t) => ({
      id: t.id,
      name: word(t.name ?? t.names ?? t.name_en ?? t.id),
      kind: String(t.kind ?? ""),
      size_m: Number(t.size_m),
      measure: String(t.measure ?? ""),
      what: word(t.what ?? t.what_en),
      from: Number(t.from ?? 0),
      to: Number(t.to ?? 1),
      fact: word(t.fact ?? t.facts ?? t.fact_en),
      source: String(t.source ?? ""),
      shape: t.shape ?? null,
      born: Number(t.born),
      credit: String(t.credit ?? ""),
    }))
    .sort((a, b) => (b.born ?? 0) - (a.born ?? 0) || a.name.localeCompare(b.name));
}

/** Things a batch run made (tools/how_big/batch_things.sh) and not folded in
 *  yet: build/how_big_batch/pool.json less the night's own. Null with no batch. */
export function batch(): Thing[] | null {
  let rows: PoolRow[];
  let night: string[];
  try {
    rows = JSON.parse(read("build/how_big_batch/pool.json")) as PoolRow[];
    night = JSON.parse(read("build/how_big_batch/night_ids.json")) as string[];
  } catch {
    return null;
  }
  const shipped = new Set(library().map((t) => t.id));
  return rows
    .filter((t) => !night.includes(t.id) && !shipped.has(t.id.replace(/^d_/, "")))
    .map((t) => ({
      id: t.id.replace(/^d_/, ""),
      name: word(t.name),
      kind: String(t.kind ?? ""),
      size_m: Number(t.size_m),
      measure: String(t.measure ?? ""),
      what: "",
      from: Number(t.from ?? 0),
      to: Number(t.to ?? 1),
      fact: word(t.fact),
      source: String(t.source ?? ""),
      shape: t.shape ?? null,
      credit: String(t.credit ?? ""),
    }))
    .sort((a, b) => a.size_m - b.size_m);
}

// ---- Players ----

export const RANGES = [
  { key: "today", label: "Today", start: "today", days: 1 },
  { key: "7", label: "7 days", start: "6daysAgo", days: 7 },
  { key: "28", label: "28 days", start: "27daysAgo", days: 28 },
  { key: "90", label: "90 days", start: "89daysAgo", days: 90 },
] as const;
export type RangeKey = (typeof RANGES)[number]["key"];

export const EVENTS = ["puzzle_start", "puzzle_complete", "puzzle_abandon", "hint_used", "board_reset", "rules_opened"];
export const NEEDED_DIMS = ["puzzle_id", "difficulty"];
export const NEEDED_METS = ["seconds", "hints"];

export type Players = {
  property: { id: string; name: string };
  dims: Record<string, boolean>;
  mets: Record<string, boolean>;
  ready: boolean;
  byBand: Map<string, Map<string, number>>; // difficulty -> event -> count
  users: Map<string, number>; // event -> players
  usersByBand: Map<string, number>; // difficulty -> players who started
  days: { date: string; starts: number; completes: number }[];
  avg: Map<string, { seconds: number | null; hints: number | null }>; // difficulty -> averages on puzzle_complete
};

export async function players(range: RangeKey): Promise<Players> {
  const prop = await property();
  const reg = await registered(prop.id);
  const dims = Object.fromEntries(NEEDED_DIMS.map((d) => [d, reg.dims.has(d)]));
  const mets = Object.fromEntries(NEEDED_METS.map((m) => [m, reg.mets.has(m)]));
  const empty: Players = {
    property: prop,
    dims,
    mets,
    ready: false,
    byBand: new Map(),
    users: new Map(),
    usersByBand: new Map(),
    days: [],
    avg: new Map(),
  };
  if (!dims.puzzle_id) return empty;

  const r = RANGES.find((x) => x.key === range)!;
  const dateRanges = [{ startDate: r.start, endDate: "today" }];
  const filter = (events: string[]) => ({
    andGroup: {
      expressions: [
        { filter: { fieldName: "customEvent:puzzle_id", stringFilter: { matchType: "EXACT", value: ID } } },
        { filter: { fieldName: "eventName", inListFilter: { values: events } } },
      ],
    },
  });
  const band = dims.difficulty ? [{ name: "customEvent:difficulty" }] : [];
  const avgMets = NEEDED_METS.filter((m) => mets[m]).map((m) => ({ name: `averageCustomEvent:${m}` }));

  const [counts, users, startUsers, days, avg] = await Promise.all([
    report(prop.id, {
      dateRanges,
      dimensions: [{ name: "eventName" }, ...band],
      metrics: [{ name: "eventCount" }],
      dimensionFilter: filter(EVENTS),
    }),
    report(prop.id, {
      dateRanges,
      dimensions: [{ name: "eventName" }],
      metrics: [{ name: "totalUsers" }],
      dimensionFilter: filter(EVENTS),
    }),
    band.length
      ? report(prop.id, { dateRanges, dimensions: band, metrics: [{ name: "totalUsers" }], dimensionFilter: filter(["puzzle_start"]) })
      : Promise.resolve([] as Row[]),
    report(prop.id, {
      dateRanges,
      dimensions: [{ name: "date" }, { name: "eventName" }],
      metrics: [{ name: "eventCount" }],
      dimensionFilter: filter(["puzzle_start", "puzzle_complete"]),
    }),
    avgMets.length
      ? report(prop.id, { dateRanges, dimensions: band, metrics: avgMets, dimensionFilter: filter(["puzzle_complete"]) })
      : Promise.resolve([] as Row[]),
  ]);

  const byBand: Players["byBand"] = new Map();
  for (const row of counts) {
    const b = band.length ? row.dims[1] : "all";
    if (!byBand.has(b)) byBand.set(b, new Map());
    byBand.get(b)!.set(row.dims[0], row.mets[0]);
  }
  const perDay = new Map<string, { starts: number; completes: number }>();
  for (const row of days) {
    const d = perDay.get(row.dims[0]) ?? { starts: 0, completes: 0 };
    if (row.dims[1] === "puzzle_start") d.starts += row.mets[0];
    else d.completes += row.mets[0];
    perDay.set(row.dims[0], d);
  }
  const series: Players["days"] = [];
  for (let i = r.days - 1; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const key = `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(d.getDate()).padStart(2, "0")}`;
    series.push({ date: key, ...(perDay.get(key) ?? { starts: 0, completes: 0 }) });
  }
  const avgMap: Players["avg"] = new Map();
  const metNames = NEEDED_METS.filter((m) => mets[m]);
  for (const row of avg) {
    const at = (m: string) => {
      const k = metNames.indexOf(m);
      return k < 0 ? null : row.mets[k];
    };
    avgMap.set(band.length ? row.dims[0] : "all", { seconds: at("seconds"), hints: at("hints") });
  }
  return {
    ...empty,
    ready: true,
    byBand,
    users: new Map(users.map((u) => [u.dims[0], u.mets[0]])),
    usersByBand: new Map(startUsers.map((u) => [u.dims[0], u.mets[0]])),
    days: series,
    avg: avgMap,
  };
}
