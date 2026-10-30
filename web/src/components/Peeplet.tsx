import Image from "next/image";

// The page's Peeplets, rendered from the live model by
// tests/_shot_site_peeplets.gd and cut by scripts/gen_games.py; the sizes
// are the trimmed renders'. Decorative: no alt, hidden from readers.
const SIZES: Record<string, [number, number]> = {
  coral: [232, 247],
  flowers: [216, 255],
  laugh: [220, 336],
  mushroom: [241, 317],
  party: [242, 336],
  reader: [249, 290],
  sunhat: [245, 289],
  watcher: [220, 302],
};

export function Peeplet({ name, className }: { name: keyof typeof SIZES; className: string }) {
  const [width, height] = SIZES[name];
  return (
    <Image
      className={`peep ${className}`}
      src={`/peeplets/${name}.webp`}
      alt=""
      aria-hidden="true"
      width={width}
      height={height}
      loading="lazy"
    />
  );
}
