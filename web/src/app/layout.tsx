// layout.tsx: root pass-through. The <html> shell lives in [locale]/layout.tsx
// so it can read the active locale; this file exists only because Next
// requires a root layout.
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Peeplet: Daily Puzzles",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return children;
}
