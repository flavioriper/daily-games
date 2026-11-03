// /admin/music/<id>: a track's .ogg straight from assets/music, with byte
// ranges so the player can seek. `next dev` only, like the rest of /admin.
import { readFileSync } from "node:fs";
import path from "node:path";
import { MUSIC_DIR } from "@/lib/soundtrack";

export const dynamic = "force-dynamic";

export async function GET(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!/^\w+$/.test(id)) return new Response("Not found", { status: 404 });
  let data: Buffer;
  try {
    data = readFileSync(path.join(MUSIC_DIR, `${id}.ogg`));
  } catch {
    return new Response("Not found", { status: 404 });
  }
  const head = { "Content-Type": "audio/ogg", "Accept-Ranges": "bytes", "Cache-Control": "no-store" };
  const range = req.headers.get("range")?.match(/bytes=(\d*)-(\d*)/);
  if (range) {
    const start = range[1] ? Number(range[1]) : 0;
    const end = range[2] ? Math.min(Number(range[2]), data.length - 1) : data.length - 1;
    return new Response(new Uint8Array(data.subarray(start, end + 1)), {
      status: 206,
      headers: { ...head, "Content-Range": `bytes ${start}-${end}/${data.length}`, "Content-Length": String(end - start + 1) },
    });
  }
  return new Response(new Uint8Array(data), { headers: { ...head, "Content-Length": String(data.length) } });
}
