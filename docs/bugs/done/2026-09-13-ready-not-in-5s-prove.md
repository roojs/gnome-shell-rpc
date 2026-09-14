# Boot never reaches READY in the 5s prove

**Status:** ✔️ FIXED / archived — A2 `READY=1` + A4 proxy (`Meta.is_restart`
/ prepare-started) green on nested prove. Post-boot stay-up is a **separate**
bug: [`../2026-09-14-waylandclient-spawnv-no-rpc-lid.md`](../2026-09-14-waylandclient-spawnv-no-rpc-lid.md).  
**Hit:** 2026-09-13 nested Weston (`weston-gsr-prove.sh`)  
**Plan:** [`0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md) A2–A4  
**Archived:** 2026-09-14  
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

**Post-READY (historical):** not an RPC hang. Early client **SIGSEGV** after
READY was fixed (`util_touch_file_async` GIR scope + layout child-meta).
`ENTER`/`REPLY done` balanced.

**A4:** ✔️ — `Meta.is_restart` / prepare-started. Stay-up after A4 → spawnv bug.

**🚫** Do not chase layout `PRIORITY_*` / idle-callback retuning.

---

## Hang / crash check (2026-09-13)

| Check | Result |
| ----- | ------ |
| Open `DBG invoke ENTER` without `REPLY done` | **0** |
| Who crashes | **client** `gnome-shell-rpc` (GJS host) |
| Who does session-bus resolve | **client** stock JS → Gio → `g_dbus_address_get_for_bus_sync` |
| Server role in that call | **none** (falls over when client dies) |
| gdb (`GI_META_GDB=batch`) | SEGV: `g_base_info_get_type` with **`rdi=0x2`** (invalid
`GIBaseInfo*`) ← `g_callable_info_load_return_type` ← gjs ← libffi;
outer `info symbol` names `g_dbus_address_get_for_bus_sync`. |
| Stock `gjs` alone | `Gio.dbus_address_get_for_bus_sync(SESSION)` + `Gio.DBus.session` **OK** |
| Nested bus setup | `dbus-run-session` private session bus + host
`/run/user/UID/bus` — **by design**; wrong-bus usually errors, not `rdi=0x2` |
| Just before READY | `GSocketClient` connect_async (session-bus connect in flight) |

Stock `main.js`: schedules READY idle, then continues into
`ExtensionDownloader.init()` / `ExtensionManager.init()`; earlier
`Gio.DBus.session.watch_name(...)` already touched the session bus.

---

## Online investigation (2026-09-13)

Searched for this stack / symptom. **No current known bug that matches.**

| Hit | Relevance |
| --- | --------- |
| [gjs 2009 Bug 586665](https://mail.gnome.org/archives/commits-list/2009-June/msg06045.html) — SEGV freeing callback type / `g_base_info_get_type` | Same *family* (invalid GIBaseInfo use in GJS), **ancient**, not dbus_address |
| [Launchpad #1714989](https://bugs.launchpad.net/bugs/1714989) gnome-shell SIGSEGV via ffi | Different top frame (`g_type_check_instance_cast` / St.Label) |
| GLib [!3846](https://gitlab.gnome.org/GNOME/glib/-/merge_requests/3846) stack-allocated `GIBaseInfo` | Related *class* of GI misuse; not this nest stack |
| `call_with_unix_fd_list_finish is not a function` | Seen on some proves (AccountsService / `environment.js` `_promisify`); **separate** JS TypeError, not proven as this SEGV |

**Conclusion:** treat as **our nest-specific** corruption / bad callable info while GJS marshals a stock Gio session-bus call — not “known upstream dbus-run-session bug.”

---

## When READY is supposed to happen (stock)

In `vendor/gnome-shell/js/ui/main.js`, after `_initializeUI()`, shell schedules:

1. `Shell.util_sd_notify()` → `READY=1`  
2. `global.context.notify_ready()`

A4 (`Meta.is_restart` / layout `startup-complete`) is later — was unreachable
while the client segfaulted; that crash is fixed and A4 is green.

---

## Not this

| | |
| - | - |
| Preferred ask/reply mismatch | no — matched |
| Close-ask-then-measure hang | fixed; archived |
| Prove timer alone (A2) | fixed — extend window |
| Post-READY RPC hang | **no** — client crash |
| layout.js `PRIORITY_*` / idle retune | rejected |
| Wait 40s | rejected — crash is immediate |
| “Two D-Buses” as direct SEGV cause | unlikely — isolation is intentional; symptom is bad `GIBaseInfo*` |
| Server doing the D-Bus call | **no** — client only |

---

## Progress (same day)

1. ✔️ Cover/Header CRITICAL — OPC proxy reuse + `register_handle`.
2. ✔️ Online search — no matching known bug.
3. ✔️ **Abort (not SEGV):** `GLib.error` on
   `Clutter-LayoutManager.child_set_property` with **no `rpc_lid`** on
   `Gjs_ui_quickSettings_QuickSettingsLayout` (~2s after READY when Quick
   Settings builds). Fixed: local child-meta path for GJS `LayoutManager`
   (`LayoutManager.override` / `LayoutMeta.override` + `Actor.layout_manager`
   calls `set_container`).
4. ✔️ After that fix, prove sometimes reaches **A4** (`Meta.is_restart`).
5. **Still open (was):** intermittent client **SIGSEGV** ~100ms after READY
   — **likely fixed:** `Shell.util_touch_file_async` GIR had
   `scope=notified`/`owned` callback vs stock `scope=async`; GTask→GJS
   callback then corrupted GI (`rdi=0x2` / `GLIBC_2.`). Now `scope=async`.
6. After touch_file fix: proves that reach READY hit **A4**
   (`Meta.is_restart` / prepare-started). Early nest flakes (READY=0) are
   separate from the post-READY SEGV.

### “Stopped at workspace managers” (visual)

`Meta-WorkspaceManager.*` calls in the client log all get `replied`. Last
post-READY RPC cluster is wallpaper (`Helper-BackgroundImageCache.load` /
`Meta-BackgroundImage.is_loaded`) plus a couple of
`get_workspace_by_index` / `get_work_area_for_monitor` from region update —
then silence or SEGV. Stock A4 is `_loadBackground` → idle →
`_prepareStartupAnimation` → `Meta.is_restart`. No hand override on
`WorkspaceManager`; generated stubs only. Do not treat “workspace” in the
log tail as a missing WorkspaceManager override. (If the on-screen freeze
is wallpaper + chrome without the grow-in animation, that is the
background → `_prepareStartupAnimation` gate / crash — layout also has
`_bgManagers`, easy to conflate with “workspace managers”.)

## Next (superseded)

Boot bar closed. Stay-up / Phase B continue under 0.8 +
[`../2026-09-14-waylandclient-spawnv-no-rpc-lid.md`](../2026-09-14-waylandclient-spawnv-no-rpc-lid.md).

## GDB (built-in)

Build already has `-Drpc_gdb_spawn=true`. Mutter wraps the client when set:

```bash
GI_META_GDB=batch ./scripts/weston-gsr-prove.sh
# or attach: GI_META_GDB=wait  →  gdb ./build/src/gnome-shell-rpc
#            (gdb) target extended-remote localhost:9234
```

Modes: `batch` (auto bt on SEGV/ABRT), `wait`/`server` (gdbserver :9234),
`1`/`interactive` (`gdb --args`).
