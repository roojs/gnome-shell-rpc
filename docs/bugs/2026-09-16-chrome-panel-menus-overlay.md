# Panel / menus / grey overlay — current chrome bar

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
> File/update **this** bug, pick the next allowed prove step, rebuild, prove,
> repeat. **Prove-first** in the **test area** (`src/gjs-embed/`, observe
> probe) — **no** speculative stub / Helper / deny / JS thrash on the main
> tree. **No** `GLib.idle_add` / Idle / defer. No layout.js ship hacks.
>
> **User call 2026-09-16:** banner on **this bug only** (plus the active
> plan) — do not re-splat onto other bugs/docs. Prove without modifying
> the main codebase until the smoke names the fix.

**Status:** ⏳ open — user 2026-09-16 redirect  
**Hit:** 2026-09-16 — nest after Interval/Transition corridor land  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Roles:** **consumer** panel / PopupMenu / overview cover · **not** Interval mint
(already ✔️) · **not** layout.js ship hacks

**Supersedes open chase on:**
[`done/2026-09-15-chrome-placement.md`](done/2026-09-15-chrome-placement.md) (menu size
residual) · residual grey from
[`done/2026-09-15-adjustment-animatable-startup-grey.md`](done/2026-09-15-adjustment-animatable-startup-grey.md)
· blank-vs-grey bisect in
[`2026-09-15-boot-blank-background.md`](2026-09-15-boot-blank-background.md)

---

## 🔷 CRITICAL — prove first, no chrome hacking

**Do not** thrash Vala stubs / Helpers / stock JS trying to make the nest
“look better.” Every claim needs a **FAIL→PASS** gate (named
`GI_META_SMOKE=…` under `src/gjs-embed/`, or a mock gate) that pins the
mechanism — same class as `actor-allocate-box-smoke` /
`constraint-allocate-smoke` / `panel-click-smoke`.

**Prove without modifying the main codebase.** Experiments belong in
`src/gjs-embed/` smokes and observe-only `src/shell-js-probe/`. Do **not**
edit `src/gi-stub/`, `src/rpc/helper/`, deny lists, or vendor JS to “try”
a theory. A product fix lands only after the smoke names the contract and
the fix is the stock-shaped answer to that FAIL — not speculation.

Allowed while chasing:

- Read existing nest logs
  (`~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc}.debug.log`)
- Named smokes / observe probes that assert or log (test area only)
- Sparse `GI_RPC_JS_OVERRIDE_DIR=src/shell-js-probe` **only** to observe,
  never as the product fix

**🚫** Speculative Helper / override / deny edits.  
**🚫** `GLib.idle_add` / Idle / emit-defer / “queue then hope” — **never**
on this chase (user 2026-09-16).  
**🚫** Vendor `js/` / `layout.js` / production `GI_RPC_JS_OVERRIDE_DIR`.  
**🚫** Shipping a fix without a smoke that would have FAILed before it.

Fix lands **after** the smoke names the broken contract.

---

## Symptom (user)

| # | Surface | Observed | Stock expectation |
| - | ------- | -------- | ----------------- |
| 1 | Top-left desktop / workspace selectors | Not vertically centred on the top bar | Centred on panel height |
| 2 | System menu (right) + clock / dateMenu | Click does **nothing** — no pull-down | Opens PopupMenu below source |
| 3 | Desktop background | Big dark / grey-brown overlay on top of wallpaper | Wallpaper visible; no stuck overview cover |

**Regression note:** right pull-down **used to open** (layout wrong — stage-sized
BoxPointer). Now it does not open at all. Clock same.

---

## Do not conflate

| Track | Status | Notes |
| ----- | ------ | ----- |
| `St.Adjustment` Animatable | ✔️ | corridor smoke |
| Transition `set_relay_value` (D1.7) | ✔️ code | [`done/2026-09-16-transition-interval-gvalue-wire.md`](done/2026-09-16-transition-interval-gvalue-wire.md) |
| Interval mint (D1.8) | ✔️ code + smoke | [`done/2026-09-16-interval-value-type-mint.md`](done/2026-09-16-interval-value-type-mint.md) |
| Nest `_startingUp` clears | ❌ FAIL | see Evidence — blocked on ensureAllocation |
| dateMenu size / preferred | ⏳ | still stage-sized when forced open; after §3 |

Ease Interval/Transition wire is **not** the stuck-startup pin (relay runs once;
startup still never completes).

---

## Evidence (2026-09-16) — prove only

### LayoutManager sketch applied (2026-09-16 later)

| Gate | Result |
| ---- | ------ |
| `startup-allocate-smoke` **A** / **E** | **PASS** |
| Nest cast `StViewport` → Helper.Actor | **gone** (soft `as` + `priv_helper_actor_peer` guard) |
| Nest `gsr-chrome: waiting startingUp` | still ×N — moved past allocate into `_startupAnimationSession` |
| New pin | **`clutter_actor_box_copy` undefined** — Vala exports `_dup`; stock GIR/GJS looks up `_copy`. Hits `layout.js` `findMonitorForActor` / `getWorkAreaForMonitor` during `_startupAnimationSession`. |
| ActorBox.copy alias landed | **symbol present**; nest no longer throws that ERROR. **`_startingUp` still stuck** (probe still `waiting startingUp`; no `post-startup`). |

### Nest observe (`GI_RPC_JS_OVERRIDE_DIR=src/shell-js-probe`)

- `layoutManager._startingUp` stays **true** for the whole prove window
  (`gsr-chrome: waiting startingUp` ×N until kill).
- Stock `layout.js` keeps a **reactive** `_coverPane` + `_systemBackground`
  until `_startupAnimationComplete` — that is the grey + click-eater.
- While still startingUp (earlier probe): `overview` idle; **`dateMenu.menu.open(0)`
  and `quickSettings.menu.open(0)` both set `isOpen=true`** — click path is the
  break, not PopupMenu.open itself.
- dateMenu BoxPointer still ~stage-sized (`754×600`, preferred
  `220,436,754,600`).

Stock hang site (`overviewControls.runStartupAnimation`):

```js
await this.layout_manager.ensureAllocation(); // before dash.ease onStopped
```

`ControlsLayout.ensureAllocation` → `layout_changed()` + Promise flushed from
`vfunc_allocate` → `_runPostAllocation`.

### FAIL gate — `startup-allocate-smoke`

```bash
GI_META_SMOKE=startup-allocate-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
```

| Step | Result |
| ---- | ------ |
| **A** stock `ensureAllocation` | **FAIL** · `layout-changed` signal **does** fire · `allocateHits=0` · pending cb |
| **B** connect `layout-changed` → `actor.queue_relayout` (stock in-process shape) | **FAIL** `signal-queue_relayout-no-allocate` · signal handler ran · still `allocateHits=0` |
| **C** `queue_relayout` alone + pending cb | **FAIL** `queue_relayout-alone-no-allocate` |
| **E** GJS `St.Widget` + `vfunc_allocate` + GJS LM; `queue_relayout` | actor `vfunc_allocate` ran **once** at map (`hit=1` before `queue_relayout`); after relayout still `hit=1` · **`lmVfuncHits=0`** · **FAIL** `actor-vfunc-no-lm-allocate` — GJS `lm.allocate()` does not reach `vfunc_allocate` |

**Contract named:**

1. **`Actor.queue_relayout` RPC reaches mutter** (**B**/**C** logs) but does **not**
   drive another client allocate / GJS LM vfunc (**E** hits unchanged).
2. When client **does** run GJS `Actor.vfunc_allocate` and calls
   `layout_manager.allocate(container, box)`, **LM.allocate is a no-op for
   `rpc_lid==0`** (**E** `lmVfuncHits=0`) — client `Actor.allocate` uses
   `allocate_vfunc` (**D** works); GJS calling `.allocate()` does not.
3. Stock `ensureAllocation` (**A**) needs (1) and the LM dispatch in (2).

**Wire:** `Clutter-Actor.queue_relayout` ids on mutter for **B**/**C**; no
client allocate follow-up.

**🚫** Do not “fix” by destroying coverPane / forcing `_startingUp=false` /
skipping `ensureAllocation` in vendor JS.  
**🚫** Idle / `GLib.idle_add` “to make allocate happen.”

---

## Working order (prove each step)

1. **§3 startup / ensureAllocation** — turn `startup-allocate-smoke` PASS
   (layout_changed → allocate → callback) **before** chasing click cosmetics.
2. **§2 menus** — after startup completes, `pointer_click` → `isOpen` (probe
   already sketched); dateMenu preferred size.
3. **§1 panel vertical centre** — after §2–§3 honest.

---

## Prove

```bash
GI_META_SMOKE=startup-allocate-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# expect today: FAIL ensureAllocation-never-resolved

# observe (debug overlay only):
GI_RPC_JS_OVERRIDE_DIR=$PWD/src/shell-js-probe \
  GSR_NESTED_NO_A4=1 GSR_NESTED_SETTLE=12 GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# gsr-chrome: waiting startingUp …
```

Related: `layout-allocate-smoke` (direct allocate ✔️), `panel-click-smoke`,
`adjustment-animatable-smoke`.

Logs: `~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc}.debug.log`.

---

## Have we tried this before?

**Short answer:** we have not shipped this full fix and failed. One piece was
tried the wrong way today and rolled back; two other pieces are new.

| What the sketch changes | Tried before? | What happened |
| ----------------------- | ------------- | ------------- |
| Remember which actor owns a GJS layout manager, and call `queue_relayout` when JS says `layout_changed` | Half-tried earlier today, then **reverted** (also mixed with banned Idle) | Never got a PASS. The smoke already shows: even if you wire `layout_changed` → `queue_relayout` by hand, allocate still does not run. So this alone is **not** the fix. |
| Make `LayoutManager.allocate` actually call the JS `vfunc_allocate` (instead of doing nothing) | **No** failed attempt. Today it deliberately does nothing so `super.allocate()` from JS does not RPC. | That “do nothing” choice is why smoke **E** fails when JS calls `lm.allocate()`. Changing it is a **revision** of an old safety rule, not repeating a dead end. |
| When a GJS layout manager is set, install an allocate Hook so the compositor’s next allocate runs the client layout | **Not tried.** An older plan (R6) talked about layout-manager hooks and never landed. Today’s thrash used Idle instead of a Hook — that Idle path is banned. | This is the new part that matches the smoke. |

**Already known bad ideas (do not bring back):**

- Idle / “queue later” hacks to fake layout ([`done/2026-09-09-layout-relay-…`](done/2026-09-09-layout-relay-call-sync-reentrancy.md), and today’s reverted Idle on `queue_relayout`)
- Forcing startup finished / ripping out the grey cover in shell JS

**Bottom line:** approving the sketch is not “doing the same failed thing again.” The failed thing was Idle + only half of the wiring. The Hook + real `allocate` dispatch are what we have not tried.

---

## Proposed sketch (**💩** — review before any main-tree edit)

**🔷** Gate: `startup-allocate-smoke` **A** PASS. **🚫** `GLib.idle_add` / Idle.

### 1 — `src/gi-stub/overrides-clutter/LayoutManager.override.vala`

**Add** after `private static Quark child_meta_quark;`:

```vala
private weak Actor? priv_container;
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
	if (this.rpc_lid == 0 && this.priv_container != null) {
		this.priv_container.queue_relayout();
	}
}
```

**Replace:**

```vala
public virtual void allocate(Actor container, ActorBox allocation)
{
	if (this.rpc_lid == 0) {
		return;
	}
	GLib.Bytes allocation_bytes;
	uint8[] _allocation_data = new uint8[sizeof(ActorBox)];
	*((ActorBox*) _allocation_data) = allocation;
	allocation_bytes = new GLib.Bytes(_allocation_data);
	GnomeShellRpc.call_value(
		"Clutter-LayoutManager.allocate", this,
		OLLMrpc.args("oay", container, allocation_bytes));
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
	GLib.Bytes allocation_bytes;
	uint8[] _allocation_data = new uint8[sizeof(ActorBox)];
	*((ActorBox*) _allocation_data) = allocation;
	allocation_bytes = new GLib.Bytes(_allocation_data);
	GnomeShellRpc.call_value(
		"Clutter-LayoutManager.allocate", this,
		OLLMrpc.args("oay", container, allocation_bytes));
}
```

**Replace:**

```vala
public virtual void set_container(Actor? container)
{
	if (this.rpc_lid == 0) {
		return;
	}
	GnomeShellRpc.call_value(
		"Clutter-LayoutManager.set_container",
		this,
		OLLMrpc.args("o", container));
}
```

**Replace with:**

```vala
public virtual void set_container(Actor? container)
{
	if (this.rpc_lid == 0) {
		this.priv_container = container;
		return;
	}
	GnomeShellRpc.call_value(
		"Clutter-LayoutManager.set_container",
		this,
		OLLMrpc.args("o", container));
}
```

### 2 — `src/gi-stub/overrides-clutter/Actor.override.vala` · `relay_allocate`

**Replace:**

```vala
uint64 relay_allocate()
{
	return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
		var box = ActorBox();
		box.x1 = (float) call.args.get(1).get_double();
		box.y1 = (float) call.args.get(2).get_double();
		box.x2 = (float) call.args.get(3).get_double();
		box.y2 = (float) call.args.get(4).get_double();
		GnomeShellRpc.GiStub.VfuncRelay.begin(this);
		try {
			this.allocate_vfunc(box);
		} finally {
			GnomeShellRpc.GiStub.VfuncRelay.end();
		}
		if (GnomeShellRpc.GiStub.VfuncRelay.use_base) {
			return OLLMrpc.args("b", true);
		}
		return OLLMrpc.args("b", false);
	});
}
```

**Replace with:**

```vala
uint64 relay_allocate()
{
	return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
		var box = ActorBox();
		box.x1 = (float) call.args.get(1).get_double();
		box.y1 = (float) call.args.get(2).get_double();
		box.x2 = (float) call.args.get(3).get_double();
		box.y2 = (float) call.args.get(4).get_double();
		var lm = this.priv_layout_manager;
		if (lm != null && lm.rpc_lid == 0) {
			lm.allocate_vfunc(this, box);
			return OLLMrpc.args("b", false);
		}
		GnomeShellRpc.GiStub.VfuncRelay.begin(this);
		try {
			this.allocate_vfunc(box);
		} finally {
			GnomeShellRpc.GiStub.VfuncRelay.end();
		}
		if (GnomeShellRpc.GiStub.VfuncRelay.use_base) {
			return OLLMrpc.args("b", true);
		}
		return OLLMrpc.args("b", false);
	});
}
```

### 3 — `src/gi-stub/overrides-clutter/Actor.override.vala` · GJS LM → allocate Hook

**Add** next to `private LayoutManager? priv_layout_manager;`:

```vala
private bool priv_gjs_layout_allocate_hook;
```

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
				if (!this.priv_gjs_layout_allocate_hook && this.rpc_lid != 0) {
					var id = this.relay_allocate();
					if (id != 0) {
						GnomeShellRpc.call_value(
							"Helper-Actor.add_hook", this,
							OLLMrpc.args("st", "allocate", id));
						this.priv_gjs_layout_allocate_hook = true;
					}
				}
			}
```

### Rejected

```text
🚫 GLib.idle_add / Idle / timeout after queue_relayout
🚫 destroy layout._coverPane / _startingUp=false in JS
🚫 skip ensureAllocation / vendor overviewControls.js
🚫 mint rpc_lid on GJS LayoutManager
```

### Prove

```bash
GI_META_SMOKE=startup-allocate-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# A PASS · B PASS · C PASS · D PASS · E PASS
```

---

## Next

1. **User** confirm **💩** sketch (§1–§3).
2. Implement → smoke **A** PASS.
3. Nest: `_startingUp` clears · cover gone · menus via pointer.
