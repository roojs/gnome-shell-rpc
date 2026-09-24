# Allocate — follow the reference process

**User goal:** nested **`mutter-rpc` + `gnome-shell-rpc`** stays up and chrome
responds to pointer / keyboard (0.8 Phase B) — dots centred, wallpaper
visible, `ensureAllocation` resolves. Same allocate **calls** as stock
gnome-shell (GJS + mutter C), split across client/server.

Checklist: `docs/guide-to-writing-plans.md`.

**Status:** ✔️ archived 2026-09-16 — Flow 2/3 landed (`startup-allocate-smoke` **A/E/F**, `hook-o-gate` PASS). Residual panel / menus / grey → [`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md)  
**OPC:** [`OLLMchat/docs/bugs/2026-09-16-any-args-token-reg-type.md`](file:///home/alan/gitlive/OLLMchat/docs/bugs/2026-09-16-any-args-token-reg-type.md) — applied  
**Gate:** `tests/call-sync-repro/hook-o-gate` — **PASS** 2026-09-16 `get_object` identity  
**Hit:** 2026-09-16  
**Plan:** [`0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)  
**Reference:** [`clutter-layout-allocate.md`](../../clutter-layout-allocate.md)  
**Chrome:** [`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md)

**🚫** Idle / `GLib.idle_add`.  
**🚫** Vendor `panel.js` / `overviewControls.js`.  
**🚫** `rpc_lid` on the GJS LayoutManager object.  
**🚫** Client `layout_changed_invoke` → `queue_relayout`.  
**🚫** Actor allocate Hook standing in for `LayoutManagerClass.allocate`.  
**🚫** Invented GI methods on Meta / Clutter / St.  
**🚫** `proxies.get` / extra `"t"` packing to hide Live.Hook `"o"`.

| # | Work | Status |
| - | ---- | ------ |
| A | Flow 2 — public `clutter_actor_allocate` on the peer | ✔️ |
| B | Flow 1/3 — Helper LayoutManager peer + C `layout_changed` | ✔️ A/E/F PASS |

---

## Lined up — Flow 2 (dots)

Stock `WorkspaceDot` (`panel.js`): `set_allocation(self)` then
`_dot.allocate(full box)` with `_dot.y_align = CENTER`.

| Reference | Today | After A |
| --------- | ----- | ------- |
| GJS `child.allocate(box)` | same JS | same JS |
| `clutter_actor_allocate` (~8806) | RPC `Clutter-Actor.allocate` | A2 — `Helper-Actor.allocate_public` → C `clutter_actor_allocate` |
| `update_constraints` + `adjust_allocation` from **peer** `x-align` / `y-align` | ✔️ smoke **C** `inner@10,102` `midDy=0` | that C, on the peer |

**Gate:** `GI_META_SMOKE=workspace-dot-align-smoke` — **C** PASS; **A/B** stay PASS.

### A1 — ✔️ prove which cell

Nested prove 2026-09-16 16:21: `C inner y_align=2 (CENTER=2)` after RPC
`set_y_align` / `get_y_align`. Geom still origin (`inner@10,90 12x8` on
`bar@10,90 80x32`, `midDy=-12`). **A2**.

### A2 — ✔️ `Helper-Actor.allocate_public`

**Add** to `Helper.Actor.rpc_register` argument list, after `"allocate"`
hooks already exist via `add_hook`:

```
"allocate_public", "ay",
```

**Add** on `Helper.Actor` (`src/rpc/helper/ClutterActor.vala`):

```vala
[CCode (cname = "clutter_actor_allocate")]
static extern void clutter_actor_allocate_public(
	Clutter.Actor actor,
	Clutter.ActorBox box
);

public void allocate_public(OLLMrpc.Request request, GLib.Bytes box_bytes)
{
	var peer = request.connection.leases.get((int) request.lease_id) as Actor;
	if (peer == null || box_bytes.length < sizeof(Clutter.ActorBox)) {
		request.connection.reply_error(request,
			(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
		return;
	}
	Clutter.ActorBox box = *((Clutter.ActorBox*) box_bytes.get_data());
	clutter_actor_allocate_public(peer, box);
	request.reply(new OLLMrpc.Response());
}
```

**Replace** in `Actor.override.vala` `allocate` (the RPC name only):

```vala
		GnomeShellRpc.call_value(
			"Clutter-Actor.allocate", this,
			OLLMrpc.args("ay", new GLib.Bytes(data)));
```

**Replace with:**

```vala
		if (this.helper_attached) {
			GnomeShellRpc.call_value(
				"Helper-Actor.allocate_public", this,
				OLLMrpc.args("ay", new GLib.Bytes(data)));
			return;
		}
		GnomeShellRpc.call_value(
			"Clutter-Actor.allocate", this,
			OLLMrpc.args("ay", new GLib.Bytes(data)));
```

**ℹ️** `helper_attached` is the `St-Widget` / `Helper-Actor.create` path.
`St.BoxLayout` / `St.Bin` keep generated `Clutter-Actor.allocate` (smoke **A/B**).

Nested prove 2026-09-16 16:25: **A PASS** · **B PASS** · **C PASS**
`inner@10,102` `midDy=0`. RPC `Helper-Actor.allocate_public`.
Dotish is `St.Widget` (WorkspaceDot); a `Clutter.Actor` subclass never
got the allocate hook so `vfunc_allocate` never ran.

**ℹ️** `helper_attached` must run **before** the GJS-LM
`allocate_vfunc` shortcut. That shortcut left C off the stack, so
`layout_changed` RPC started a second allocate (`startup-allocate-smoke`
**F** `hits=2`). After: public C allocate, then Helper LM hook; **F**
`hits=1`.

---

## Lined up — Flow 1 / 3 (layout manager)

| Reference | Today | After B |
| --------- | ----- | ------- |
| GJS `actor.layout_manager = lm` | `set_container` locally; no `set_layout_manager` | B3 — mint Helper LM; `set_layout_manager(peer)` |
| `clutter_actor_set_layout_manager` + `::layout-changed` connect | compositor default LM | same C on the peer |
| GJS `lm.layout_changed()` | emit on client GJS object only | B4 — emit locally + RPC C emit on the peer |
| `on_layout_manager_changed` → `queue_relayout` | **MISS** | C on the server |
| `real_allocate` → `clutter_layout_manager_allocate` → GJS `vfunc_allocate` | compositor LM; no GJS vfunc | Helper LM hook → GJS vfunc |
| GJS `lm.allocate(container, box)` | `rpc_lid==0` no-op | B4 — `allocate_vfunc` |

**Gate:** `GI_META_SMOKE=startup-allocate-smoke` — **A** PASS · **E** PASS ·
**F** PASS (`hits=1`). Nest stay-up after READY is no longer this bug
(chrome **Boot death** closed for stay-up). Residual geom / menus / grey
stay on the chrome bug.

### B1 — ⏳ 🔷 **Add** `src/rpc/helper/ClutterLayoutManager.vala`

```vala
namespace GnomeShellRpc.Rpc.Helper
{
	public class LayoutManager : Clutter.LayoutManager
	{
		public Gee.HashMap<string, OLLMrpc.Live.Hook> vfuncs
			= new Gee.HashMap<string, OLLMrpc.Live.Hook>();

		public static void rpc_register()
		{
			var helper = new LayoutManager();
			OLLMrpc.Request.add_class(
				"Helper-LayoutManager", typeof(LayoutManager),
				"create", "",
				"add_hook", "st",
				null);
			OLLMrpc.Request.register_live("Helper-LayoutManager", helper);
		}

		public void add_hook(
			OLLMrpc.Request request,
			string vfunc_name,
			uint64 callback_id
		) {
			var peer = request.connection.leases.get((int) request.lease_id)
				as LayoutManager;
			if (peer == null
					|| !request.connection.callbacks.has_key((int) callback_id)) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			peer.vfuncs.set(vfunc_name,
				request.connection.callbacks.get((int) callback_id));
			request.reply(new OLLMrpc.Response());
		}

		public void create(OLLMrpc.Request request)
		{
			var created = new LayoutManager();
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(created)),
			});
		}

		public override void get_preferred_width(
			Clutter.Actor container,
			float for_height,
			out float min_width_p,
			out float nat_width_p
		) {
			min_width_p = 0.0f;
			nat_width_p = 0.0f;
			var hook = this.vfuncs.get("get_preferred_width");
			if (hook == null) {
				return;
			}
			hook.emit(OLLMrpc.args("od", container, (double) for_height));
			var args = hook.reply_args;
			if (args.size < 2) {
				return;
			}
			min_width_p = (float) args.get(0).get_double();
			nat_width_p = (float) args.get(1).get_double();
		}

		public override void get_preferred_height(
			Clutter.Actor container,
			float for_width,
			out float min_height_p,
			out float nat_height_p
		) {
			min_height_p = 0.0f;
			nat_height_p = 0.0f;
			var hook = this.vfuncs.get("get_preferred_height");
			if (hook == null) {
				return;
			}
			hook.emit(OLLMrpc.args("od", container, (double) for_width));
			var args = hook.reply_args;
			if (args.size < 2) {
				return;
			}
			min_height_p = (float) args.get(0).get_double();
			nat_height_p = (float) args.get(1).get_double();
		}

		public override void allocate(
			Clutter.Actor container,
			Clutter.ActorBox allocation
		) {
			var hook = this.vfuncs.get("allocate");
			if (hook == null) {
				return;
			}
			hook.emit(OLLMrpc.args("odddd",	container,
				(double) allocation.x1, (double) allocation.y1,
				(double) allocation.x2, (double) allocation.y2));
		}
	}
}
```

**Add** in `src/meson.build` `compositor_sources`, after
`'rpc/helper/ClutterActor.vala',`:

```
  'rpc/helper/ClutterLayoutManager.vala',
```

**Add** in `src/rpc/helper/namespace.vala` `rpc_register()`, after
`Actor.rpc_register();`:

```
		LayoutManager.rpc_register();
```

### B2 — ⏳ 🔷 **Add** on `LayoutManager.override.vala`

Mint + hooks live here so the Actor setter stays a `set_container` +
`set_layout_manager` pair. **🚫** `rpc_lid` on the GJS object — the
lease is `helper_peer`.

Stock `LayoutManagerClass.get_preferred_width(self, container, for_height)`:
the hook is already bound on `self` (the GJS LM). Remaining C args start
with the container GObject. Helper emit is `"od"` / `"odddd"`; the relay
is `call.args.get(0).get_object()` then the floats.

**🚫** `export(container)` as `"t"` + `proxies.get` (Constraint). Actor
hooks send `"t"` because the callback is already bound on that actor.
LM `this` is the LM. If Live.Hook `"o"` dies (`unsupported bin array
type 0x7F`), that is OPC — `tests/call-sync-repro/hook-o-gate` — not a
consumer lease lookup.

**Add** after `child_meta_quark`:

```vala
	internal LayoutManager? helper_peer;
```

**Add:**

```vala
	internal uint64 relay_get_preferred_width()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			float min = 0.0f, nat = 0.0f;
			var container = (Actor) call.args.get(0).get_object();
			this.get_preferred_width_vfunc(container,
				(float) call.args.get(1).get_double(),
				out min, out nat);
			return OLLMrpc.args("dd", (double) min, (double) nat);
		});
	}

	internal uint64 relay_get_preferred_height()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			float min = 0.0f, nat = 0.0f;
			var container = (Actor) call.args.get(0).get_object();
			this.get_preferred_height_vfunc(container,
				(float) call.args.get(1).get_double(),
				out min, out nat);
			return OLLMrpc.args("dd", (double) min, (double) nat);
		});
	}

	internal uint64 relay_allocate()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			var container = (Actor) call.args.get(0).get_object();
			var box = ActorBox();
			box.x1 = (float) call.args.get(1).get_double();
			box.y1 = (float) call.args.get(2).get_double();
			box.x2 = (float) call.args.get(3).get_double();
			box.y2 = (float) call.args.get(4).get_double();
			this.allocate_vfunc(container, box);
			return OLLMrpc.args("");
		});
	}

	internal LayoutManager ensure_helper_peer()
	{
		if (this.helper_peer != null) {
			return this.helper_peer;
		}
		var minted = GnomeShellRpc.call_value(
			"Helper-LayoutManager.create", null);
		var peer = (LayoutManager) GLib.Object.new(typeof(LayoutManager));
		peer.rpc_lid = minted.args.get(0).get_uint64();
		GnomeShellRpc.GiStub.Runtime.register_handle(peer);
		this.helper_peer = peer;
		GnomeShellRpc.call_value(
			"Helper-LayoutManager.add_hook", peer,
			OLLMrpc.args("st", "get_preferred_width",
				this.relay_get_preferred_width()));
		GnomeShellRpc.call_value(
			"Helper-LayoutManager.add_hook", peer,
			OLLMrpc.args("st", "get_preferred_height",
				this.relay_get_preferred_height()));
		GnomeShellRpc.call_value(
			"Helper-LayoutManager.add_hook", peer,
			OLLMrpc.args("st", "allocate",
				this.relay_allocate()));
		return peer;
	}
```

### B3 — ⏳ 🔷 **Replace** `Actor.override.vala` GJS `layout_manager` setter

**Replace:**

```vala
			} else {
				if (previous != null && previous != value && previous.rpc_lid == 0) {
					previous.set_container(null);
				}
				value.set_container(this);
			}
```

**Replace with:**

```vala
			} else {
				if (previous != null && previous != value && previous.rpc_lid == 0) {
					previous.set_container(null);
				}
				value.set_container(this);
				GnomeShellRpc.call_value(
					"Clutter-Actor.set_layout_manager",
					this,
					OLLMrpc.args("o", value.ensure_helper_peer()));
			}
```

### B4 — ⏳ 🔷 **Replace** `LayoutManager.override.vala` allocate + `layout_changed`

**Replace:**

```vala
	public virtual void allocate(Actor container, ActorBox allocation)
	{
		if (this.rpc_lid == 0) {
			return;
		}
```

**Replace with:**

```vala
	public virtual void allocate(Actor container, ActorBox allocation)
	{
		if (this.rpc_lid == 0) {
			this.allocate_vfunc(container, allocation);
			return;
		}
```

**Replace:**

```vala
	[CCode (cname = "clutter_layout_manager_layout_changed")]
	public void layout_changed_invoke()
	{
		this.layout_changed();
	}
```

**Replace with:**

```vala
	[CCode (cname = "clutter_layout_manager_layout_changed")]
	public void layout_changed_invoke()
	{
		this.layout_changed();
		if (this.helper_peer == null) {
			return;
		}
		GnomeShellRpc.call_value(
			"Clutter-LayoutManager.layout_changed",
			this.helper_peer);
	}
```

**ℹ️** `Clutter-LayoutManager.layout_changed` is the C emit-only
function (already denied as a generated method; this is that cname).
Do **not** add `queue_relayout` here — mutter
`on_layout_manager_changed` does that on the server.

---

## Order

1. **A** — `workspace-dot-align-smoke` **C**
2. Wallpaper — same public `allocate` on `_backgroundGroup` children
3. **B** — `startup-allocate-smoke` **A**+**E**+**F**
