# Gi FLAGS IN: wire uint → G_VALUE_HOLDS_FLAGS

**Status:** ✔️ fixed upstream + Wayland prove 2026-09-07 (`/tmp/mutter-rpc-flags-prove.log` — 0 asserts, 5 `set_offscreen_redirect`)  
**Hit:** 2026-09-07 — residual after Helper.St  
**Upstream:** [`OLLMchat/docs/bugs/done/2026-09-07-FIXED-gi-flags-wire-uint.md`](../../../../../gitlive/OLLMchat/docs/bugs/done/2026-09-07-FIXED-gi-flags-wire-uint.md)

---

## Symptom

`Clutter-Actor.set_offscreen_redirect` → `G_VALUE_HOLDS_FLAGS` (5 / nested boot).

---

## Cause

Client packs FLAGS as `"u"`. Server Gi `convert_interface` called `get_flags()`
only. Fixed in libocrpc (FLAGS accepts `get_uint()` like ENUM/`int`). No change
in this tree.
