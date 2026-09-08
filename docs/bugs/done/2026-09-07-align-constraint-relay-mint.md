# Panel crashes: AlignConstraint is not a real AlignConstraint

**Status:** ✔️ FIXED — real Align/Bind/Snap mint; residual L7 closed with Gi UTF8 pin  
**Hit:** 2026-09-07  
**Plan:** T-030 **L6** (mint) / **L7** (lookup)

---

## Symptom

Nested Wayland boot dies while building the panel toggle switch:

```
TypeError: obj is null
  _easeActorProperty@…/environment.js:221
  set state@…/popupMenu.js:435
  … → Panel → _initializeUI
```

Just before that, mutter prints:

```
clutter_align_constraint_set_align_axis: assertion 'CLUTTER_IS_ALIGN_CONSTRAINT (align)' failed
clutter_align_constraint_set_source: assertion 'CLUTTER_IS_ALIGN_CONSTRAINT (align)' failed
```

---

## 1. What JavaScript does

In `popupMenu.js`, the Switch builds an AlignConstraint named `"align"`,
adds it to the handle, then sets `state` (which eases that constraint’s
`factor`):

```js
// popupMenu.js — Switch._init
this._handleAlignConstraint = new Clutter.AlignConstraint({
    name: 'align',
    align_axis: Clutter.AlignAxis.X_AXIS,
    source: this,
});
this._handle.add_constraint(this._handleAlignConstraint);

this.state = state;   // calls the setter below
```

```js
// popupMenu.js — Switch set state
const duration = this._handle.mapped
    ? this._handle.get_theme_node().get_transition_duration()
    : 0;   // still unmapped → 0

this._handle.ease_property('@constraints.align.factor', handleAlignFactor, {
    duration,
});
```

With `duration === 0`, `environment.js` does not animate. It looks up the
named constraint and assigns the property:

```js
// environment.js — _easeActorProperty (duration === 0)
let [obj, prop] = _getPropertyTarget(actor, propName);
obj[prop] = target;   // TypeError if obj is null
```

```js
// environment.js — _getPropertyTarget
case '@constraints':
    return [actor.get_constraint(name), prop];
// '@constraints.align.factor' → get_constraint('align'), then .factor
```

So JS expects: create a real AlignConstraint → name it `"align"` → later
`get_constraint('align')` returns that object → set `factor`.

---

## 2. What the client does

`AlignConstraint` extends `Constraint`. The Constraint override always
creates the server object via Helper (leaf `.new` is denied):

```vala
// overrides-clutter/Constraint.override.vala — construct
var response = GnomeShellRpc.call_value(
    "Helper-Constraint.create",
    null,
    OLLMrpc.args("t", callback_id));
this.rpc_lid = response.args.get(0).get_uint64();
this.sync_actor_meta_name();      // Clutter-ActorMeta.set_name "align"
this.sync_actor_meta_enabled();
```

Construct props then RPC the AlignConstraint setters on that lease:

```vala
// Clutter_generated.vala — AlignConstraint
set {
    GnomeShellRpc.call_value(
        "Clutter-AlignConstraint.set_align_axis", this, …);
}
set {
    GnomeShellRpc.call_value(
        "Clutter-AlignConstraint.set_source", this, …);
}
```

And later, for the ease path:

```vala
// Clutter_generated.vala — Actor
public Constraint? get_constraint(string name)
{
    var response = GnomeShellRpc.call_value(
        "Clutter-Actor.get_constraint", this, OLLMrpc.args("s", name));
    …
    return (Constraint) response.retval.get_object();  // null → JS TypeError
}
```

Wire sequence from the log matches that:

```
Helper-Constraint.create
Clutter-ActorMeta.set_name          // "align"
Clutter-AlignConstraint.set_align_axis   ← CRITICAL (not an AlignConstraint)
Clutter-AlignConstraint.set_source       ← CRITICAL
Clutter-Actor.add_constraint
…
Clutter-Actor.get_constraint             // then obj[prop] = target blows up
```

---

## 3. What the server does

`Helper-Constraint.create` always builds a `ConstraintRelay` — a custom
subclass of generic `Clutter.Constraint`, not stock Align/Bind/Snap:

```vala
// rpc/helper/Constraint.vala
public class ConstraintRelay : Clutter.Constraint
{
    // update_allocation → calls back to the client (for JS subclasses)
}

public void create(OLLMrpc.Request request, uint64 callback_id)
{
    var relay = new ConstraintRelay();   // ← always this
    relay.update_hook = …;
    var handle = (uint64) request.connection.export(relay);
    request.reply(… handle …);
}
```

When Ffi then runs `clutter_align_constraint_set_align_axis` on that handle,
mutter checks `CLUTTER_IS_ALIGN_CONSTRAINT` and fails. The setters no-op.
The switch never has a working AlignConstraint named `"align"`.
`get_constraint('align')` comes back null (or unusable), and JS hits
`obj is null`.

`ConstraintRelay` is the right server object for **JS subclasses** of
Constraint that need `update_allocation` on the client. It is the wrong
object for stock `new Clutter.AlignConstraint({…})`.

---

## Fix

Class hierarchy — not a type switch in {@code create}:

- **Constraint base** (`Helper.Constraint` : `Clutter.Constraint`):
  `update_allocation` → client. Client {@code mint_server_lease()} calls
  {@code Helper-Constraint.create}.
- **Align / Bind / Snap**: override {@code mint_server_lease()} to call
  {@code Clutter-AlignConstraint.new} (etc.). Server Ffi mints the real
  mutter GType via {@code g_object_new} (same pattern as {@code Helper.St}).

Destroy {@code ConstraintRelay}. Do not route stock Align/Bind/Snap through
{@code Helper-Constraint.create}.


---

## Prove

Wayland nested (~5s):

- No `CLUTTER_IS_ALIGN_CONSTRAINT` / `CLUTTER_IS_SNAP_CONSTRAINT` asserts
  for these constructors.
- No `TypeError: obj is null` from Switch `set state`.
- Boot gets past Panel construct.

---

## Files

- JS: `bisect-js/ui/popupMenu.js`, `bisect-js/ui/environment.js`
- Client: `src/gi-stub/overrides-clutter/Constraint.override.vala`
- Server: `src/rpc/helper/Constraint.vala`
