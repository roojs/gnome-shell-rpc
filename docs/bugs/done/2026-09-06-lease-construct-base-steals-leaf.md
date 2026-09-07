# Lease-on-construct: leaves never mint their own peer (L4)

**Status:** ✔️ fixed — Wayland prove 2026-09-07 (`/tmp/mutter-rpc-l4-prove.log`)  
**Plan:** [`docs/plans/0.7.7-thin-shell-bootstrap.md`](../plans/0.7.7-thin-shell-bootstrap.md) T-030 **L4**  
**Hit:** 2026-09-06 — Wayland nested, `_initializeUI` chrome ~**main.js L246–252**  
**Last updated:** 2026-09-07

**Fix:** generated lease `construct` walks `Bin.gtype_to_alias` and mints leaf `alias.new`. Prove: `St-Button`/`BoxLayout`/`Label`/… `.new` on wire; no `get_clutter_text` SEGV; nested ~1m. Residual: `ST_IS_WIDGET` → [St ctor parent-walk](2026-09-07-st-ctor-parent-walks-to-actor.md).
---

## Short version

The bug is not “Actor is evil.” It is that **derived St/Clutter stubs do not finish leasing as themselves**.

On `new St.Button()`, the **Button** construct block runs, sees `rpc_lid` already set by a **base** (`Clutter.Actor`), and **returns without calling `St-Button.new`**. The client object is still a Button stub in GJS/Vala, but its wire peer is whatever the base minted — almost always a plain **Actor**. Later `St-Button.*` / `St-BoxLayout.*` / `St-Bin.*` / `St-Icon.*` RPCs hit that Actor on the compositor → `ST_IS_*` asserts → eventually SEGV (e.g. `St-Label.get_clutter_text`).

People sometimes say “falling back to Widget.” The mechanism is the same idea (leaf did not lease; an ancestor did). On the live log the ancestor that actually won is **`Clutter-Actor.new`**, not `St-Widget.new`, because Actor’s construct runs first and sets the lid before Widget’s construct can mint.

---

## How leasing is supposed to work

Every live stub implements `OLLMrpc.Live.Handle` with `rpc_lid`. The generator emits lease-on-construct (this body is **LOCKED** — do not change without an explicit design note and owner approval):

```vala
construct {
    if (this.rpc_lid != 0) {
        return;
    }
    var response = GnomeShellRpc.call_value("Ns-Type.new", null /*, args */);
    var stub = response.retval.get_object() as OLLMrpc.Live.Handle;
    this.rpc_lid = stub.rpc_lid;
}
```

That matches the Handle contract in libocrpc:

- **Wire import:** `Bin.Stream.parse_object` does `Object.new(T, "rpc-lid", id)`. Construct properties are applied before construct bodies, so every class in the chain sees `rpc_lid != 0` and **skips** minting. Correct: the server already has the object; we must not call `T.new` again.
- **Local create:** `new T()` starts with `rpc_lid == 0`. The first construct that runs with lid still zero calls `Ns-Type.new`, exports a server peer, and stores the lease id.

For a **single** class with no leasing bases, that is enough. For a **hierarchy** where many ancestors also emit the same pattern, local create breaks.

---

## What happens on `new St.Button()` (local)

Approximate client hierarchy (stock St):

`Clutter.Actor` → `St.Widget` → … → `St.Bin` → `St.Button`

Vala/GObject runs **construct base → derived**:

| Step | Class construct | `rpc_lid` on entry | Action |
| --- | --- | --- | --- |
| 1 | `Clutter.Actor` | `0` | Calls **`Clutter-Actor.new`**, sets `rpc_lid` to that Actor’s lease |
| 2 | `St.Widget` (generated and/or `Widget.override`) | **non-zero** | **Skip** — never `St-Widget.new` |
| 3 | Intermediate St types (`Bin`, …) | non-zero | **Skip** |
| 4 | `St.Button` | non-zero | **Skip** — never **`St-Button.new`** |

So:

- The **leaf’s lease construct did run**, but it did not lease **as a Button**.
- The stub “falls back” to the peer created by the first ancestor that found `rpc_lid == 0` — here **Actor**.
- If Actor did not emit lease-on-construct and Widget were first, the peer would be a Widget instead. Same class of bug: **wrong GType on the server for this client leaf**.

Wire evidence from the nested run: lots of `Clutter-Actor.new`, then `St-Button.set_icon_name` / `St-BoxLayout.set_orientation` / `St-Bin.set_child` with `ST_IS_*` failures. You do not see a matching `St-Button.new` before those sets.

On the compositor, Gi invokes the real C entry points on the leased GObject. An Actor lease is not an `StButton*`. Assertions fire; some paths SEGV (Label text peer).

---

## Why this is easy to miss on mock

Mock/GiMock often returns a token typed loosely enough that JS keeps going. Live mutter checks `ST_IS_BUTTON` etc. Product progress is **Wayland**. Mock already cleared this chrome band (~L246–252 through ~L329); that does **not** mean live leaf leasing is correct.

---

## Why the Handle early-return exists (and must stay for wire)

If we delete `if (this.rpc_lid != 0) return` and always call `Ns-Type.new` in every construct:

- Local `new St.Button()` would mint Actor, then Widget, then Button — leaf could win by overwrite.
- Wire `Object.new(Stage, "rpc-lid", id)` would still enter Stage’s construct with lid already set, **call `Clutter-Stage.new` again**, get another object, replace the lid, and/or recurse when decoding the return of that `.new`.

That hung the client on `Meta-Backend.get_stage` (`/tmp/mutter-rpc-l4.log`): import of Stage re-entered construct minting. So “always mint, no skip” is not a safe global rule under today’s wire decode (`rpc-lid` as construct property).

The early-return is right for **wire**. It is what stops the **leaf** from minting on **local** create when a base already leased.

---

## Wrong framings / rejected shortcuts

### Type / `is_a` / “Gjs parent” gates in the generator

Tried earlier: only mint if `get_type()` is exactly `C`, or walk off `Gjs*` names. Rejected: fragile, wrong abstraction, and `is_a(typeof(C))` inside `C`’s own construct is always true for subclasses anyway. Also forbidden to sneak back into the **LOCKED** `emit_lease_construct` body.

### Unconditional remint in every St leaf `.override.vala`

Override construct runs in addition to the generated one. A second construct that always calls `St-Button.new` and overwrites `rpc_lid` would fix local Button **and** re-mint on wire import of a Button lease — duplicate server objects, wrong peer identity, painful later. Do not treat that as the fix without a design that covers wire.

### Denying `Clutter.Actor.new` lease emit

Stops Actor from stealing, but shell code freely does `new Clutter.Actor()`. Those objects would never get a lid. Not acceptable.

### Treating “fall back to Widget” as the whole story

Widget is one ancestor. Live theft is usually **Actor** because it constructs first. The invariant to restore is: **after `new Leaf()`, `rpc_lid` must refer to a server object whose GType is that leaf (or the intentional Helper peer, e.g. ConstraintRelay).**

---

## Preferred direction (2026-09-07)

**Not** “Actor skips when the instance isn’t an Actor.”

**Yes:** when a leasing construct runs (typically the first base that finds `rpc_lid == 0`), look at **`this.get_type()`**, walk **up the GType parent chain**, and mint using the **first type that is registered** as a lease target (has a wireable `Ns-Type.new` / lease entry). Call **that** RPC, not hard-coded `Clutter-Actor.new`.

Example — `new St.Button()`:

1. Actor construct runs, `rpc_lid == 0`.
2. `get_type()` → `StButton` (or walk from a `Gjs_*` subclass up to `StButton`).
3. `StButton` is registered → **`St-Button.new`** → set `rpc_lid`.
4. Later Widget / Bin / Button constructs see `rpc_lid != 0` → Handle skip (same as wire). Lid already names a Button peer.

Example — `new Clutter.Actor()`:

1. Walk finds `ClutterActor` registered → **`Clutter-Actor.new`**.

Example — Gjs `class Foo extends St.Button`:

1. Walk `Gjs_Foo` → … → first registered stock type (likely `StButton`) → **`St-Button.new`**.

### Sketch (expected shape)

Use the existing **back-map** from registration — not a new table.

Client already does `Bin.register("St-Button", typeof(St.Button))` (via `st_register` / `meta_register`). That fills:

- `Bin.alias_to_gtype` — wire name → GType  
- `Bin.gtype_to_alias` — **GType → wire name** (look backwards)

Mint selection:

```vala
if (this.rpc_lid != 0) {
    return;
}
var t = this.get_type();
while (t != GLib.Type.INVALID) {
    /* gtype_to_alias is filled by Bin.register — same map encode uses */
    if (OLLMrpc.Bin.gtype_to_alias == null || !OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
        t = t.parent();
        continue;
    }
    var response = GnomeShellRpc.call_value(OLLMrpc.Bin.gtype_to_alias.get(t) + ".new", null);
    this.rpc_lid = (response.retval.get_object() as OLLMrpc.Live.Handle).rpc_lid;
    return;
}
GLib.error("lease construct: no Bin-registered ancestor for %s", this.get_type().name());
```

`new St.Button()`: Actor construct walks `Button` → hit in map → `St-Button.new`.  
`new Clutter.Actor()`: hit `Clutter-Actor` → `Clutter-Actor.new`.  
Gjs subclass: walk until a stock type that was `Bin.register`’d.  
Exhausted parents with no hit → **`GLib.error`** (same as other gi-stub hard fails; do not leave `rpc_lid == 0`).

**Note:** `gtype_to_alias` is public (OLLMchat ✔️). Do not invent a parallel registry.

**Constraint:** Align/Bind/Snap extend {@code ConstraintRelay} on the server (aliases). Mint stays {@code Helper-Constraint.create} — Ffi cannot own wire {@code Clutter-*.new} (clashes with GObject {@code *_new}). Not a client walk skip; Helper is the mint path until/unless OLLMchat Ffi maps {@code .new} to a non-ctor symbol (e.g. {@code gsr_*}).

First construct with `rpc_lid == 0` runs the walk+mint; later constructs skip. Wire import still sets `rpc-lid` before construct → all skip → no walk mint.

### Explicitly not this design

- Exact-type-only skip (“Actor returns if `get_type() != Actor`”) as the main fix — leaves mint later; user’s choice is **base mints the correct leaf RPC**.
- Always overwrite without skip (hung wire).
- Per-leaf always-remint overrides as the product fix.
- Client walk holes for Helper types (skip Constraint / special-case before loop) — fix the **other-side `.new`** instead.

---

## Process

1. ✔️ Owner ack + unlock `emit_lease_construct`.  
2. ✔️ Emit walk-then-mint **inline in generated construct**.  
3. Re-prove: leaf `.new` on the wire → Wayland ~5s past L246–252.  
4. Mark T-030 **L4** ✔️ only after Wayland confirm.

---

## Non-goals

- Scattering always-remint St leaf overrides “to unblock boot”
- Counting mock progress as Wayland progress
- Patching libocrpc from this tree without an OLLMchat bug

---

## Refs

- Emitter: `src/gi-stub-gen/Generator.vala` — `emit_lease_construct` (**LOCKED**)  
- Handle contract: `OLLMchat/libocrpc/Live/Handle.vala`  
- Constraint relay: `src/gi-stub/overrides-clutter/Constraint.override.vala`, `Clutter.deny` `*Constraint.new`  
- Residual `ST_IS_WIDGET`: `docs/bugs/done/2026-09-07-st-ctor-parent-walks-to-actor.md`  
- Plan cursor: T-030 L4 in `0.7.7-thin-shell-bootstrap.md`  
