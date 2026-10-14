# Signal reentrancy

A signal handler can call back into the compositor and wait. While that wait is open, another signal can arrive. In one process, the signal caused by the call runs before the call returns, and a frame update does not cut into the handler. Shell and compositor are two processes. The same order still has to hold, and it has to be proved before it is put into `src/`.

## Follow the debugging procedure

`tests/call-sync-repro/signal-reentrancy-gate.vala` is one small program. Two threads pass one-byte messages through a pair of pipes. It does not start GNOME Shell, and it does not link product code.

When a bug looks like one signal running in the middle of another:

1. Follow [`docs/debugging.md`](debugging.md) in order and keep the bug file current after every stage.
2. At stage 4, shrink the failure into this gate.
3. At stage 5, add a mode that copies the rule being tested and run `meson test -C build --suite signal-reentrancy`.
4. Keep product code unchanged until the reproduction passes and still matches the stage 3 failure.
5. Only at stage 6 may a minor proven change land or a major change be written as a proposed-code review.

The overview click that starts a drag in the middle of `clicked` is the case this test was built for. That work lives in [`plans/1.4-signal-reentrancy.md`](plans/1.4-signal-reentrancy.md). Further reentrancy bugs use this same test before any product change.

## How to read a result

- **Desired pass.** A check added for the work in hand. Success is the result we want.
- **Desired failure.** A check added for the work in hand. Failure is the result we want. If it starts succeeding, the check has stopped doing its job.
- **Existing pass.** An older test that already succeeded. It must stay succeeding.
- **Existing failure.** The old bug, kept as its own check until a reviewed fix is in the real server.

`current` is the existing failure for the click: `before-update` runs inside `clicked`. `stack-eager` and `stack-defer` are desired failures: an unrelated signal overtaking the open signal, and a caused signal waiting until the outer signal closes. `proposal-during`, `proposal-noreply`, `call-hold`, and `later-skip` are desired failures from the later tries. The suite is in good shape only when those checks still fail, the desired passes succeed, and the older RPC tests stay existing passes.

## What the bytes mean

| Byte | Meaning |
| ---- | ------- |
| `O` | The outer signal is open. In `press-gap` this is `clicked` |
| `L` | `long-press`. The handler returns before the frame |
| `R` | The handler made a nested call |
| `A` | A signal caused by that call |
| `U` | An unrelated signal, such as a frame update |
| `S` | The nested call's reply |
| `D` | The exchange is finished |
| `Y` | A boolean handler finished |
| `K` | A void handler finished |

The order we want: `A` runs before `S`. `U` waits until the outer signal has finished. Boolean and void handlers share that schedule. Only the completion byte differs.

## The rule under test for the click

The click plan's server rule is copied by three modes. They are not the product code. A one-way signal is held only when a wait is already open and the server is not inside the shell's call. Any other one-way signal is sent at once, and the server waits for the shell to finish it.

- `proposal-after` is a desired pass. The frame becomes ready after the nested call returns, while the outer wait is still open, and it is held. That is the timing in the click log.
- `proposal-during` is a desired failure. The hold is skipped while the server is inside the shell's call, so the frame is sent at once. That is not the name-list rule.
- `proposal-noreply` is a desired failure. The client reads the signal and never replies. The stand-alone wait stops after 200ms. On the real server that wait would not stop.

Those two failures are why that particular hold stays unapplied. Removing the name list is the `server` check, and that one passed.

The server blocks stay unapplied. The next try was three client ideas. One of them keeps the order. The other two do not, and those two checks are meant to keep failing.

- `emit-queue` passed. The frame waits until the whole click handler has returned, including the part after the nested call. The signal that call caused still runs immediately. That queue is in `src/client/libshell-16/Signals.vala`.
- `press-gap` is an existing failure. `long-press` returns, then the frame, then `clicked`. The queue does not hold that frame, because no handler is running. The drag starts before `clicked` sets the flag.
- `server-gap` is an existing failure. The passing server rule is applied to that same order. The frame is still sent, because no signal is open between the two.
- `event` passed. The frame stays held until `clicked` has replied. The signal that call caused is still sent at once. That order is not in the server. An idle flush was tried and removed. Idle is not a way to deliver it.
- `event-no-click` is a desired failure. Holding the frame from `long-press` until `clicked` replies never sends the frame when the user drags and no `clicked` follows.
- `event-scope` passed. Frames are held while the pointer event is open and sent when that event ends: after `clicked` replies on a click, and after `long-press` replies on a drag. The click arm holds one frame before `clicked` and another during its nested call. Boolean and void clicks use the same schedule, a causal nested signal still runs immediately, and a later idle frame is not held.
- `event-reschedule` passed. It replaces all frames that become ready during one pointer event with one follow-up frame. It retains no notification arguments, handles a drag with no `clicked`, keeps the causal signal nested, and leaves an idle frame immediate.
- `clutter-event-frame-order-gate` passed against real Clutter. `long-press(CANCEL)` and both `clicked` handlers have a current event. The scheduled `before-update` follows them with no current event.
- `call-hold` did not. The frame is released when the nested call returns, and the click is still going. That is the bug.
- `later-skip` did not. The drag callback waits, but the frame signal itself still runs during the click.
