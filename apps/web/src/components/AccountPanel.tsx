"use client";
import { useEffect, useState, type FormEvent } from "react";
import type { User } from "@the-margin/contracts";
import { ApiClient, ApiError, NetworkError } from "@/lib/api.ts";

type Mode = "signin" | "register";

const api = new ApiClient();

function message(err: unknown): string {
  if (err instanceof NetworkError) return "The accounts server can't be reached right now. You can still play; progress is saved in this browser.";
  if (err instanceof ApiError) {
    if (err.code === "VALIDATION_FAILED") {
      const issues = (err.details.issues as { path: string }[] | undefined) ?? [];
      if (issues.some((i) => i.path === "password")) return "Passwords need at least 10 characters.";
      if (issues.some((i) => i.path === "email")) return "That doesn't look like an email address.";
      if (issues.some((i) => i.path === "displayName")) return "Pick a name of 1 to 32 characters.";
    }
    return err.message;
  }
  return "Something went wrong. Try again.";
}

export function AccountPanel() {
  const [user, setUser] = useState<User | null | undefined>(undefined);
  const [mode, setMode] = useState<Mode>("signin");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api.session().then(
      (s) => setUser(s.user),
      (err) => {
        setUser(null);
        setError(message(err));
      },
    );
  }, []);

  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const email = String(f.get("email") ?? "");
    const password = String(f.get("password") ?? "");
    setBusy(true);
    setError("");
    try {
      const s = mode === "register" ? await api.register(email, password, String(f.get("displayName") ?? "")) : await api.login(email, password);
      setUser(s.user);
      window.dispatchEvent(new Event("themargin:account"));
    } catch (err) {
      setError(message(err));
    } finally {
      setBusy(false);
    }
  }

  async function signOut() {
    setBusy(true);
    try {
      await api.logout();
      setUser(null);
      window.dispatchEvent(new Event("themargin:account"));
    } catch (err) {
      setError(message(err));
    } finally {
      setBusy(false);
    }
  }

  if (user === undefined) return <p className="status-line">Checking…</p>;

  if (user) {
    return (
      <div className="panel settings" data-account="signed-in">
        <p>
          Signed in as <strong>{user.displayName}</strong> ({user.email}).
        </p>
        <p>Your progress is saved online whenever you play, and picked up on any browser you sign in on.</p>
        <div className="actions">
          <a className="button" href="/play">
            Play
          </a>
          <button className="button secondary" type="button" onClick={signOut} disabled={busy}>
            Sign out
          </button>
        </div>
        <p className="status-line" role="alert">
          {error}
        </p>
      </div>
    );
  }

  return (
    <div className="panel settings" data-account="signed-out">
      <div className="tabs" role="tablist" aria-label="Account">
        {(["signin", "register"] as const).map((m) => (
          <button key={m} type="button" role="tab" aria-selected={mode === m} onClick={() => (setMode(m), setError(""))}>
            {m === "signin" ? "Sign in" : "Create account"}
          </button>
        ))}
      </div>
      <form onSubmit={submit} aria-label={mode === "signin" ? "Sign in" : "Create account"}>
        {mode === "register" && (
          <div className="text-field">
            <label htmlFor="displayName">Name</label>
            <input id="displayName" name="displayName" required maxLength={32} autoComplete="nickname" />
          </div>
        )}
        <div className="text-field">
          <label htmlFor="email">Email</label>
          <input id="email" name="email" type="email" required autoComplete="email" />
        </div>
        <div className="text-field">
          <label htmlFor="password">Password</label>
          <input
            id="password"
            name="password"
            type="password"
            required
            minLength={mode === "register" ? 10 : 1}
            autoComplete={mode === "register" ? "new-password" : "current-password"}
            aria-describedby={mode === "register" ? "password-hint" : undefined}
          />
          {mode === "register" && <small id="password-hint">At least 10 characters.</small>}
        </div>
        <button className="button" type="submit" disabled={busy}>
          {mode === "signin" ? "Sign in" : "Create account"}
        </button>
      </form>
      <p className="status-line" role="alert">
        {error}
      </p>
      <p className="note">You don&rsquo;t need an account to play. One keeps your progress safe and lets you continue on another browser.</p>
    </div>
  );
}
