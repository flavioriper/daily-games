// admin/layout.dev.tsx: the local admin page, seen only by `next dev`
// (next.config.mjs, pageExtensions). It lives outside [locale], so it brings
// its own <html>; the root layout is a pass-through.
import type { Metadata } from "next";
import Link from "next/link";
import "./admin.css";

export const metadata: Metadata = {
  title: "Peeplet admin",
  robots: { index: false, follow: false },
};

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="admin">
        <nav className="nav">
          <span className="kicker">Peeplet admin · local</span>
          <Link href="/admin">Soundtrack</Link>
          <Link href="/admin/games">Games</Link>
        </nav>
        {children}
      </body>
    </html>
  );
}
