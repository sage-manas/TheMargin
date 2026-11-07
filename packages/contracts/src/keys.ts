// Dependency-free constants, importable on their own
// (`@the-margin/contracts/keys`) by pages that must not ship Zod.

// The game mirrors every save to localStorage under this key (save_manager.gd
// WEB_KEY). The site reads it to show progress; only the game writes it.
export const LOCAL_SAVE_KEY = "the-margin.save_main";
