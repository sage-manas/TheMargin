// Connects the game on /play to the player's account: save sync, chapter
// completions and achievements (through an outbox that survives reloads),
// and settings. Signed out or offline, the game plays exactly as before.
import { LOCAL_SAVE_KEY, SaveSchema, SettingsSchema, type GameToWeb, type Save, type Settings } from "@the-margin/contracts";
import { ApiClient, ApiError, NetworkError } from "../lib/api.ts";
import { readSettings, writeSettings } from "../lib/settings.ts";
import { browserStorage, readItem, writeItem } from "../lib/storage.ts";
import type { GameBridge } from "../game/bridge.ts";
import { SaveSync, type SyncState, type SyncStatus } from "./save-sync.ts";

export const SYNC_KEY = "the-margin.sync";
export const OUTBOX_KEY = "the-margin.outbox";

export type CloudStatus = SyncStatus | "connecting" | "local";

type OutboxItem = { kind: "chapter" | "achievement"; id: string };

function readJson<T>(key: string): T | null {
  try {
    const t = readItem(browserStorage(), key);
    return t ? (JSON.parse(t) as T) : null;
  } catch {
    return null;
  }
}

function readLocalSave(): Save | null {
  const r = SaveSchema.safeParse(readJson(LOCAL_SAVE_KEY));
  return r.success ? r.data : null;
}

/** Idempotent calls (completing a chapter, unlocking an achievement) kept until the API accepts them. */
class Outbox {
  private items: OutboxItem[] = readJson<OutboxItem[]>(OUTBOX_KEY) ?? [];
  private busy = false;
  private readonly api: ApiClient;

  constructor(api: ApiClient) {
    this.api = api;
  }

  add(item: OutboxItem): void {
    if (!this.items.some((i) => i.kind === item.kind && i.id === item.id)) this.items.push(item);
    this.persist();
    void this.flush();
  }

  async flush(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      while (this.items.length) {
        const item = this.items[0];
        try {
          if (item.kind === "chapter") await this.api.completeChapter(item.id);
          else await this.api.unlockAchievement(item.id);
        } catch (err) {
          // Offline or the server is down: keep it for later. Refusals (an
          // unknown code, a chapter out of order) won't change, so drop them.
          if (err instanceof NetworkError || (err instanceof ApiError && (err.status >= 500 || err.status === 429 || err.status === 401))) return;
          console.warn("Dropped a progress update the API refused", item, err);
        }
        this.items.shift();
        this.persist();
      }
    } finally {
      this.busy = false;
    }
  }

  private persist(): void {
    writeItem(browserStorage(), OUTBOX_KEY, JSON.stringify(this.items));
  }
}

/**
 * Starts cloud features for the launcher. `gameReady` resolves on GAME_READY:
 * the game only listens for LOAD_CLOUD_SAVE once it is running (messages
 * queued before that are drained before its main scene connects).
 */
export function connectCloud(bridge: GameBridge, gameReady: Promise<void>, onStatus: (s: CloudStatus) => void): () => void {
  const api = new ApiClient();
  let sync: SaveSync | null = null;
  let latest: Save | null = null;
  let settingsTimer: ReturnType<typeof setTimeout> | undefined;
  let stopped = false;
  const outbox = new Outbox(api);

  const unsubscribe = bridge.subscribe((msg: GameToWeb) => {
    switch (msg.type) {
      case "SAVE_UPDATED":
        latest = msg.payload.save;
        sync?.saveUpdated(msg.payload.save);
        break;
      case "CHAPTER_COMPLETED":
        if (sync) outbox.add({ kind: "chapter", id: msg.payload.chapterId });
        break;
      case "ACHIEVEMENT_UNLOCKED":
        if (sync) outbox.add({ kind: "achievement", id: msg.payload.code });
        break;
      case "SETTINGS_UPDATED":
        if (sync) {
          clearTimeout(settingsTimer);
          const s = msg.payload.settings;
          settingsTimer = setTimeout(() => void api.putSettings(s).catch(() => {}), 1000);
        }
        break;
    }
  });

  let connecting = false;

  async function connect(): Promise<void> {
    if (connecting || sync) return;
    connecting = true;
    try {
      await connectOnce();
    } finally {
      connecting = false;
    }
  }

  async function connectOnce(): Promise<void> {
    onStatus("connecting");
    let user;
    try {
      user = (await api.session()).user;
    } catch {
      // No API reachable: local play only; try again when back online.
      onStatus("offline");
      return;
    }
    if (stopped) return;
    if (!user) {
      onStatus("local");
      return;
    }
    // Settings: the cloud fills in a browser that has none of its own.
    if (!readSettings(browserStorage())) {
      try {
        const cloud = SettingsSchema.parse(await api.getSettings());
        writeSettings(browserStorage(), cloud);
        const { version: _v, ...patch }: Settings = cloud;
        bridge.send({ v: 1, type: "SET_SETTINGS", payload: { settings: patch } });
      } catch {
        // Not worth blocking sync over.
      }
    }
    const store = {
      read: () => readJson<SyncState>(SYNC_KEY),
      write: (s: SyncState) => void writeItem(browserStorage(), SYNC_KEY, JSON.stringify(s)),
    };
    sync = new SaveSync({
      userId: user.id,
      transport: api,
      store,
      loadIntoGame: (save) => void gameReady.then(() => bridge.send({ v: 1, type: "LOAD_CLOUD_SAVE", payload: { save } })),
      onStatus,
    });
    await sync.start(latest ?? readLocalSave());
    void outbox.flush();
  }

  const wake = () => {
    if (document.visibilityState === "hidden") return;
    if (sync) {
      sync.online();
      void outbox.flush();
    } else void connect();
  };
  window.addEventListener("online", wake);
  document.addEventListener("visibilitychange", wake);
  void connect();

  return () => {
    stopped = true;
    sync?.stop();
    unsubscribe();
    window.removeEventListener("online", wake);
    document.removeEventListener("visibilitychange", wake);
  };
}
