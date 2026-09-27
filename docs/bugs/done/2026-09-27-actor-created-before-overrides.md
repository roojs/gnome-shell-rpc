# The actor is leased before it is told which methods were replaced

**Status:** ✔️ archived 2026-09-27. Create carries the override list.
The user confirmed the desktop background is on screen, which is the
session proof: `allocate` was in that list and the helper ran it.

**Plan:** [`../../plans/0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)

**How a virtual call works:** [`../../vfuncs.md`](../../vfuncs.md)

**Seen from:** [`../2026-09-24-overview-picker-preview-gone.md`](../2026-09-24-overview-picker-preview-gone.md).
The wallpaper row of that bug is closed by the same confirmation. Icon
click stays there.

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

The wire cannot carry a list of pairs. The list goes as two arrays of
the same length: the method ids, then the callback ids.

`add_hook` stays for an actor that already existed, such as the stage.
It is the wrong way to finish an actor we just created.
