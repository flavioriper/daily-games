// /admin, local only: what is in the game right now, read from the repo on
// every load. The soundtrack; the games are at /admin/games.
import Soundtrack from "@/components/admin/Soundtrack";
import { readSoundtrack } from "@/lib/soundtrack";

export const dynamic = "force-dynamic";

export default function AdminPage() {
  const music = readSoundtrack();
  return (
    <div className="shell">
      <header className="top">
        <h1>Soundtrack</h1>
      </header>
      <Soundtrack {...music} />
    </div>
  );
}
