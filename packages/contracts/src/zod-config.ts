import { z } from "zod";

// In browsers, Zod must not probe for `new Function` (its fast path): the
// site's CSP forbids eval, and Firefox reports even a caught probe as a
// violation (TDD §6). Servers keep the fast path.
if (typeof document !== "undefined") z.config({ jitless: true });
