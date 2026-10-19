# Debugging instructions for LLMs

Do not hack product code. The order is prove, debug, prove the fix off the product code, then propose. Apply the change only when it is trivial and that off-code prove already passed.

1. **Prove** the failure. Read the logs that already exist, then show the same failure on Weston. Leave `src/` as it was.
2. **Debug** on a reproduction: a `tests/call-sync-repro` gate or a `tests/gjs-embed` smoke. That program is what you change.
3. **Prove the fix off the product code.** Rerun the reproduction until it passes, and the pass still matches the failure proved in step 1. Primary `src/` stays unchanged through this step.
4. **Propose** the proven change in the bug file, as code fences (see stage 6).
5. **Apply** only a trivial change: copy that proven edit into `src/`, rebuild, and rerun the Weston command from step 1. A major change stays a proposal until review.

A guess in `src/` before the reproduction passes is a hack. Do not do it. A candidate fix lands in `src/` only in stage 6, and only when it is a minor change that already passed on the reproduction.

Written for the model. Mandatory when the user asks to fix a failure or says to start with the debugging rules. Follow this file in order. [`nested-debug.md`](nested-debug.md) is the log and stop-reason reference. This file is the procedure. The five steps above are the rule. The stages below are how to carry them out.

Keep working. Do not pause to narrate each prove, summarise a dead end, or ask whether to continue. That rule is [`.cursor/rules/no-status-theatre.mdc`](../.cursor/rules/no-status-theatre.mdc). Its text stays there.

---

## 1. Create the bug report

Create `docs/bugs/YYYY-MM-DD-slug.md` before any other step when this failure does not already have one. Update that file at the end of every step below. The file is the record. Chat is not.

The top is the current account. Rewrite it when the facts change. It holds what the bug is, the diagnosis that is still true, and where the reproduction is (the log path, the Weston command, or the gate or smoke and how to run it). A fact that is no longer true comes out of the top.

Suggestions, next tries, and the trial log stay out of the top. They go in `## LLM efforts` at the bottom. Append there as each run finishes: what was tried, the command, and what the log or the gate actually did. Do not rewrite that section into a summary.

## What you send

One line, and only when you stop. The bug file is the rest. Do not paste the log, the diagnosis, or the next step into chat.

The line names the bug file and why the review was requested. The same reason is the first lines of that file. A review is not "this is done". If the smoke or the gate has not passed, the reason says what is unproven and why you stopped.

- `Can you review docs/bugs/<file>.md — <why>`
- `Can you review the proposal in docs/bugs/<file>.md — <why>`

The second line is only for a stage 6 major change. The `alan2` copy request in stage 2 is the one ask that is not a review.

---

## 2. Read the logs that already exist

Do this before adding debug or starting a new prove. The failure may already be in a log from Weston, from a remote installed session, or from the `alan2` login.

| Where | What to read |
| ----- | ------------ |
| This machine, Weston | `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`, `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log`, and the tail of `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`. See [`nested-debug.md`](nested-debug.md). |
| Remote installed session | `alan@192.168.88.197` (host `alan-VirtualBox`), when that host answers from here. Same cache paths on that account, plus `journalctl -b` for the `gsr-client` pid. |
| `alan2` greeter login | This account cannot read `/home/alan2/.cache/gnome-shell-rpc/`. Ask for the copy below before anything else. |

One machine can reach the remote session and can run Weston. Another machine can only run Weston. If `alan@192.168.88.197` does not answer, Weston logs are the session this machine has.

When the failure is an `alan2` login, say so at the start and ask for this copy. Wait until the files are there.

```bash
sudo mkdir -p /tmp/gsr-crash-HHMM
sudo cp -a /home/alan2/.cache/gnome-shell-rpc/. /tmp/gsr-crash-HHMM/
sudo chown -R alan:alan /tmp/gsr-crash-HHMM
```

Replace `HHMM` with the time of that login. A crash also needs the cores, copied the same way and chowned to `alan`: `/var/lib/systemd/coredump/core.gsr-client.1002.*`, `/var/lib/systemd/coredump/core.gsr-server.1002.*`, and `/var/crash/_usr_bin_gsr-*.1002.crash` when one exists. Those files are mode 640 for uid 1002.

Stage 2 is done when those logs have been read, or the user has been asked for the `alan2` copy and it is in `/tmp`. Write the path and the line that names the failure into the top of the bug file, and append the read under `## LLM efforts`.

---

## 3. Reproduce on Weston

See the failure on the real nested path, under a scripted timeout, with a log line that names it.

Debug output is unconditional `GLib.debug()` at a real phase boundary (after a substantive call, before return). The runtime already logs file and line. Coding standards [`debug-warning-statements`](coding-standards.md#debug-and-warning-statements): no sampling, no `if (verbose)`, no counters, no extra fields whose only job is to gate a log.

Run one of these. Both are Weston in an X11 window ([`weston-nested-test-env.md`](weston-nested-test-env.md)).

```bash
# Agent prove: prove mode, auto-close, 25s nest, 40s wall
./scripts/weston-gsr-prove.sh

# Session, held only as long as the timeout
timeout --foreground -k 2 90 ./scripts/weston-gsr-session.sh --debug
```

Lengthen the nest with `GSR_NESTED_TIMEOUT`. `GSR_NESTED_STAYUP=1` on the prove script keeps the nest past the A4 / READY early stop, still inside the wall clock `timeout`.

To force the flow, edit the shell JavaScript the client actually loads, and in that same edit stop the process once the observation is done (`global.context.terminate()`, `loop.quit()`, or a log line the prove already treats as finished: `<name>: ok`, `<name>: done`, `<name>: miss`).

| Knob | What you edit |
| ---- | ------------- |
| `GI_RPC_JS_OVERRIDE_DIR` | Sparse tree of `.js` files mirroring `resource:///org/gnome/shell/…` (for example `ui/windowPreview.js`). The client compiles them over the bundled resource. No full JS rebuild. |
| `./scripts/prepare-js-override.sh` then `GNOME_SHELL_JS_DIR` | Full JS tree on disk (`js-override/`, gitignored). Boot `ui/init.js` from that tree. |

Those edits are the reproduction harness. They trigger the path and end the run. They are not the permanent change, and `vendor/gnome-shell/` is not the place to keep them.

Read the stop reason at the end of `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log` before treating a death as a crash. [`nested-debug.md`](nested-debug.md). `stop (prepare-started)`, `stop (READY=1+settle)`, `stop (smoke-ok)`, and `stop (timeout)` are the script ending the nest.

Stage 3 is done when that log shows the same failure. Write the command and the line into the top of the bug file, and append the run under `## LLM efforts`. Leave `src/` as it was.

---

## 4. Shrink it

A program small enough to run without booting the shell, that fails the same way.

| Kind | Where | Run |
| ---- | ----- | --- |
| Vala, when the failure is RPC, GI, or a Vala path | `tests/call-sync-repro/<gate>.vala` plus a `meson.build` entry. See [`tests/call-sync-repro/README.md`](../tests/call-sync-repro/README.md). | `meson compile -C build tests/call-sync-repro/<gate>` then `timeout 5 ./build/tests/call-sync-repro/<gate>` |
| JavaScript, when the failure is shell JS or needs a live display | `tests/gjs-embed/<name>.js`. Print `<name>: ok` or `<name>: miss <reason>`, then `global.context.terminate()` or `loop.quit()`. | `GI_META_SMOKE=<name> ./scripts/weston-gsr-prove.sh` |

The tiny program is what changes next. Product code stays as it was. Write where it lives and how to run it into the top of the bug file, and append the result under `## LLM efforts`.

---

## 5. Fix the reproduction

Try each idea on the reproduction: the gate, the smoke, or a copy of the failing function beside it. Rerun that program. Primary `src/` stays unchanged until one idea passes and the pass still matches the stage 3 failure. Append each idea under `## LLM efforts`. When one passes, the top of the bug file names that reproduction and that result.

---

## 6. Land

- **Minor change.** Copy that proven change into the primary code, rebuild, and rerun the stage 3 command. The stage 3 marker is the bar. The top of the bug file records that landing.
- **Major architectural change.** Write the proposal in the top of the bug file. Send `Can you review the proposal in docs/bugs/<file>.md`. Wait. Do not apply it.

  A proposal is proposed code, in the form in [`guide-to-writing-plans.md`](guide-to-writing-plans.md) under **Code proposals section**. Each edit is a numbered `###` with the file path, the function or region, **Why**, **Where**, and **Depends on**, then **`#### Remove`** / **`#### Replace with`** / **`#### Add`** fences. The fences are verbatim hunks. An implementer applies them. Say what the reproduction proved in the lines above the fences. Do not leave the change as a description of what the code should do.

---

## While you work

Rebuild and rerun. Each stage above updates the bug file before the next stage.

Shell JavaScript is `vendor/gnome-shell/js/`. That checkout is gitignored, so workspace search and `rg` from the repo root skip it and the file looks missing. Open that path directly (`vendor/gnome-shell/js/ui/windowPreview.js` and the rest of `js/ui/`). There is no second copy to hunt for. Upstream pin and fetch: [`../gnome-shell/README.md`](../gnome-shell/README.md).

A checkout or a downloaded package used to extract data goes under `/tmp`, the same place as the `alan2` copies. Never in the project root.

OPC / libocrpc has one stop, and it is the one in `.cursor/rules/no-status-theatre.mdc`: a FAIL gate under `tests/call-sync-repro/`, the bug doc, and no edit to OLLMchat from this tree. A PASS gate means the consumer is still the problem.
