# Nest dies after READY (session/hold)

**Status:** ⏳ fix in flight — GJS `LayoutManager.layout_changed`  
**Hit:** 2026-09-14 session hold ~13:34  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Logs:** `~/.cache/gnome-shell-rpc/{mutter-rpc,org.gnome.ShellRpc,nested-weston-prove.tee}.log`

**Roles:** **consumer** Gi stub · prove settle is separate (10s now)

---

## Was (13:34 session)

`nested-weston-hold` (no settle SIGKILL). `READY=1` @ 28.319 → socket closed @ 35.521 (~7s).

| Signal | Detail |
| ------ | ------ |
| `Clutter-LayoutManager.layout_changed: no rpc_lid` on `WorkspaceLayout` / `ControlsManagerLayout` | uncaught `call_value` → CRITICAL (line Clutter_generated 10341) |
| mutter `CLUTTER_IS_LAYOUT_MANAGER` / cogl viewport 0×0 | GJS manager never cleared stock manager on server |
| First `set_theme` | ok `customs=0` — not the killer this run |
| Pending at death | `Meta-Compositor.get_laters` (mutter stopped mid-flight) |

Same gap as archived `child_set_property` / GJS LayoutManager: `set_container` was local-safe; **`layout_changed` was not**.

---

## Landed

| Piece | State |
| ----- | ----- |
| Deny `LayoutManager.layout_changed` RPC method (keep GIR **signal**) | ✔️ PERMANENT |
| GJS `Actor.layout_manager` set → clear compositor manager | ✔️ |
| Prove settle 10s / `GSR_NESTED_STAYUP` | ✔️ scripts |
| Re-prove session stay-up | ⏳ |

ℹ️ Same deny block as `set_container` / `child_set_property` — shell JS
LayoutManagers are client-owned by design, **not** a TEMPORARY mock. The
signal stays for local emit; only the generated RPC method was wrong.

---

## Prove

```bash
./scripts/weston-gsr-session.sh
# expect: no layout_changed no rpc_lid CRITICAL flood; nest stays past READY
# tee: nested-weston-hold: mutter exited … only when you close Weston
```
