// Cloud save sync (TDD §4.3, SAVE_SCHEMA §5). The local save is always the
// one being played; the cloud is a mirror. Every local save is pushed with
// the cloud revision it was based on. If the cloud moved on meanwhile (another
// device), the two are resolved deterministically: the loser is kept as a
// cloud backup, and if the cloud copy wins it is loaded into the game.
// Offline, pushes retry with backoff (2 s doubling to 5 min) and at once when
// the browser comes back online.
import { CloudSaveSchema, resolveConflict, SaveConflictDetailsSchema, type CloudSave, type Save } from "@the-margin/contracts";
import { ApiError, NetworkError } from "../lib/api.ts";

export type SyncState = {
  userId: string;
  /** The cloud revision the local save was last in step with; null before the first sync. */
  cloudRevision: number | null;
  /** The local save has changes the cloud hasn't seen. */
  pending: boolean;
};

export type SyncStatus = "syncing" | "synced" | "offline" | "signed-out" | "error";

export type Transport = {
  getSave(): Promise<CloudSave | null>;
  putSave(baseRevision: number | null, save: Save): Promise<{ revision: number }>;
  putBackup(ts: number, save: Save): Promise<unknown>;
};

export type SaveSyncOptions = {
  userId: string;
  transport: Transport;
  /** Persists SyncState across page loads (localStorage). */
  store: { read(): SyncState | null; write(s: SyncState): void };
  /** Sends a save that won against the local one to the game (LOAD_CLOUD_SAVE). */
  loadIntoGame(save: Save): void;
  onStatus?(status: SyncStatus): void;
  now?(): number;
  setTimer?(fn: () => void, ms: number): unknown;
  clearTimer?(handle: unknown): void;
};

export const RETRY_MIN_MS = 2_000;
export const RETRY_MAX_MS = 300_000;
const MAX_CONFLICT_ROUNDS = 3;

/** Key order differs between the game's JSON and Postgres JSONB, so compare canonically. */
export function sameSave(a: unknown, b: unknown): boolean {
  const canon = (v: unknown): unknown =>
    Array.isArray(v) ? v.map(canon) : v && typeof v === "object" ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, canon((v as Record<string, unknown>)[k])])) : v;
  return JSON.stringify(canon(a)) === JSON.stringify(canon(b));
}

export class SaveSync {
  status: SyncStatus = "syncing";
  private readonly o: Required<SaveSyncOptions>;
  private state: SyncState;
  private local: Save | null = null;
  private reconciled = false;
  private stopped = false;
  private inFlight: Promise<void> | null = null;
  private again = false;
  private attempt = 0;
  private timer: unknown = null;

  constructor(opts: SaveSyncOptions) {
    this.o = {
      onStatus: () => {},
      now: () => Date.now(),
      setTimer: (fn, ms) => setTimeout(fn, ms),
      clearTimer: (h) => clearTimeout(h as ReturnType<typeof setTimeout>),
      ...opts,
    };
    const stored = opts.store.read();
    // A different account signed in on this browser: its cloud is unrelated.
    this.state = stored?.userId === opts.userId ? stored : { userId: opts.userId, cloudRevision: null, pending: true };
  }

  /** Reconciles the save this browser has (or null) with the cloud. */
  start(local: Save | null): Promise<void> {
    this.local = local;
    return this.kick();
  }

  /** The game wrote a save (SAVE_UPDATED). */
  saveUpdated(save: Save): void {
    this.local = save;
    this.setState({ pending: true });
    void this.kick();
  }

  /** The browser is back online or the tab is visible again: retry now. */
  online(): void {
    if (this.timer === null || this.stopped) return;
    this.o.clearTimer(this.timer);
    this.timer = null;
    void this.kick();
  }

  stop(): void {
    this.stopped = true;
    if (this.timer !== null) this.o.clearTimer(this.timer);
    this.timer = null;
  }

  get syncState(): SyncState {
    return { ...this.state };
  }

  /** Runs one flush at a time; anything that arrives meanwhile triggers another. */
  private kick(): Promise<void> {
    // While a retry is scheduled it will carry the latest save; don't race it.
    if (this.stopped || this.timer !== null) return Promise.resolve();
    if (this.inFlight) {
      this.again = true;
      return this.inFlight;
    }
    this.inFlight = this.flush().finally(() => {
      this.inFlight = null;
      if (this.again && !this.stopped && this.timer === null) {
        this.again = false;
        void this.kick();
      }
    });
    return this.inFlight;
  }

  private async flush(): Promise<void> {
    this.setStatus("syncing");
    try {
      if (!this.reconciled) {
        await this.reconcile();
        this.reconciled = true;
      } else if (this.state.pending && this.local) {
        await this.push(this.local, 0);
      }
      this.attempt = 0;
      this.setStatus("synced");
    } catch (err) {
      this.fail(err);
    }
  }

  private async reconcile(): Promise<void> {
    const fetched = await this.o.transport.getSave();
    const server = fetched ? CloudSaveSchema.parse(fetched) : null;
    const local = this.local;
    if (!server) {
      if (local) await this.push(local, 0);
      return;
    }
    if (!local) {
      // A new device: play continues from the cloud.
      this.adopt(server, server.save);
      return;
    }
    if (sameSave(local, server.save)) {
      this.setState({ cloudRevision: server.revision, pending: false });
      return;
    }
    if (this.state.cloudRevision === server.revision) {
      // The cloud hasn't moved since we last synced; only we have news.
      if (this.state.pending) await this.push(local, 0);
      return;
    }
    await this.resolve(local, server, 0);
  }

  private async push(save: Save, round: number): Promise<void> {
    try {
      const { revision } = await this.o.transport.putSave(this.state.cloudRevision, save);
      // A newer local save that arrived during the request is still pending.
      this.setState({ cloudRevision: revision, pending: this.local !== save });
    } catch (err) {
      if (err instanceof ApiError && err.code === "SAVE_CONFLICT") {
        const { server } = SaveConflictDetailsSchema.parse(err.details);
        await this.resolve(save, server, round + 1);
        return;
      }
      throw err;
    }
  }

  private async resolve(local: Save, server: CloudSave, round: number): Promise<void> {
    if (round > MAX_CONFLICT_ROUNDS) throw new Error("The cloud save keeps changing; giving up for now.");
    const { winner, loser, winnerSource } = resolveConflict(local, server.save);
    // The loser is never discarded (SAVE_SCHEMA §5).
    await this.o.transport.putBackup(this.o.now(), loser);
    if (winnerSource === "remote") {
      this.adopt(server, winner);
      return;
    }
    this.setState({ cloudRevision: server.revision });
    if (this.local === local) this.local = winner;
    await this.push(winner, round);
  }

  /** The cloud copy wins: it becomes the local save, in step with the cloud. */
  private adopt(server: CloudSave, save: Save): void {
    this.local = save;
    this.setState({ cloudRevision: server.revision, pending: false });
    this.o.loadIntoGame(save);
  }

  private fail(err: unknown): void {
    if (err instanceof ApiError && err.status === 401) {
      this.setStatus("signed-out");
      this.stop();
      return;
    }
    const transient = err instanceof NetworkError || (err instanceof ApiError && (err.status >= 500 || err.status === 429));
    if (!transient) {
      // Invalid or unsupported saves won't fix themselves; the next save retries.
      console.warn("Cloud sync failed", err);
      this.setStatus("error");
      return;
    }
    this.setStatus("offline");
    const delay = Math.min(RETRY_MIN_MS * 2 ** this.attempt, RETRY_MAX_MS);
    this.attempt++;
    this.timer = this.o.setTimer(() => {
      this.timer = null;
      void this.kick();
    }, delay);
  }

  private setState(patch: Partial<SyncState>): void {
    this.state = { ...this.state, ...patch };
    this.o.store.write(this.state);
  }

  private setStatus(s: SyncStatus): void {
    if (s === this.status) return;
    this.status = s;
    this.o.onStatus(s);
  }
}
