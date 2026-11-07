"use client";
import { useEffect, useState } from "react";
import { DEFAULT_SETTINGS, type Settings } from "@the-margin/contracts";
import { readSettings, writeSettings } from "@/lib/settings.ts";
import { browserStorage } from "@/lib/storage.ts";

type Volume = "masterVolume" | "musicVolume" | "sfxVolume";

const VOLUMES: [Volume, string][] = [
  ["masterVolume", "Master volume"],
  ["musicVolume", "Music"],
  ["sfxVolume", "Sound effects"],
];

export function SettingsForm() {
  const [settings, setSettings] = useState<Settings>(DEFAULT_SETTINGS);
  const [status, setStatus] = useState("");

  useEffect(() => {
    const saved = readSettings(browserStorage());
    if (saved) setSettings(saved);
    else if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) setSettings({ ...DEFAULT_SETTINGS, reducedMotion: true });
  }, []);

  function change(next: Settings) {
    setSettings(next);
    setStatus(writeSettings(browserStorage(), next) ? "Saved. The game picks these up next time it starts." : "This browser is blocking site storage, so settings can't be kept.");
  }

  return (
    <form className="panel settings" onSubmit={(e) => e.preventDefault()} aria-describedby="settings-status">
      {VOLUMES.map(([key, label]) => (
        <div className="field" key={key}>
          <label htmlFor={key}>{label}</label>
          <output htmlFor={key}>{Math.round(settings[key] * 100)}%</output>
          <input
            id={key}
            type="range"
            min={0}
            max={100}
            step={5}
            value={Math.round(settings[key] * 100)}
            onChange={(e) => change({ ...settings, [key]: Number(e.target.value) / 100 })}
          />
        </div>
      ))}
      <div className="check">
        <input
          id="reducedMotion"
          type="checkbox"
          checked={settings.reducedMotion}
          onChange={(e) => change({ ...settings, reducedMotion: e.target.checked })}
        />
        <label htmlFor="reducedMotion">
          <strong>Reduce motion</strong>
          <br />
          Stops words bobbing and panels floating, and turns the page-turn curl into a fade.
        </label>
      </div>
      <div className="actions">
        <button className="button secondary" type="button" onClick={() => change(DEFAULT_SETTINGS)}>
          Reset to defaults
        </button>
      </div>
      <p id="settings-status" className="status-line" role="status">
        {status}
      </p>
    </form>
  );
}
