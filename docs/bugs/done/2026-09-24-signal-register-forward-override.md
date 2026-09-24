# Signal arguments need a type override

**User goal:** nested mutter-rpc + gnome-shell-rpc stays up and answers pointer and keyboard. From [`../../plans/0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md).

**Status:** ✅ closed 2026-09-24. `Clutter.Event` goes out as fields. The `key-press-event` name check is gone.

**Seen:** 2026-09-24 10:22:59 and 10:23:32. `gnome-shell-rpc` `SIGTRAP`.

```text
connection write error: unsupported bin value type 'ClutterEvent'
Error receiving data: Connection reset by peer
```

**Landed:**

- OLLMchat `docs/bugs/done/2026-09-24-FIXED-bin-type-override.md` — `OLLMrpc.Bin.TypeOverride`, `pack_params`, `fill_params`
- `src/rpc/helper/ClutterEventOverride.vala` — compositor pack
- `src/shell-gi/ClutterEventOverride.vala` — client unpack via `from_local`
- `src/shell-gi/Signals.vala` — `fill_params`; the empty-args `key-press-event` branch is removed

The 14:24 connection reset after this landed was `Unregistered class type schema: GTask`, not `ClutterEvent`.

## Existing flow

```text
emit signal
  -> pack every argument as a bin value
  -> ClutterEvent has no bin encoding
  -> connection reset
```

`relay_event` already sends that value as fields:

```text
type, x, y, button, keyval
pack: tidduu
client: Event.from_local(type, x, y, button, 0, keyval)
```

## Intended flow

**🔷** The forwarder looks at the argument's type.

**🔷** A `Clutter.Event` is written as the fields already used by `LayoutHooks.measure_event` and `Helper.ClutterHelper.get_current_event`.

**🚫** Generator tags. Signal-name checks. A "do not forward" flag.

## 1. Type registry

**ℹ️** OLLMchat `docs/bugs/done/2026-09-24-FIXED-bin-type-override.md`.

**🔷** `OLLMrpc.Bin.TypeOverride`, `pack_params`, `fill_params`, and the `Subscription.emit` call live in that bug. This file does not repeat them.

## 2. `Clutter.Event` helper

**Where:** this tree, not libocrpc. Subclass of `OLLMrpc.Bin.TypeOverride`. Registered once at shell startup and once from compositor helper startup.

**ℹ️** Field order is type, x, y, button, key symbol (`idduu`). Button is read only for button and pad-button events. Key symbol is read only for key press and key release.

## 3. Pack each argument

**ℹ️** `Subscription.emit` calling `pack_params` is in OLLMchat `docs/bugs/done/2026-09-24-FIXED-bin-type-override.md`.

## 4. `Signals.vala` — unpack

**Where:** `src/shell-gi/Signals.vala`. The name check in `Signals.connect` is removed. `Signals.emit` calls `fill_params`, then keeps the empty `Clutter.Frame` fill.

## Where it sits

**ℹ️** Registry, `pack_params`, `fill_params`, and `Subscription.emit` are OLLMchat `docs/bugs/done/2026-09-24-FIXED-bin-type-override.md`.

**🔷** `ClutterEventOverride` stays in this tree. Pack and unpack call `Clutter.Event`. libocrpc does not know those.

**🔷** `Signals.emit` calls `fill_params`, then keeps the empty `Clutter.Frame` fill and `emitv`. The `key-press-event` name check is deleted here.
