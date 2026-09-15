# Nested boot blanks background — start with user extensions off

**Status:** ⏳ debug — extensions-off is the first bisect step  
**Hit:** 2026-09-15 — user: something blanks the background during boot  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Roles:** **consumer** boot / `ExtensionManager` / background chrome

---

## Approach

Do **not** chase wallpaper / blank with the full user extension set loaded.

Stock has **no** `--disable-extensions` / `--enable-extensions` on
`gnome-shell`. `ExtensionManager` honors the GSettings key
`org.gnome.shell disable-user-extensions` (also flipped via
`gsettings` / `gnome-extensions`).

**This nest host** sets that same key on a **memory** `GSettingsBackend`
via `Shell.Global.host_install_settings` (gir=false) so live-session dconf
is not written. Desktop schemas (`org.gnome.desktop.*`) still use the user
database. `Shell.Global.settings` stays stock-shaped.

Log line: `gnome-shell-rpc: disable-user-extensions (memory org.gnome.shell)`.

**Lead (2026-09-15):** after startup animation, `ScreenShield.lockIfWasLocked`
calls `global.get_runtime_state('b', 'screenShield.locked')` — stub was missing
→ `TypeError`. Stock impl is file-backed under
`$XDG_RUNTIME_DIR/gnome-shell/runtime-state-{LE|BE}.$DISPLAY/`
(`vendor/gnome-shell/src/shell-global.c`). Null → no re-lock. Landed on
`Shell.Global` next to `get_persistent_state`.

**ℹ️** Session **mode** extensions (`sessionMode.enabledExtensions`, e.g.
Ubuntu dock / DING) can still load — next bisect step if blank remains.

---

## Next

1. Nest → no `get_runtime_state` TypeError; confirm blank / magic-button.
2. If blank remains → mode extensions / wallpaper / coverPane.
3. Only then stop installing the memory override to reintroduce user extensions.
