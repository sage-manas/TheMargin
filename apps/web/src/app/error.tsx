"use client";
// A page that failed to render (TDD §6b): reported, with a way back.
import Link from "next/link";
import { useEffect } from "react";
import { reportError } from "@/lib/report.ts";

export default function PageError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => reportError("site", error), [error]);
  return (
    <main id="main" className="wrap page-head">
      <span className="caption">Hmm.</span>
      <h1>This page smudged</h1>
      <p>Something went wrong drawing it. It has been reported.</p>
      <p>
        <button type="button" onClick={reset}>
          Try again
        </button>{" "}
        or <Link href="/">go back to the front cover</Link>
      </p>
    </main>
  );
}
