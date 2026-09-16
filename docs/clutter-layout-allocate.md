# Clutter layout / allocate — reference flow vs ours

**Owns:** the in-process **gnome-shell** call chain (GJS + mutter C, one
address space), then the same moments split across RPC **client**
(`gnome-shell-rpc`) and RPC **server** (`mutter-rpc`). Chrome bugs
prove a **broken row**, they do not invent a second layout.

**Reference process:** stock `gnome-shell` — GJS
(`js/ui/panel.js`, `panelMenu.js`, `overviewControls.js`) and mutter
**gnome-48** C (`clutter-actor.c`, `clutter-stage.c`,
`clutter-layout-manager.c`) in **one** process. GJS
`GObject.registerClass` / `vfunc_*` **is** `Class->allocate` /
`LayoutManagerClass.allocate` in that process. Do not treat reference
as C-only.

**Client:** `src/gi-stub/overrides-clutter/Actor.override.vala`,
`LayoutManager.override.vala`.  
**Server:** `src/rpc/helper/ClutterActor.vala` plus stock mutter C on
the leased peer.

Read each flow **top to bottom**. Client and server are **never** on the
same row — an RPC or hook is the next physical step (blank reference,
then the other column). A cell is **blank** when that column has no
equivalent.

**MISS** in a cell is a critical mismatch with the reference (wrong
call, or a required call that never happens). Those are the problem
rows.

---

## Flow 1 — dirty mark → stage clock → allocate

**Entry:** something needs a new size (`queue_relayout`).  
**Exit:** GJS `vfunc_allocate` (Actor and/or LayoutManager) has run in
the same tick as the container’s allocate.

| Reference process | RPC client | RPC server |
| ----------------- | ---------- | ---------- |
| | `Helper-Actor.create` / `add_hook` (`Actor.override.vala` `relay_attach`) — once, at construct | |
| | | `Helper-Actor.create` mints the peer; `add_hook` binds `vfuncs["allocate"]` |
| GJS `actor.queue_relayout()` | JS `actor.queue_relayout()` → generated `Clutter-Actor.queue_relayout` | |
| `clutter_actor_queue_relayout` (`clutter-actor.c` ~7848) | | GI invoke → same C on the leased peer |
| `_clutter_actor_queue_only_relayout` (~7771) emits `::queue-relayout` | | same C on the peer |
| `clutter_actor_real_queue_relayout` (~2558) sets `needs_allocation`, walks to parent (shallow if `NO_LAYOUT`) | | same C on the peer |
| `clutter_actor_queue_shallow_relayout` (~1652) → `clutter_stage_queue_actor_relayout` (`clutter-stage.c` ~910) prepends `pending_relayouts` | | same C, if the peer is on the stage |
| `clutter_stage_finish_layout` (~1006) / `clutter_stage_maybe_relayout` (~957) steals `pending_relayouts` | | same mutter stage clock — **not** a client Idle |
| `clutter_actor_allocate_preferred_size` (`clutter-actor.c` ~12850) → **Flow 2** public `allocate` | | same C on the peer |
| `Class->allocate`: GJS `vfunc_allocate(box)` when gjs replaced the slot (`Panel`, `WorkspaceDot`, GJS `St.Widget`) | | GJS subclass peer: `Helper.Actor.allocate` (`ClutterActor.vala` ~223) emits Live.Hook `allocate` |
| | hook reply → `relay_allocate` (`Actor.override.vala` ~150) → `this.allocate_vfunc(box)` | |
| else `clutter_actor_real_allocate` (~2458) — no JS Actor override | | stock `St.*` peer, no hook: `real_allocate` |
| GJS `actor.layout_manager = lm` — `clutter_actor_set_layout_manager` (~15446) stores the **GJS** LM on `priv->layout_manager` and connects `::layout-changed` | setter: `set_container` → **`set_container_vfunc`** (GJS LM) + `set_layout_manager(helper_peer)` | |
| `clutter_layout_manager_set_container` → GJS `vfunc_set_container` (e.g. WorkspaceLayout fills `_workarea`) | same — **MISS** was rpc_lid==0 no-op; gate `layout-set-container-smoke` | |
| | | C `clutter_actor_set_layout_manager` on the Helper LM peer (alias `Clutter-LayoutManager`, same as `St-Widget` for Helper.Actor) |
| `real_allocate` → `clutter_layout_manager_allocate` (~393) → GJS `vfunc_allocate(container, box)` | | Helper LM `klass->allocate` hook: `"odddd"` container GObject + box floats (remaining C args after self) |
| | `relay_allocate` → `call.args.get(0).get_object()` → `allocate_vfunc(container, box)` | |

**Exit check:** ControlsLayout `vfunc_allocate` runs in-process as
`LayoutManagerClass.allocate`. The **MISS** rows are
`startup-allocate-smoke` **E**.

---

## Flow 2 — parent assigns a child (this is where align happens)

**Entry:** a parent GJS `vfunc_allocate` / LM calls `child.allocate(box)`.  
**Exit:** child’s stored allocation includes **that child’s** align +
margins; child’s `Class->allocate` (GJS or C) has run.

`clutter_actor_allocate` (~8806): *“This function will adjust the stored
allocation to take into account `x-align` / `y-align` and margins.”*

| Reference process | RPC client | RPC server |
| ----------------- | ---------- | ---------- |
| GJS `WorkspaceDot.vfunc_allocate` (`panel.js`): `this.set_allocation(box); box.set_origin(0,0); this._dot.allocate(box)` (`_dot.y_align = CENTER`). Same shape: `Panel`, `ButtonBox` | same JS | |
| `clutter_actor_allocate` (`clutter-actor.c` ~8806) | stub `Actor.allocate`: GJS LM on **this** actor → `lm.allocate_vfunc` locally. Helper peer → `Helper-Actor.allocate_public`. Else `Clutter-Actor.allocate` | |
| | | Helper: C `clutter_actor_allocate` + `adjust_allocation`. Smoke **C** `midDy=0` |
| `clutter_actor_update_constraints` (~8601) may mutate the box | | same C (`constraint-allocate-smoke`) |
| `clutter_actor_adjust_allocation` (~8647) applies **this child’s** `x-align` / `y-align` / margins | | C on the Helper peer (`allocate_public`) |
| `clutter_actor_allocate_internal` (~8758) → `klass->allocate` | | Helper peer: hook. Plain `St.Widget` (the dot): stock C `Class->allocate` |
| GJS child `vfunc_allocate` if gjs replaced the slot; else `clutter_actor_real_allocate` (~2458) | GJS override: `relay_allocate` → `vfunc_allocate` | |
| | | stock peer: `real_allocate`; compositor LM → Flow 1 GJS LM rows |

**Exit check:** `_dot` is an `St.Widget` with `y_align=CENTER`. After
`adjust_allocation` the stored box is preferred-size, vertically
centred. Gate: `workspace-dot-align-smoke` **C** (`midDy=0`).
**A/B** PASS: BoxLayout / `St.Bin` still compute a centred child box
when **they** are the parent.

**🚫** Do not edit `panel.js` to call `allocate_align_fill`. Stock GJS
already uses Flow 2.

---

## Flow 3 — `layout_changed` → next Flow 1 (ensureAllocation)

**Entry:** GJS `ControlsManagerLayout.ensureAllocation()`
(`overviewControls.js`): `this.layout_changed()` + Promise for
`_runPostAllocation`.  
**Exit:** GJS LM `vfunc_allocate` runs `_runPostAllocation`; Promise
resolves.

| Reference process | RPC client | RPC server |
| ----------------- | ---------- | ---------- |
| GJS `lm.layout_changed()` | stub `layout_changed_invoke` (`LayoutManager.override.vala` ~17) | |
| `clutter_layout_manager_layout_changed` (`clutter-layout-manager.c` ~417) **only emits** `::layout-changed` on that **same** GJS LM object | GObject emit on the client GJS LM (`rpc_lid==0`) | |
| | | RPC `Clutter-LayoutManager.layout_changed` on the helper peer — C emit on that peer |
| `on_layout_manager_changed` (~15427) — connected when GJS did `actor.layout_manager = lm` → `clutter_actor_queue_relayout` | | same C on the server |
| Flow 1 on the **container** (GJS Actor `vfunc_allocate` and/or GJS LM `vfunc_allocate`) | | |

**Exit check:** Promise resolves in the GJS allocate that
`layout_changed` requested — not from Idle, not from the signal
handler calling `allocate` itself.

---

## Chrome — which flow

| Surface | Flow | Not |
| ------- | ---- | --- |
| Workspace dots | **2** (GJS `WorkspaceDot` → `_dot.allocate`) during panel allocate, before startup await | waiting for `_startingUp`; vendor `panel.js` |
| Wallpaper actors | **2** on `_backgroundGroup` children; SystemBackground is `#282828` until those paint | `_coverPane` (opacity 0) |
| Startup grey left up | **3** never exits → `_startupAnimationComplete` never destroys SystemBackground | “cover is the grey” |

---

## Prove — name the miss by call

| Smoke | Row |
| ----- | --- |
| `workspace-dot-align-smoke` **C** | Flow **2** `clutter_actor_allocate` / `adjust_allocation` |
| `actor-allocate-box-smoke` | Flow **2** Helper `allocate` hook — must not `set_allocation` with the pre-hook box after JS stored a new one |
| `constraint-allocate-smoke` | Flow **2** `update_constraints` |
| `layout-allocate-smoke` | Flow **1** GJS `LayoutManager.vfunc_allocate` |
| `startup-allocate-smoke` **A–E** | Flow **3** `on_layout_manager_changed` and Flow **1** GJS LM row |

**🚫** A smoke that asserts a call mutter / GJS does not have.  
**🚫** Stub / Helper / vendor JS edits without a FAIL that cites a
**row**.  
**🚫** `GLib.idle_add` as a substitute for `clutter_stage_maybe_relayout`.  
**🚫** Invented GI methods.

**Allocate (archived):**
[`bugs/done/2026-09-16-allocate-follow-reference.md`](bugs/done/2026-09-16-allocate-follow-reference.md).
Chrome residual: [`bugs/2026-09-16-chrome-panel-menus-overlay.md`](bugs/2026-09-16-chrome-panel-menus-overlay.md).

---

## LLM only — reading I don't give a crap about

Not the work. Agents: do not repeat these. Do not promote them back into
the flows or the close.

**Client rewrite of C (reverted 2026-09-16).** Never RPCd
`set_layout_manager` for a GJS LM; hijacked **Actor** allocate Hook to
run LM `vfunc`; `layout_changed_invoke` → client `queue_relayout`.
Wrong Class slot. Re-entered allocate (`startup-allocate-smoke` **F**);
nest EOS / mutter ec=133. Server-side C emit + `on_layout_manager_changed`
marks dirty for the **next** stage clock — that is why F is `hits=1`
when we do not queue from the client stub.

Related landings (already closed):
[`bugs/done/2026-09-15-gjs-layoutmanager-null-allocate.md`](bugs/done/2026-09-15-gjs-layoutmanager-null-allocate.md)
· [`bugs/done/2026-09-15-chrome-placement.md`](bugs/done/2026-09-15-chrome-placement.md)
