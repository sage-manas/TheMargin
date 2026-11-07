// The host side of the game bridge (TDD §4.2). It must be installed before the
// engine loads: the game looks for `window.TheMarginBridge` once, at start.
import { encodeWebMessage, GameToWebSchema, type GameToWeb, type WebToGame } from "@the-margin/contracts";

/** The object the game finds on `window`. The game installs `deliver` once it is up. */
export type HostBridge = {
  _inbox: string[];
  onGameMessage(json: string): void;
  deliver?: (json: string) => void;
};

export type GameBridge = {
  /** Validates and sends a message, queueing it until the game is listening. */
  send(msg: WebToGame): void;
  subscribe(fn: (msg: GameToWeb) => void): () => void;
};

export function installBridge(target: { TheMarginBridge?: HostBridge }, onInvalid: (raw: string, err: unknown) => void = () => {}): GameBridge {
  const listeners = new Set<(msg: GameToWeb) => void>();
  const host: HostBridge = {
    _inbox: [],
    onGameMessage(json: string) {
      let msg: GameToWeb;
      try {
        msg = GameToWebSchema.parse(JSON.parse(json));
      } catch (err) {
        onInvalid(json, err);
        return;
      }
      for (const fn of listeners) fn(msg);
    },
  };
  target.TheMarginBridge = host;
  return {
    send(msg) {
      const json = encodeWebMessage(msg);
      if (host.deliver) host.deliver(json);
      else host._inbox.push(json);
    },
    subscribe(fn) {
      listeners.add(fn);
      return () => listeners.delete(fn);
    },
  };
}
