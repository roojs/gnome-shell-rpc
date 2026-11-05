# Keymap reset returns never reach mutter

**Status:** Open. Mutter reads two signal returns. Nothing in the subscription path writes them.

## What mutter reads

`meta_backend_reset_keymap_async` in mutter:

```c
g_signal_emit (backend, signals[RESET_KEYMAP_DESCRIPTION], 0, &keymap_description);
g_signal_emit (backend, signals[RESET_KEYMAP_LAYOUT_INDEX], 0, &layout_index);
```

Shell 50 `keyboardManager.js`:

```js
global.backend.connect('reset-keymap-description', () => this._ourKeymapDescription);
global.backend.connect('reset-keymap-layout-index', () => this._current.groupIndex);
```

| Signal | Return |
| --- | --- |
| `reset-keymap-description` | `KeymapDescription`, boxed, transfer full |
| `reset-keymap-layout-index` | `guint` |

`keymap-changed` and `keymap-layout-group-changed` return nothing. They are not this bug.

## 1. `add_signals` does not wait

`src/server/libmutter-clutter-18/ClutterActor.vala`. The two reset names are not in this switch, so `blocking` stays false.

```vala
case "keymap-changed":
case "keymap-layout-group-changed":
    subscription.blocking = true;
    break;
```

`libocrpc/Live/Subscription.vala`. A non-blocking subscription writes the notice and returns. Mutter's two locals stay unset.

```vala
if (!subscription.blocking) {
    subscription.connection.write(notif);
    return;
}
```

## 2. `Subscription.emit` stores a boolean

Same file, after the reply arrives. This is the only write into the signal return. `reply_args` may already hold a `uint` or a lease id. Both are discarded.

```vala
if (return_value != null) {
    return_value.set_boolean(waiter.reply_args.size > 0 &&
        waiter.reply_args.get(0).type() == GLib.Type.BOOLEAN &&
        waiter.reply_args.get(0).get_boolean());
}
```

Waiting in `add_signals` would run this on a `guint` and on a boxed `KeymapDescription`.

## 3. The client reply has no description

`src/client/libshell-16/Signals.vala`. One return is sent back as a boolean, a `uint`, or an object lease id.

```vala
if (returned.get(0).holds(GLib.Type.BOOLEAN)) {
    /* "tb" */
}
if (returned.get(0).holds(GLib.Type.UINT)) {
    /* "tu" — the group index can leave the client */
}
if (returned.get(0).holds(GLib.Type.OBJECT)) {
    /* "tt" — lease id */
}
/* anything else, including a boxed description: "tb" false */
```

Mutter's description is a boxed record. The server lease keeps it on `Gsr.Server.Meta.Keymap.desc`. No code copies that field into `return_value`.

## LLM efforts

- 2026-11-05. User asked for a report of this problem: these two signals are being used to pass return data, which a signal subscription is not for. Read the stock signal signatures and `keyboardManager.js` on `192.168.122.115`. Wrote this file. Did not change the signal marshal.
- 2026-11-05. User: say it in plain English. The first reply stops the emission. The write-up about further handlers was irrelevant. Replaced the body with that.
- 2026-11-05. User: the report was only GObject behaviour. The gap is that our reply path only carries a boolean, and these two returns are a description and a `uint`. Rewrote the top to that.
- 2026-11-05. User: name where the problem is. The reply wire keeps the value. `OLLMrpc.Live.Subscription.emit` then writes only a boolean. Rewrote the top to that function.
- 2026-11-05. User: the one-paragraph report was unreadable. Replaced it with the three code sites: `add_signals` does not wait, `Subscription.emit` stores a boolean, the client reply has no boxed description.
