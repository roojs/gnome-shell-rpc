# mutter-rpc dies after READY (session/hold — not prove settle)

**Status:** ⏳ open — stay-up  
**Hit:** 2026-09-14 nested Weston  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Logs:** `~/.cache/gnome-shell-rpc/{mutter-rpc,org.gnome.ShellRpc}.debug.log`  
**Related:** [`2026-09-14-ffi-as-string-array-empty.md`](2026-09-14-ffi-as-string-array-empty.md)

**Roles:** **consumer** — compositor exit under **hold** / session

---

## Prove settle vs real death

`weston-gsr-prove.sh` early-stops with **SIGKILL** on:

- `Meta.is_restart` (A4), or  
- `READY=1` + settle (now **10s**, was 5s)

That looks identical to a crash (`socket closed`, random pending RPC).  
**Session** (`./scripts/weston-gsr-session.sh` → `nested-weston-hold.sh`) does **not**
do that — if mutter exits there, it exited for real (`nested-weston-hold: mutter exited ec=…`).

Stay-up timed path:

```bash
GSR_NESTED_STAYUP=1 ./scripts/weston-gsr-prove.sh   # no READY/A4 kill
# or look:
./scripts/weston-gsr-session.sh
```

---

## Was (candidates)

### A — second `Helper-ThemeContext.set_theme` (13:13)

First `set_theme` `customs=0` **ok**. Second recv, no `ok`, socket closed (~8s after READY).  
May still be real under hold; re-check with session + `enter customs=` debug.

### B — prove settle / A4 kill (13:28)

`READY=1` → socket closed **~4.8s** later (old 5s settle). Pending `St-Icon.new` —
harness kill, not St-Icon.

### C — layout noise (both)

`CLUTTER_IS_LAYOUT_MANAGER` / cogl viewport 0×0 on mutter; JS
`LayoutManager.layout_changed: no rpc_lid` on client. Not proven fatal alone.

---

## Want

1. Settle default **10s**; nest timeout **25s** (landed in prove scripts).  
2. Re-prove **session/hold** (or `GSR_NESTED_STAYUP=1`) and capture:
   - `nested-weston-hold: mutter exited ec=N`
   - last mutter line + any `set_theme enter customs=N`
3. Fix the real exit cause (likely theme apply / layout), not prove SIGKILL.
