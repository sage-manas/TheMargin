// The site's client for the API (docs/api/API_CONTRACT.md). It is free of Zod
// so every page can show the signed-in state; callers that act on response
// bodies (the save sync) validate them with the contracts schemas.
import type { CloudSave, ErrorCode, Progression, Save, SessionResponse, Settings, User } from "@the-margin/contracts";

export const API_URL = (process.env.NEXT_PUBLIC_API_URL ?? "/v1").replace(/\/$/, "");

/** The API answered with its error envelope. */
export class ApiError extends Error {
  readonly status: number;
  readonly code: ErrorCode;
  readonly details: Record<string, unknown>;

  constructor(status: number, code: ErrorCode, message: string, details: Record<string, unknown> = {}) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

/** The API couldn't be reached (offline, DNS, CORS, a proxy with no API behind it). */
export class NetworkError extends Error {}

export type Fetch = (url: string, init: RequestInit) => Promise<Response>;

export class ApiClient {
  private csrf: string | null = null;
  private readonly base: string;
  private readonly fetchFn: Fetch;

  constructor(base = API_URL, fetchFn: Fetch = (u, i) => fetch(u, i)) {
    this.base = base;
    this.fetchFn = fetchFn;
  }

  async session(): Promise<SessionResponse> {
    const s = await this.call<SessionResponse>("GET", "/auth/session");
    this.csrf = s.csrfToken;
    return s;
  }

  register(email: string, password: string, displayName: string): Promise<SessionResponse> {
    return this.call("POST", "/auth/register", { email, password, displayName });
  }
  login(email: string, password: string): Promise<SessionResponse> {
    return this.call("POST", "/auth/login", { email, password });
  }
  logout(): Promise<void> {
    return this.call("POST", "/auth/logout");
  }
  updateProfile(patch: { displayName?: string }): Promise<User> {
    return this.call("PATCH", "/me/profile", patch);
  }

  /** null when there is no cloud save yet. */
  async getSave(): Promise<CloudSave | null> {
    try {
      return await this.call<CloudSave>("GET", "/saves/main");
    } catch (err) {
      if (err instanceof ApiError && err.code === "NOT_FOUND") return null;
      throw err;
    }
  }
  putSave(baseRevision: number | null, save: Save): Promise<{ revision: number }> {
    return this.call("PUT", "/saves/main", { baseRevision, save });
  }
  putBackup(ts: number, save: Save): Promise<{ slot: string }> {
    return this.call("PUT", `/saves/backup-${ts}`, { save });
  }

  progression(): Promise<Progression> {
    return this.call("GET", "/progression");
  }
  completeChapter(chapterId: string): Promise<unknown> {
    return this.call("POST", `/progression/${encodeURIComponent(chapterId)}/complete`);
  }
  unlockAchievement(code: string): Promise<unknown> {
    return this.call("POST", `/achievements/${encodeURIComponent(code)}/unlock`);
  }
  getSettings(): Promise<Settings> {
    return this.call("GET", "/settings");
  }
  putSettings(settings: Settings): Promise<Settings> {
    return this.call("PUT", "/settings", settings);
  }

  private async call<T>(method: string, path: string, body?: unknown, retried = false): Promise<T> {
    if (method !== "GET" && !this.csrf) await this.session();
    const headers: Record<string, string> = {};
    if (body !== undefined) headers["content-type"] = "application/json";
    if (method !== "GET" && this.csrf) headers["x-csrf-token"] = this.csrf;
    let res: Response;
    try {
      res = await this.fetchFn(this.base + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body), credentials: "include", cache: "no-store" });
    } catch (err) {
      throw new NetworkError(err instanceof Error ? err.message : String(err));
    }
    const text = await res.text();
    let json: unknown = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      // A proxy's HTML error page, say: the API isn't really there.
      throw new NetworkError(`Unexpected response (HTTP ${res.status})`);
    }
    if (res.ok) return json as T;
    const e = (json as { error?: { code?: ErrorCode; message?: string; details?: Record<string, unknown> } } | null)?.error;
    if (!e?.code) throw new NetworkError(`Unexpected response (HTTP ${res.status})`);
    // A stale CSRF token (cookies cleared, another tab signed out): refresh once.
    if (res.status === 403 && /CSRF/.test(e.message ?? "") && !retried) {
      await this.session();
      return this.call(method, path, body, true);
    }
    throw new ApiError(res.status, e.code, e.message ?? "", e.details ?? {});
  }
}
