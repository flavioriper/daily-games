/** tools/beads.js, copied into lib/ by `npm run build`: an image as a bead
 *  picture and the bank's rules for one. The page's Picture maker runs the
 *  same file. */
declare const Beads: {
  PALETTE: Record<string, string>;
  SIZES: number[];
  optionsFor(size: number): Beads.Options;
  fillOf(rows: string[]): number;
  check(rows: string[], size: number): Beads.Check[];
  convert(rgba: Uint8Array | Uint8ClampedArray, width: number, height: number, opt: Beads.Options): {rows: string[]};
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
  interface Check {
    ok: boolean;
    text: string;
  }
}
export = Beads;
