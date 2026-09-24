# `style-changed` is manually repaired in `Clutter.Actor`

**Status:** ⏳ **open** — temporary setter bridge still in tree (pulled back from archive 2026-09-24). The `local_emit_after` bridge is the work. Do not treat it as closed by the overview picker bug.

**Scope:** `src/gi-stub/overrides-clutter/Actor.override.vala` and the
`local_emit_after` setters in `St.overrides`.

**Related:** overview look [`2026-09-24-overview-picker-preview-gone.md`](2026-09-24-overview-picker-preview-gone.md) does not own this. Generator note [`2026-09-23-prefix-generated-vala-signals.md`](2026-09-23-prefix-generated-vala-signals.md).

## Problem

`Clutter.Actor` construction used to check the runtime type for a foreign
`style-changed` signal and manually subscribe it:

```vala
if (this.get_type() != t
		&& GLib.Signal.lookup("style-changed", this.get_type()) != 0) {
	GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe(
		this, "style-changed");
}
```

This existed so GJS `BaseIcon.vfunc_style_changed` runs and creates app
textures. It was deliberately after lease mint because subscribing from
`St.Widget` construction caused nested RPC while parsing a reply.

## Why this is suspicious

- A `Clutter.Actor` base override knows about and repairs an `St.Widget`
  signal.
- It discovers the behavior through runtime type/signal lookup rather than
  generated GI metadata.
- It couples lease-construction timing to signal/class-vfunc dispatch.
- It is easy to copy for another signal, producing per-signal hacks. The
  rejected `clicked` attempt in
  [`2026-09-22-search-result-click-no-launch.md`](2026-09-22-search-result-click-no-launch.md)
  demonstrated that this pattern is unsafe.
- `signal_prefer=style_changed` splits the GIR signal and class slot in the
  generated stub. The generator should preserve their stock relationship
  automatically instead of requiring a parent-constructor repair.

The shared generator design problem is documented under “Primary design
suspicion: `signal_prefer`” in
[`2026-09-22-search-result-click-no-launch.md`](2026-09-22-search-result-click-no-launch.md).
This bug tracks removal of the `style-changed` workaround after that
general mechanism is corrected.

## Temporary replacement (2026-09-23) — still in tree

The post-mint `Clutter.Actor` lookup/subscription block has been removed.
Forwarding the server signal, or firing it from a synchronous vfunc hook,
enters the generated `StWidgetClass.style_changed` closure while
`call_poll()` is still inside GJS and crashes in libgjs.

For current startup, generated `St.Widget.style` and `style_class` setters
temporarily call `signal_style_changed()` only after their RPC reply returns.
This passes `buttonbox-hpadding-smoke` (`nat=12 min=6`) and the integrated
nested startup reaches `READY=1` without the style-signal SIGSEGV.

The bridge is marked `local_emit_after` in `St.overrides`. It is not the final
replacement: remove it when notifications can dispatch outside the active
GJS→RPC frame.

## Guardrail

Leave the current bridge in place until a replacement has a failing gate and
keeps icon creation working. **Do not use this bridge as precedent for
`clicked`, `repaint`, icon-click signals, or any other signal.**

Do not treat the old subscribe as the delivery path for
`buttonbox-hpadding-smoke`. That smoke is a GJS `St.Widget` on Helper-Actor
(`relay_attach`). The hook runs during `set_style` and, while it does not
emit, the connect handler stays at 0. There is no `style-changed`
notification in that log. Re-subscribing, or moving this block into
`St.Widget` construct, does not fix that smoke. The locked next edit is on
the virtual signal in
[`2026-09-23-prefix-generated-vala-signals.md`](2026-09-23-prefix-generated-vala-signals.md)
(Locked — do not re-derive).

Do not move the subscription back into `St.Widget` construction: the recorded
nested-RPC/reply-parse deadlock remains a constraint, not a justification for
the current architecture.

## Required replacement proof

1. A focused gate fails when a relayed `style-changed` signal does not invoke a
   GJS `vfunc_style_changed` override.
2. GI stub generation emits the stock signal/class-slot relationship without a
   per-type runtime bridge.
3. The gate passes with the generated behavior.
4. Shell startup still creates BaseIcon textures.
5. The `Actor.override.vala` lookup/subscription block stays deleted, and the
   `local_emit_after` setter bridge is removed.

## Source lookup

GNOME Shell JS is vendored under `vendor/gnome-shell/js/`. Use the vendored
source directly; do not extract installed GResources while investigating this
bug.
