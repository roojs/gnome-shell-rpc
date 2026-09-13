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

**A2:** ✔️ on **8s** prove — `READY=1` + `notify_ready` (debug-slow boot;
5s was only the timer).

**A4:** still ❌ — no `Meta.is_restart` / `startup-complete` in the settle
window after READY.

---

## When READY is supposed to happen (stock)

In `vendor/gnome-shell/js/ui/main.js`, after a long `_initializeUI()`
(layout, overview, panel, message tray, …), shell schedules an idle that
calls:

1. `Shell.util_sd_notify()` → our log line `READY=1`  
2. `global.context.notify_ready()`

```318:322:vendor/gnome-shell/js/ui/main.js
    GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
        Shell.util_sd_notify();
        global.context.notify_ready();
        return GLib.SOURCE_REMOVE;
    });
```

That idle is **after** panel / message-tray / layout construction — not at
the start of boot.

A4 (`Meta.is_restart` / `startup-complete`) is even later (layout prepare),
and only after READY-side init has progressed.

---

## What the 5s prove actually shows (2026-09-13)

Fresh prove: stop reason **timeout** (ec=124). Client log ~**4.2s** then
disconnect.

| Marker | Count |
| ------ | ----: |
| `READY=1` | **0** |
| `notify_ready` | **0** |
| `Meta.is_restart` | **0** |
| Preferred ask / reply | **201 / 201** |
| `Helper-Actor.base_preferred_*` | **98** (timing fix; asks stay open) |
| `Helper-Actor.create` | **115** |
| `Clutter-Actor.add_child` | **556** |
| `St-BoxLayout.new` | **178** |

Last RPCs before kill (still building UI):

- `St-BoxLayout.new`, `St-Label.new`, `set_text`, `add_child`, …

Per-second work is mostly **mint widgets + style + add_child + callback
register**, with size-measure (`base_preferred`) mixed in the whole window
(~0.5s–4.0s) — not a hang at the end of preferred.

```
t+0..3s  heavy create / style / add_child / register
t+4s     still the same, fewer calls, then kill
         never READY / never notify_ready
```

One server CRITICAL seen: `cogl_framebuffer_set_viewport` width/height 0 —
noise relative to “never reached READY.”

---

## Plain picture

```
Stock:   build UI ──► idle: READY + notify_ready ──► later A4
Ours:    build UI via many RPCs (+ debug) ──► prove timer ──► stop
         (still in build if window too short; idle never ran)
```

So A2 is red when **`util_sd_notify` never runs**, not because READY was
lost on the wire. A4 is red because we never get past that.

Preferred hang is fixed. This bug is: **prove window vs debug-slow boot**.

---

## Not this

| | |
| - | - |
| Preferred ask/reply mismatch | no — matched |
| Close-ask-then-measure hang | fixed; archived |
| Missing `READY=1` after notify | never called yet |
| “Do not raise timeout” / paper over | wrong — debug is slow; **8s** ok |
| `suppress_emit` / measure-depth | rejected |

---

## Next

1. A2 done at 8s. Chase **A4**: why no `Meta.is_restart` in 1s settle after
   READY (layout prepare).  
2. Update this bug or split an A4 bug once the method is named.

**Done for A2:** `READY=1` on stock 8s prove. **A4** still open.
