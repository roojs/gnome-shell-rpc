# What a client can lock on the server

**Status:** analysis. 2026-10-31. No product change.

An implementation is not needed because a client that dies already unlocks the server. The socket close ends the wait, and the crash screen is the reset. A master key would only matter for a client that stays alive and never answers, and a keybinding cannot run then: the compositor thread is inside the wait, so the main loop is not turning.

A wait sits on the compositor thread, inside `GLib.poll` with no timeout. The mutter main loop is not running for the whole wait. Frames, input, the 30 second ready timer, and Alt+F2 restart all wait on that loop, so none of them can fire while the poll is open.

## A dead client

The socket closes. `Connection.emit_wait_poll` sees hangup or error, marks every outstanding callback replied, and returns. It does not call `stop()` on that stack. Stopping in the middle of the wait would make the next `Hook.emit` a write that does nothing followed by another infinite poll.

`Hook.emit` and a blocking `Subscription.emit` then leave their loops, because `replied` is set. The vfunc or the signal returns. `SpawnClient` is already waiting on the child. That callback stops the connection and paints the crash screen: Restart, Restart with debug, Restart without extensions, Emergency mode, Log Out.

Killing the client from outside does the same thing. `kill` closes the socket, the poll wakes, the wait ends, the crash screen comes up. The reset already exists. It runs only after the process is gone and the poll has returned.

## A live client that never answers

The socket stays open. Nothing is readable. `poll` was asked to wait forever, so it does. The compositor thread stays inside it.

That is the hang. The shell window stops painting. Pointer and key events are not dispatched. The crash screen is not up, because the client has not exited. Nothing that needs the mutter main loop can run, including:

- the 30 second “not ready” kill in `SpawnClient` (`GLib.Timeout.add_seconds`)
- Alt+F2 `r`, which is an RPC from the client plus a `GLib.Idle` that calls `force_exit`
- any Meta keybinding, including one we might add as an escape

A handler that is merely slow looks the same as a handler that will never return. The wait has no deadline, so the server cannot tell them apart.

`SIGSTOP` on the client is the same shape. The process is alive, the socket stays open, the poll does not wake.

## The two waits

Both are on the compositor thread. Both use `poll` with timeout `-1`.

**Reply wait.** `OLLMrpc.Live.Hook.emit` writes `Live.Invoke` and loops on `emit_wait_poll` until that invoke’s reply arrives. A blocking signal does the same with a one-shot hook: `Subscription.emit` writes the notification with a `reply_id` and waits for `RPC-Live-Callback.reply`. The client sends that reply only after the handler returns (`Signals.emit` for a signal, the invoke handler in `src/client/rpc/namespace.vala` for a vfunc). A handler that never returns never replies.

The loop also ends when `connection.running` is false. The wait path does not clear that flag. `stop()` does, and `stop()` runs from the child-exit callback, which needs the main loop.

**Write wait.** `Connection.write` flushes the socket. If the send buffer is full it polls for the buffer to drain, and it reads first so a nested call from the client is not left sitting unread. That is the destroy hang (`docs/bugs/done/2026-10-06-destroy-reenter-hang.md`): both sides were polling for write and neither was reading. A client that is alive and neither reading nor writing still fills this wait. Hangup ends it the same way as the reply wait.

A signal that is not in the blocking list does not wait for a reply. It can still stick in the write wait once the send buffer fills.

## What the server waits on

Every row is a reply wait. The client has to answer before the compositor thread continues.

Blocking signals, set in `ClutterActor.add_signals`:

| Signal | When the wait starts |
| --- | --- |
| `before-update` | each frame, before paint |
| `button-press-event`, `button-release-event` | pointer button |
| `captured-event`, `event` | an event on the capture or bubble path |
| `clicked` | a click |
| `enter-event`, `leave-event` | pointer crossing |
| `key-press-event`, `key-release-event` | a key |
| `motion-event` | pointer motion |
| `scroll-event` | scroll |
| `touch-event` | touch |
| `long-press` | long press |

Vfuncs and other callbacks, each one a `Hook.emit`:

| Wait | Where |
| --- | --- |
| preferred width, preferred height, allocate, event, style-changed | `LayoutHooks` |
| gesture begin, progress, end, cancel, prepare | `ClutterGestureAction` |
| constraint `update_allocation` | `Constraint` |
| viewport allocate | `ViewportActor` |
| drawing-area preferred size | `DrawingAreaActor` |
| drawing-area `repaint` | `DrawingArea.watch_repaint` |
| stage event filter | `Clutter.event_add_filter` |
| repaint func | `ClutterThreads.threads_add_repaint_func` |
| keybinding and custom keybinding handler | `Keybinding` |
| idle-monitor watch | `IdleMonitor` |
| `foreach_transient`, `foreach_ancestor` | `Window` |
| clipboard text callback | `Clipboard.emit_text` |

`before-update` and the event signals are the ones a stuck script hits in ordinary use. A frame or a click is enough. The layout vfuncs are the ones a stuck `get_preferred_width` or `allocate` hits during startup, which is the same poll with no frame on screen yet.

## What “nothing ever happens” means on the client

The reply is sent after the handler returns. These leave it unsent while the process stays up:

- JavaScript that never returns: a loop, or a wait that never finishes, on the handler the server is blocked in.
- The client thread blocked somewhere that is not reading the RPC socket. A nested `call_poll` does read it, and that is how a handler calls back into the server without deadlocking. A block that does not read the socket leaves the invoke sitting in the buffer. The server’s poll is the RPC fd only, so it does not notice.
- The client stopped (`SIGSTOP`) or wedged in native code on its main thread.

A handler that returns, including one that throws after the reply is queued, does not leave this wait open. A handler that returns a result and keeps working later is also done, from the server’s point of view. The reply has already been sent.

## A master key

A keybinding inside mutter cannot be the escape. Dispatching it needs the main loop, and the main loop is the thread stuck in `poll`. The shell’s own keybindings are themselves reply waits (`Keybinding` `row.emit`).

The action that unsticks the server is the client process ending. The crash screen is already the reset after that. A master key only has to kill `client_proc`. It does not need a second teardown.

It has to run somewhere that is not the mutter main loop:

- A deadline on the `poll` itself. `GLib.Timeout` cannot fire here. The timeout argument of this `poll` can. On deadline, `force_exit` the client and keep polling until hangup marks the callbacks replied. Then the existing child-exit path paints the crash screen.
- A thread that is not the compositor thread, reading a key chord from evdev or a signal, whose only job is that same `force_exit`.

The poll deadline covers “nothing ever happens” with nobody at the keyboard. The chord covers “this handler is allowed to be slow, and a person can see that it is stuck.” Both end at the crash screen. A short deadline will also kill a shell that is legitimately busy inside one handler, so the chord is the one that matches “the user decides.”

The 30 second ready kill does not cover this. It runs only until the client calls `notify_ready`, and only while the main loop is turning.
