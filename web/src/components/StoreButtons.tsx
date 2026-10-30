import { useTranslations } from "next-intl";
import { IOS_URL, PLAY_URL } from "@/lib/siteUrl";

function IconGooglePlay() {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M3.609 1.814 13.792 12 3.61 22.186a.996.996 0 0 1-.61-.92V2.734a1 1 0 0 1 .609-.92Zm10.89 10.893 2.302 2.302-10.937 6.301 8.635-8.603Zm3.199-3.183 2.654 1.529a1 1 0 0 1 0 1.736l-2.586 1.49-2.587-2.587 2.519-2.168Zm-3.16-3.16L5.864 1.498l10.937 6.301-2.263 2.563Z" />
    </svg>
  );
}

function IconApple() {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701" />
    </svg>
  );
}

// The two ways to get the game: an icon, a small line, the store's name.
export function StoreButtons() {
  const t = useTranslations("site");
  return (
    <div className="get">
      <a className="store primary" href={PLAY_URL} rel="noopener">
        <IconGooglePlay />
        <span><small>{t("androidEyebrow")}</small>{t("androidCta")}</span>
      </a>
      <a className="store" href={IOS_URL} rel="noopener">
        <IconApple />
        <span><small>{t("iosEyebrow")}</small>{t("iosCta")}</span>
      </a>
    </div>
  );
}
