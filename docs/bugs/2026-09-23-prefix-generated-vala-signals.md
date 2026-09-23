# Prefix generated Vala signals with `signal_`

> # ⚠️⚠️⚠️ AGENTS — READ THIS FIRST ⚠️⚠️⚠️
>
> ## DO NOT STOP for “status theatre”
>
> **Keep working.** Do not pause to narrate progress, summarize what you tried,
> or ask whether to continue after every prove / dead end / rebuild. Carry on
> until the bar moves or you hit one of the stop conditions below.
>
> ## When you MAY stop
>
> 1. **You actually need the user’s help** — a decision only they can make,
>    credentials, a machine/session you cannot reach, or explicit approval the
>    plan forbids you from assuming. Say what you need in one short ask, then
>    wait.
> 2. **OPC / libocrpc is the problem** — and only then: write a **FAIL-backed**
>    gate under `tests/call-sync-repro/` that **FAIL**s, file the **bug in
>    OLLMchat** (`docs/bugs/`), **do not edit OLLMchat code from this tree**,
>    and **stop**. Do **not** file OPC bugs under this repo’s `docs/bugs/`.
>    PASS gates → chase the **consumer**; do not stop to “report” a theory.
>
> ## Everything else
>
> File/update the tracking bug, pick the next allowed step, rebuild, prove,
> repeat. No Idle/defer/helper thrash. No layout.js ship hacks.

**Status:** ⚠️ **open / event, clicked, style and relayed layout proofs pass**

**Scope:** generated client GI stubs in `src/gi-stub-gen/Generator.vala`

Unblocks [`2026-09-22-search-result-click-no-launch.md`](2026-09-22-search-result-click-no-launch.md) and [`2026-09-22-style-changed-manual-subscription.md`](2026-09-22-style-changed-manual-subscription.md).

## Agent handoff — 2026-09-23 18:10

Current tree builds successfully with `ninja -C build -j1`.

The important new repair is the temporary stock-offset vfunc bridge:

- `src/gi-stub/c-vfunc-relay.c` reads a function pointer from
  `G_OBJECT_GET_CLASS(instance) + typelib_offset`;
- `src/gi-stub/VfuncRelay.vala` exposes typed Vala calls into that bridge;
- `Actor.override.vala` uses it for relayed preferred width/height, allocate,
  event, captured-event and queue-relayout;
- the bridge is explicitly marked temporary;
- duplicate key-event emission in `relay_event` was removed;
- `Clutter.Event.get_flags()` now exports the real stock
  `clutter_event_get_flags` symbol and returns `NONE` for reconstructed events.

Do not revert this to direct `this.event_vfunc()` / `allocate_vfunc()` calls.
Those compile, but valac's generated `ClutterActorClass` field order differs
from the stock typelib offsets used by GJS. `panel-click-smoke` previously
failed without entering `vfunc_event`; it now logs `vfunc_event`, `clicked`,
and `ok`.

The nested wrapper currently ends with `ec=137` after successful smoke output,
apparently during teardown; use
`~/.cache/gnome-shell-rpc/nested-weston-prove.tee.log` as the smoke result.
This is separate from the earlier runtime failures.

Next:

1. Run the full nested shell and visually reassess right-side panel icon
   placement, stacking, notification dismissal and cursor trails.
2. Trace any remaining bad Actor relay through the same stock-offset rule;
   do not add Idle/Timeout queues or `layout.js` clamps.
3. Strengthen the class-slot gate. Its total-size assertion cannot detect
   valac's per-field reordering.
4. Replace the temporary bridge only when generated class ABI can preserve
   every stock field offset.

## Working result — 2026-09-23 17:30

Vala's renamed `public virtual signal` installs the correct C class-field
offset, but GJS does not install `vfunc_style_changed` for it. The temporary
working representation therefore splits the concepts:

- `Widget.style_changed_vfunc()` retains the stock `style_changed` class slot;
- non-virtual `signal_style_changed` retains the stock GObject signal name;
- `Widget.override.vala` connects that signal to the virtual method;
- post-mint `style-changed` subscription restores server delivery;
- `Widget.set_style` emits locally after its RPC has returned.

The prefix migration also exposed a stale deny for
`Clutter.Actor::queue-relayout`. Removing that deny and applying the same
temporary split-signal bridge restored the real GObject signal alongside the
hand-written `queue_relayout()` method and preserved the stock class slot.
Without it, app grid creation stopped at:

```text
No signal 'queue-relayout' on object 'Gjs_ui_appDisplay_AppIcon'
```

With both repairs, the integrated app-grid gate now reaches:

```text
app-search-launch-smoke: nGrid=6 first=true
app-search-launch-smoke: icon-textures=6/6
app-search-launch-smoke: stopped-icons=6
app-search-launch-smoke: L1 launch() returned true
```

`buttonbox-hpadding-smoke` still passes with `min=6`, `nat=12`, including its
GJS `vfunc_style_changed` assertion. `class-struct-offset-gate` passes.

Generated-library VAPIs export the stock signal identifier when there is no
method collision, so cross-library `shell-gi` consumers use those exported
spellings. In-library generated Vala still uses `signal_*`.

## Stock class-slot dispatch regression — 2026-09-23 18:04

The remaining event/layout regression was not an RPC or signal-delivery
failure. `ClutterActorClass` physically interleaves virtual methods and signal
class closures, while valac regroups them in its generated C class struct.
Consequently GJS installed `vfunc_event` at the stock typelib offset, but
Vala's `this.event_vfunc()` read a different generated field. The old
`class-struct-offset-gate` only compared total class size, so it could pass
while individual fields were wrong.

A clearly marked temporary C bridge now calls the function pointer at the
typelib byte offset. Actor event, captured-event, preferred-size, allocate and
queue-relayout relay paths use it. The generator also sorts repository class
and interface fields by `FieldInfo.offset`, although that alone cannot prevent
valac's later regrouping.

Proofs after the bridge:

```text
panel-click-smoke: vfunc_event type=6
panel-click-smoke: clicked
panel-click-smoke: ok

buttonbox-hpadding-smoke: theme min=6 nat=12 _minHPadding=6 _natHPadding=12
buttonbox-hpadding-smoke: ok nat=12 min=6

date-menu-open-smoke: open dateMenu
date-menu-open-smoke: ok
```

The date-menu run also exposed a real stock API omission:
`clutter_event_get_flags`. The local reconstructed event now exports that
method and returns `0` (`CLUTTER_EVENT_NONE`) until relay event flags are
carried on the wire.

`quicksettings-layout-neg-smoke` still reproduces `min=-12 nat=-12` for an
empty QuickSettings grid. That is the pinned stock
`(rows.length - 1) * row_spacing` case; no forbidden `layout.js` clamp was
added.

## Phases

- **🔷** Work stays in this bug. Not a `docs/plans/` file.
- **🚫** Phase 2 before Phase 1 gates PASS
- **🚫** Phase 3 before Phase 2 gates PASS
- **🚫** `Idle.add` / `Timeout.add` / invoke queues / `queue_*_emit` helpers
- **🚫** New fire-path logic to paper over GJS reentry
- **🚫** Invented GI methods on `Clutter.Actor` / `St.Widget`

| # | Cut | Status |
| - | --- | ------ |
| 1 | Generator `signal_*` + virtual signal | ✔️ |
| 2 | Trash `signal_prefer` + clash workarounds | ⏳ in progress |
| 3 | Override content review | ⏳ 🔷 |

### Phase 1 — Generator

**Where:** `src/gi-stub-gen/Generator.vala`

#### Remove

```text
emit class slots
  signal_prefer name → slot becomes *_vfunc
emit methods
emit signals under the stock Vala identifier
```

```vala
public signal void clicked(uint button);

[CCode (cname = "gsr_button_clicked_vfunc")]
public virtual void clicked_vfunc(uint button) {
}
```

#### Replace with

```text
for each class-struct field:
    if field is the class closure for a signal:
        emit renamed virtual signal at this field position
    else:
        emit normal virtual method

for each remaining signal:
    emit renamed non-virtual signal

emit callable methods independently
```

```vala
[CCode (cname = "clicked")]
public virtual signal void signal_clicked(uint button) {
}
```

- **✔️** Match on this class's GIR signal (`St.Button::clicked`), not `signal_prefer`.
- **✔️** Mechanical Vala identifier updates (`stopped.connect` → `signal_stopped.connect`, `event_vfunc` → `signal_event`).
- **✔️** Delete Widget construct `style_changed.connect` → `style_changed_vfunc()`.
- **✔️** Tree compiles.
- **ℹ️** `vfunc_fallback=hand` layout `*_vfunc` (`allocate`, `show`, `hide`) stays.
- **✔️** `signal_prefer` lines and the parser are gone (Phase 2).
- **✔️** `Actor.destroy` is the generated method again (`clutter_actor_destroy` beside `signal_destroy`). `destroy_rpc` is gone.
- **🚫** Rename signals on real mutter objects (`src/rpc/Server.vala`, `src/rpc/helper/*`).
- **🚫** Search click-to-launch as a Phase 1 gate.
- **🚫** Delete Actor post-mint `style-changed` subscribe in this phase.
- **🚫** Nested stay-up as a Phase 1 gate — virtual-signal fire is Phase 2.
- **🚫** New logic on the fire path (`Idle.add`, coalesce queues, skip-class-closure pokes, extra public Actor methods).

**Gates**

- **✔️** `class-struct-offset-gate` — `ok checked=39 clicked@488 style_changed@448`
- **✔️** GIR/GObject names `clicked` / `style-changed` (not `signal-clicked` / `signal-style-changed`)
- **✔️** `captured-event::touchpad` still `G_SIGNAL_DETAILED`
- **✔️** `Clutter.Text` `activate()` method + `activate` signal coexist

### Phase 2 — Trash clash machinery

**Depends on:** Phase 1 ✔️.

#### Remove

`src/gi-stub-gen/St.overrides` / `Clutter.overrides`:

```text
Namespace signal_prefer=clicked
Namespace signal_prefer=style_changed
…
```

Plus `signal_prefer` field / parser in `Generator.vala` / `Application.vala`.

- **✔️** `Namespace signal_prefer=…` removed from `Clutter.overrides` and `St.overrides`.
- **✔️** `signal_prefer` field and parser removed. Generator matches this class's GIR signal.
- **✔️** Dead `method_names` / `signal_names` bookkeeping removed. A generator run records no `signal_method_clash` gaps (`Clutter_generated.missing.md`, `St_generated.missing.md`).
- **✔️** `Clutter.deny` `Actor.destroy` removed. Generated `Actor.destroy()` is `clutter_actor_destroy`. `signal_destroy` still registers GObject `"destroy"` at `ClutterActorClass.destroy`. No second `clutter_actor_destroy` symbol. `destroy_rpc` removed from `Actor.override.vala`.

After proof:

```text
Actor.override.vala post-mint style-changed subscribe
```

- **ℹ️** Widget construct bridge already gone in Phase 1.
- **ℹ️** Keep `vfunc_fallback=hand` and `relay=1`.
- **⏳** Post-mint `style-changed` subscribe stays. Removed once: stay-up held and `St-Icon.new` still ran, but `style-changed` notifications went to zero, so `vfunc_style_changed` was not proved. Subscribe restored.
- **🚫** Move the `style-changed` subscribe into `St.Widget` construct.
- **🚫** `Idle.add` / queues / extra Actor methods to hide GJS reentry.

**Stay-up (2026-09-23)** — `emit_by_name("style-changed")` in `relay_style_changed` removed.

Boot reached `READY=1` and was still replying to `before-update` 21s later. The earlier death was `ec=133` about 3s after READY:

```text
#7  g_signal_emit_by_name
#8  relay_style_changed  Clutter_generated.vala:1869
    GLib.Signal.emit_by_name(this, "style-changed")
JS show() → call_poll(Clutter-Actor.show) → Live.Invoke
→ class closure re-enters libgjs → SIGSEGV
```

That hook no longer emits. `connect('style-changed')` and `vfunc_style_changed` do not run from it.

### Locked — do not re-derive (2026-09-23)

Shell stays up. Layout is wrong, the software cursor is painted again and again, icons are gone, icon layout is wrong. Same missing client `style-changed`. Do not open a cursor bug or an icon bug beside this section. `src/Plugin.vala` already records that an uncleared framebuffer trails the software cursor.

`buttonbox-hpadding-smoke` is the gate. 2026-09-23 15:52, hook still a no-op:

```text
theme min=6 nat=12 _minHPadding=0 _natHPadding=0
FAIL nat-hpadding-cache want>=12 got=0 (style-changed did not update GJS)
FAIL min-hpadding-cache want>=6 got=0
```

Client log for that run: `St-Widget.set_style` (id=45) nested `Live.Invoke` of the style hook (callback ids 20 and 24), empty reply, then `ensure_style`. No `notification method=style-changed`. The hook ran. It did not emit. Theme lengths RPC. GJS `connect('style-changed')` did not.

Do not run this investigation again. These are closed:

- **🚫** Put `GLib.Signal.emit_by_name(this, "style-changed")` back. That is the SIGSEGV above. It existed only because `Actor.override` is Clutter and cannot name `St.Widget.signal_style_changed`.
- **🚫** `Idle.add` / `Timeout.add` / a queue / `queue_*_emit` around that emit. Already tried; stay-up timed out (`ec=124`).
- **🚫** Another post-mint `ensure_signal_subscribe`, or moving it into `St.Widget` construct. Subscribe is the `.new` lease path (BaseIcon / `St.Bin`). This smoke is Helper-Actor via `relay_attach`. Removing the subscribe zeroed notifications and did not change this hook. Nested RPC mid-reply parse is why it is not in Widget construct.
- **🚫** A new `Clutter.Actor` method, a parent-class `Signal.lookup`, or a second class slot. `class-struct-offset-gate` is already `style_changed@448`.

One next edit, then the same smoke. Nothing else.

`relay_event` already fires a virtual signal from a hook: `this.signal_event(ev)` → `g_signal_emit`. That is the stock fire. `signal_style_changed` is the same kind of member (`public virtual signal`, `g_signal_new("style-changed", ..., G_STRUCT_OFFSET(StWidgetClass, style_changed), ...)`). The hook body belongs on `St.Widget`, where that member exists:

```text
Widget.override — register the style hook after Actor.relay_attach
                 (Actor construct runs first; helper rpc_lid is set)
hook body      — this.signal_style_changed()
Actor.override — delete relay_style_changed and its add_hook
                 so the signal cannot fire twice
```

Then:

```text
GI_META_SMOKE=buttonbox-hpadding-smoke ./scripts/agent-nested-smoke-prove.sh
```

Pass is `ok nat>=12 min>=6`. If that process SIGSEGVs, record the stack under this heading and stop. Do not swap in another emit, and do not put `emit_by_name` back. `signal_event` from a hook is the comparison, not a reason to invent a third path.

**✔️ 2026-09-23 16:11** — `buttonbox-hpadding-smoke` only:

```text
theme min=6 nat=12 _minHPadding=6 _natHPadding=12
ok nat=12 min=6
```

That smoke is `set_style` on a tiny `St.Widget`. It is not boot.

**❌ 2026-09-23 16:14 hold** — user start. Not a prove SIGKILL. `READY=1` at 16:13:57. Client log ends at 16:14:00 on `invoke ENTER id=1619` with no reply. Mutter then `Unexpected early end-of-stream`. `nested-weston-prove: mutter exited ec=133` on the gdb rerun (8s).

`GI_META_GDB=batch` (no SIGTRAP catch): Thread 1 SIGSEGV in `libgjs.so.0`.

```text
#0  libgjs.so.0
#4  g_closure_invoke
#8  g_signal_emit
#9  __lambda5_  src/St_generated.vala:3051
    this.signal_style_changed()
#20 oll_mrpc_client_call_poll
#22 gnome_shell_rpc_call_value "Clutter-Actor.show"
#23 clutter_actor_show
#27 libgjs / libmozjs   (JS already inside show())
```

GType at frame 9: `Gjs_ui_workspacesView_WorkspacesDisplay`. That class extends `St.Widget` and has no `style-changed` handler of its own (`vendor/gnome-shell/js/ui/workspacesView.js`).

`this.signal_style_changed()` is `g_signal_emit`. Same death as `emit_by_name`, same `show()` → `call_poll` nest. Do not call this a different fix. Do not put `emit_by_name` back. Do not Idle/queue it.

**❌ 2026-09-23 16:34** — helper `relay_attach` subscribed `style-changed` and the hook did not emit. Same death, other call site. `mutter exited ec=133` after 7s. `READY=1`, then `Clutter-Actor.show`, then `notification method=style-changed`, then the client is gone.

```text
#4  g_closure_invoke
#6  g_signal_emitv
#7  Runtime.emit_signal_from_args  signal_name="style-changed"
    Runtime.vala:124
#17 oll_mrpc_client_call_poll
```

Hook emit and notification emit are the same `g_signal_emit` of the virtual signal. At `6ac7b3a` the generated member was `public signal void style_changed()` — class closure offset 0 — and the class field was a separate `style_changed_vfunc`. `emit_by_name` ran connect handlers and did not enter that field. Phase 1 points `g_signal_new` at `StWidgetClass.style_changed`, so both emits enter the GJS class closure during `show()`. Helper subscribe removed again after this stack. Do not add it back as a fix.

**✔️ TEMPORARY 2026-09-23 16:50** — style setters emit after RPC return.

`St.overrides` marks only `Widget.set_style` and
`Widget.set_style_class_name` with `local_emit_after=signal_style_changed`.
The generator emits that call after `call_value()` has returned, outside the
active `call_poll()` frame. The post-mint Actor `style-changed` subscription is
gone.

```text
buttonbox-hpadding-smoke: theme min=6 nat=12 _minHPadding=6 _natHPadding=12
buttonbox-hpadding-smoke: ok nat=12 min=6
```

The full nested startup reached `READY=1` and completed its timed prove without
SIGSEGV. Applying the same temporary emit to pseudo-class and add/remove-class
mutators caused an overview callback storm, so those broader entries were
removed. This is explicitly a temporary bridge, not the final notification
dispatch architecture.

**✔️ TEMPORARY 2026-09-23 16:56** — `clicked` transport is subscribed after
`Helper-Actor.create` for client types that expose the generated stock
`clicked` signal. This no longer needs the rejected hand-written Button class
handler: `signal_clicked` owns `StButtonClass.clicked`.

`app-search-launch-smoke` completed `L2`, `L3`, and `ok`, with two mapped normal
windows. That smoke still recorded no `notification method=clicked`, so it does
not by itself close the real physical-click bar; the temporary subscription
remains until that delivery is observed.

**Gates:** RPC `"clicked"` → `AppIcon.vfunc_clicked()` · `style-changed` → GJS `vfunc_style_changed()` · post-mint subscribe gone · `class-struct-offset-gate` · nested stay-up + BaseIcon textures.

- **✔️** `class-struct-offset-gate` — `ok checked=39 clicked@488 style_changed@448` (after the clash-machinery delete).
- **✔️ temporary** style-changed connect/vfunc delivery after style setters; old post-mint style subscription gone; nested startup stays up.
- **⏳** real clicked notification → `AppIcon.vfunc_clicked()` observation.

### Phase 3 — Override content review

**Depends on:** Phase 2 gates.

Walk:

```text
src/gi-stub/overrides/
src/gi-stub/overrides-clutter/
src/gi-stub/overrides-st/
```

- **⏳ 🔷** Keep/trash table in this bug **before** deleting.

| Keep | Trash |
| ---- | ----- |
| Lease / mint | Per-signal connect → `*_vfunc` bridges |
| `relay=1` + `*_vfunc_fallback` | Runtime `Signal.lookup` repairs |
| Local properties | Extra virtuals that smash class-struct offsets |
| Documented RPC bodies | Leftover `destroy_rpc`-style renames |
| `ensure_signal_subscribe` for `connect()` not `vfunc_*` | Rejected `clicked` Button override |

- **⏳ 🔷** [`../signals-client.md`](../signals-client.md) collision section describes `signal_*` + virtual signal, not `signal_prefer`.

## Problem

Generated Vala currently tries to use the stock identifier for several different GI concepts:

```text
GObject signal
class-struct signal closure
virtual function
callable method
property
```

Vala does not allow a signal and method to share one source-language identifier.

The current generator resolves selected collisions with:

```text
Namespace signal_prefer=clicked
Namespace signal_prefer=style_changed
...
```

It then generates two independent Vala members:

```vala
public signal void clicked(uint button);

[CCode (cname = "gsr_button_clicked_vfunc")]
public virtual void clicked_vfunc(uint button) {
}
```

This preserves:

```text
GJS connect('clicked')
GJS vfunc_clicked class-struct offset
```

It does not preserve:

```text
emit('clicked') -> class closure -> vfunc_clicked()
```

The resulting split is the known cause of RPC `clicked` delivery not invoking `AppIcon.vfunc_clicked()`.

See:

- [`2026-09-22-search-result-click-no-launch.md`](2026-09-22-search-result-click-no-launch.md)
- [`2026-09-22-style-changed-manual-subscription.md`](2026-09-22-style-changed-manual-subscription.md)
- [`../signals-client.md`](../signals-client.md)

## Proposed Vala naming rule

Every generated Vala signal should use a source-language `signal_` prefix:

```vala
[CCode (cname = "stopped")]
public signal void signal_stopped(bool finished);
```

For canonical hyphenated GObject names:

```vala
[CCode (cname = "style-changed")]
public signal void signal_style_changed();
```

The names should remain:

```text
Vala source identifier: signal_style_changed
GObject signal name:     style-changed
GJS signal name:         style-changed
```

Client Vala code would use the explicit signal member:

```vala
transition.signal_stopped.connect((transition, finished) => {
    // ...
});
```

GJS would remain stock:

```js
transition.connect('stopped', (_transition, finished) => {
    // ...
});
```

## Signal-backed class slots

A GIR signal with a corresponding stock class-struct closure must become one renamed **virtual signal**, not a signal plus a separate virtual method.

Target shape:

```vala
[CCode (cname = "clicked")]
public virtual signal void signal_clicked(uint button) {
}
```

Expected external views:

```text
Vala source signal: signal_clicked
GObject signal:     clicked
C class field:      clicked
GJS connection:     connect('clicked', ...)
GJS override:       vfunc_clicked(...)
```

The generator must emit this declaration at the stock GIR class-struct position.

It must not also emit:

```vala
public virtual void clicked_vfunc(uint button) {
}
```

Otherwise the generated class has two independent slots and retains the existing bug.

## Method/signal collisions

The prefix should let Vala represent both concepts without choosing a winner:

```vala
public void activate() {
    // RPC method
}

[CCode (cname = "activate")]
public signal void signal_activate();
```

Expected external API:

```js
object.activate();
object.connect('activate', handler);
```

The migration must verify that Vala's generated C emitter symbols do not collide with generated RPC method symbols. If they do, the generator must assign separate internal C symbols while retaining the stock GObject signal name.

## Why `CCode(cname)` rather than a hand-written C wrapper

Vala supports renamed signals:

```vala
[CCode (cname = "stock-signal-name")]
public signal void signal_source_name();
```

The annotation is expected to control:

```text
GObject signal registration name
signal lookup and connection name
signal emission name
generated GIR signal name
generated class-field name for a virtual signal
```

A hand-written C registration wrapper should only be added if a focused gate proves that Vala cannot preserve a required stock detail:

```text
class-closure offset
signal flags
detail support
return type
accumulator
marshaller
GIR metadata
```

Do not introduce C glue merely to rename the Vala identifier.

## Generator changes

The design should replace the current order:

```text
emit class slots
emit methods
emit signals
```

with collision-aware generation:

```text
read GIR signals
read GIR class-struct fields

for each class-struct field:
    if field is the class closure for a signal:
        emit renamed virtual signal at this field position
    else:
        emit normal virtual method

for each remaining signal:
    emit renamed non-virtual signal

emit callable methods independently
```

The matching key must be the fully qualified GIR symbol:

```text
St.Button::clicked
St.Widget::style-changed
Clutter.Actor::event
```

Do not use a namespace-wide bare-name allowlist as the primary mechanism.

## Migration impact

Generated Vala call sites must change:

```vala
// Before
transition.stopped.connect(handler);

// After
transition.signal_stopped.connect(handler);
```

Local Vala emission must change:

```vala
// Before
this.style_changed();

// After
this.signal_style_changed();
```

String-based GObject and GJS calls must not change:

```vala
GLib.Signal.emit_by_name(this, "style-changed");
```

```js
object.connect('style-changed', handler);
object.emit('style-changed');
```

Likely migration areas:

```text
src/gi-stub/overrides-*/
src/gjs-embed/
tests/
generated GIR and typelib expectations
```

## Required gates

### Renamed non-virtual signal

```vala
[CCode (cname = "pinged")]
public signal void signal_pinged(string payload);
```

Prove:

```text
Vala signal_pinged.connect() works
GObject signal lookup("pinged") works
GJS connect('pinged') works
generated GIR contains pinged
generated GIR does not expose signal-pinged
```

### Signal/class-slot collision

Use a real generated collision such as `St.Button::clicked`.

Prove:

```text
RPC notification "clicked"
  -> client emits GObject signal "clicked"
  -> connected GJS handlers run
  -> GJS vfunc_clicked() runs
```

Also prove:

```text
super.vfunc_clicked() chain-up works
class-struct-offset-gate remains PASS
no duplicate clicked class slots exist
```

### `style-changed`

Prove:

```text
server St.Widget::style-changed
  -> client signal_style_changed
  -> connect('style-changed') handler
  -> GJS vfunc_style_changed()
```

After that proof, remove:

```text
src/gi-stub/overrides-st/Widget.override.vala hand bridge
src/gi-stub/overrides-clutter/Actor.override.vala post-mint workaround
```

### Detailed signal

Prove:

```text
connect('captured-event::touchpad', handler)
```

retains:

```text
stock detailed signal name
G_SIGNAL_DETAILED
detail quark dispatch
```

### Non-void signal

Generate at least one non-void signal and prove local behavior:

```text
return GType
default handler
connected handlers
accumulator behavior, if present
```

This does not add cross-process return transport. Generic RPC signal notifications remain one-way.

### Method/signal collision

Prove one object can expose:

```js
object.activate();
object.connect('activate', handler);
```

without:

```text
Vala identifier collision
C symbol collision
GIR omission
GJS ambiguity
```

## Removal criteria

The migration is complete only when:

```text
all generated Vala signals use signal_*
stock GObject and GJS names are unchanged
signal/class-slot collisions use one class closure
signal_prefer is removed or limited to documented exceptional GIR defects
manual style-changed bridges are removed
clicked RPC delivery reaches AppIcon.vfunc_clicked()
class-struct ABI gates pass
integrated GNOME Shell startup and interaction gates pass
```

## Non-goals

- **🚫** automatic RPC subscription from GJS `connect()`
- **🚫** client-to-server signal emission
- **🚫** generic signal return-value transport
- **🚫** subscription reference counting
- **🚫** C glue merely to rename the Vala identifier
- **🚫** rejected `Button.override.vala` `clicked` hand bridge
