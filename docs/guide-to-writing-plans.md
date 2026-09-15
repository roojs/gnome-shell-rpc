# Guide to writing plans

Written for **AI agents**. Human contributors may treat this as a helpful guide.

Plan files live in **`docs/plans/`**. Completed work is archived under **`docs/plans/done/`**.

> **ℹ️** The no-status-theatre banner lives on the **currently active plan
> only** — today [`plans/0.8-init-complete-and-interaction.md`](plans/0.8-init-complete-and-interaction.md).
> Do **not** paste it on other plans, bugs, or docs (user call 2026-09-13 —
> it was only relevant to the plan being run and had splattered everywhere).
> The behaviour rule itself is `.cursor/rules/no-status-theatre.mdc`.

## Agent rule: product goal follows the active plan

**🔷 CRITICAL.** The **only active plan** is [`0.8-init-complete-and-interaction.md`](plans/0.8-init-complete-and-interaction.md): prove **init finished**, then **pointer/keyboard interaction** in nested Wayland.

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
