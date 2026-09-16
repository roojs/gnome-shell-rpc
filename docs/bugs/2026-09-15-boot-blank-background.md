# Nested boot blanks background — start with user extensions off

**Status:** ⏳ parked — grey/overlay chase owns residual under [`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md); keep this for extensions-off bisect only  
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

Parked behind
[`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md).
Revisit only if that chase shows the grey is **not** overview/cover and
extensions-off still matters.
