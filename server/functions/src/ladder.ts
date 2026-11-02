import type {Verdict} from "./eye";

/**
 * How a drawing is read into a jelly or a hoop: who answers next, and whether
 * the same drawing is worth another ask. A Plan is told how each try ended.
 *
 * With DAILY_MAP_TIERS (cheapest first, comma separated) it is the Ladder (the
 * user, 2026-11-02): a score near the bar is tried again on the same model; a
 * far one gets a new drawing first, since a poor drawing is no mapper's fault,
 * and climbs only if the new drawing is far too; a try the board's rules
 * refused stays, then climbs after two. Without it, the Fixed plan: so many
 * asks of the reviewer on each of so many drawings, as before.
 */
export interface Plan {
  /** The next ask's model; undefined leaves it to the role. */
  model(): string | undefined;
  /** Nothing more to try. */
  done(): boolean;
  /** A drawing that could not be drawn. */
  noDrawing(): void;
  /** How a try ended, and what comes next. */
  after(t: {why: string; error?: string; verdict?: Verdict}): "again" | "redraw";
}

/** The floor is 7: 5 and 6 are near, 4 and under far. */
export const NEAR = 5;
/** Asks of each tier before the next. */
export const TIER_TRIES = [2, 2, 1];
/** A rule refused this often on one tier climbs. */
const REFUSALS = 2;
/** Drawings that may fail before a thing is given up. */
const BLANKS = 3;

class Ladder implements Plan {
  private tier = 0;
  private used = 0;
  private refusals = 0;
  private redrew = false;
  private blanks = 0;
  constructor(private tiers: string[]) {}
  model(): string {
    return this.tiers[this.tier];
  }
  done(): boolean {
    return this.tier >= this.tiers.length || this.blanks >= BLANKS;
  }
  noDrawing(): void {
    this.blanks++;
  }
  private climb(): void {
    this.tier++;
    this.used = 0;
    this.refusals = 0;
    this.redrew = false;
  }
  after(t: {why: string; error?: string; verdict?: Verdict}): "again" | "redraw" {
    this.used++;
    const out = this.used >= (TIER_TRIES[this.tier] ?? 1);
    if (t.verdict === undefined) {
      this.refusals++;
      if (out || this.refusals >= REFUSALS) this.climb();
      return "again";
    }
    if (t.verdict.score >= NEAR) {
      if (out) this.climb();
      return "again";
    }
    if (this.redrew || out) this.climb();
    else this.redrew = true;
    return "redraw";
  }
}

class Fixed implements Plan {
  private asks = 0;
  private drawings = 0;
  constructor(private most: number, private perDrawing: number) {}
  model(): undefined {
    return undefined;
  }
  done(): boolean {
    return this.drawings >= this.most;
  }
  noDrawing(): void {
    this.drawings++;
  }
  after(): "again" | "redraw" {
    if (++this.asks < this.perDrawing) return "again";
    this.asks = 0;
    this.drawings++;
    return "redraw";
  }
}

export function mapPlan(drawings: number, asks: number): Plan {
  const tiers = (process.env.DAILY_MAP_TIERS ?? "").split(",").map((m) => m.trim()).filter((m) => m !== "");
  return tiers.length > 0 ? new Ladder(tiers) : new Fixed(drawings, asks);
}
