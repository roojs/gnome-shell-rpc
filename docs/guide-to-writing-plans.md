# Guide to writing plans

Written for **AI agents**. Human contributors may treat this as a helpful guide.

Plan files live in **`docs/plans/`**. Completed work is archived under **`docs/plans/done/`**.

> **ℹ️** “Do not stop for status theatre” is an agent rule
> (`.cursor/rules/no-status-theatre.mdc`). It does **not** go in plans.
> User call 2026-10-02: that text is not for general reading, and it does
> not belong in every plan. Do **not** paste it into plans, bugs, or other docs.

## Agent rule: product goal follows the active plan

**🔷 CRITICAL.** The **only active plan** is [`1.1-installable-bootable-session.md`](plans/1.1-installable-bootable-session.md): an installable **GNOME Shell RPC** session you can pick at the login screen.

- **0.8** is **✅** (user 2026-10-02) — [`done/0.8-init-complete-and-interaction.md`](plans/done/0.8-init-complete-and-interaction.md). **0.8.4** and **0.8.6** are **✅** in [`plans/done/`](plans/done/). **0.8.3** stays open and is not active.
- Next, not active: [`1.2-teardown-and-restart.md`](plans/1.2-teardown-and-restart.md).
- Boot-through-`init.js` is **✔️** archived under [`done/0.7.7-thin-shell-bootstrap.md`](plans/done/0.7.7-thin-shell-bootstrap.md). Plans **0.1–0.7** live in [`plans/done/`](plans/done/) — reference only.
- Treat stub completeness, header %, and full API parity as **means** — only pursue them when they unblock the **current** plan phase.
- Put the **user goal** from the active plan at the **top of every new plan** (after the title). Do not bury it.
- Prefer fix-forward on the nested path over speculative completeness. **1.1** greeter login is user-supervised — agents still do not `meson install` onto the live prefix or log in without an ask in that message.

## Checklist

- Concrete **Remove** / **Replace with** / **Add** fences live in the **same section** that discusses that work.
- **No orphan code** in Purpose or notes sections.
- After implementing, mark work **✔️** — **not** **✅**. Only the user promotes items to **✅**.
- If blocked on something only the user can decide: revert speculative code,
  update the plan, **stop and ask** (`.cursor/rules/no-status-theatre.mdc`).
  Otherwise update the plan/bug and keep working.

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
