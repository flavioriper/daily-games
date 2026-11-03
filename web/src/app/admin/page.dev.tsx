// /admin, local only: what is in the game right now, read from the repo on
// every load. First section: the soundtrack.
import Soundtrack from "@/components/admin/Soundtrack";
import { readSoundtrack } from "@/lib/soundtrack";

export const dynamic = "force-dynamic";

export default function AdminPage() {
  const music = readSoundtrack();
  return (
    <div className="shell">
      <header className="top">
        <p className="kicker">Peeplet admin · local</p>
        <h1>What&apos;s in the game</h1>
      </header>
      <Soundtrack {...music} />
    </div>
  );
}
