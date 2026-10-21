import {defineConfig} from "vite";
import react from "@vitejs/plugin-react";

// tools/beads.js lives two folders up; the dev server may read it.
export default defineConfig({plugins: [react()], server: {fs: {allow: ["../.."]}}});
