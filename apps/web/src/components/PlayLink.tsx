"use client";
import { useEffect, useState } from "react";
import { continueLabel, readLocalProgress } from "@/lib/progress.ts";
import { browserStorage } from "@/lib/storage.ts";

// The label depends on this browser's save, so it starts generic on the
// server and updates after hydration. A plain <a>: /play needs a fresh page.
export function PlayLink() {
  const [label, setLabel] = useState("Play chapter 1");
  useEffect(() => {
    const text = continueLabel(readLocalProgress(browserStorage()));
    if (text) setLabel(text);
  }, []);
  return (
    <a className="button" href="/play">
      {label}
    </a>
  );
}
