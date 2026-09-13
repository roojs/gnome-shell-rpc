# Preferred size ask finished too early (hang)

**Status:** ✔️ FIXED — measure while the panel ask is still open  
**Hit:** 2026-09-12 nested Weston (`weston-gsr-prove.sh`)  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md) A4  
**Archived:** 2026-09-13

**Roles:** **server** = `mutter-rpc` · **client** = `gnome-shell-rpc`

---

## What was wrong

We copied in-process “try JS, else parent measure.” Over RPC, “ask
client” waited for an answer, so “else measure” ran **after** the client
closed the panel ask. Child size asks came too late → boot stuck.

---

## Fix

When the client has no local measure, it calls
`Helper-Actor.base_preferred_*` **before** answering the panel ask, then
returns real min/natural. Children are asked while that ask is still open.

Prove: ENTER/REPLY balanced; `base_preferred` runs; no close-then-measure
hang.

---

## Not closed by this bug

A4 (`Meta.is_restart` / `startup-complete`) still **red** on 5s stock
prove — READY often not reached (boot still building UI). Chase that on
the plan, not as this hang.

---

## Also landed while investigating

- `LiveCallback`: Callback.reply with error **code** → `reply_error`
  (normal throw path) for real failures — not used for preferred
  fallthrough anymore.
