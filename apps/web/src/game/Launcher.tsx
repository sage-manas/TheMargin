"use client";
// The /play launcher (TDD §5.3). It drives Godot's Engine API directly rather
// than using the exported index.html: the bridge goes in first, then the
// build manifest, the engine script, and the engine on our own canvas.
import { useEffect, useRef, useState } from "react";
import { BuildManifestSchema, type GameToWeb } from "@the-margin/contracts";
import { installBridge, type GameBridge, type HostBridge } from "./bridge.ts";
import { readSettings, writeSettings } from "@/lib/settings.ts";
import { browserStorage } from "@/lib/storage.ts";
import { connectCloud, type CloudStatus } from "@/sync/cloud.ts";

type GodotEngine = {
  init(basePath: string): Promise<void>;
  preloadFile(file: string, path?: string): Promise<void>;
  start(override?: { args?: string[] }): Promise<void>;
};
type EngineConstructor = {
  new (config: Record<string, unknown>): GodotEngine;
  getMissingFeatures(opts: { threads: boolean }): string[];
};
type LauncherWindow = Window & { Engine?: EngineConstructor; TheMarginBridge?: HostBridge; __theMarginStarted?: boolean };

type Phase =
  | { name: "loading"; progress: number }
  | { name: "ready" }
  | { name: "error"; message: string }
  | { name: "unsupported"; missing: string[] };

const BUILD_URL = process.env.NEXT_PUBLIC_GAME_BUILD_URL ?? "/game";

const CLOUD_LABEL: Record<CloudStatus, string> = {
  connecting: "",
  local: "",
  syncing: "Saving online…",
  synced: "Saved online",
  offline: "Offline: saved here, will sync",
  "signed-out": "Signed out: saved here only",
  error: "Online save failed",
};

function loadScript(src: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const s = document.createElement("script");
    s.src = src;
    s.async = true;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error("The game's engine script could not be downloaded."));
    document.head.appendChild(s);
  });
}

export function Launcher() {
  const stage = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const bridge = useRef<GameBridge | null>(null);
  const [phase, setPhase] = useState<Phase>({ name: "loading", progress: 0 });
  const [muted, setMuted] = useState(false);
  const [fullscreen, setFullscreen] = useState(false);
  const [canFullscreen, setCanFullscreen] = useState(false);
  const [cloud, setCloud] = useState<CloudStatus>("connecting");

  // The canvas is sized in device pixels to fill the stage; Godot (resize
  // policy 0) follows whatever size the canvas has.
  useEffect(() => {
    const el = stage.current;
    const c = canvas.current;
    if (!el || !c) return;
    const fit = () => {
      const r = el.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      c.width = Math.max(1, Math.round(r.width * dpr));
      c.height = Math.max(1, Math.round(r.height * dpr));
    };
    fit();
    const ro = new ResizeObserver(fit);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    setCanFullscreen(document.fullscreenEnabled);
    const onChange = () => setFullscreen(document.fullscreenElement === stage.current);
    document.addEventListener("fullscreenchange", onChange);
    return () => document.removeEventListener("fullscreenchange", onChange);
  }, []);

  useEffect(() => {
    const win = window as LauncherWindow;
    // An engine can only start once per document (and React's dev mode runs
    // effects twice). Arriving here again in the same document reloads.
    if (win.__theMarginStarted) {
      if (!bridge.current) window.location.reload();
      return;
    }
    win.__theMarginStarted = true;

    const b = installBridge(win, (raw, err) => console.warn("Ignored a game message that breaks the contract", raw, err));
    bridge.current = b;
    let ready: () => void = () => {};
    const gameReady = new Promise<void>((r) => (ready = r));
    b.subscribe((msg: GameToWeb) => {
      if (msg.type === "GAME_READY") ready();
      if (msg.type === "GAME_READY") setPhase({ name: "ready" });
      if (msg.type === "SETTINGS_UPDATED") writeSettings(browserStorage(), msg.payload.settings);
      // Lets other parts of the site (and tests) follow the game.
      window.dispatchEvent(new CustomEvent("themargin:message", { detail: msg }));
    });
    // Settings changed on the site reach the game before its first frame.
    const settings = readSettings(browserStorage());
    if (settings) {
      const { version: _version, ...patch } = settings;
      b.send({ v: 1, type: "SET_SETTINGS", payload: { settings: patch } });
    }
    // The account's cloud save, achievements and settings, when signed in.
    connectCloud(b, gameReady, setCloud);
    // Ask the browser not to evict saves under storage pressure (Risk R5).
    navigator.storage?.persist?.().catch(() => {});

    (async () => {
      try {
        const res = await fetch(`${BUILD_URL}/build.json`, { cache: "no-cache" });
        if (!res.ok) throw new Error(`The game build could not be found (HTTP ${res.status}).`);
        const manifest = BuildManifestSchema.parse(await res.json());
        const exe = `${BUILD_URL}/${manifest.executable}`;
        await loadScript(`${exe}.js`);
        const Engine = win.Engine;
        if (!Engine) throw new Error("The game's engine script did not load.");
        const missing = Engine.getMissingFeatures({ threads: false });
        if (missing.length) {
          setPhase({ name: "unsupported", missing });
          return;
        }
        const fileSizes: Record<string, number> = {};
        for (const [file, size] of Object.entries(manifest.fileSizes)) fileSizes[`${BUILD_URL}/${file}`] = size;
        const engine = new Engine({
          canvas: canvas.current,
          canvasResizePolicy: 0,
          executable: exe,
          fileSizes,
          focusCanvas: true,
          onProgress: (current: number, total: number) => {
            if (total > 0) setPhase((p) => (p.name === "loading" ? { name: "loading", progress: Math.min(1, current / total) } : p));
          },
        });
        // The pack goes to a fixed in-memory path, wherever the build is hosted.
        await Promise.all([engine.init(exe), engine.preloadFile(`${exe}.pck`, "index.pck")]);
        await engine.start({ args: ["--main-pack", "index.pck"] });
      } catch (err) {
        console.error(err);
        setPhase({ name: "error", message: err instanceof Error ? err.message : String(err) });
      }
    })();
  }, []);

  const refocus = () => canvas.current?.focus();

  function toggleMute() {
    const next = !muted;
    setMuted(next);
    bridge.current?.send({ v: 1, type: "SET_SETTINGS", payload: { settings: { muted: next } } });
    refocus();
  }

  async function toggleFullscreen() {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await stage.current?.requestFullscreen();
    } catch {
      // Refused (no user gesture, or blocked by the browser): nothing to do.
    }
    refocus();
  }

  return (
    <div className="launcher" data-state={phase.name}>
      <header className="launcher-bar">
        <a className="launcher-back" href="/">
          <span aria-hidden="true">←</span> The Margin
        </a>
        <div className="launcher-tools">
          <span className="launcher-cloud" role="status" data-cloud={cloud}>
            {cloud === "local" ? <a href="/account">Sign in to save online</a> : CLOUD_LABEL[cloud]}
          </span>
          <button type="button" onClick={toggleMute} aria-pressed={muted}>
            {muted ? "Unmute" : "Mute"}
          </button>
          {canFullscreen && (
            <button type="button" onClick={toggleFullscreen} aria-pressed={fullscreen}>
              {fullscreen ? "Exit full screen" : "Full screen"}
            </button>
          )}
        </div>
      </header>
      <div className="launcher-stage" ref={stage}>
        <canvas ref={canvas} id="game-canvas" tabIndex={0} aria-label="The Margin game" onContextMenu={(e) => e.preventDefault()}>
          The Margin needs a browser with WebGL 2 and WebAssembly.
        </canvas>
        {phase.name === "loading" && (
          <div className="launcher-overlay" role="status">
            <p className="launcher-title">Drawing the page…</p>
            <div
              className="launcher-progress"
              role="progressbar"
              aria-label="Loading the game"
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuenow={Math.round(phase.progress * 100)}
            >
              <span style={{ width: `${phase.progress * 100}%` }} />
            </div>
          </div>
        )}
        {phase.name === "error" && (
          <div className="launcher-overlay" role="alert">
            <p className="launcher-title">The page didn&rsquo;t load.</p>
            <p>{phase.message}</p>
            <button className="button" type="button" onClick={() => window.location.reload()}>
              Try again
            </button>
          </div>
        )}
        {phase.name === "unsupported" && (
          <div className="launcher-overlay" role="alert">
            <p className="launcher-title">This browser can&rsquo;t run the game.</p>
            <p>It is missing:</p>
            <ul>
              {phase.missing.map((m) => (
                <li key={m}>{m}</li>
              ))}
            </ul>
            <p>Try an up-to-date desktop Chrome, Edge, Firefox or Safari, with hardware acceleration turned on.</p>
          </div>
        )}
      </div>
    </div>
  );
}
