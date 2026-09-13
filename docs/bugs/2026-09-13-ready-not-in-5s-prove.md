# Boot never reaches READY in the 5s prove

> # ⚠️⚠️⚠️ AGENTS — READ THIS FIRST ⚠️⚠️⚠️
>
> ## DO NOT STOP for “status theatre”
>
> **Keep working.** Do not pause to narrate progress, summarize what you tried,
> or ask whether to continue after every prove / dead end / rebuild. Carry on
> until the bar moves or you hit one of the stop conditions below.
>
> ## When you MAY stop
>
> 1. **You actually need the user’s help** — a decision only they can make,
>    credentials, a machine/session you cannot reach, or explicit approval the
>    plan forbids you from assuming. Say what you need in one short ask, then
>    wait.
> 2. **OPC / libocrpc is the problem** — and only then: write a **FAIL-backed**
>    bug (gate under `tests/call-sync-repro/` that **FAIL**s, plus the bug doc),
>    **do not edit OLLMchat from this tree**, and **stop**. That is the **only**
>    OPC-related stop. PASS gates → chase the **consumer**; do not stop to
>    “report” a theory.
>
> ## Everything else
>
> File/update the tracking bug, pick the next allowed step, rebuild, prove,
> repeat. No Idle/defer/helper thrash. No layout.js ship hacks.

**Status:** 🔍 open  
**Hit:** 2026-09-13 nested Weston (`weston-gsr-prove.sh`)  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md) A2–A4  
**Logs:** `~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc}.debug.log`  
**Prove:** `./scripts/weston-gsr-prove.sh` (**15s** / settle **5s** after READY)

**Roles:** **server** = `mutter-rpc` · **client** = `gnome-shell-rpc`

**🚫** No OLLMchat / libocrpc edits. **🚫** No OPC without FAIL gate.  
**🚫** No Idle / emit-defer / `run_emit`. **🚫** No layout.js `PRIORITY_*` ship path.  
**🚫** No `suppress_emit` / measure-depth / emit_guard.

---

## Verdict

**A2:** ✔️ — `READY=1` + `notify_ready` (~+5.2s with debug). Early **5s**
hard kill was only the timer. Prove window extended (**15s** / **5s** settle).

**Post-READY:** **not an RPC hang.** `ENTER`/`REPLY done` balanced (0 open).
Client dies with **SIGSEGV (139)** within ~ms of READY (after
`notify_ready` + one nested `base_preferred_height` reply). Mutter often then
exits **133 (SIGTRAP)**. Longer settle does not help until the crash is fixed.

**A4:** ❌ blocked by that crash — not by prove timeout / idle priority.

**🚫** Do not chase layout `PRIORITY_*` / idle-callback retuning.

---

## Hang check (2026-09-13)

| Check | Result |
| ----- | ------ |
| Open `DBG invoke ENTER` without `REPLY done` | **0** |
| Post-READY RPC progress | brief (`notify_ready`, preferred reply) then stop |
| `gnome-shell-rpc` exit | **139 / SIGSEGV** (wrapper) |
| gdb | SEGV in `libffi` ← `libgio` (`g_dbus_address_get_for_bus_sync` @ gio+0x110def) ← main loop |
| Just before READY in log | `GSocketClient` connect_async (session / extensions path in `main.js` after READY idle is scheduled) |

Stock `main.js` schedules READY idle, then continues into
`ExtensionDownloader.init()` / `ExtensionManager.init()` — D-Bus traffic fits.

---

## When READY is supposed to happen (stock)

In `vendor/gnome-shell/js/ui/main.js`, after `_initializeUI()`, shell schedules:

1. `Shell.util_sd_notify()` → `READY=1`  
2. `global.context.notify_ready()`

A4 (`Meta.is_restart` / layout `startup-complete`) is later — unreachable while
client segfaults.

---

## Not this

| | |
| - | - |
| Preferred ask/reply mismatch | no — matched |
| Close-ask-then-measure hang | fixed; archived |
| Prove timer alone (A2) | fixed — extend window |
| Post-READY RPC hang | **no** — crash |
| layout.js `PRIORITY_*` / idle retune | rejected |
| Wait 40s | rejected — crash is immediate |

---

## Next

1. Chase **SIGSEGV** after READY (ffi/gio/dbus — extension / session bus path).  
2. Re-prove A4 only after client stays up past READY.
