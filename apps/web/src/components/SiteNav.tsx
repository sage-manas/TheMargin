"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

// /play is a plain link: the engine needs a fresh document every time it starts.
export function SiteNav() {
  const path = usePathname();
  const current = (href: string) => (path === href ? "page" : undefined);
  return (
    <nav className="site-nav" aria-label="Main">
      <a href="/play">Play</a>
      <Link href="/chapters" aria-current={current("/chapters")}>
        Chapters
      </Link>
      <Link href="/settings" aria-current={current("/settings")}>
        Settings
      </Link>
    </nav>
  );
}
