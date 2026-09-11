# Layout relay vs `call_sync` reentrancy (chrome piled top-left)

**Status:** ✔️ fixed — archived 2026-09-11 (nested boot; OPC Gi INOUT float + layout relay)  
**OPC:** ✔️ nested `call_poll` mid-emit; ✔️ Gi INOUT float (`libocrpc` ~18:18)  
**Hit:** 2026-09-09 nested Wayland (`mutter-rpc --wayland --nested`)  
**Plan:** T-030 chrome layout  

**OPC proposal / fix:** `OLLMchat/docs/bugs/2026-09-09-call-sync-mid-wait-live-invoke-flow.md`  
**OPC (INOUT):** `OLLMchat/docs/bugs/done/2026-09-10-FIXED-gi-inout-float-as-value-segfault.md`  
**Repro:** `tests/call-sync-repro/` — see README

---

## 2026-09-10 late — SIGSEGV after `*_vfunc` preferred hits theme

Layout mint now calls Class `*_vfunc` slots; preferred hooks run. Hit:
`St-ThemeNode.adjust_for_height` → mutter-rpc segfault (`0xbf800000` =
`-1.0f` as pointer). **OPC Gi INOUT scalar fix installed** (~18:18
`libocrpc.so`) — re-run nested to confirm `replied` and chrome layout:

→ `OLLMchat/docs/bugs/done/2026-09-10-FIXED-gi-inout-float-as-value-segfault.md`

---

## 2026-09-10 evening — piled-left with boot alive

Boot no longer hangs (`Meta-Context.notify_ready` in
`~/.cache/gnome-shell-rpc/*.debug.log` ~17:30). Visual: top bar Apps /
clock / indicators still stuffed left.

### Log prove (existing DBG, no rebuild)

From `mutter-rpc` + `org.gnome.ShellRpc` debug logs:

| Counter | Value | Meaning |
|---------|------:|---------|
| allocate `emit END` | 42 | all `replied=true args=1` |
| allocate chain boolean | **42 / 42 true** | server always `base.allocate` |
| invoke `REPLY … extra=null` | 223 | preferred chain (empty reply) |
| invoke `REPLY … extra=1` | 42 | allocate boolean only |
| invoke `REPLY … extra=2` | **0** | **no JS preferred `dd` values ever** |

Panel (`vendor/.../panel.js`) has `vfunc_allocate` that places
`_leftBox` / `_centerBox` / `_rightBox`. Hook path never reaches it:
client Vala `self.allocate` / `get_preferred_*` hit the
`layout_relay_target` chain sentinel → server stock `BoxLayout` packs
children from the left → exact piled-left chrome.

Suspect next: Vala virtual call from the hook does **not** enter GJS
`vfunc_*` (Class slot vs Vala method), not a missing Panel mint.

**2026-09-10 fix:** mint calls stock-offset `*_vfunc` slots (what GJS
patches); denied Class slots emit layout_relay chain fallthrough. Prove:
`chain=false` / `path=js` on `Gjs_ui_panel_Panel`.

Sharper DBG added (rebuild to use):

- client `DBG layout_relay {preferred_width,preferred_height,allocate} type=… name=… chain=…`
- server `path=base|js` on preferred/allocate END

```bash
rg 'layout_relay allocate|path=js|path=base' \
  ~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc}.debug.log \
  | head -80
```

Expect today: all `chain=true` / `path=base`, including GType names that
look like Panel / UiActor subclasses.

---

## 2026-09-09 evening — expedition log (what went wrong)

### Product goal (unchanged)

Nested chrome lays out like in-process mutter: **JS preferred/allocate run against server peers** (panel full width, not piled). Thin peer = **Constraint-shaped relay** (`Hook.emit` → apply reply). Reentrancy lives at **one client Runtime boundary + one server relay boundary**, not inside widget peers.

### What the expedition actually did (hacking)

| Change | Intent | Result |
|--------|--------|--------|
| Client `sync_depth` + invoke **queue** | Avoid nested `call_sync` when Live.Invoke arrives mid-stub | **Deadlocks** with sync `Hook.emit` (server waits for reply; client will not run handler until outer call finishes) |
| Peer Idle / cache / stamp-`set_allocation` / `queue_relayout` | “Fix” preferred without sync emit | Peer **owned layout** (not a relay); blank / wrong geometry |
| Strip peer to sync emit like Constraint | User: stop owning allocate | Correct shape for the peer; still hung without a real boundary |
| `DeferRelay` (schedule → then `can_sync_emit` / `emit` depth) | One server place for emit rules | API churned mid-flight; never a clear “off-stack emit that still returns preferred outs” |
| **`RelayConnection`** (new class; `Listen` switched) | Count `request_depth` without OPC change | Extra class; duplicates `Connection.on_input_ready`; not agreed design |
| Gate **Constraint** `update_allocation` on `can_sync_emit` | Stop mid-request Constraint emit hang on `get_width` | Touched a working path; still not a designed relay |
| DesaturateEffect / Runtime debug spam | Diagnose nested `set_factor` | Side quest; not chrome layout |

### Observed proves (evening)

- Queue + sync emit → hang (no `notify_ready`).
- Preferred cache + DeferRelay schedule → booted, **Cover/Header** asserts (message-list z-order, **not** panel geometry); panel still wrong / later blank.
- Thin sync emit without queue → `get_width` → Constraint/layout emit → **nested reply** → server stuck in `Hook.emit` → **blank nested window**.

### Working tree at stop → **code reverted**

**2026-09-09 ~20:07:** expedition **code** restored to `HEAD` (Idle-in-peer `Helper.Actor`, Runtime Idle-defer reply, no `DeferRelay` / `RelayConnection`). Deleted untracked `src/rpc/RelayConnection.vala` and `src/rpc/helper/DeferRelay.vala`.

Only this bug doc still carries the expedition log. Chrome may again be **visible but squashed** — that is the known baseline until a real design lands.

### Working tree at stop (historical — evening before revert)

Modified then: `Runtime.vala`, `ClutterActor.vala`, `Constraint.vala`, `Listen.vala`, `namespace.vala`, `meson.build`, this doc.  
Untracked then: `src/rpc/RelayConnection.vala`, `src/rpc/helper/DeferRelay.vala`.


### Design constraints that keep getting rediscovered

1. **Preferred outs are synchronous** in Clutter. Idle-then-cache is not a relay; it is a second layout engine.
2. **Client invoke queue + server sync `Hook.emit` on the request stack = deadlock.** Both halves of the bug doc are required; inventing only one half fails.
3. **`Hook.emit` reply via `call_sync` while already inside `call_sync` = nested forbid.** Idle-only reply while the client private sync loop is running never drains → hang. Reply-path needs an explicit design (not ad-hoc Idle).
4. **Peers must stay Constraint-shaped.** `Helper.Actor` / Constraint call a **shared emit path**; they must not grow flags, caches, or stamp-allocate policy.

### Decision gate (answer before more code)

Code is back at HEAD. Next step is design-only until you say otherwise.

**A.** Done — reverted.  
**B.** Write emit/reply contract next (no code).  
**C.** Something else (say what).

---

## Symptom

1. **Chrome geometry wrong.** Panel / `UiActor` GJS subclasses implement `vfunc_get_preferred_*` / `vfunc_allocate`. Server peers were plain `St.Widget` → stock allocate → Apps / clock / indicators pile top-left instead of full-width panel layout.
2. **Soft CRITICAL spam while still booting.** After Helper-Actor minting lands, nested still reaches `Meta-Context.notify_ready`, but logs show e.g.:

```
Client.vala: … method=Clutter-DesaturateEffect.new
… nested call_sync is not supported (g-io-error-quark, 0)
```

(Observed ~10× on one prove; always during another stub `call_sync`, often around effect / chrome construct.)

Visual prove (panel not piled) is still incomplete while reentrancy races remain.

---

## Goal (product)

Nested shell: **JS layout vfuncs run against compositor peers**, so chrome sizes and positions like in-process mutter. Same shape as the working **Helper-Constraint** relay — not a special Clutter API we invent on stock types.

Corridor: stubs only implement **real** GI symbols; layout hooks are **our** Helper peer + **relay/Runtime** boundaries (not stock Meta/St APIs).

---

## Stock / in-process model

```
Stage allocate
  → parent.get_preferred_* / parent.allocate   (may be GJS vfunc)
      → child.allocate(box)                   (same address space)
      → set_allocation(box)                   (must stay inside allocate vfunc)
```

Out-of-process, `child.allocate` is an RPC. The JS vfunc body is **full of `call_sync`**. That is normal and required.

---

## Working precedent: Helper-Constraint

```
Server: Constraint.update_allocation
  → Hook.emit(Live.Invoke)          // blocks on default MainContext until reply
Client: Runtime invoke handler
  → JS / Vala update_allocation     // usually mutates ActorBox locally
  → RPC-Live-Callback.reply
Server: applies reply_args to box
```

Constraint hooks rarely need a storm of nested GI RPCs inside the handler. **Actor allocate does.**

---

## Intended layout relay (same shape)

| Side | Role |
|------|------|
| Client construct | Parent-walk lease: first Bin alias `St-Widget` → `mint_layout_relay()` → `Helper-Actor.create(ttt)` with preferred-w/h + allocate callbacks |
| Server peer | `Helper.Actor : St.Widget` — Clutter lifecycle only; **no** IPC Idle flags |
| Server relay | Off-request-stack `Hook.emit` + apply path (`set_allocation` / preferred outs) |
| Client Runtime | Queue Live.Invoke while `sync_depth > 0` |
| Client Vala fallthrough | Chain sentinel when no JS override (server bases; **no** chain RPC from inside the hook) |
| Bin | `register_alias("St-Widget", typeof(Helper.Actor))` so Gi `add_child` accepts the peer |

Peer minting is correct. Failure modes are **when** invoke runs relative to `call_sync`, and **where** off-stack emit is scheduled (relay vs peer).

---

## How blocking GI RPC works (and why OPC got `call_sync`)

Every stock GI stub method ends in `GiStub.Runtime.do_call` → one wire round-trip. The shell is written as if those calls were ordinary C: construct props, setters, `allocate`, etc. all expect **synchronous** returns. So the client must block until the server replies.

### Before 2026-09-08 — nest the default `MainLoop`

`do_call` used to turn async `Client.call` into “sync” like this:

```vala
var call_loop = new GLib.MainLoop();          // DEFAULT MainContext
Runtime.client.call.begin(request, (obj, res) => {
    …; call_loop.quit();
});
call_loop.run();  // dispatches *everything* on the default context until quit
```

While waiting on the socket, that nested loop also ran Pulse/Gvc, Clutter idles, GJS timeouts, etc. Stock `volume.js` connects `default-sink-changed` before `this._output = new OutputStreamSlider(…)`. In-process Gvc almost never fires mid-construct; out-of-process the nested loop **did**, so JS ran `_readOutput` while `_output` was still unset → soft `TypeError: this._output is undefined` (and the same class of race anywhere else that assumes “no foreign main-context work mid-GI-call”).

That was **our** bug, not volume.js. Reordering stock JS would only paper over one site.

### What we changed in OPC (and why it looked suspicious)

OPC added `Client.call_sync`: block on a **private** `MainContext` that only pumps the RPC read watch (and optional call timeout). Default-context sources stay frozen for the duration of one stub call. Consumer switched:

```vala
// GiStub.Runtime.do_call
return Runtime.client.call_sync(request);
```

**Why that belongs in OPC, not only in the shell client:** any consumer that needs “sync RPC without re-entering the app main loop” hits the same trap. The private-context pump is transport policy.

**Why nesting is forbidden there:** `call_sync` keeps a single `sync_loop` / private watch. A second `call_sync` while the first is waiting would need either (a) re-entering that private loop from inside `on_read` (undefined ownership of the watch / pending map), or (b) falling back to the default loop (which undoes the volume fix). OPC therefore throws `nested call_sync is not supported` if `sync_loop != null`. That is a deliberate fence, not an unfinished feature.

Follow-ons after the first landing (still OPC, still about the same design):

| Follow-on | Mistake | Correction |
|-----------|---------|------------|
| Hang / CRITICAL removing the sync watch | `GLib.Source.remove` on a source attached to the **private** context | Remove via the context that owns the source |
| Boot hangs after an RPC burst | early `call_sync` used `push_thread_default(private)` so Clutter/GJS/`Idle.add` sources were created on the private context and died on teardown | **Do not** push thread-default; attach **only** the RPC watch (+ timeout) to the private context; sync-flush the outbound head inside `call_sync` |

Consumer refs: `docs/bugs/done/2026-09-08-volume-output-undefined-reentrancy.md`.  
OPC refs: `OLLMchat/docs/bugs/done/2026-09-08-FIXED-sync-call-nested-mainloop-reentrancy.md` (+ Source.remove / no-`push_thread_default` follow-ons).

### What that buys us — and what it costs for layout

| Property | Meaning for chrome |
|----------|-------------------|
| Default context frozen mid-stub | Gvc/Clutter/GJS cannot run “inside” a GI call (volume race closed) |
| Private `on_read` still runs | Socket bytes for **this** wait — including opportunistic `Live.Invoke` frames — are handled on the private context |
| No nested `call_sync` | A live handler that itself needs GI RPC **must not** run while depth &gt; 0 |

So OPC `call_sync` solved the **wrong main-loop** problem. Layout relay surfaces the **sibling** problem: server→client live hooks need GI RPC, and those hooks can be delivered on the private read path of an unrelated stub call. That is **not** a reason to reopen nested `call_sync` in OPC; it is a reason to schedule those handlers in the client library when depth is 0.

---

## Root cause (design, not a missing ocrpc feature)

### Contract we already rely on

`OLLMrpc.Client.call_sync` (as above):

- Private `MainContext` for RPC IO only — default sources do not run mid-stub.
- **Forbids nesting** — intentional fence after the volume fix.

**🔷 Fixing chrome must not mean enabling nested `call_sync` in OPC.** The layout fix lives in **two symmetric boundary layers** (client Runtime queue + server relay dispatcher) — not in concrete `Helper.Actor` / Constraint subclasses.

### How Live.Invoke actually arrives

`Hook.emit` writes `Live.Invoke` and spins **default** `MainContext` until `RPC-Live-Callback.reply`.

On the client, `Runtime.client.invoke` runs the bound handler **inline** from `on_read`. `on_read` also runs on the **private** sync context while any `call_sync` is in flight (response wait). So:

```
call_sync(A)                          // e.g. DesaturateEffect.new
  private on_read
    may deliver Live.Invoke(B)        // e.g. Helper-Actor allocate hook
      handler(B)                      // JS vfunc_allocate
        call_sync(C)                  // child.allocate / set_x_expand / …
          → CRITICAL nested call_sync
```

Idle-deferring only the **reply** (current `Runtime.vala`) does **not** fix this: the **handler** still runs inside `call_sync(A)` and still issues `call_sync(C)`.

### Deadlock if we only “queue on client” without server discipline

```
Client: call_sync(A) waiting for response A
Server: still handling A, also Hook.emit(B) waiting for reply B
Client: will not run B until A completes
→ deadlock
```

So a complete design needs **both boundary halves** — and they must live in **one relay / Runtime layer each**, not copied into every peer widget:

1. **Server relay boundary:** never `Hook.emit` layout (or similar) hooks on the stack of an in-flight client request. Schedule emission off that stack (Idle today; could later be frame-clock / a dedicated queue) **inside the dispatcher**, then apply the reply (e.g. `set_allocation`) through a callback the peer provides.
2. **Client Runtime boundary:** never run a live handler that may `call_sync` while `do_call` depth &gt; 0. Queue invoke → run handler + reply when depth returns to 0.

Server-only Idle inside `Helper.Actor` still races: invoke can land in the private `on_read` of an unrelated later `call_sync` (DesaturateEffect spam). Client queue alone deadlocks if the server emits on the request stack. **Both halves; one place each.**

---

## What we tried (and why it is hacking)

| Attempt | Why it is insufficient |
|---------|-------------------------|
| Skip preferred hooks; always `base.get_preferred_*` | Avoids emit during preferred; **layout sizes wrong**; does not fix allocate reentrancy |
| Idle / `in_allocate_hook_emit` **inside** `Helper.Actor` | Right *idea* (emit off request stack); **wrong layer** — scatters IPC sync into the Clutter peer (see below) |
| Idle-defer `RPC-Live-Callback.reply` only | Stops reply-inside-`call_sync`; **handler** still nests |
| Chain sentinel for Vala fallthrough | Good; unrelated to JS allocate child RPCs |
| Teach OPC nested `call_sync` | 🚫 User: out of bounds; also re-opens volume-style default-context hazards if done naïvely |
| Call `set_allocation` from Idle alone (no re-enter allocate) | Clutter critical: allocation only inside allocate vfunc |

Shipping Idle flags in each peer without a relay boundary leaves CRITICAL spam, unverified chrome, and duplicated protocol logic.

---

## Review conclusion: one reentrancy layer (not in the peer)

**🔷 Important distinction.** Pushing `Idle` re-entrancy and layout flags (`in_allocate_hook_emit`, `allocate_idle_queued`, …) into individual server subclasses like `Helper.Actor` **scatters IPC synchronization across the object model** instead of insulating peers behind a strict protocol boundary.

If `Helper.Actor` must know *how* to bounce calls through `GLib.Idle` to satisfy RPC transport state, the boundary between the **protocol layer** and the **Clutter peer** is leaking.

### Why not in `Helper.Actor`

1. **Leaky layer boundary.** Concrete widgets should care about Clutter lifecycle (`allocate`, `get_preferred_*`). They should not own IPC reentrancy state.
2. **Duplication risk.** Every new peer actor, constraint, or server-side hook subclass would re-implement the same Idle deferral dance.
3. **Implicit protocol contracts.** “Layout hooks must be deferred off the request stack” becomes folklore in widget files instead of an explicit guarantee of the relay framework.

### Target architecture

```
[ GJS / client subclasses ]
       │
       ▼
[ Client Runtime ]     ←── queue incoming Live.Invoke when sync_depth > 0
       │
═══════╪══════════════════════════════════════════ IPC BOUNDARY
       │
[ Server relay ]       ←── schedule Hook.emit off request stack; one place
       │
       ▼
[ Helper.Actor ]       ←── pure Clutter peer (no Idle / reentrancy flags)
```

Sketch (names illustrative — land as whatever fits `src/rpc/`):

```vala
/* Peer — Clutter only; delegates emit+apply to the relay */
public override void allocate(Clutter.ActorBox box) {
    base.allocate(box);  /* sync pass so tree can finish mid-RPC */
    this.layout_relay.dispatch_allocate(box, (computed) => {
        this.set_allocation(computed);  /* must still run inside allocate vfunc */
    });
}

/* Relay boundary — owns scheduling + Hook.emit rules */
public void dispatch_allocate(Clutter.ActorBox box, owned AllocationApply apply) {
    /* never emit synchronous layout hooks on an active client-RPC stack */
    GLib.Idle.add(() => {
        var reply = /* Hook.emit allocate … */;
        if (!reply.is_chain_sentinel) {
            apply(reply.box);
        }
        return GLib.Source.REMOVE;
    });
}
```

Clutter still requires `set_allocation` **inside** an `allocate` vfunc. The relay must arrange that (e.g. Idle that re-enters `allocate`, or an equivalent peer callback invoked while still on the allocate stack) — but the **scheduling policy** stays in the relay, not as ad-hoc fields on every peer.

Constraint `update_allocation` / future hooks should use the **same** server emit path once it exists (no second Idle copy in `Helper.Constraint`).

---

## Designed solution (boundary layers only)

### Invariant

> **Live handlers that may perform GI RPC run only when client `call_sync` depth is 0.**  
> **Server must not `Hook.emit` those handlers on the stack of an in-flight client RPC.**  
> **Both rules are enforced at the Runtime / server-relay boundary — not inside concrete widget peers.**

### Client — `GiStub.Runtime`

1. Track `sync_depth` around `do_call` → `client.call_sync` (our wrapper; no OPC API change).
2. On `invoke`:
   - If `sync_depth > 0`: enqueue `(call, handler)` — **do not** run handler, **do not** reply yet.
   - If `sync_depth == 0`: run handler; then `RPC-Live-Callback.reply`.
3. When `sync_depth` returns to 0: drain queue (handler then reply) on the **default** context, so Clutter/GJS see a normal turn.
4. Prove allocate / constraint handlers that RPC children succeed without nested errors; DesaturateEffect construct during chrome build must not CRITICAL.

### Server — relay / dispatcher (new or extract), not peer flags

1. Introduce a **server layout (live-hook) relay** that wraps `Hook.emit` for allocate / preferred (and later Constraint-style hooks): off-request-stack scheduling + chain-sentinel handling + apply callback.
2. Strip `Helper.Actor` down to Clutter delegation: call the relay; **no** `in_allocate_hook_emit` / peer-local Idle ownership as the protocol mechanism.
3. **Preferred:** wire through the same relay before treating JS preferred as real. Until then, document base-only preferred as known geometry skew — still do not invent a second deferral style inside the peer.
4. Peers must not emit hooks from `create` / property RPC handlers on the request stack (relay enforces or peers simply call `dispatch_*`).

### Explicit non-goals

- 🚫 Changing `libocrpc` to allow nested `call_sync`.
- 🚫 Inventing `Meta`/`St`/`Clutter` APIs that are not in GIR.
- 🚫 Patching stock gnome-shell JS to avoid `vfunc_allocate`.
- 🚫 Leaving Idle / reentrancy flags as the long-term home inside each `Helper.*` peer.

---

## Files (current vs intended)

| Path | Role |
|------|------|
| `src/gi-stub/Runtime.vala` | `sync_depth` + invoke queue + direct-reply |
| `src/rpc/LayoutRelay.vala` | server defer/emit + `request_depth` |
| `src/rpc/RelayConnection.vala` | enter/leave request around dispatch |
| `src/rpc/helper/ClutterActor.vala` | Helper.Actor — defer allocate via LayoutRelay |
| `src/rpc/helper/Constraint.vala` | sync emit only when `can_sync_emit` |
| `src/rpc/Listen.vala` | uses `RelayConnection` |
| `src/gi-stub/overrides-clutter/Actor.override.vala` | parent-walk mint, layout hooks, chain sentinel |
| `vapi/st-widget-peer.*` | real `StWidget` class/instance sizes |
| `src/rpc/Server.vala` | `Bin.register_alias("St-Widget", …)` |
| `tests/call-sync-repro/` | pure-gio failure + solution modes |

Intended after design: one Runtime rule + one server emit relay; peers Constraint-shaped only.

---

## Prove

```bash
timeout 25 dbus-run-session ./build/src/mutter-rpc --debug --wayland --nested \
  2>&1 | tee /tmp/mutter-rpc-layout.log
```

Expect:

1. Many `Helper-Actor.create` (chrome / UiActor subclasses).
2. **Zero** `nested call_sync is not supported`.
3. Reach `Meta-Context.notify_ready` and stay up (~5s+).
4. Nested window: top bar full width; Apps / clock / indicators not piled top-left.
5. No Clutter critical `set_allocation … only be called from … allocate`.
6. **No** reentrancy Idle / `in_*_hook_emit` logic left in concrete peers once the relay lands.

---

## Related

- **OPC `call_sync` origin (read this with the section above):**  
  consumer `docs/bugs/done/2026-09-08-volume-output-undefined-reentrancy.md` ·  
  OPC `…/OLLMchat/docs/bugs/done/2026-09-08-FIXED-sync-call-nested-mainloop-reentrancy.md` ·  
  follow-ons Source.remove / no-`push_thread_default` hang under same date prefix in OPC `docs/bugs/done/`
- Constraint mint: `docs/bugs/done/2026-09-07-align-constraint-relay-mint.md`
- Theme CSS (orthogonal visibility): `docs/bugs/done/2026-09-09-st-theme-not-on-server.md`
- OPC `Client.call_sync` implementation: `libocrpc/Client.vala` — nested throw stays

---

## Decision needed before more code

See **Decision gate (A/B/C)** in the expedition log above.

The long-standing design (still correct as a target, not as a claim that the tree implements it):

1. **Client:** one Runtime rule for Live.Invoke vs `call_sync` (queue **or** another reply strategy that does not deadlock with server emit — pick explicitly).  
2. **Server:** one relay that owns when `Hook.emit` may run (off request stack) and how preferred outs / allocate apply still satisfy Clutter.  
3. **Peers:** `Helper.Actor` / Constraint = emit → apply only; **no** peer-local Idle/cache/stamp as protocol.

Do not land more helper tweaks without that contract written and the expedition cleaned up.
