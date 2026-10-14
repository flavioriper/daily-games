/** tools/beads.js, copied into lib/ by `npm run build`: an image as a bead
 *  picture and the bank's rules for one. The page's Picture maker runs the
 *  same file. */
declare const Beads: {
  PALETTE: Record<string, string>;
  /** By the band's side: the side its rows may be, colours and fill. */
  RULES: Record<number, {side: number[]; colours: number[]; fill: number[]}>;
  SIZES: number[];
  optionsFor(size: number): Beads.Options;
  fillOf(rows: string[]): number;
  check(rows: string[], size: number): Beads.Check[];
  convert(rgba: Uint8Array | Uint8ClampedArray, width: number, height: number, opt: Beads.Options): {rows: string[]};
  /** Pixel art read at its own squares; null when no grid is found. */
  snap(rgba: Uint8Array | Uint8ClampedArray, width: number, height: number): Beads.Snapped | null;
  /** A snapped drawing as a band's rows, or `why` it is not one. */
  fromSnap(sn: Beads.Snapped, size: number, colours: number, scene: boolean, slack: number):
    {rows?: string[]; why?: string; w?: number; h?: number};
  /** A snapped drawing of one thing kept at its own squares: a square of
   *  its longer side plus `margin` each way, never under `least`; `w` and
   *  `h` are the thing's, `why` why there are no rows. */
  cutOut(sn: Beads.Snapped, colours: number, margin: number, least: number):
    {rows?: string[]; why?: string; w?: number; h?: number; side?: number};
};
declare namespace Beads {
  interface Options {
    size: number;
    frame: "subject" | "crop" | "pad";
    bg: "auto" | "all" | "alpha";
    tol: number;
    margin: number;
    colours: number;
    zoom: number;
    px: number;
    py: number;
    vivid: number;
  }
  interface Snapped {
    cols: number;
    rows: number;
    pitch: number[];
    mixed: number;
    fit: number;
  }
  interface Check {
    ok: boolean;
    text: string;
  }
}
export = Beads;
