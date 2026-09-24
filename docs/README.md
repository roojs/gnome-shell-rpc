# Docs

User-facing docs (no plan numbers):

| Path | What |
| ---- | ---- |
| [`build.md`](build.md) | Prerequisites, meson/ninja, nested run, install |
| [`weston-nested-test-env.md`](weston-nested-test-env.md) | Why Weston-in-X11 is the default nested prove env |
| [`nested-debug.md`](nested-debug.md) | Prove SIGKILL vs real death; do not gdb your own kill |
| [`libmutter-rpc-for-gnome-shell-js.md`](libmutter-rpc-for-gnome-shell-js.md) | `GI_TYPELIB_PATH` / pkg-config for client Meta |
| [`clutter-layout-allocate.md`](clutter-layout-allocate.md) | Stock Clutter/GJS allocate program — chrome chases follow this |
| [`signals-client.md`](signals-client.md) | Client proxy signals, class closures, and subscription dispatch |
| [`signals-server.md`](signals-server.md) | Server leases, subscriptions, and vfunc hooks |
| [`gjs-overridden-properties.md`](gjs-overridden-properties.md) | GJS property overrides: server get/set calls the JavaScript accessor |
| [`coding-standards.md`](coding-standards.md) | Vala style |
| [`coding-standards-router.md`](coding-standards-router.md) | Which standards apply to a change |
| [`../src/README.md`](../src/README.md) | What each `src/` folder is for |

Agent / design history: active plan [`plans/0.8-init-complete-and-interaction.md`](plans/0.8-init-complete-and-interaction.md); archive [`plans/done/`](plans/done/). See [`guide-to-writing-plans.md`](guide-to-writing-plans.md).

Closed bug write-ups: [`bugs/done/`](bugs/done/).

Mutter C reference tree follows upstream `doc/coding-style.md`.
