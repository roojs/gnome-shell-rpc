# Search result click does not spawn the application

**Status:** ✔️ archived 2026-09-24 — the user click stays on [`../2026-09-24-overview-picker-preview-gone.md`](../2026-09-24-overview-picker-preview-gone.md).

20:22 boot has no `JS ERROR` and does not re-prove the click. `app-search-launch-smoke: ok` does not close it.

What that smoke already showed: `Shell.App.launch` reaches `Helper-AppLaunch` and a non-D-Bus GTK desktop can map on mutter-rpc. A physical click produced client `clicked` notifications and did not run `AppIcon.vfunc_clicked`. The hand-written `Button.override.vala` class handler was rejected after it crashed the shell. The missing piece is generated signal class-closure dispatch, tracked with [`../2026-09-23-prefix-generated-vala-signals.md`](../2026-09-23-prefix-generated-vala-signals.md).
