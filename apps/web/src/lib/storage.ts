// Browser storage can be missing or throw (blocked site data, some private
// modes), so every access goes through these and fails soft.
export type KeyValueStore = Pick<Storage, "getItem" | "setItem" | "removeItem">;

export function browserStorage(): KeyValueStore | null {
  try {
    return typeof window === "undefined" ? null : window.localStorage;
  } catch {
    return null;
  }
}

export function readItem(store: KeyValueStore | null, key: string): string | null {
  try {
    return store?.getItem(key) ?? null;
  } catch {
    return null;
  }
}

export function writeItem(store: KeyValueStore | null, key: string, value: string): boolean {
  try {
    if (!store) return false;
    store.setItem(key, value);
    return true;
  } catch {
    return false;
  }
}
