# Typing in overview search aborts the client

**Status:** ✔️ archived 2026-09-30 — taken off the board. Not re-reported that day. Live UI is [`../2026-09-30-overview-boot-flicker.md`](../2026-09-30-overview-boot-flicker.md). The notes below are the earlier abort.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Seen:** 2026-09-29 09:47:09. Nested desktop up. Typed `t` (start of `ter`) in overview search.

```text
key press  : key: t (116)
Clutter.keysym_to_unicode
Clutter-Stage.set_key_focus
gi-stub: Clutter-Actor.event not wired
Unexpected early end-of-stream
```

Vendor `js/ui/searchController.js` `startSearch`:

```js
global.stage.set_key_focus(this._text);
this._text.event(event, false);
```

`_text` is `searchEntry.clutter_text`. `Clutter.Event` is Compact, so the generator cannot put it on the wire and emits the aborting stub.

## Fix

`Actor.event` is denied and implemented in `Actor.override.vala`. It calls `Helper-Actor.deliver_event`. The compositor runs `clutter_actor_event` on the leased actor. While the stage key handler is still on the stack, that is `clutter_get_current_event()` (unicode and device intact). Otherwise a synthetic key is built with `clutter_keysym_to_unicode`.
