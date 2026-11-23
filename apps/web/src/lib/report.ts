// Error reports to the API (TDD §6b): the site's own errors, the engine not
// starting, and the game's error lines. Each distinct error is sent once per
// page load, batched, with keepalive so a closing tab still sends. Reporting
// never throws and never reports itself.
import type { ClientErrorReport } from "@the-margin/contracts";
import { API_URL } from "./api.ts";

export const RELEASE = (process.env.NEXT_PUBLIC_RELEASE ?? "dev").slice(0, 40);
const MAX_PER_PAGE = 20;
const BATCH = 10;

type Source = ClientErrorReport["source"];

/** Errors that aren't ours: browser extensions, and a benign layout warning. */
export function isNoise(message: string, stack = ""): boolean {
  return /ResizeObserver loop/.test(message) || /(chrome|moz|safari(-web)?)-extension:\/\//.test(stack);
}

export type Sender = (reports: ClientErrorReport[]) => void;

const beacon: Sender = (reports) => {
  fetch(`${API_URL}/client-errors`, { method: "POST", keepalive: true, headers: { "content-type": "application/json" }, body: JSON.stringify({ reports }) }).catch(() => {});
};

export class Reporter {
  private readonly seen = new Set<string>();
  private queue: ClientErrorReport[] = [];
  private timer: ReturnType<typeof setTimeout> | null = null;
  private readonly send: Sender;
  private readonly path: () => string;
  private readonly delayMs: number;

  constructor(send: Sender = beacon, path: () => string = () => location.pathname, delayMs = 2000) {
    this.send = send;
    this.path = path;
    this.delayMs = delayMs;
  }

  report(source: Source, message: string, stack?: string): void {
    try {
      message = message.trim().slice(0, 500) || "(no message)";
      if (isNoise(message, stack)) return;
      const key = `${source}\u0000${message}`;
      if (this.seen.has(key) || this.seen.size >= MAX_PER_PAGE) return;
      this.seen.add(key);
      this.queue.push({ source, message, stack: stack?.slice(0, 4000) || undefined, path: this.path().slice(0, 200), release: RELEASE });
      if (this.queue.length >= BATCH) this.flush();
      else this.timer ??= setTimeout(() => this.flush(), this.delayMs);
    } catch {
      // Reporting must never be the next error.
    }
  }

  flush(): void {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    while (this.queue.length) this.send(this.queue.splice(0, BATCH));
  }
}

let shared: Reporter | null = null;
export const reporter = (): Reporter => (shared ??= new Reporter());

export function reportError(source: Source, err: unknown): void {
  const e = err instanceof Error ? err : null;
  reporter().report(source, e ? `${e.name}: ${e.message}` : String(err), e?.stack);
}

/**
 * The game's stderr, line by line (Godot's printErr): an `ERROR:` or
 * `SCRIPT ERROR:` line opens a report and the `at:` lines after it are its
 * stack. Warnings are ignored.
 */
export class GameErrorLines {
  private current: { message: string; stack: string[] } | null = null;
  private readonly emit: (message: string, stack: string) => void;

  constructor(emit: (message: string, stack: string) => void) {
    this.emit = emit;
  }

  line(text: string): void {
    const t = text.trimEnd();
    if (/^(SCRIPT |USER )?ERROR:/.test(t.trimStart())) {
      this.end();
      this.current = { message: t.trim(), stack: [] };
      queueMicrotask(() => this.end());
    } else if (this.current && /^\s+at:/.test(t)) {
      this.current.stack.push(t.trim());
    }
  }

  private end(): void {
    if (this.current) this.emit(this.current.message, this.current.stack.join("\n"));
    this.current = null;
  }
}
