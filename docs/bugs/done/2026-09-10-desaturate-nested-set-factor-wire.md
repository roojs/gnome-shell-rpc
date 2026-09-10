# DesaturateEffect: nested `set_factor` mid-`.new` reply → wire desync

**Status:** ✔️ `mint_done` gate — nested Wayland prove 2026-09-10 ~17:30  
**Hit:** 2026-09-10 nested Wayland (`mutter-rpc --wayland --nested`)  
**Prove:** `/tmp/mutter-rpc-desaturate-mint-done.log` + `~/.cache/gnome-shell-rpc/*.debug.log`  
**Fix:** `mint_done` on `factor` setter — store during construct-prop apply; RPC only after mint  
**JS:** `messageList.js` — `MessageHeader` → `new Clutter.DesaturateEffect()`  
**Stub:** `src/gi-stub/overrides-clutter/DesaturateEffect.override.vala`  
**Upstream (partial):** `OLLMchat/docs/bugs/done/2026-09-10-FIXED-live-parse-object-new-before-token-end.md`  
**Related:** Constraint / BrightnessContrastEffect “store then sync after mint”; layout reentrancy side quest in `2026-09-09-layout-relay-call-sync-reentrancy.md`

---

## Short version

Local `new Clutter.DesaturateEffect()` mints with `Clutter-DesaturateEffect.new`.
While the client is still decoding that reply’s live handle into a proxy
(`Object.new(..., "rpc-lid", …)`), the `factor` **set-construct** setter sees
`rpc_lid != 0` and issues a nested `Clutter-DesaturateEffect.set_factor` on the
**same** socket / `call_poll` stack.

That second sync call starts a new root `bin.parse()` while the outer Result
message is only **partly** consumed → protocol error
(`expected object type byte, got 0x00`). Neither call gets `replied`. Boot dies
in message-list chrome.

This is **not** “Desaturate is special.” It is **any** stub that RPCs from a
`set construct` property while a live proxy is being materialised from the wire.

---

## Symptom (prove)

```text
Client: id=4383 method=Clutter-DesaturateEffect.new
Server: recv id=4383 method=Clutter-DesaturateEffect.new
Client: id=4384 method=Clutter-DesaturateEffect.set_factor   ← nested, same ms
Server: recv id=4384 method=Clutter-DesaturateEffect.set_factor
Client: expected object type byte, got 0x00                  ← Client.vala:657 → bin.parse
```

No `replied id=4383` / `4384`. RPC stops; nested shell stays up as compositor
only (pointer motion continues on the server log).

Earlier OPC capture (pre TOKEN_END reorder) showed the sibling failure mode:

```text
Client: unexpected byte 0xFD after 0xFF   ← TOKEN_END misread as next message
```

Same nest; different leftover byte.

---

## What JavaScript does

```js
// ui/messageList.js — MessageHeader
const sourceIconEffect = new Clutter.DesaturateEffect();
const sourceIcon = new St.Icon({ … });
sourceIcon.add_effect(sourceIconEffect);
```

Empty ctor. Stock Clutter defaults `factor` to `1.0`. No explicit
`effect.factor = …` in this path — the nested `set_factor` is entirely from
**stub construct / wire decode**, not from a later JS assignment.

Surrounding chrome (same millisecond, ids just before):

```text
St-Button.new → set_style_class_name → set_accessible_role → set_can_focus
→ set_x_expand / set_y_expand
→ St-BoxLayout.new → set_orientation → set_x_expand → St-Bin.set_child
→ St-BoxLayout.new → set_style_class_name → set_x_expand
→ Clutter-DesaturateEffect.new   ← boom
```

---

## Intended stub contract (local create)

`DesaturateEffect.override.vala` documents this order for
`new DesaturateEffect({ name, … })`:

| Step | What runs | `rpc_lid` | Allowed RPC? |
|------|-----------|-----------|--------------|
| 1 | GObject applies `set construct` props (`name`, `enabled`, `factor`) | `0` | **No** — store only |
| 2 | `construct { }` mints `Clutter-DesaturateEffect.new(factor)` | still `0` → then set | **Yes** — one `.new` |
| 3 | After mint: push `ActorMeta.set_name` / `set_enabled` if needed | non-zero | **Yes** — after reply fully done |

`factor` setter today:

```vala
set construct {
    this.priv_factor = value;
    if (this.rpc_lid != 0) {
        GnomeShellRpc.call_value(
            "Clutter-DesaturateEffect.set_factor", this,
            OLLMrpc.args("d", this.priv_factor));
    }
}
```

Local prop apply (step 1) is fine (`rpc_lid == 0`). The bug is a **third**
path: wire materialisation of the **return value** of `.new`.

---

## RPC sequence (what actually happens)

```text
GJS:  new Clutter.DesaturateEffect()
        │
        ▼
Client stub construct (rpc_lid == 0)
  call_poll #4383  Clutter-DesaturateEffect.new (d=1.0)
        │
        ▼
Server  recv #4383
  clutter_desaturate_effect_new(factor)
  encode Result: live handle (uint64) + TOKEN_END  (+ Result framing)
        │
        ▼
Client  mid call_poll #4383 — decoding retval
  bin.parse → … → parse_object (live)
    read handle
    read TOKEN_END                    ← OPC fix: consumed BEFORE Object.new
    Object.new(DesaturateEffect, "rpc-lid", handle)
      │
      ├─ set construct rpc_lid = handle     (now != 0)
      ├─ set construct factor = default 1.0
      │     └─ rpc_lid != 0 → call_poll #4384  Clutter-DesaturateEffect.set_factor
      │           │
      │           ▼
      │     Nested root bin.parse() on SAME DataInputStream
      │     Outer Result message still unfinished (trailer / next field)
      │     → reads leftover bytes as a new message
      │     → "expected object type byte, got 0x00"  (or 0xFF/0xFD pre-fix)
      │
      └─ never returns cleanly; #4383 never "replied"
```

Server **does** see both methods (order preserved). The failure is **client
parse reentrancy**, not a missing server implementation of `set_factor`.

```text
Time ──►

Client write:  [4383 .new][4384 set_factor]
Server recv:   [4383 .new][4384 set_factor]
Client parse:  ─── inside 4383 Result ──┬─ nested parse for 4384 ─► ERROR
                                        │
                     (outer message body still on the stream)
```

---

## Why OPC TOKEN_END fix is not enough

Upstream now does handle → `TOKEN_END` → **then** `Object.new` so the nest
cannot eat the live-object end token as the next message header
(`0xFF` `0xFD`). Comment in `libocrpc/Bin/Stream.vala` even says construct
setters *may* nest after that.

That only closes one byte of framing. Nested `call_poll` still starts a
**new root parse** while the outer Result (or call_poll bookkeeping) is on
the stack. Leftover framing after the object body still desyncs — today’s
`got 0x00` prove is with the TOKEN_END reorder already in the linked
`libocrpc.so`.

Consumer must not nest here. Library hardening does not replace that rule.

---

## Working precedents in this tree

| Stub | Construct props | When RPC? |
|------|-----------------|-----------|
| `Constraint.override` | `name` / `enabled` | **Store only** in setters; `sync_actor_meta_*` **after** mint in `construct` |
| `BrightnessContrastEffect.override` | `name` / `enabled` | Same — comment: setters must not RPC; wire decode uses `Object.new(..., "rpc-lid")` |
| `DesaturateEffect.override` | `factor` | **RPCs when `rpc_lid != 0`** ← breaks wire decode of `.new` retval |

AlignConstraint `set_factor` from JS ease paths is a **separate**, post-lease
call and is fine once the proxy already exists.

---

## Fix directions (consumer)

### Landed: `mint_done` gate (2026-09-10)

Prove: three `Clutter-DesaturateEffect.new` → each `replied` with **no**
interleaved `set_factor`; boot reached `Meta-Context.notify_ready`.
No `expected object type byte` / `0xFD` on this path.

`factor` setter stores always; RPCs `set_factor` **only if `mint_done`**.

- Local / wire construct-prop apply runs **before** `construct { }` →
  `mint_done` still false → no nest on reply `Object.new(..., "rpc-lid")`.
- Local mint: `.new(d, priv_factor)` already sets server factor; then
  name/enabled; then `mint_done = true`.
- Wire early-return: `mint_done = true` so later JS assigns still sync.
- Do **not** gate on `rpc_lid != 0` alone (that was the bug).

### Optional / larger (not needed here)

- Pure store-only + never post-construct `factor` RPC (messageList never assigns).
- Defer lease mint / wire batch — OPC-level.

🚫 Teach OPC nested `call_sync` / mid-parse `call_poll` as the product fix.

---

## Acceptance

1. Nested Wayland past `MessageHeader` / `new Clutter.DesaturateEffect()` with
   **zero** `expected object type byte` / `unexpected byte 0xFD`.
2. Wire shows `Clutter-DesaturateEffect.new` → `replied`, then later
   (only if needed) a **non-nested** `set_factor` — never `set_factor` between
   `.new` send and `.new` replied.
3. `BrightnessContrastEffect` / Constraint name+enabled remain store-then-sync
   (no regression to RPC-from-setter).

Reproduce:

```bash
timeout 30 dbus-run-session ./build/src/mutter-rpc --debug --wayland --nested \
  > /tmp/mutter-rpc-desaturate.log 2>&1
# or inspect ~/.cache/gnome-shell-rpc/*.debug.log for DesaturateEffect.new
```

---

## Refs

- Stub: `src/gi-stub/overrides-clutter/DesaturateEffect.override.vala`
- Deny / hand lease: `src/gi-stub-gen/Clutter.deny` (`DesaturateEffect.new` / `factor` / `set_factor`)
- Peer pattern: `BrightnessContrastEffect.override.vala`, `Constraint.override.vala`
- JS: `src/shell-js/ui/messageList.js` (`MessageHeader`)
- OPC: `libocrpc/Bin/Stream.vala` `parse_object` live path; done bug
  `2026-09-10-FIXED-live-parse-object-new-before-token-end.md`
