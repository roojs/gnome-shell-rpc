# Keymap reset returns never reach mutter

**Status:** ✅ closed 2026-11-06. User: this is done. The two reset subscriptions are blocking. `reset-keymap-layout-index` uses the typed `guint` reply. `reset-keymap-description` resolves the client `Meta.KeymapDescription` lease to the server boxed value and copies it into mutter’s signal return. The `guint` failure is fixed in libocrpc and the real consumer gate returns `7`; see [`2026-11-05-FIXED-libocrpc-non-boolean-signal-returns.md`](../../../../OLLMchat/docs/bugs/done/2026-11-05-FIXED-libocrpc-non-boolean-signal-returns.md). The boxed lease-to-value codec and all focused callback regressions pass. User has not seen this fail in use.

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

## Fix

`src/server/libmutter-clutter-18/ClutterActor.vala` now makes both reset subscriptions blocking:

```vala
case "reset-keymap-description":
case "reset-keymap-layout-index":
    subscription.blocking = true;
    break;
```

`reset-keymap-layout-index` uses the ordinary typed reply. Integrated libocrpc copies its `guint` into the signal return.

For `reset-keymap-description`, the client return is a `Meta.KeymapDescription` GObject proxy. `Signals.vala` sends its lease to `Gsr-Mutter-Keymap.reply_description`. The server resolves `Gsr.Server.Meta.Keymap.desc`, wraps the real boxed description in a typed `GValue`, and completes the waiting subscription. `Live.Subscription.emit` then copies that typed value into mutter's signal return.

## Verification

```bash
meson test -C build \
  blocking-void-signal \
  subscription-uint-return \
  subscription-boxed-lease-return \
  signal-reentrancy-reentrant-emit-call \
  signal-reentrancy-outer-emit-reply \
  signal-reentrancy-same-hook-reentrant-emit \
  --print-errorlogs
```

All six pass on this API 16 host. The `Meta.KeymapDescription` reply lives in the API 18 shell library.

## LLM efforts

- 2026-11-05. User asked for a report of this problem: these two signals are being used to pass return data, which a signal subscription is not for. Read the stock signal signatures and `keyboardManager.js` on `192.168.122.115`. Wrote this file. Did not change the signal marshal.
- 2026-11-05. User: say it in plain English. The first reply stops the emission. The write-up about further handlers was irrelevant. Replaced the body with that.
- 2026-11-05. User: the report was only GObject behaviour. The gap is that our reply path only carries a boolean, and these two returns are a description and a `uint`. Rewrote the top to that.
- 2026-11-05. User: name where the problem is. The reply wire keeps the value. `OLLMrpc.Live.Subscription.emit` then writes only a boolean. Rewrote the top to that function.
- 2026-11-05. User: the one-paragraph report was unreadable. Replaced it with the three code sites: `add_signals` does not wait, `Subscription.emit` stores a boolean, the client reply has no boxed description.
- 2026-11-05. Split the proved `guint` marshalling failure into a FAIL-backed libocrpc report. Kept the boxed return codec and missing blocking selection here as consumer work.
- 2026-11-05 15:57 HKT. Rebuilt and ran `subscription-uint-return-gate` against the integrated libocrpc fix. PASS: the remote uint reply reached the signal emitter as `7`.
- 2026-11-05 15:59 HKT. Added `subscription-boxed-lease-return-gate`. The first attempt used only `Hook.complete`, which does not cover `Subscription`'s legacy `reply_id`/`reply_args` wait and timed out. The gate passes after resolving the client lease to its server boxed value and completing either Hook form.
- 2026-11-05 16:03 HKT. Applied the two blocking names, specialized the `Meta.KeymapDescription` client reply, added the server lease-to-boxed reply, and factored callback completion so both Hook forms use the same path. The two return gates plus four void/nested callback regressions pass.
- 2026-11-05 17:33 HKT. User rejected an API-version conditional and a new return-policy helper class. Left the legacy dispatcher whole in `libshell-16/Signals.vala`, copied it to `libshell-18/Signals.vala`, and put the `Meta.KeymapDescription` reply only in the API 18 copy. Meson selects exactly one complete dispatcher for the target API. The API 16 shell library rebuild and both focused return gates pass.
- 2026-11-05 17:39 HKT. Corrected the copied API 18 file: it now preserves the API 16 file's comments and formatting exactly. Its only diff is the `Meta.KeymapDescription` reply branch.
- 2026-11-05 17:42 HKT. Re-read the mandatory line-breaking standard after the user caught the missed gate. Removed the gratuitous condition split; the branch now matches the surrounding file's compact conditions and grouped call arguments.
- 2026-11-05 17:47 HKT. Applied the call-wrapping gate to the whole new API 18 file. Collapsed the short `parse_name` and queued `Signals.emit` calls, grouped wrapped call arguments, kept wrapped method-definition parameters one per line, and left only nested RPC calls whose complete expressions exceed the surrounding line length.
- 2026-11-05 17:48 HKT. Collapsed every split boolean and comparison expression in the API 18 copy after the user identified two remaining violations. No continuation line now begins with `||`, `&&`, `==`, or `!=`.
- 2026-11-06. User: the reset returns are fixed and have not caused issues. Closed this bug. Marked both signals done in [`0.9.1-examine-26.04-requirements.md`](../../plans/0.9.1-examine-26.04-requirements.md) and [`0.9-multi-shell-series.md`](../../plans/0.9-multi-shell-series.md).
