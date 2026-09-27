# Emitting `clicked` does not run the method the shell overrode

**Status:** ⏳ open. Not applied to the shell. Waiting on a design call.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Seen from:** [`2026-09-24-overview-picker-preview-gone.md`](2026-09-24-overview-picker-preview-gone.md). Clicking Terminal in the overview does not start it. Calling `Shell.App.launch` directly does.

**Reproduction:** `tests/clicked-slot-emit-gate`.

## What the library does

On a real `St.Button`, `clicked` is one class field. Emitting the signal loads the function pointer in that field and calls it. The shell replaces that pointer (`vfunc_clicked` on `AppIcon`). The emit then runs the shell method, which launches the app.

`AppIcon` does not `connect('clicked')`. The launch is the method, not a signal handler.

## What we generate

Vala cannot declare a signal and a method with the same name, and a Vala virtual signal is parked at the end of the class. Every field after it moves. `allocate` moved that way, and the desktop picture stayed 0×0. That is [Virtual functions](../vfuncs.md).

The generator therefore emits two separate members, on purpose:

1. A plain virtual at the library's byte, so GJS still writes `vfunc_clicked` where the real library would.
2. A normal signal, not a virtual one, so `connect('clicked')` still finds the stock name and later fields stay put.

Vala registers that normal signal with no class field. The generated C is `g_signal_new (..., 0, ...)`. The `0` means emit runs `connect()` handlers and does not load the method.

So a click notification can arrive, the signal can be emitted, and `AppIcon.vfunc_clicked` still does not run. Nothing in the shell calls that method on the notification path.

## What the gate showed

`tests/clicked-slot-emit-gate` is that shape and nothing else. A subclass overrides the plain virtual and does not connect the signal. Emitting the signal left the override at 0.

The same program then, from its class initializer, points the signal at the existing method:

```c
g_signal_type_cclosure_new (type, offset);
g_signal_override_class_closure (id, type, closure);
```

After that, the override runs: `hits=1`, exit 0. In the gate the method is the first slot, so `offset` is `sizeof(GObjectClass)`. On a real `St.Button` it is not the first slot. A shell change would have to pass the library's byte, not that constant.

## Why this may be a workaround

That extra call does not make the signal and the method one field. Vala has already registered the signal with offset 0. The call reaches back afterwards and installs the link GLib would have had if the offset had been the method's byte in the first place.

Vala has no way to say "this signal's default handler is that existing field, and the field stays at this byte." The construct that does say it is `virtual signal`, and Vala implements that by moving the field. We already rejected that move.

So the gate's call papers over the split. It is not the layout the library uses, and it is not in the generator.

The same kind of call, made while `call_poll` was still inside JavaScript, crashed the session. Recorded in [`2026-09-23-prefix-generated-vala-signals.md`](2026-09-23-prefix-generated-vala-signals.md). This gate emits from `main`. It does not emit from inside a remote call, so a pass here does not say the shell would survive it.

## Design question

Is the split (plain virtual at the real byte, signal with no class field) the design we keep, with emit never calling the method unless we add a later link?

Or does a signal that is also a class method have to be one field, which means Vala's virtual-signal layout cannot be what we emit?

The later link is not applied. Do not put `virtual signal` back to get the call.
