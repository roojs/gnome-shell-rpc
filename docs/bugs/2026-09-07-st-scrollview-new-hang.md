# St-ScrollView.new hangs (blocks startup-complete)

**Status:** ⏳ open — Mock fix ✔️; Wayland prove ⏳  
**Hit:** 2026-09-07  
**Plan:** T-030 **L5**

---

## Symptom

`St-ScrollView.new` looked like “server never replies”: client never logged
`replied`, then **120s** timeout. Boot never reaches `startup-complete`.

| Run | Log | Prove |
| --- | --- | --- |
| Wayland nested (pre-fix) | `/tmp/mutter-rpc-startup2.log` | `id=2304` hang → 120s timeout |
| Mock smoke (pre-fix) | `/tmp/gi-rpc-smoke-scroll3.log` | `id=1735` recv, no reply → timeout |
| Mock smoke (post-fix) | `/tmp/scroll-hang-fix.log` | `id=1735` `replied` in &lt;1ms; later ScrollViews OK |

---

## Cause

Mock **did** mint and reply. Hang was **client decode** of that reply.

`parse_object` → `Object.new(ScrollView, "rpc-lid", handle)`. Override marked
`hscrollbar_policy` / `vscrollbar_policy` as **`set construct`**; setters call
`set_policy` once `rpc_lid != 0`. GObject applied construct defaults during that
`Object.new` → **nested RPC inside reply parse** → connection deadlock.

GIR: those props are writable with defaults, **not** construct.

---

## Fix

`overrides-st/ScrollView.override.vala`: drop `construct` from both policy
setters (`set` only). Wire decode only sets `rpc-lid`; no nested `set_policy`.
GJS `new St.ScrollView({ hscrollbar_policy: … })` still applies props after
construct when the lease exists.

---

## Corridor

1. Live ✔️ (hang)  
2. Mock ✔️ (same deadlock shape)  
3. Fix override ✔️ → mock re-prove ✔️ (`/tmp/scroll-hang-fix.log`)  
4. Wayland ~5s ⏳  

---

## Refs

- `overrides-st/ScrollView.override.vala` — policy setters  
- Decode: `OLLMchat/libocrpc/Bin/Stream.vala` `parse_object` → `Object.new(..., "rpc-lid")`  
- Emit: `vendor/gnome-shell/js/ui/layout.js` `_startupAnimationComplete`
