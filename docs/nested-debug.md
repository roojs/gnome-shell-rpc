# Nested debug — do not chase your own kill

Agents: read this **before** gdb, `catchsegv`, or treating a nest death as a
shell crash. Update this file when a new self-kill shows up.

Weston layout: [`weston-nested-test-env.md`](weston-nested-test-env.md).  
Build: [`build.md`](build.md).

---

## 1. Classify the stop **first**

Look at **`~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`** (end of
file) for the prove-script line, **not** the last RPC in the client log.

| Log line | What happened | Crash? |
| -------- | ------------- | ------ |
| `nested-weston-prove: stop (prepare-started)` | Script saw `Meta.is_restart` (A4) and **SIGKILL**’d the tree | **No** |
| `nested-weston-prove: stop (READY=1+settle)` | Script waited `GSR_NESTED_SETTLE` after `READY=1`, then **SIGKILL** | **No** |
| `nested-weston-prove: stop (smoke-ok)` | Named smoke printed `…: ok` / `…: done` | **No** |
| `nested-weston-prove: stop (timeout)` | Hit `GSR_NESTED_TIMEOUT` — nest was still running | **No** (bar may still be wrong) |
| `nested-weston-prove: mutter exited ec=N` | Mutter actually exited. **Then** decode `N` | Maybe |
| `nested-weston-hold: mutter exited ec=N` | Session/hold — **no** settle SIGKILL | Maybe |

`./scripts/weston-gsr-prove.sh` **always** early-stops on A4 unless you set
`GSR_NESTED_STAYUP=1` or `GSR_NESTED_NO_A4=1`. The script even says: early
stop SIGKILLs mutter; the client log then looks like a crash (socket closed,
pending RPC).

**Stay-up look** (did the nest die on its own?):

```bash
./scripts/weston-gsr-session.sh
# or timed, no A4/READY SIGKILL:
GSR_NESTED_STAYUP=1 ./scripts/weston-gsr-prove.sh
```

Do not gdb a default prove run that printed `prepare-started`.

---

## 2. Exit 133 / “Unexpected early end-of-stream” is often the **second** death

`src/rpc/Connection.vala` `drain_readable`: a parse error (including peer
close) is **`GLib.error()`** → **SIGTRAP** → mutter **`ec=133`** (`128+5`).

Sequence that fools people:

1. `gnome-shell-rpc` exits or is SIGKILL’d.
2. Mutter reads EOS → logs `Unexpected early end-of-stream` → **aborts**.
3. You debug mutter 133 / SIGTRAP and miss who closed the socket.

**Client gone first** = last useful fact is the **client** log / client
coredump / hold `mutter exited` **after** a client line that is *not* a
prove `stop (…)` kill. Mutter 133 is the aftermath.

`GLib.error` on EOS is still a compositor footgun (shell restart should not
kill mutter) — do not treat fixing that abort as the chrome/layout bug.

---

## 3. gdb rules (we have already eaten these)

Needs `-Drpc_gdb_spawn=true` (meson) so mutter can wrap **`gnome-shell-rpc`**
via `GI_META_GDB`. `scripts/weston-gsr-session.sh` quotes `GI_META_GDB_EX`
with `printf %q` — unquoted `catch signal SIGTRAP;…` used to source as
`signal: command not found` and never wrap.

**Never** `catch signal SIGTRAP` (not in `GI_META_GDB_EX`, not in
`GdbSpawnWrap`). GLib `g_error()` is SIGTRAP; so is the dynamic linker at
`dl_main`. Catching it kills the client at **startup** and you “debug” ld.so
or `Shell.Global.get: host must call bind_display first`.

**gdb delays spawn.** `gnome-shell-rpc` under `GI_META_GDB=batch` can run JS
before the host calls `bind_display`. That `GLib.error` is **not** the
post-READY failure. If the unwrapped nest reached `READY=1` and gdb dies at
`Global.get`, you caused it.

`GdbSpawnWrap` batch already catches **SIGABRT** and **SIGSEGV** only. Leave
SIGTRAP to gdb’s default once the process is past libc init — and only after
step 1 says it is a real death.

**`kernel.yama.ptrace_scope=1`:** `gdb -p` after READY is denied (`ptrace:
Inappropriate ioctl`). Only a **parent** wrap (`GI_META_GDB` from mutter
spawn) can ptrace — and that wrap is what hits `bind_display` (above).
This host has no `coredumpctl` until `systemd-coredump` is installed.

---

## 3b. Packages that actually help

gdb is already here. The missing piece for a **post-READY** client death is a
core, not another spawn wrap.

```bash
sudo apt install systemd-coredump
# optional: SIGSEGV dump without gdb wrap
sudo apt install glibc-tools   # catchsegv
```

Then stay-up; after `mutter exited ec=133`:

```bash
coredumpctl list gnome-shell-rpc
coredumpctl debug gnome-shell-rpc   # last dump
```

**Not a package:** Linux **Yama** (`kernel.yama.ptrace_scope`). Ubuntu defaults
to `1`: a process may only be ptraced by its parent, so `gdb -p` after READY
fails. That is not Microsoft Yammer.

```bash
# this session
sudo sysctl kernel.yama.ptrace_scope=0
# persist
echo 'kernel.yama.ptrace_scope = 0' | sudo tee /etc/sysctl.d/10-ptrace.conf
```

`0` = any same-uid process can attach (normal for local debug). Prefer
coredumps (`systemd-coredump`) if you do not want this session-wide.

**GJS symbols:** Ubuntu 25.04 (plucky) has **no** `ddebs.ubuntu.com` suite
(404). Do not add that repo — `apt update` will fail. Remove it:

```bash
sudo rm -f /etc/apt/sources.list.d/ddebs.sources
```

Use debuginfod instead of a `-dbgsym` package:

```bash
export DEBUGINFOD_URLS=https://debuginfod.ubuntu.com
# ~/.gdbinit
set debuginfod enabled on
```

gdb `-batch` answers **N** to the prompt unless that is set. Or install the
`.ddeb` from Launchpad (`libgjs0g-dbgsym` 1.82.1-1) — it is not in apt.

Do not wrap gdb until:

- the stop line is `mutter exited` / hold exit (not `stop (prepare-started)`),
- and you are not just confirming mutter’s EOS `GLib.error`.

---

## 4. Logs (what they are)

| File | Use |
| ---- | --- |
| `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log` | **Stop reason.** Appends forever — read the **tail**. |
| `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` | Client RPC. Truncated at each prove/hold start. Last `method=` is often **in flight** when SIGKILL hits — not the fault. |
| `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log` | Server recv. `Unexpected early end-of-stream` → see §2. |
| `nested-weston-prove.tee.log` | Mutter stdout copy; prove truncates it. |

`READY=1` + `method=Meta.is_restart` on a **default prove** usually means A4
**succeeded** and the script killed the nest ~0.3s later. That is progress,
not a SEGV.

---

## 5. What to run for which question

| Question | Command |
| -------- | ------- |
| Did init reach prepare? | Default `./scripts/weston-gsr-prove.sh` — look for `stop (prepare-started)` |
| Does the nest **stay up**? | `./scripts/weston-gsr-session.sh` or `GSR_NESTED_STAYUP=1 ./scripts/weston-gsr-prove.sh` |
| Named RPC/layout gate | `GI_META_SMOKE=… ./scripts/weston-gsr-prove.sh` (smoke-ok early-stop is success) |
| Client SIGSEGV/ABRT stack | Confirm §1, then `GI_META_GDB=batch` **without** SIGTRAP catch. Log gdb via `GI_META_GDB_EX` (`set logging file …`; session.sh quotes it) |

---

## 6. Hits we already paid for (do not repeat)

- 2026-09-16: default prove `prepare-started` + client log ending on
  `St-Adjustment.get_value` treated as a crash. It was A4 SIGKILL and/or
  mutter EOS `GLib.error` after the client left.
- 2026-09-16: `catch signal SIGTRAP` → gdb stack in `dl_main` / `rtld.c`.
- 2026-09-16: `GI_META_GDB=batch` → `Global.get` `bind_display` `GLib.error`
  because gdb slowed spawn. Unwrapped nest had already reached READY.
- `GI_META_GDB_EX` with spaces/`;` unquoted in `gsr-weston-autolaunch.env`
  → `signal: command not found` (fixed: `printf %q` in
  `weston-gsr-session.sh`).
- 2026-09-16: `gdb -p` after READY with `ptrace_scope=1` — attach denied.
- Stay-up **real** death: client **SIGSEGV** in `libgjs.so.0` with
  `clutter_actor_allocate` (`Clutter_generated.vala` / Actor.allocate) on
  the stack. `gdb -p` after READY works when `ptrace_scope=0`. If gdb
  handles the SEGV, `coredumpctl` may list `COREFILE none`.
