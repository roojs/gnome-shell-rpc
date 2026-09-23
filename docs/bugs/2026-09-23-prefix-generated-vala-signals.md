# Prefix generated Vala signals with `signal_`

**Status:** ⚠️ **open / Phase 1 ✔️ · Phase 2 next**

**Scope:** generated client GI stubs in `src/gi-stub-gen/Generator.vala`

Unblocks [`2026-09-22-search-result-click-no-launch.md`](2026-09-22-search-result-click-no-launch.md) and [`2026-09-22-style-changed-manual-subscription.md`](2026-09-22-style-changed-manual-subscription.md).

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
| 2 | Trash `signal_prefer` + clash workarounds | ⏳ 🔷 |
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
- **ℹ️** `signal_prefer` lines remain as dead config. Generator does not read them.
- **ℹ️** `Actor.destroy_rpc` stays until Phase 2.
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

After proof:

```text
Actor.override.vala post-mint style-changed subscribe
```

- **ℹ️** Widget construct bridge already gone in Phase 1.
- **ℹ️** Keep `vfunc_fallback=hand` and `relay=1`.
- **⏳ 🔷** Restore stock `destroy` vs `destroy_rpc` if prefix makes `Clutter.deny` `Actor.destroy` unnecessary.
- **⏳ 🔷** Drop `signal_method_clash` if a generator run emits zero such gaps.
- **🚫** Move the `style-changed` subscribe into `St.Widget` construct.
- **🚫** `Idle.add` / queues / extra Actor methods to hide GJS reentry.

**Stay-up after Phase 1 emit (2026-09-23)** — expected until this cut:

```text
GSR_NESTED_STAYUP=1 ./scripts/weston-gsr-prove.sh
READY=1 + Meta.is_restart
mutter exited ec=133
```

```text
GI_META_GDB=batch → SIGSEGV libgjs.so.0
#7  g_signal_emit_by_name
#8  Actor.relay_style_changed
    GLib.Signal.emit_by_name(this, "style-changed")
JS show() → call_poll(Clutter-Actor.show) → Live.Invoke
→ class closure = GJS vfunc_style_changed
→ re-enter SpiderMonkey
```

- **ℹ️** `ec=133` is mutter EOS after the **client** SIGSEGV. [`../nested-debug.md`](../nested-debug.md).
- **🚫** `Idle.add` defer of that emit — tried, then `stop (timeout) after 25s` / `ec=124`, **reverted**.

**Gates:** RPC `"clicked"` → `AppIcon.vfunc_clicked()` · `style-changed` → GJS `vfunc_style_changed()` · those two workarounds gone · `class-struct-offset-gate` · nested stay-up + BaseIcon textures.

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
