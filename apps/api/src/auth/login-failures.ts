// Failed sign-ins per account (R10). IP rate limits stop one machine guessing;
// this stops many machines guessing one account's password. Counts live in
// memory: the API runs as one machine (fly.toml), and a restart forgetting
// them costs an attacker a cold start each time.
import { Inject, Injectable } from "@nestjs/common";
import { CONFIG, type Config } from "../config.js";
import { ApiError } from "../common/errors.js";

const MAX_TRACKED = 10_000;

@Injectable()
export class LoginFailures {
  private readonly counts = new Map<string, { n: number; until: number }>();

  constructor(@Inject(CONFIG) private readonly config: Config) {}

  /** Refuses before the password is checked, so a locked account can't be guessed at. */
  check(email: string): void {
    const c = this.counts.get(email);
    if (c && c.until > Date.now() && c.n >= this.config.loginFailures.limit) {
      throw new ApiError("RATE_LIMITED", "Too many failed sign-ins for this account. Try again in 15 minutes.");
    }
  }

  failed(email: string): void {
    const now = Date.now();
    const c = this.counts.get(email);
    if (c && c.until > now) c.n++;
    else {
      if (this.counts.size >= MAX_TRACKED) this.prune(now);
      this.counts.set(email, { n: 1, until: now + this.config.loginFailures.windowMs });
    }
  }

  succeeded(email: string): void {
    this.counts.delete(email);
  }

  private prune(now: number): void {
    for (const [k, c] of this.counts) if (c.until <= now) this.counts.delete(k);
    // Still full of live entries: drop the oldest (Maps keep insertion order).
    while (this.counts.size >= MAX_TRACKED) this.counts.delete(this.counts.keys().next().value!);
  }
}
