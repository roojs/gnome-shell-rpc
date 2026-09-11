# St theme CSS never reached compositor (client-only set_theme)

**Status:** ✔️ fixed — archived 2026-09-11  
**Hit:** 2026-09-09 — panel/menu invisible despite construction  
**Plan:** T-030 chrome visibility

---

## Symptom

Panel/menus constructed (many `St-Button` / `Actor.show` before `notify_ready`) but nothing visible. `chrome-stage-smoke` with inline `set_style` could paint; stock chrome uses `style_class` + CSS.

## Cause

`St.Theme` / `ThemeContext.set_theme` were **client-local** (deny + map by `rpc_lid` for ding). Server St widgets got `set_style_class_name` over RPC but **no theme** on the compositor `ThemeContext` → no CSS paint.

Not caused by post-`notify_ready` stall (menus are built earlier).

## Fix

✔️ `Helper-ThemeContext.set_theme` (`sssas` URIs) — register `gnome-shell-theme.gresource`, `st_theme_new` + `load_stylesheet` + `st_theme_context_set_theme` on the leased context.  
✔️ Client `ThemeContext.set_theme` still keeps the local map, then calls Helper.  
✔️ `Theme.construct_uris` / `stylesheet_uris` for wire.

## Prove

```bash
timeout 22 dbus-run-session ./build/src/mutter-rpc --debug --wayland --nested
# Expect: Helper-ThemeContext.set_theme ok …
# Nested window: top bar / menus visible (CSS).
```
