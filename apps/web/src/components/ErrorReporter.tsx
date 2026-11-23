"use client";
// Reports uncaught errors and rejected promises on every page (TDD §6b).
import { useEffect } from "react";
import { reporter, reportError } from "@/lib/report.ts";

export function ErrorReporter() {
  useEffect(() => {
    const onError = (e: ErrorEvent) => reportError("site", e.error ?? e.message);
    const onRejection = (e: PromiseRejectionEvent) => reportError("site", e.reason);
    const onHide = () => reporter().flush();
    window.addEventListener("error", onError);
    window.addEventListener("unhandledrejection", onRejection);
    window.addEventListener("pagehide", onHide);
    return () => {
      window.removeEventListener("error", onError);
      window.removeEventListener("unhandledrejection", onRejection);
      window.removeEventListener("pagehide", onHide);
    };
  }, []);
  return null;
}
