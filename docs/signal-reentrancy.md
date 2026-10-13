# Signal reentrancy

A signal handler can call back into the compositor and wait. While that wait is open, another signal can arrive. In one process, the signal caused by the call runs before the call returns, and a frame update does not cut into the handler. Shell and compositor are two processes. The same order still has to hold, and it has to be proved before it is put into `src/`.

## Prove a change in the stand-alone test first

`tests/call-sync-repro/signal-reentrancy-gate.vala` is one small program. Two threads pass one-byte messages through a pair of pipes. It does not start GNOME Shell, and it does not link product code.

When a bug looks like one signal running in the middle of another:

1. Add a mode to that program that copies the rule you want to try.
2. Run `meson test -C build --suite signal-reentrancy`.
3. Write any `src/` change in a plan, as `Remove` / `Replace with` / `Add`, and review it.
4. Apply it only after that mode shows the order you want.

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
| `O` | The outer signal is open |
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
- `proposal-during` is a desired failure. The frame becomes ready inside the nested call, and this rule sends it at once.
- `proposal-noreply` is a desired failure. The client reads the signal and never replies. The stand-alone wait stops after 200ms. On the real server that wait would not stop.

Those two failures are why the blocks in the click plan stay unapplied.

The server blocks stay unapplied. The next try was three client ideas. One of them keeps the order. The other two do not, and those two checks are meant to keep failing.

- `emit-queue` passed. The frame waits until the whole click handler has returned, including the part after the nested call. The signal that call caused still runs immediately. The code for that is written in the click plan and is not applied.
- `call-hold` did not. The frame is released when the nested call returns, and the click is still going. That is the bug.
- `later-skip` did not. The drag callback waits, but the frame signal itself still runs during the click.
