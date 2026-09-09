# Layout relay vs `call_sync` reentrancy (chrome piled top-left)

**Status:** ⏳ design — stop hacking; fix in **client library** (`GiStub.Runtime` + helpers)  
**Hit:** 2026-09-09 nested Wayland (`mutter-rpc --wayland --nested`)  
**Plan:** T-030 chrome layout  
**OPC:** 🚫 out of scope — do **not** teach `libocrpc` nested `call_sync` for this

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

Corridor: stubs only implement **real** GI symbols; layout hooks live on **our** `Helper.Actor` / client Runtime.

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
| Server peer | `Helper.Actor : St.Widget` (real class size via `st-widget-peer`) |
| Server vfuncs | Prefer / allocate → live hooks → client JS vfuncs → reply → `set_allocation` / preferred outs |
| Client Vala fallthrough | Chain sentinel when no JS override (server bases; **no** chain RPC from inside the hook) |
| Bin | `register_alias("St-Widget", typeof(Helper.Actor))` so Gi `add_child` accepts the peer |

This part is correct as a **product design**. The failure is **when** the client runs the live handler relative to `call_sync`.

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

**🔷 Fixing chrome must not mean enabling nested `call_sync` in OPC.** The layout fix lives in `GiStub.Runtime` (+ Helper emit discipline).

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

So a complete design needs **both**:

1. **Server:** never `Hook.emit` layout hooks on the stack of an in-flight client request (or any path that blocks that request’s reply). Re-enter allocate from Idle (or equivalent) so `set_allocation` still runs inside the Clutter allocate vfunc on the second entry.
2. **Client:** never run a live handler that may `call_sync` while `do_call` / `call_sync` depth &gt; 0. Queue invoke → run handler + reply when depth returns to 0.

Server Idle alone races: invoke can still land in the private `on_read` of an unrelated later `call_sync` (DesaturateEffect spam). Client queue alone deadlocks if the server emits on the request stack. **Both halves are the design; neither is a drive-by.**

---

## What we tried (and why it is hacking)

| Attempt | Why it is insufficient |
|---------|-------------------------|
| Skip preferred hooks; always `base.get_preferred_*` | Avoids emit during preferred; **layout sizes wrong**; does not fix allocate reentrancy |
| Sync allocate = `base.allocate` only; Idle re-enter for hook | Correct *server* half for Clutter `set_allocation` rules; **races** with client `call_sync` without a client queue |
| Idle-defer `RPC-Live-Callback.reply` only | Stops reply-inside-`call_sync`; **handler** still nests |
| Chain sentinel for Vala fallthrough | Good; unrelated to JS allocate child RPCs |
| Teach OPC nested `call_sync` | 🚫 User: out of bounds; also re-opens volume-style default-context hazards if done naïvely |
| Call `set_allocation` from Idle alone | Clutter critical: allocation only inside allocate vfunc |

Shipping a pile of these without the invariant below leaves CRITICAL spam and unverified chrome.

---

## Designed solution (client library + helpers)

### Invariant

> **Live layout (and any other) handlers that may perform GI RPC must run only when client `call_sync` depth is 0.**  
> **Server must not `Hook.emit` those handlers on the stack of an in-flight client RPC.**

### Client — `GiStub.Runtime` (primary fix locus)

1. Track `sync_depth` around `do_call` → `client.call_sync` (our wrapper; no OPC API change).
2. On `invoke`:
   - If `sync_depth > 0`: enqueue `(call, handler)` — **do not** run handler, **do not** reply yet.
   - If `sync_depth == 0`: run handler; then `RPC-Live-Callback.reply` (Idle-defer reply is optional once depth rule holds; keep if it still helps ordering).
3. When `sync_depth` returns to 0: drain queue (handler then reply) on the **default** context (Idle), so Clutter/GJS see a normal turn.
4. Prove that allocate / constraint handlers that RPC children succeed without nested errors; DesaturateEffect construct during chrome build must not CRITICAL.

No invented stock GI methods. No OPC nested `call_sync`.

### Server — `Helper.Actor` (keep / finish the non-hack part)

1. **Allocate:** sync entry: `base.allocate` so tree layout can finish; queue Idle → set `in_allocate_hook_emit` → re-enter `allocate` → `Hook.emit` → on chain sentinel `base.allocate`, else `set_allocation` (still inside vfunc).
2. **Preferred:** same emit-off-request-stack rule before wiring JS preferred for real. Until then document that preferred is base-only (known geometry skew).
3. Prefer hooks must not emit from `create` / property RPCs.

### Explicit non-goals

- 🚫 Changing `libocrpc` to allow nested `call_sync`.
- 🚫 Inventing `Meta`/`St`/`Clutter` APIs that are not in GIR.
- 🚫 Patching stock gnome-shell JS to avoid `vfunc_allocate`.

---

## Files (current state)

| Path | Role |
|------|------|
| `src/gi-stub/Runtime.vala` | invoke + `do_call` — **needs sync_depth + queue** |
| `src/gi-stub/overrides-clutter/Actor.override.vala` | parent-walk mint, layout hooks, chain sentinel |
| `src/rpc/helper/ClutterActor.vala` | Helper.Actor + Idle re-enter allocate |
| `vapi/st-widget-peer.*` | real `StWidget` class/instance sizes |
| `src/rpc/Server.vala` | `Bin.register_alias("St-Widget", …)` |

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

---

## Related

- **OPC `call_sync` origin (read this with the section above):**  
  consumer `docs/bugs/done/2026-09-08-volume-output-undefined-reentrancy.md` ·  
  OPC `…/OLLMchat/docs/bugs/done/2026-09-08-FIXED-sync-call-nested-mainloop-reentrancy.md` ·  
  follow-ons Source.remove / no-`push_thread_default` hang under same date prefix in OPC `docs/bugs/done/`
- Constraint mint: `docs/bugs/done/2026-09-07-align-constraint-relay-mint.md`
- Theme CSS (orthogonal visibility): `docs/bugs/2026-09-09-st-theme-not-on-server.md`
- OPC `Client.call_sync` implementation: `libocrpc/Client.vala` — nested throw stays

---

## Decision needed before more code

Implement **Runtime sync_depth + invoke queue** as the client half, keep Helper-Actor Idle re-enter as the server half, then re-prove nested chrome. Treat further Idle/`reply`-only tweaks without that invariant as out of order.
