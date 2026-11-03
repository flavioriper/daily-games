// admin/layout.dev.tsx: the local admin page, seen only by `next dev`
// (next.config.mjs, pageExtensions). It lives outside [locale], so it brings
// its own <html>; the root layout is a pass-through.
import type { Metadata } from "next";
import "./admin.css";

export const metadata: Metadata = {
  title: "Peeplet admin",
  robots: { index: false, follow: false },
};

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="admin">{children}</body>
    </html>
  );
}
