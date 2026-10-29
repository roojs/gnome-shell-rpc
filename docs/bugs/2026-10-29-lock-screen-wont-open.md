# Lock screen cannot be opened

**Status:** ✅ proved 2026-10-29 16:43. A key on the clock page opens the password page. Applied in `Event.vala`.

The lock button does lock. The screen fades to black, and a pointer motion brings the clock back. A key then has to open the password page. Before the fix, that key threw and the page stayed on the clock.

## Seen

User 2026-10-29: the lock screen cannot be opened.

`unlockDialog.js` `vfunc_key_press_event` reads `event.get_key_unicode()` and then shows the password page. The client typelib calls `clutter_event_get_key_unicode`. That symbol was undefined in `libmutter-clutter-rpc-16.so`, so the key handler threw and `_showPrompt()` never ran.

The server already packs `key_unicode` on the key event. The client event did not keep it, and it had no getter.

## Reproduction

```bash
GSR_NESTED_TIMEOUT=45 \
  GI_META_SMOKE=lock-screen-open-smoke/ui/init \
  ./scripts/weston-gsr-prove.sh
```

`tests/gjs-embed/lock-screen-open-smoke.js`. After startup it clicks Lock Screen, waits until the short lightbox is black, moves a virtual pointer, then sends key `a`.

2026-10-29 16:39, before the getter, `~/.cache/gnome-shell-rpc/nested-weston-prove.tee.log`:

```text
lock-screen-open-smoke/ui/init: black opacity=255 active=true
JS ERROR: Could not locate clutter_event_get_key_unicode
  vfunc_key_press_event@resource:///org/gnome/shell/ui/unlockDialog.js:642
lock-screen-open-smoke/ui/init: miss key-no-prompt opacity=0
```

2026-10-29 16:43, after the getter:

```text
lock-screen-open-smoke/ui/init: ok prompt opacity=0 active=false active=true locked=true visible=true mapped=true
```

`~/.cache/gnome-shell-rpc/lock-screen.png` is the password page: the user name and the entry.

## Change

`Clutter.Event.get_key_unicode` returns the character packed with the key. `apply_state` and `copy` keep that field. The shell override writes it back when it packs a key event.

---

## LLM efforts

**2026-10-29.** User: the lock screen cannot be opened. Cache logs through 15:55 are the startup-overview prove. They do not name a lock attempt.

**2026-10-29 16:28.** `GI_META_SMOKE=lock-screen-open-smoke` without `ui/init`. `miss start TypeError: global.stage.context is null`. Mutter ec=133. The startup lock was not taken.

**2026-10-29 16:29.** Same smoke under `ui/init`, menu opened during startup. Socket closed on `Clutter-Actor.allocate`. `miss lock-threw TypeError: grab is null` at `screenShield.js` `_becomeModal`. Mutter ec=133. The grab was null because the connection was already gone.

**2026-10-29 16:32.** After `_startingUp` is false, `screenShield.lock(true)`. `ok active=false locked=true visible=true mapped=true`. The shield shows.

**2026-10-29 16:34.** Lock button click, then `_showPrompt()` immediately. `miss prompt-hidden auth=true`. The prompt box is hidden until the adjustment moves. A second wait: `ok ... prompt-shown`.

**2026-10-29 16:35.** Screenshot at that moment, mean luminance 9.2. The short lightbox had faded the page to black.

**2026-10-29 16:38.** Wait for lightbox opacity 255, then virtual pointer motion. `black opacity=255`. `ok woke opacity=0`. The clock is on screen (`16:38`, Thursday October 29).

**2026-10-29 16:39.** After the wake, `notify_keyval` of `a`. `miss key-no-prompt`. `vfunc_key_press_event` throws `undefined symbol: clutter_event_get_key_unicode` at `unlockDialog.js:642`.

**2026-10-29 16:43.** Getter added. Same command. `ok prompt`. Password page is in `lock-screen.png`.
