# B2 — keybinding handler does not run on key press

**Status:** ✔️ `key-smoke: add_keybinding fired` + `ok` (2026-09-15)  
**Hit:** 2026-09-15 — Phase B after stay-up  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Prove:** `GI_META_SMOKE=key-smoke` weston prove → `key-smoke: add_keybinding fired` then `key-smoke: ok`

**Roles:** **server** virtual keyboard → mutter grab → Helper callback · **client** `callback_bind`

---

## Was

B1 registers `Display.add_keybinding` + `keybindings_set_custom_handler`
(`key-smoke: ok` on register only). Fire / mutter delivery never proved.
Override trampoline passes `null` event + empty `KeyBinding` (soft).

## Fix

1. `Helper-Actor.fire_key` — virtual `KEYBOARD_DEVICE` + `notify_keyval`
   (mods then key), same seat pattern as `pointer_click`.
2. `Shell.Global.fire_key` — nested prove harness (not stock).
3. `key-smoke.js` — after register, fire `<Super>n` (schema default for
   `focus-active-notification`), main-loop until handler log, then `ok`.

**🚫** Parked: notification/menu placement, panel bold, spawn argv OPC.
**🚫** Invent non-GIR key APIs on Meta.Display.

## Prove

```bash
GI_META_SMOKE=key-smoke GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
# expect: key-smoke: add_keybinding fired … key-smoke: ok
```

**Landed 2026-09-15:** nested prove ec=0; tee shows fired then ok.