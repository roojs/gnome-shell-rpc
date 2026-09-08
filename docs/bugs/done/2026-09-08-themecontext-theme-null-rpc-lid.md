# ThemeContext.get_theme null after loadTheme (extension theme is null)

**Status:** ✔️ FIXED — client theme map by `rpc_lid`  
**Hit:** 2026-09-08  
**Plan:** T-030 soft gap (ding / extensions)

---

## Symptom

```
Extension ding@rastersoft.com: TypeError: theme is null
  St.ThemeContext.get_for_stage(global.stage).get_theme()
```

`main.loadTheme()` had called `set_theme`, but later `get_for_stage` returned null theme.

## Cause

`parse_object` mints a **new** ThemeContext proxy for each live handle decode (does not reuse `proxies`). Per-instance `active_theme` was lost.

## Fix

`overrides-st/ThemeContext.override.vala` — `Gee.HashMap<int, Theme>` keyed by `rpc_lid`; `set_theme` / `get_theme` use the map; emit `changed` on set.

## Prove

Restart nested Wayland — ding / other extensions should pass stylesheet load (no `theme is null`).
