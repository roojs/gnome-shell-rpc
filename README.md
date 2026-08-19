# gnome-shell-rpc

Vala **mutter plugin** that exposes compositor state over GObject RPC, plus an out-of-process shell client. Stock `mutter` loads the plugin; the shell is a separate process that can crash and restart.

Plans live in [`docs/plans/`](docs/plans/):

| Plan | What |
| ---- | ---- |
| [`0.1`](docs/plans/0.1-decouple-gnome-shell-vala-rpc.md) | Master plan (Phases 1, 2.0, 4, 5) |
| [`0.2`](docs/plans/0.2-rpc-server-read-only-streaming.md) | RPC server + read-only streaming |
| [`0.3`](docs/plans/0.3-minimal-shell-top-bar.md) | Out-of-process minimal shell (top bar) |

Start at [`0.1`](docs/plans/0.1-decouple-gnome-shell-vala-rpc.md).
