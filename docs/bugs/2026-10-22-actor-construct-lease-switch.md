# Actor construct lease is a switch

**Status:** ⏳ open. `Clutter.Actor.construct` chooses the server object with a switch on the alias. A new peer means another arm.

**Next:** The class that needs a different lease answers that itself. Construct calls one method. The switch does not grow an arm per type.

Split from [`done/2026-10-12-applications-picker-not-working.md`](done/2026-10-12-applications-picker-not-working.md).

- Pagination: [`2026-10-22-app-grid-pagination.md`](2026-10-22-app-grid-pagination.md)
- Performance: [`2026-10-22-app-grid-performance.md`](2026-10-22-app-grid-performance.md)

**Where it stands:** The switch is `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala`, `construct`. Current arms:

- `Meta-BackgroundActor`, `Clutter-Clone`, `St-DrawingArea` return and let the leaf construct lease.
- `Meta-WindowActor` and `St-Widget` call `create_with_overrides`.
- `St-Viewport`: exact type uses `St-Viewport.new`. A subclass calls `create_viewport`.
- `St-Bin`: exact type uses `St-Bin.new`. A `ShellSquareBin` in the type chain calls `Gsr-St-SquareBin.new`. That arm walks `scan.name()`.
- `Clutter-Actor`: exact type uses `.new`. A subclass calls `create_with_overrides`.
- Anything else calls `alias + ".new"`.

A made-up alias cannot stand in for this. `Gi.vfunc_names` splits the alias on the first hyphen and looks it up in the typelib. `Gsr-St-SquareBin` aborted with `no object Gsr.St-SquareBin`.

## LLM efforts

### 2026-10-22 10:15 split from the picker bug

The `St-Bin` arm is the case that made the grid icons square enough to see. It stays until this design replaces the switch. No code moved in this split.
