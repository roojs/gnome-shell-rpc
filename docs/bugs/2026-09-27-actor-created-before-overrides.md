# The actor is leased before it is told which methods were replaced

**Status:** ⏳ current. The create request now carries the list. Not yet
re-proved in a nested session.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**How a virtual call works:** [`../vfuncs.md`](../vfuncs.md)

**Seen from:** [`2026-09-24-overview-picker-preview-gone.md`](2026-09-24-overview-picker-preview-gone.md).
That screen is still wrong for a separate reason, written there. This bug
is the birth of every helper actor, not the wallpaper by itself.

## What happened

The client already knows which methods the shell replaced before it asks
for a lease. It scans the class, locally, and builds a list. The create
request did not carry that list. It sent only the type name.

The server made the actor, gave out the lease, and the override map was
empty. Each replaced method was a later message, one at a time
(`Helper-Actor.add_hook`). Until those messages arrived, layout treated
the actor as a plain widget.

The callbacks were registered even earlier, on their own calls. The later
message refuses a callback the connection does not already have. So the
list existed on the client before create, and the callbacks existed on
the connection before create, and create still did not carry them.

The same split was on the layout manager: create, then three `add_hook`
calls.

## What should happen

The create request carries each replaced method and the callback that
implements it. The server stores those on the new actor, then returns
the lease. There is no leased actor whose override map is still empty.

`add_hook` stays for an actor that already existed, such as the stage.
It is the wrong way to finish an actor we just created.

## What this does not fix

The wallpaper inside the desktop frame is still 0×0 if `allocate` is not
in the list. The scan that builds the list still misses that method,
because the function sits in a different field than the one the scan
reads. That is the preview bug. Turning the sizing function on by copying
it, or by reshuffling fields until the scan happens to see it, works
around a class that does not match the library. It is not this fix.
