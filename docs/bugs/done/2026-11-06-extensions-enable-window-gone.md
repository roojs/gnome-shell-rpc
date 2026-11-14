# Enabling extensions stops halfway and every window disappears

**Status:** ✔️ archived 2026-11-14. Closed 2026-11-07 — `WaylandClient.wait` / `WaylandClient.exited` wait lockup fixed.

`Gsr-Mutter-WaylandClient.wait` replies as soon as `GLib.Subprocess.wait_async` is armed. The process exit is `WaylandClient.exited`. `Meta.RpcSubprocess.wait_async` returns from that notification. `GLib.SignalHandler.disconnect` drops the client watch because `OLLMrpc.Client.disconnect()` takes no handler id. Local `libmutter-rpc-16.so` linked and `libmutter-16/WaylandClient.c` compiled. This host is mutter 16, so `gsr-server` for Shell 50.1 is not built here. The guest session is still the 13:22 binaries.

Seen on `alan@192.168.122.52` (`alan-VirtualBox`, GNOME Shell 50.1, mutter 18). Session started 13:23:33 HKT. `gsr-server` pid 45767, `gsr-client` pid 46065, binaries stamped 13:22. No new core. `gsettings get org.gnome.shell enabled-extensions` is `['ding@rastersoft.com']`. `ding.js` pid 47893 was still running. Extension Manager was not. `yelp` pid 48166 was.

Journal for this session:

```text
13:24:40 gsr-client: Launching DING process
13:25:07 JS ERROR: can't access property "index", window.get_workspace() is null
         activateWindow@ui/main.js:847
         … spawnv@ding@rastersoft.com/extension.js:547
13:26:27 JS ERROR: global.get_switcheroo_control is not a function
13:26:40 Client.vala:699: RPC failed Gsr-Mutter-WaylandClient.wait id=27672: call timed out
13:26:42 gsr-server: signal 'style-changed' is invalid for instance of type 'MetaWindowWayland'
13:26:50 value "inf" is invalid for property 'scale-x' / 'scale-y'
13:28:40 Client.vala:699: RPC failed Gsr-Mutter-WaylandClient.wait id=35805: call timed out
```

`Launching DING process` to the first `wait` timeout is 120s. `style-changed` was also emitted on `MetaSeatNative`, `MetaWorkspaceManager`, and `ClutterClickGesture` from startup. Debug logs in `~/.cache/gnome-shell-rpc/` on that account stop at 13:23:21, the previous session. This session was not started with `--debug`.

User: enabling extensions in Extension Manager stopped halfway down the list. The overview still showed Extension Manager as an active window, and the window was gone. Then every window disappeared.

Gate:

```bash
meson compile -C build tests/call-sync-repro/wayland-wait-blocks-gate
timeout 5 ./build/tests/call-sync-repro/wayland-wait-blocks-gate
timeout 5 ./build/tests/call-sync-repro/wayland-wait-blocks-gate yield
```

`wayland-wait-blocks-gate` exits 1: `call_poll` holds `Gate.wait` for the 1s timeout and the default main-context timeout does not run. `wayland-wait-blocks-gate yield` exits 0: `OLLMrpc.Client.call` lets that timeout run, the timeout `call_poll`s `Gate.release`, and `wait` completes. That yield still leaves the RPC outstanding until exit or the 120s timeout. The edits below are the proposal.

## Proposal

`Gsr-Mutter-WaylandClient.wait` replies as soon as the server has armed `GLib.Subprocess.wait_async`. When the process exits, the server writes `WaylandClient.exited`. `Meta.RpcSubprocess.wait_async` completes from that notification.

### 1. `src/server/libmutter-18/WaylandClient.vala` — `wait`

**Why:** The reply is no longer the exit. The exit is `WaylandClient.exited` on this lease.

**Where:** `Gsr.Server.Meta.WaylandClient.wait`, the whole method.

**Depends on:** none.

#### Remove

```vala
		public void wait(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			if (proc == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED("WaylandClient.wait: no subprocess")
				);
				return;
			}
			proc.wait_async.begin(null, (obj, res) => {
				try {
					proc.wait_async.end(res);
				} catch (GLib.Error e) {
					request.connection.reply_error(
						request, (int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e
					);
					return;
				}
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("b", true),
				});
			});
		}
```

#### Replace with

```vala
		public void wait(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			if (proc == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED("WaylandClient.wait: no subprocess")
				);
				return;
			}
			var connection = request.connection;
			int lease_id = (int) request.lease_id;
			if (!proc.get_if_exited()) {
				proc.wait_async.begin(null, (obj, res) => {
					try {
						proc.wait_async.end(res);
					} catch (GLib.Error e) {
						GLib.warning("WaylandClient.wait: %s", e.message);
					}
					connection.write(new OLLMrpc.Notification() {
						method = "WaylandClient.exited",
						id = lease_id,
					});
				});
			}
			if (proc.get_if_exited()) {
				connection.write(new OLLMrpc.Notification() {
					method = "WaylandClient.exited",
					id = lease_id,
				});
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", true),
			});
		}
```

### 2. `src/server/libmutter-16/WaylandClient.vala` — `wait`

**Why:** Same exit notification on the mutter 16 peer.

**Where:** `Gsr.Server.Meta.WaylandClient.wait`, the whole method. Same body as ### 1.

**Depends on:** none.

#### Remove

```vala
		public void wait(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			if (proc == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED("WaylandClient.wait: no subprocess")
				);
				return;
			}
			proc.wait_async.begin(null, (obj, res) => {
				try {
					proc.wait_async.end(res);
				} catch (GLib.Error e) {
					request.connection.reply_error(
						request, (int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e
					);
					return;
				}
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("b", true),
				});
			});
		}
```

#### Replace with

```vala
		public void wait(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			if (proc == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED("WaylandClient.wait: no subprocess")
				);
				return;
			}
			var connection = request.connection;
			int lease_id = (int) request.lease_id;
			if (!proc.get_if_exited()) {
				proc.wait_async.begin(null, (obj, res) => {
					try {
						proc.wait_async.end(res);
					} catch (GLib.Error e) {
						GLib.warning("WaylandClient.wait: %s", e.message);
					}
					connection.write(new OLLMrpc.Notification() {
						method = "WaylandClient.exited",
						id = lease_id,
					});
				});
			}
			if (proc.get_if_exited()) {
				connection.write(new OLLMrpc.Notification() {
					method = "WaylandClient.exited",
					id = lease_id,
				});
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", true),
			});
		}
```

### 3. `src/client/libmutter-rpc-16/RpcSubprocess.vala` — exit watch

**Why:** `wait_async` has to resume when `WaylandClient.exited` arrives, after `wait` has already returned.

**Where:** `Meta.RpcSubprocess`, immediately after `private GLib.InputStream? stdout_pipe = null;`.

**Depends on:** none.

#### Add — fields after `stdout_pipe`

`saw_exit` is set from the notification. `exited` resumes `wait_async` only when that method is already yielded.

```vala
		private bool saw_exit = false;
		public signal void exited();
```

### 4. `src/client/libmutter-rpc-16/RpcSubprocess.vala` — `wait_async`

**Why:** `Client.call` still holds `Gsr-Mutter-WaylandClient.wait` until the process exits and still hits the 120s timeout. `call_value` returns as soon as the server has armed the watch. The method then yields on `exited`.

**Where:** `Meta.RpcSubprocess.wait_async`, the whole method.

**Depends on:** ### 1, ### 2, ### 3.

#### Remove

```vala
		public async bool wait_async(
			GLib.Cancellable? cancellable = null
		) throws GLib.Error {
			/* call_poll would block the default main context until this
			 * process exits. DING waits on a process that stays up, so
			 * extension timeouts never ran and the call hit 120s.
			 * Client.call yields; force_exit stays on call_poll so it
			 * can still be written while this wait is outstanding. */
			var response = yield Gsr.Client.Rpc.client.call(new OLLMrpc.Request() {
				method = "Gsr-Mutter-WaylandClient.wait",
				lease_id = this.rpc_lid,
			});
			if (response.retval.type() == GLib.Type.INVALID) {
				return false;
			}
			return response.retval.get_boolean();
		}
```

#### Replace with

```vala
		public async bool wait_async(
			GLib.Cancellable? cancellable = null
		) throws GLib.Error {
			ulong watch = Gsr.Client.Rpc.client.notification.connect((notif) => {
				if (notif.method != "WaylandClient.exited") {
					return;
				}
				if ((uint64) notif.id != this.rpc_lid) {
					return;
				}
				this.saw_exit = true;
				this.exited();
			});
			Gsr.Client.Rpc.call_value("Gsr-Mutter-WaylandClient.wait", this);
			if (!this.saw_exit) {
				ulong resume = this.exited.connect(() => {
					wait_async.callback();
				});
				yield;
				this.disconnect(resume);
			}
			GLib.SignalHandler.disconnect(Gsr.Client.Rpc.client, watch);
			return true;
		}
```

## LLM efforts

- 2026-11-06 13:26 HKT. User: DING abort looks fixed; Extension Manager stopped enabling halfway; overview showed that app with no window. Then every window disappeared. `192.168.122.115` has no route. `alan@192.168.122.52` is `alan-VirtualBox`, Shell 50.1, this session. Client journal `_PID=46065` and server `_PID=45767` as quoted above. Installed client maps `libmutter-rpc-18.so`, `libshell-18.so`, `libmutter-clutter-rpc-18.so`, `libst-rpc-18.so`. Those `.so` files were compiled from `src/client/libmutter-rpc-16/` (and the clutter and st `-16` dirs); that is the `-16` meson file selecting `-18` sources, not a 16 typelib on a 50.1 session. `RpcSubprocess.wait_async` is a synchronous `call_value`. DING `extension.js` `spawnv` and `launchDesktop` each call `wait_async` on `ding.js`, which does not exit. `call_poll` does not iterate the default main context (`OLLMchat/libocrpc/Client.vala`, `call_timeout_seconds` default 120). Did not edit `src/`.
- 2026-11-06 13:33 HKT. Gate `wayland-wait-blocks-gate` exit 1: `FAIL wayland-wait-blocks-gate: default timeout did not run during call_poll (1000 ms)` and `call timed out Gate.wait id=2 after 1 s`. `wayland-wait-blocks-gate yield` exit 0: `PASS wayland-wait-blocks-gate: default timeout ran while wait was outstanding`. A second `Client.call` cannot leave the queue while `wait` is still pending, so the yield mode releases with `call_poll`, which is what `force_exit` already does. Copied that into `RpcSubprocess.wait_async`. `ninja -C build src/client/libmutter-rpc-16/libmutter-rpc-16.so` linked. Guest not rebuilt.
- 2026-11-06 14:00 HKT. User: waiting on that socket for the life of the process is the wrong fix. `Client.call` still leaves `Gsr-Mutter-WaylandClient.wait` outstanding until exit, and `wait_response` still applies `call_timeout_seconds` (120). DING would still see a timeout and relaunch. The yield edit stays in the tree and is not that fix.
- 2026-11-06 14:02 HKT. User: the bug file needs the proposal as hunks. Wrote ## Proposal with ### 1–4 Remove / Replace with / Add for both server `wait` methods, the client exit signal, and `wait_async`.
- 2026-11-06 14:51 HKT. User approved the proposal. Applied ### 1–4. `OLLMrpc.Client.disconnect()` takes no handler id, so the client watch uses `GLib.SignalHandler.disconnect`, and that line in ### 4 was updated to match. `libmutter-rpc-16.so` linked. `libmutter-16/WaylandClient.c` compiled. `gsr-server` did not link: `rpc/Server.vala` calls `GI.Repository.dup_default` and this host's `girepository` header has no declaration. Guest not rebuilt.
- 2026-11-14. User: archive old desktop cube / icons / DING bugs. Moved to `docs/bugs/done/`.
