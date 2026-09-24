# Clutter.Interval mint — value_type without shipping a GType

**Status:** ✔️ code + smoke archived — nest ease / grey → [`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md)  
**Hit:** 2026-09-16 — nest ease after Transition `set_relay_value` lands  
**Related:**
[`2026-09-16-transition-interval-gvalue-wire.md`](2026-09-16-transition-interval-gvalue-wire.md)
(D1.7 ✔️) ·
[`2026-09-15-adjustment-animatable-startup-grey.md`](2026-09-15-adjustment-animatable-startup-grey.md)  
**Plan:** [`1.0-run-to-end.md`](../../plans/1.0-run-to-end.md) **D1.8**

**Roles:** **Helper** Interval create-by-name + **client** Interval
construct / `value_type` override · **not** generator GType wire ·
**not** OLLMchat

---

## Symptom / gap

Shell ease still does:

```js
interval: new Clutter.Interval({ value_type: pspec.value_type }),
…
transition.set_to(target);
```

**D1.7** fixed `set_to` / `set_from`. That does **not** mint the Interval.

---

## Design

**Wire:** one type-indicator argument (`"s"`). Pack with
{@link OLLMrpc.args}.

Indicator for Interval mint = **`GLib.Type.name()`** (fundamentals are
stable across processes: `"gdouble"`, `"gint"`, …). Helper resolves with
**`GLib.Type.from_name`** — stock GLib, not a letter switch and not a new
helper in this tree.

**Do not** ship a process-local `GType` int.
**Do not** pack typed zeros / hand-built `ArrayList` of `GLib.Value`.
**Do not** add `kind_letter` / `value_from_kind` / any type `switch` in
Interval mint (client or Helper).
**Do not** copy or extract Transition’s D1.7 relay switch for mint —
that switch exists only to pack scalar payloads for `set_relay_value`.

D1.7 Transition still uses kind letters + int/double slots for from/to
values. Interval mint only needs a type, so it does not share that path.

Boxed / registered later: Bin alias → `alias_to_gtype`.

---

## Proposed sketch

### Helper — `rpc/helper/Interval.vala`

```vala
public void create(OLLMrpc.Request request, string name)
{
	var gtype = GLib.Type.from_name(name);
	if (gtype == GLib.Type.INVALID) {
		request.connection.reply_error(request,
			(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
		return;
	}
	var peer = (Clutter.Interval) GLib.Object.new(
		typeof(Clutter.Interval), "value-type", gtype);
	request.reply(new OLLMrpc.Response() {
		id = request.id,
		args = OLLMrpc.args("t",
			(uint64) request.connection.export(peer)),
	});
}
```

### Client — `overrides-clutter/Interval.override.vala`

```vala
construct {
	if (this.rpc_lid != 0) {
		return;
	}
	var response = GnomeShellRpc.call_value(
		"Helper-Interval.create", null,
		OLLMrpc.args("s", this.priv_value_type.name()));
	this.rpc_lid = response.args.get(0).get_uint64();
	GnomeShellRpc.GiStub.Runtime.register_handle(this);
}
```

Deny: `Interval.with_values`, `get_value_type`, `set_initial`,
`set_final` (for now).

---

## Rejected

- `Transition.kind_letter` / any extracted GType→letter switch for mint
- Helper letter→`GType` switch / `OLLMrpc.val(kind, 0)` papering over mint
- Typed-zero packs so Helper can read `.type()`
- Hand-built `ArrayList` + `GLib.Value(...)`
- Shipping numeric `GType` in `Request.args`
- Client-only Interval (no compositor peer)

---

## Prove

```bash
GI_META_SMOKE=adjustment-animatable-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
```

---

## Next

Code + smoke **landed**. Nest ease / grey →
[`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md).
