/**
 * Jobs side by side, at most DAILY_PARALLEL at once, their answers in the
 * items' order. One at a time when it is unset: Vertex draws about two images
 * a minute, and the night's order of work stays as it was. The Neon gateway
 * has no such limit (tools/neon_day.sh sets 4).
 */
export async function sideBySide<T, R>(items: T[], job: (item: T) => Promise<R>): Promise<R[]> {
  const most = Math.max(1, Number(process.env.DAILY_PARALLEL) || 1);
  const out: R[] = new Array(items.length);
  let next = 0;
  const worker = async () => {
    while (next < items.length) {
      const i = next++;
      out[i] = await job(items[i]);
    }
  };
  await Promise.all(Array.from({length: Math.min(most, items.length)}, worker));
  return out;
}
