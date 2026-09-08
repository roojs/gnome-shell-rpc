# St-Icon.get_icon_name → GJS malformed UTF-8

**Status:** ✔️ fixed upstream (libocrpc) — re-prove nested  
**Hit:** 2026-09-08  
**Plan:** T-030 soft gap (quick settings)  
**Upstream:** `/home/alan/gitlive/OLLMchat/docs/bugs/done/2026-09-08-FIXED-gi-scalar-utf8-return-malformed.md`

---

## Symptom

```
St-Icon.get_icon_name
TypeError: malformed UTF-8 character sequence at offset 0
  quickSettings.js:83 — bind_property('icon-name', … SYNC_CREATE)
```

Same family as L7 **IN** UTF8 pin (`ActorMeta.set_name`), but on **Gi UTF8 return** packing.

## Fix

libocrpc `Gi.scalar` UTF8/FILENAME OUT — consumer only re-proves after rebuilding against fixed `libocrpc`.

## Not this bug

- Desktop icons / trash (`ding@rastersoft.com`) → was ThemeContext `theme is null` (ported: theme by `rpc_lid`).
- Missing Soft `util_*` / Global APIs (ported).

## Prove logs (pre-fix)

- `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` (~18:55)
- `/tmp/mutter-rpc-l7-stock.log` (~09:49)
