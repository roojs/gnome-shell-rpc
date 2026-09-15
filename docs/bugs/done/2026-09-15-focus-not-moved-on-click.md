# B4 — focus does not move on click

**Status:** ✔️ `focus-smoke: ok` (2026-09-15)  
**Hit:** 2026-09-15 — Phase B after B2  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Prove:** `GI_META_SMOKE=focus-smoke` → `focus-smoke: ok`

**Roles:** **consumer** `St.FocusManager` + stage `key_focus` · seat via `pointer_click`

---

## Bar

`Global.focus_manager` (leased) + two `can_focus` widgets: click A then B
via `Shell.Global.pointer_click`; stage `key_focus` must follow.

## Fix (as needed)

Wire whatever fails the smoke — likely stage `key_focus` / click-to-focus /
`FocusManager.add_group` peer path. Do not vendor layout.js.

**🚫** Parked UI placement. **🚫** Invent non-GIR focus APIs.

## Prove

```bash
GI_META_SMOKE=focus-smoke GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
# expect: focus-smoke: ok
```

**Landed:** St.Widget subclass + fire_button_press → grab_key_focus; stage key_focus A→B.
