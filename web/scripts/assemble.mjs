// Lays the hosting folder: the static export, then what server/site already
// serves (/f, the privacy policy, .well-known, app-ads.txt). Its own index.html
// is gone; this page is the root now.
import { cpSync, rmSync } from "node:fs";

const out = new URL("../../server/public_site/", import.meta.url).pathname;
rmSync(out, { recursive: true, force: true });
cpSync(new URL("../out/", import.meta.url).pathname, out, { recursive: true });
cpSync(new URL("../../server/site/", import.meta.url).pathname, out, { recursive: true });
