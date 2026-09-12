# Guide to writing plans

Written for **AI agents**. Human contributors may treat this as a helpful guide.

Plan files live in **`docs/plans/`**. Completed work is archived under **`docs/plans/done/`**.

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
>
> **🔷** Paste this exact banner at the top of every **active** plan and every
> **open** bug (after the title). Cursor rule: `.cursor/rules/no-status-theatre.mdc`.

## Agent rule: product goal follows the active plan

**🔷 CRITICAL.** The **only active plan** is [`0.8-init-complete-and-interaction.md`](plans/0.8-init-complete-and-interaction.md): prove **init finished**, then **pointer/keyboard interaction** in nested Wayland. Index: [`plans/README.md`](plans/README.md).

- Boot-through-`init.js` is **✔️** archived under [`done/0.7.7-thin-shell-bootstrap.md`](plans/done/0.7.7-thin-shell-bootstrap.md). Plans **0.1–0.7** live in [`plans/done/`](plans/done/) — reference only.
- Treat stub completeness, header %, and full API parity as **means** — only pursue them when they unblock the **current** plan phase.
- Put the **user goal** from the active plan at the **top of every new plan** (after the title). Do not bury it.
- Prefer fix-forward on the nested path over speculative completeness.

## Checklist

- Concrete **Remove** / **Replace with** / **Add** fences live in the **same section** that discusses that work.
- **No orphan code** in Purpose or notes sections.
- After implementing, mark work **✔️** — **not** **✅**. Only the user promotes items to **✅**.
- If blocked on something only the user can decide: revert speculative code,
  update the plan, **stop and ask** (see banner). Otherwise update the plan/bug
  and keep working — do not stop for status theatre.

## Discussion style (emoji prefixes)

Prefix discussion bullets so readers can scan intent. First token on the line is the emoji.

| Marker | Meaning |
| ------ | ------- |
| **✅** | User confirmed done |
| **✔️** | Agent implemented — not user-approved yet |
| **⏳** | Not implemented (backlog) |
| **🔷** | User-specified requirement |
| **💩** | LLM suggestion the user did not ask for — confirm before building |
| **ℹ️** | Pointer / fact / existing behaviour |
| **🚫** | Out of scope or do not implement |

Pair **⏳** with **🔷** or **💩** on every open work item.

## Agent rule: do not change the user’s session

**🚫 CRITICAL.** Do not mutate the live desktop without an explicit ask in the current message.

- **🚫** `meson install` / writing under `/usr`
- **🚫** killing host `gnome-shell`, `gjs`, or the user’s Wayland/X11 session
- **🚫** `kill -9` against host processes
- **🚫** replacing `/run/user/*/wayland-0`

**Allowed without asking:** repo edits, meson **build** in this tree, nested `mutter --wayland --devkit --mutter-plugin /abs/path/to/our.so` inside `dbus-run-session`.

When a session or install step is needed: print the command, explain why, wait.

## OLLMchat `libocrpc` plan names

New work there is **`{PREFIX}-1.n-slug.md`** (example: `RPC-1.1-rpc-register.md`). Old **`RPC-8.x`** filenames stay. Category index: `docs/plans/RPC-1.0-summary.md`. See `OLLMchat/docs/plans/-README.md`.
