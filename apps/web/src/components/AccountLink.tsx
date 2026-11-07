"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { ApiClient } from "@/lib/api.ts";

// Shows who is signed in. If the API can't be reached it shows the plain
// link, because the site works without accounts.
export function AccountLink({ current }: { current: boolean }) {
  const [name, setName] = useState<string | null>(null);
  useEffect(() => {
    const load = () =>
      new ApiClient().session().then(
        (s) => setName(s.user?.displayName ?? null),
        () => setName(null),
      );
    load();
    window.addEventListener("themargin:account", load);
    return () => window.removeEventListener("themargin:account", load);
  }, []);
  return (
    <Link href="/account" aria-current={current ? "page" : undefined} data-account-name={name ?? ""}>
      {name ?? "Sign in"}
    </Link>
  );
}
