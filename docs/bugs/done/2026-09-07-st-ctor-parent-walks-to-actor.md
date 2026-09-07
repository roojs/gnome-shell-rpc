# St-Widget / DrawingArea / Viewport `.new` parent-walks to Actor

**Status:** ✔️ fixed + Wayland prove 2026-09-07 (`/tmp/mutter-rpc-st-ctor.log`)  
**Hit:** 2026-09-07 — residual after L4 walk mint (`/tmp/mutter-rpc-l4-prove.log`)  
**Plan:** T-030 residual `ST_IS_WIDGET` in `0.7.7-thin-shell-bootstrap.md`

---

## Symptom

After `St-Widget.new` / `St-DrawingArea.new` / `St-Viewport.new` on the wire,
`St-Widget.set_style_class_name` / `add_style_class_name` / `set_can_focus`
assert `ST_IS_WIDGET`. `St-Button` / `St-Label` / `St-BoxLayout` (have real
`*_new`) mostly OK. `G_VALUE_HOLDS_FLAGS` on `set_offscreen_redirect` often
follows a bad `St-Widget.new`.

Stats from L4 prove (next style after `.new`): Widget **46 fail / 5 ok**;
DrawingArea **4/4 fail**; Viewport **1/1 fail**; Button **14/14 ok**.

---

## Cause

GIR: **Widget**, **DrawingArea**, **Viewport** have **no** constructor `new`
(and no `st_*_new` in libst). Client lease construct (LOCKED) still mints
`alias.new` because those types are in `Bin.gtype_to_alias`.

Server `OLLMrpc.Gi.dispatch`: `find_method("new")` walks **parents** →
`Clutter.Actor.new` → **`clutter_actor_new`**. Lease is a plain Actor.
Client stub is still Widget/DrawingArea → later `St-Widget.*` → assert.

Not the L4 base-steal bug (leaf `.new` is on the wire); the leaf wire name
is wrong at the **server** invoke.

---

## Why not a client override?

Actor (base) construct runs first, already sets `rpc_lid` from the bad mint.
Leaf construct sees `rpc_lid != 0` and skips (wire-decode contract). Override
cannot remint without breaking that contract. **Do not unlock
`emit_lease_construct`.**

---

## Fix

**Server Ffi** (before Gi): `Helper.St` registers
`St-Widget.new` / `St-DrawingArea.new` / `St-Viewport.new` and
`g_object_new` the glib type named by the wire prefix.

Upstream (optional): Gi should not parent-walk for `IS_CONSTRUCTOR` — file in
OLLMchat when convenient; local Helper is enough for boot.

---

## Prove

Nested Wayland ~8s (`/tmp/mutter-rpc-st-ctor.log`): **0** `ST_IS_WIDGET`;
DrawingArea/Viewport/Widget `.new` → style **ok**. FLAGS residual cleared
upstream — [gi-flags](2026-09-07-gi-flags-wire-uint.md).

---

## Refs

- Helper: `src/rpc/helper/St.vala`
- Locked emitter: `Generator.emit_lease_construct`
- Prior: `2026-09-06-lease-construct-base-steals-leaf.md` (L4)
