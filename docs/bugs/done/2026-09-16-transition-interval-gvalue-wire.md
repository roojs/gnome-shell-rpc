# Transition / Interval GValue wire — typed from/to relay

**Status:** ✔️ code archived — nest ease / grey → [`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md)  
**Hit:** 2026-09-15 — nest `ease` / `transition.set_to` after Animatable land  
**Related:** [`2026-09-15-adjustment-animatable-startup-grey.md`](2026-09-15-adjustment-animatable-startup-grey.md) §2 ·
[`2026-09-16-interval-value-type-mint.md`](2026-09-16-interval-value-type-mint.md) (D1.8 ✔️)

**Landed:** `Helper-Transition.set_relay_value` (`bsid`) +
`Transition.override` thin `set_*_value` → `relay_value(is_to, value)`.

**Roles:** **Helper** one `set_relay_value` + **client** `set_*_value`
overrides · **not** generator “pass GValue through” · **not** OLLMchat
unless a gate FAILs

---

## Symptom

GJS `environment.js` `_easeActorProperty`:

```js
interval: new Clutter.Interval({value_type: pspec.value_type}),
…
transition.set_to(target);
```

→ stock `clutter_transition_set_to_value(transition, GValue*)`.

Generator today treats `GObject.Value` as a boxed blob and emits
`OLLMrpc.args("ay", memcpy_of_GValue_struct)`. That cannot work across
processes. TEMPORARY deny keeps the C symbol; ease never reaches the
compositor.

---

## What GValue is for on the compositor

Stock API uses `GValue*` because Interval is keyed by a fixed
`value_type` and interpolates by that type. That is a **compositor-local**
concern. The RPC wire does **not** need to look like a GValue — only to
carry enough for the Helper to rebuild one.

**Type on the far side must still match the interval’s `value_type`.**

---

## Types that actually animate

Built-in in `clutter_interval_real_compute_value`:

| Fundamental | Notes |
| --- | --- |
| `INT` / `UINT` / `CHAR` / `UCHAR` | linear |
| `FLOAT` / `DOUBLE` | linear (nest ease uses these a lot) |
| `BOOLEAN` | step at 0.5 |

Registered progress (`clutter_interval_register_progress_funcs`):

| GType | Shape |
| --- | --- |
| `Graphene.Point` / `Point3D` / `Size` / `Rect` / `Matrix` | boxed structs |
| `Cogl.Color` | boxed |

Shell `ease` passes whatever `pspec.value_type` is — startup grey path is
`St.Adjustment:value` (**double**); actor geometry props are usually
**float**. Boxed colors/points show up in other animations later.

Fundamentals first for the ease corridor; boxed is a later tier on the
**same** relay pattern (tag + payload), not a reason to ship GValues.

---

## Chosen: typed from/to relay (B)

Skip shipping a GValue. Wire carries **`is_to`** + **kind** + widened
scalars; **one** Helper method `set_relay_value` rebuilds a
compositor-local `GValue` and calls stock `set_to_value` /
`set_from_value`.

### Fundamentals — two payload kinds, not five

Do **not** send a separate wire type per fundamental. Widen on the client;
narrow on the Helper using the indicator:

| Wire payload | Covers (indicator → `g_value_set_*`) |
| --- | --- |
| **integer** (`i` / `u` on transport) | `INT`, `UINT`, `CHAR`, `UCHAR`, `BOOLEAN` |
| **double** (`d`) | `DOUBLE`, `FLOAT` (cast to float on Helper) |

Indicator is a short UTF8 string (or single letter) naming the **destination**
fundamental — e.g. `"i"`, `"u"`, `"y"`/`"c"`, `"b"`, `"d"`, `"f"`. Transport
always sends the widened slot(s); Helper ignores the unused kind.

Example shapes (pick one when implementing):

```
# set_to only (GJS ease): indicator + one widened value
s i d     # type, int_slot, double_slot — fill the one that applies

# from + to (Interval mint / set both ends):
s i i d d
```

Float vs double: **send double always** for both; indicator `"f"` vs `"d"`
picks `g_value_set_float` vs `g_value_set_double`. Precision is enough for
actor geometry; avoids a third payload kind.

Bool: send `0`/`1` in the integer slot; indicator `"b"`.

### Boxed / registered types — Bin table, not raw `GType`

Same relay family later: indicator + payload; Helper builds a `GValue`.

**Do not send a process-local `GType` int** (client and compositor ids
differ). **Do not invent a parallel `g_type_name` string path.**

Use the **RPC registered type table** both sides already share:

- `OLLMrpc.Bin.register(alias, gtype)` / `Gi.register` fill
  `alias_to_gtype` and `gtype_to_alias`
- Wire already sends a **registry token** for objects
  (`Stream.write_gtype` → reg_id → alias → local `GType` via
  `alias_to_gtype`)

For Interval boxed progress types (`Graphene.Point`, `Cogl.Color`, …):
register them in Bin like everything else, then the indicator is that
**alias** (or the same reg_id mechanism args/objects already use). Each
side looks up **its** local `GType` from the table; payload is
`ay`/fields as today for boxed blobs.

Ease corridor does not need boxed first — but when it does, it reuses
Bin, not a one-off name string.


### Client / Helper split

**Client:** deny generated `set_to*` / `set_from*`. Stock
`set_to_value` / `set_from_value` are one-liners into a local
`relay_value(is_to, value)` that owns the kind switch + Helper call.

**Helper:** **one** method `set_relay_value` — kind switch → `g_value_set_*`;
`if (is_to)` stock `set_to_value` else `set_from_value`. No separate
Helper `set_to` / `set_from`. No private pack helpers.

**Pros:** two transport kinds, explicit indicator, easy mock, no GValue
blob, no cross-process `GType` ints.  
**Cons:** Helper surface (ok); boxed tier later; uint→int slot must use
unsigned transport letter if we care about full `guint` range.

---

## Proposed code (fundamentals only)

Wire: `bsid` — `is_to`, kind, int slot, double slot.
Fill the scalar slot that applies; other is `0`.

### Client — `Transition.override.vala`

`set_to_value` / `set_from_value` are thin; one local method owns the
kind switch + Helper call:

```vala
/* Deny keeps generator off these; GJS set_to → set_to_value. */
public void set_to_value(GLib.Value value)
{
	this.relay_value(true, value);
}

public void set_from_value(GLib.Value value)
{
	this.relay_value(false, value);
}

void relay_value(bool is_to, GLib.Value value)
{
	string kind = "";
	int i = 0;
	double d = 0.0;
	var t = value.type();
	switch (t) {
		case GLib.Type.INT:
			kind = "i";
			i = value.get_int();
			break;
		case GLib.Type.UINT:
			kind = "u";
			i = (int) value.get_uint();
			break;
		case GLib.Type.BOOLEAN:
			kind = "b";
			i = value.get_boolean() ? 1 : 0;
			break;
		case GLib.Type.CHAR:
			kind = "c";
			i = value.get_schar();
			break;
		case GLib.Type.UCHAR:
			kind = "y";
			i = value.get_uchar();
			break;
		case GLib.Type.FLOAT:
			kind = "f";
			d = value.get_float();
			break;
		case GLib.Type.DOUBLE:
			kind = "d";
			d = value.get_double();
			break;
		default:
			GLib.warning("Transition.relay_value: unsupported %s",
				t.name());
			return;
	}
	GnomeShellRpc.call_value(
		"Helper-Transition.set_relay_value", this,
		OLLMrpc.args("bsid", is_to, kind, i, d));
}
```

Move deny rows from TEMPORARY noop to PERMANENT hand-override (same as
`set_animatable`). Keep varargs `set_to` / `set_from` denied.

### Helper — `rpc/helper/Transition.vala` (sketch)

**One** registered method only:

```vala
public class Transition : GLib.Object
{
	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Helper-Transition", typeof(Transition),
			"set_relay_value", "bsid",
			null);
		OLLMrpc.Request.register_live(
			"Helper-Transition", new Transition());
	}

	public void set_relay_value(
		OLLMrpc.Request request,
		bool is_to,
		string kind,
		int i,
		double d
	) {
		var peer = (Clutter.Transition) request.connection.leases.get(
			(int) request.lease_id);
		if (peer == null) {
			request.connection.reply_error(request,
				(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		GLib.Value v = {};
		switch (kind) {
			case "i":
				v = GLib.Value(typeof(int));
				v.set_int(i);
				break;
			case "u":
				v = GLib.Value(typeof(uint));
				v.set_uint((uint) i);
				break;
			case "b":
				v = GLib.Value(typeof(bool));
				v.set_boolean(i != 0);
				break;
			case "c":
				v = GLib.Value(typeof(char));
				v.set_schar((int8) i);
				break;
			case "y":
				v = GLib.Value(typeof(uchar));
				v.set_uchar((uint8) i);
				break;
			case "f":
				v = GLib.Value(typeof(float));
				v.set_float((float) d);
				break;
			case "d":
				v = GLib.Value(typeof(double));
				v.set_double(d);
				break;
			default:
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
		}
		if (is_to) {
			peer.set_to_value(v);
		} else {
			peer.set_from_value(v);
		}
		request.reply(new OLLMrpc.Response() { id = request.id });
	}
}
```

Register from `Helper.rpc_register()`; mock
`Helper-Transition.set_relay_value` as void in `HelperMock` if needed.

Boxed later: grow a Bin-alias kind + `ay` branch in the kind switch —
still one Helper method, still no extracted pack helpers.

---

## Rejected: hold `GLib.Value` in `Request.args` (A)

OPC can pin a held `GObject.Value` (`gvalue-in-gate` PASS). That does
**not** make A a good consumer design.

Why A is out:

- Treats GValue as if it were a normal wire type; it is a tagged union /
  pin dance, not a value we want stubs to “just pass through.”
- Pushes GValue construction/packing into every generated GValue* site
  (`Transition`, `Interval`, `LayoutManager.child_set_property`, …)
  instead of one deliberate Helper.
- Generator special-case forever; easy to regress back to `ay` memcpy.
- Opaque on the wire compared to an explicit type letter + scalars.
- Nest only needs a small type set for ease; full GType surface is the
  wrong ambition for this corridor.

`gvalue-in-gate` stays as an OPC regression smoke only — **not** a green
light to generate held-Value stubs for Transition.

---

## Also rejected

- `Helper-Transition.set_to` / `set_from` as separate methods (use one
  `set_relay_value` with `is_to`)
- `Helper-Transition.set_to_double` / `_float` / `_int` forks  
  (kind letter on the one method instead)
- Client poking `Interval:final` via `set_property` with ad-hoc `sd`/`sf`
- Reimplementing ease on the client without compositor Interval
- Inventing non-GIR methods on `Adjustment` itself

---

## Prove

```bash
# after Helper B + Transition override:
GI_META_SMOKE=adjustment-animatable-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
```

| Gate | Meaning |
| --- | --- |
| nest ease / Adjustment value | end-to-end after B |
| optional small Helper unit | tag `d`/`f`/`i` round-trip |

---

## Next

Wire + override + Helper **landed**. Nest ease / grey paint →
[`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md).
Boxed via Bin later if needed.
