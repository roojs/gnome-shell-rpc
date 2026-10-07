# Actor destroy hangs the nested shell

**Status:** ✅ closed 2026-10-07. User: assume fixed.

Weston debug session, 2026-10-06 20:12. `libocrpc.so` installed 20:11:12. `build/src/gsr-server` 20:11:53, `build/src/gsr-client` 20:11:58. Started with `./scripts/weston-gsr-session.sh --debug`. Server pid 15393, client pid 15426. The cursor trails and the window stops painting. Both processes stay up. There is no `Unregistered declared class type schema` and no end-of-stream in this run.

## Write it down

The shell is in the middle of tearing down a search entry. The last call the server finishes is `Clutter-Actor.show` id 24435 at 20:12:35.612. The client then calls `Clutter-Actor.destroy` id 24436. The server logs that recv and never replies. The client's `destroy` handler runs on the notification that arrives while that call is still outstanding, and from there it sends more synchronous `RPC-Live-Subscribe.unsubscribe` and `Clutter-Actor.destroy` calls, ids 24437–24453. None of those are received. Both main threads sit in `poll`. The logs stop at 20:12:35.623.

`Meta-Window.get_compositor_private` returned `-32602` at 20:12:29, before this stall. The connection stayed up after those errors.

## Debug

Client, in order, from `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`:

```text
20:12:35.606  id=24432  St-Entry.set_text          replied
20:12:35.607  id=24433  Clutter-Text.set_cursor_visible
20:12:35.607  notification captured-event
20:12:35.608  notification event
20:12:35.608  notification before-update
20:12:35.611  replied id=24433
20:12:35.611  id=24434  Clutter-Text.set_selection  replied
20:12:35.612  id=24435  Clutter-Actor.show          replied
20:12:35.612  id=24436  Clutter-Actor.destroy
20:12:35.613  notification destroy
20:12:35.613  id=24437  RPC-Live-Subscribe.unsubscribe
20:12:35.614  notification destroy
20:12:35.614  id=24438  RPC-Live-Subscribe.unsubscribe
20:12:35.614  notification destroy
20:12:35.615  id=24439  Clutter-Actor.destroy
```

The same destroy / unsubscribe pair repeats through id 24453. No `replied id=24436`. No later `invoke ENTER` left open. Server `mutter-rpc.debug.log` last line is `recv id=24436 method=Clutter-Actor.destroy`. Ids 24437–24453 never appear there.

`ss -xnp` on `/run/user/1000/mutter-rpc.sock` while both processes were still in `poll`:

| End | Recv-Q | Send-Q |
| --- | ---: | ---: |
| `gsr-server` fd 32 | 651 | 192768 |
| `gsr-client` fd 9 | 391 | 213504 |

The nested calls are the designed path. `tests/call-sync-repro/notif-nested-call-gate.vala` `Gate.outer` writes one notification, calls `request.reply`, and returns. It does not read inside the handler. `Gsr.Server.Rpc.Connection.drain_readable` then hits `while (input_pending())` and receives the nested `call_poll`. If that request is not buffered yet, `on_input_ready` returns and the `IN` watch fires. A `Thread.usleep` inside the outer handler fails: the watch cannot run until the handler returns, and the `while` has not been reached. `emit_wait_poll` inside that handler passes and is the wrong tool. It belongs to `Hook.emit`. `src/client/rpc/namespace.vala` says the same thing for a `Live.Invoke` reply: nested `call_poll` stays in flow, and it is not deferred or queued.

`Clutter-Actor.destroy` never reaches that `while`. `Request.dispatch` falls through to `Gi.dispatch_function`, which calls `g_function_info_invoke` and only then `request.reply`. `clutter_actor_destroy` emits `destroy` for the subtree on that stack. `Subscription.emit` writes each notification and returns; it does not wait. `Connection.write` then `bin.out_stream.flush()`. Both RPC sockets are `O_NONBLOCK` (`/proc/<pid>/fdinfo` flags `02004002` on server fd 32 and client fd 9). That flush waits in `poll` for `OUT` only. The client is in the same wait: `call_poll` does `output.flush` before its `poll` for `IN`, and `Shell.Signals.disconnect` has already entered nested `call_poll` for `RPC-Live-Subscribe.unsubscribe`. Further child `Clutter-Actor.destroy` calls are the same shape. Those are ids 24437–24453.

Both send buffers are full (server Send-Q 192768, client Send-Q 213504), so `OUT` is not ready. Both receive buffers have data (651 and 391). `IN` being ready does not finish an `OUT`-only wait, which is why both main threads stay in `do_poll` with a non-zero Recv-Q. `input_pending()` would be true. Nothing calls it. `dispatch()` does not return, so `drain_readable`'s `while` does not run, and `on_input_ready` does not return, so the `IN` watch is not polling.

## Reproduce

```bash
./scripts/weston-gsr-session.sh --debug
```

Wait until the shell is up. Type in the overview search entry, then clear it so the result actors are destroyed. The stall is `Clutter-Actor.destroy` still inside `drain_readable` while the client has already entered the nested `call_poll`.

Confirm with the two debug logs and `ss -xnp` on `mutter-rpc.sock`: server recv stops on that destroy, the client has unreplied ids after it, and the server Recv-Q stays non-zero while the main thread is in `poll`.

The reduced shape is `notif-nested-call-gate` with the outer handler blocked in the emit, which is the `Thread.usleep` failure already in that file. This run is that failure with `clutter_actor_destroy` in place of the sleep.

## Proposed fix

`src/server/rpc/Connection.vala` overrides `OLLMrpc.Transport.Connection.write` (`libocrpc/Transport/Connection.vala`). `write_with` is not called. It flushes.

```vala
		public override void write(
			GLib.Object gobject,
			OLLMrpc.Live.Buffer? buffer = null
		)
		{
			if (!this.channel_open || this.bin == null) {
				return;
			}
			var serializable = gobject as OLLMrpc.Bin.Serializable;
			if (serializable == null) {
				GLib.warning("connection write: not bin Serializable");
				return;
			}
			if (this.buffer_stream != null && buffer != null
					&& this.buffer_stream.socket != null) {
				try {
					buffer.send(this.buffer_stream.socket);
				} catch (GLib.Error e) {
					GLib.warning("connection write error: %s", e.message);
					this.stop();
					return;
				}
			}
			try {
				this.bin.write(serializable);
			} catch (GLib.Error e) {
				GLib.warning("connection write error: %s", e.message);
				this.stop();
				return;
			}
			while (this.channel_open) {
				if (this.input_pending()) {
					this.drain_readable();
					continue;
				}
				var ready = GLib.IOCondition.OUT;
				try {
					ready = this.stream.get_socket().condition_check(
						GLib.IOCondition.OUT | GLib.IOCondition.ERR | GLib.IOCondition.HUP);
				} catch (GLib.Error e) {
					GLib.warning("connection write error: %s", e.message);
					this.stop();
					return;
				}
				if ((ready & (GLib.IOCondition.ERR | GLib.IOCondition.HUP)) != 0) {
					this.stop();
					return;
				}
				if ((ready & GLib.IOCondition.OUT) != 0) {
					try {
						this.bin.out_stream.flush();
					} catch (GLib.Error e) {
						GLib.warning("connection write error: %s", e.message);
						this.stop();
					}
					return;
				}
				var poll_source = GLib.PollFD();
				poll_source.fd = this.channel.unix_get_fd();
				poll_source.events =
					GLib.IOCondition.IN | GLib.IOCondition.OUT | GLib.IOCondition.ERR | GLib.IOCondition.HUP;
				var poll_fds = new GLib.PollFD[] { poll_source };
				if (GLib.poll(poll_fds, -1) <= 0) {
					return;
				}
				if ((poll_fds[0].revents & GLib.IOCondition.ERR) != 0
						|| (poll_fds[0].revents & GLib.IOCondition.HUP) != 0) {
					this.stop();
					return;
				}
				if ((poll_fds[0].revents & GLib.IOCondition.IN) != 0) {
					this.drain_readable();
				}
			}
		}
```
