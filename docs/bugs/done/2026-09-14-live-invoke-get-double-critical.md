# Live.Invoke `g_value_get_double` CRITICAL (not AlignConstraint)

**Status:** ✔️ FIXED — typo `"tiidu"` → `"tiddu"` in event Hook pack  
**Hit:** 2026-09-14 `12:11:31.402749` nested Weston  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Gate:** `tests/call-sync-repro/event-tiidu-gate.vala` — **PASS**  
**Logs:** `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`

**Roles:** **server** `LayoutHooks.measure_event` / `fire_button_press` pack

---

## Was

```
DBG invoke ENTER id=467 reply_id=846
CRITICAL g_value_get_double HOLDS_DOUBLE failed
DBG invoke REPLY start id=467 extra=1
```

`set_align_axis` was only in-flight; motion nested an **event** Live.Invoke.

Pack used `OLLMrpc.args("tiidu", …)` intending lease / type / x / y / button
(`t i d d u`). The string **`tiidu` is letter-wise `t i i d u`** — two ints,
one double. Arg[2] arrived as `gint`; client `get_double` CRITICAL.

Gate proved: `args("tiidu", …)` → types `guint64 gint gint gdouble guint`.

---

## Fix

`src/rpc/helper/ClutterActor.vala`: `"tiidu"` → `"tiddu"` in
`measure_event` and `fire_button_press`.

```bash
meson compile -C build event-tiidu-gate mutter-rpc gnome-shell-rpc
timeout 5 ./build/tests/call-sync-repro/event-tiidu-gate   # PASS
```
