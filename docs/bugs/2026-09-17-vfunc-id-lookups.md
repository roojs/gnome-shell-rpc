# Vfunc hot path still hashes the name string

**Status:** ⏳ open — performance follow-on to 0.8.2, not a stay-up crash.

**GitHub:** https://github.com/roojs/gnome-shell-rpc/issues/1

**Plan:** [`../plans/0.8.5-vfunc-id-lookups.md`](../plans/0.8.5-vfunc-id-lookups.md)

**Upstream contract:** OLLMchat `docs/plans/RPC-1.10-vfunc-id-lookups.md` — libocrpc already has the ints. Nothing to land there.

**User goal (0.8):** nested mutter-rpc + gnome-shell-rpc stays up and chrome responds. This bug is the leftover **string hash on every layout/event**, after 0.8.2 made hooks name-keyed.

---

## Problem

- **🔷** Phase C (Clutter already entered `allocate` / measure / event) still does `this.vfuncs.get("allocate")`.
- **🔷** Phase B (`add_hook`) still sends `"st"` — `vfunc_name` string + `hook_id`.
- **ℹ️** `hook_id` is already an int (`RPC-Live-Callback.register` → `Live.Invoke.id`). Emit does not need the name.
- **ℹ️** `Gi.vfunc_offset` is already an int (class-struct slot). Both processes can compute it from the typelib with no handshake.

Expected: register once with `vfunc_id` + `hook_id`. Fire looks up `vfunc_id`, then emit `hook_id`.

---

## Conclusions

- **🔷** libocrpc will not add another string map. Consumer owns `add_hook` and the peer map (RPC-1.8).
- **🔷** `vfunc_id` = offset. `hook_id` = trampoline row. Do not mix them.
- **ℹ️** `bind_vfunc` is **generated** (`Generator.emit_object_class_slots`, `relay=1`). Helper `$(rname)_id` + `register_vfunc_ids()` are **generated** (`--helper-out`, type `helper=1`). `relay_attach`, Helper `add_hook`, and fire stay **hand**. LayoutManager `ensure_helper_peer` is **hand** (uses generated `bind_vfunc`).
- **ℹ️** How to implement: the plan, including generator emit.

---

## Not this

- **🚫** OLLMchat / libocrpc edits from this tree.
- **🚫** New library `add_hook` / `VfuncPeer`.
- **🚫** Inventing GI methods on Clutter/St stubs.
- **🚫** Divert 0.8 chrome prove into this until that bar allows it.
