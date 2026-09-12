# Plans index

> # ⚠️⚠️⚠️ AGENTS — READ THIS FIRST ⚠️⚠️⚠️
>
> ## DO NOT STOP for “status theatre”
>
> **Keep working.** Do not pause to narrate progress, summarize what you tried,
> or ask whether to continue after every prove / dead end / rebuild. Carry on
> until the bar moves or you hit a real stop (need user help, or FAIL-backed
> OPC bug — then stop). Banner required on every **active** plan and **open**
> bug — see [`guide-to-writing-plans.md`](../guide-to-writing-plans.md) and
> `.cursor/rules/no-status-theatre.mdc`.

**Active work:** [`0.8-init-complete-and-interaction.md`](0.8-init-complete-and-interaction.md) only.

**Deferred (not active):** [`0.7.10-src-directory-layout.md`](0.7.10-src-directory-layout.md) — `src/` naming / tidy-up after **0.8**; inventory in [`src/README.md`](../../src/README.md).

Everything below **0.8** is **archived** under [`done/`](done/) — kept for history and grep, not a backlog to execute unless 0.8 points at a specific gap.

Conventions: [`guide-to-writing-plans.md`](../guide-to-writing-plans.md).

---

## Active

| Plan | Purpose |
| ---- | ------- |
| [**0.8**](0.8-init-complete-and-interaction.md) | Prove init finished (`startup-complete`, `notify_ready`, …), then pointer/keyboard interaction — **A1/A2/A5 ✔️**; GIR no-getter props ✔️; **A4 still ⏳** |

### Deferred

| Plan | Purpose |
| ---- | ------- |
| [**0.7.10**](0.7.10-src-directory-layout.md) | Audit and optionally rename `src/` folders (legacy vs product); **wait for 0.8** |
| [**0.9**](0.9-multi-shell-series.md) | Separate **named** `libmutter-rpc-NN` per shell release + **head** track — **after 0.8** on 48 |

---

## Archived chain (0.1 → 0.7) — relevance audit 2026-09-11

| Plan | Verdict | Why |
| ---- | ------- | --- |
| [0.1](done/0.1-decouple-gnome-shell-vala-rpc.md) | **Done / reference** | Vala mutter plugin + OLLMrpc — landed in `mutter-rpc` |
| [0.2](done/0.2-rpc-server-read-only-streaming.md) | **Done** | Hello, `list_windows`, notifications |
| [0.3](done/0.3-minimal-shell-top-bar.md) | **Done** | Fake-shell probe (pre–real GJS) |
| [0.4](done/0.4-server-spawns-shell-client.md) | **Done** | Spawn polarity in `Rpc.Server` / `Listen` — placeholder text was stale |
| [0.5](done/0.5-gnome-shell-js-layer.md) | **Done** | GI stub layer + gjs-embed smokes — product is `gnome-shell-rpc` |
| [0.5.1](done/0.5.1-runtime-helpers-and-positional-args.md) | **Done** | Window FFI + positional args |
| [0.5.2](done/0.5.2-close-gi-stub-gaps.md) | **Done** | Meta gaps → 0; generator + overrides |
| [0.5.3](done/0.5.3-partial-clutter.md) | **Done** | Clutter POC smokes; Helpers elsewhere |
| [0.5.4](done/0.5.4-generator-ollmrpc-args.md) | **Done** | `OLLMrpc.args` generator wiring |
| [0.5.5](done/0.5.5-remaining-meta-stub-gaps.md) | **Done** | Folded into 0.5.2 / 0.5.8 |
| [0.5.6](done/0.5.6-gi-callback-rpc.md) | **Done** | Live callbacks + Helper pattern |
| [0.5.7](done/0.5.7-gi-override-rpc.md) | **Done** | Overrides + Helper registration |
| [0.5.8 gaps](done/0.5.8-gir-gaps-after-compile.md) | **Done** | Compile-time GIR gaps closed |
| [0.5.8 throws](done/0.5.8-rpc-client-throws.md) | **Done** | Client throw behaviour |
| [0.6](done/0.6-libmutter-rpc.md) | **Done** | `libmutter-rpc-16` + typelib swap for GJS |
| [0.7](done/0.7-gnome-shell-rpc-client.md) | **Done** | Shell client process umbrella — superseded by 0.8 |
| [0.7.1](done/0.7.1-libshell-c-meta-gaps.md) | **Obsolete path** | libshell C bootstrap abandoned for 0.7.7 thin host |
| [0.7.2](done/0.7.2-libst-clutter-c-abi.md) | **Obsolete path** | Client libst — superseded by 0.7.6 server St |
| [0.7.3](done/0.7.3-init-js-boot-nested.md) | **Done** | `init.js` nested — folded into 0.7.7 |
| [0.7.4](done/0.7.4-clutter-header-generator.md) | **Done** | Generated headers for St/Shell compile |
| [0.7.5](done/0.7.5-clutter-actor-abi-size.md) | **Cancelled** | Client St sizing — explicitly superseded by 0.7.6 |
| [0.7.6](done/0.7.6-st-server-relay.md) | **Done** | St on server, client relay |
| [0.7.7](done/0.7.7-thin-shell-bootstrap.md) | **Done** | Thin host, no libshell C — nested boot |
| [0.7.8](done/0.7.8-gi-rpc-noop-server.md) | **Done** | Mock harness for fast replay |
| [0.7.9](done/0.7.9-init-complete-and-interaction.md) | **Renumbered** | Same intent as **0.8** (short-lived filename) |
| [0.7.10](0.7.10-src-directory-layout.md) | **Deferred** | `src/` layout README + rename audit — not in `done/` until executed |

---

## When to open an old plan

- **0.8 Phase A/B** hits an RPC error naming a symbol → grep `done/0.5*` / overrides / Helpers — fix forward, do not resurrect whole phases.
- **Architecture “why”** → read **0.1** + **0.7.6** only.
- **New feature track** (packaging, CI pin, host session) → new **0.9+** plan; do not un-archive 0.4 placeholders.
