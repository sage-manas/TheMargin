import { test } from "node:test";
import assert from "node:assert/strict";
import { DEFAULT_SETTINGS, type GameToWeb } from "@the-margin/contracts";
import { installBridge, type HostBridge } from "./bridge.ts";

test("messages queue in the inbox until the game installs deliver", () => {
  const win: { TheMarginBridge?: HostBridge } = {};
  const bridge = installBridge(win);
  bridge.send({ v: 1, type: "SET_SETTINGS", payload: { settings: { muted: true } } });
  assert.equal(win.TheMarginBridge?._inbox.length, 1);
  const delivered: string[] = [];
  win.TheMarginBridge!.deliver = (json) => delivered.push(json);
  bridge.send({ v: 1, type: "PAUSE", payload: {} });
  assert.deepEqual(delivered.map((j) => JSON.parse(j).type), ["PAUSE"]);
});

test("invalid outgoing messages are refused before they reach the game", () => {
  const win: { TheMarginBridge?: HostBridge } = {};
  const bridge = installBridge(win);
  assert.throws(() => bridge.send({ v: 1, type: "SET_SETTINGS", payload: { settings: { musicVolume: 5 } } }));
  assert.equal(win.TheMarginBridge?._inbox.length, 0);
});

test("game messages are validated against the contract", () => {
  const win: { TheMarginBridge?: HostBridge } = {};
  const invalid: string[] = [];
  const bridge = installBridge(win, (raw) => invalid.push(raw));
  const seen: GameToWeb[] = [];
  const off = bridge.subscribe((m) => seen.push(m));
  win.TheMarginBridge!.onGameMessage(JSON.stringify({ v: 1, type: "SETTINGS_UPDATED", payload: { settings: DEFAULT_SETTINGS } }));
  win.TheMarginBridge!.onGameMessage(JSON.stringify({ v: 1, type: "NOPE", payload: {} }));
  win.TheMarginBridge!.onGameMessage("{not json");
  assert.deepEqual(seen.map((m) => m.type), ["SETTINGS_UPDATED"]);
  assert.equal(invalid.length, 2);
  off();
  win.TheMarginBridge!.onGameMessage(JSON.stringify({ v: 1, type: "GAME_PAUSED", payload: {} }));
  assert.equal(seen.length, 1);
});
