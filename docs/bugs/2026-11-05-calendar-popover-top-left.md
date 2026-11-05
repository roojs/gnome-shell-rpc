# Calendar popover sticks at the top left

**Status:** Seen on the live Ubuntu 26.04 emulator `alan@192.168.122.115`
(`ubuntu2604`, GNOME Shell 50.1). Session started 19:47:10 HKT:
`gsr-server` pid 42128, `gsr-client` pid 42372. Log
`~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` on that account.
`src/` has not been changed. No gate yet.

The clock popover's allocate throws, so the placement that should move it
under the clock does not finish and the popover stays at the origin.

## What the log shows

The user opened the calendar around 19:57. `DateMenuButton` logged
`property 'mapped' is not writable` at 19:57:07.460, 19:57:07.471, and
19:57:07.480. Then the popover allocate threw four times:

| Time | Line |
| --- | --- |
| 19:57:10.848 | `JS ERROR: TypeError: can't access property "source", this._adjBinding is undefined` |
| 19:57:12.846 | same |
| 19:57:16.188 | same |
| 19:57:56.718 | same |

Each stack is:

```text
vfunc_allocate@resource:///org/gnome/shell/ui/messageList.js:1750:20
vfunc_allocate@resource:///org/gnome/shell/ui/boxpointer.js:267:18
@resource:///org/gnome/shell/ui/init.js:20:20
```

The line before each throw is `St-Adjustment.get_upper`. That is
`this.vadjustment.upper` at the start of `MessageView.vfunc_allocate`.
No earlier `JS ERROR` in this session names `messageList.js` or
`boxpointer.js`. The other `JS ERROR`s are `iconGrid.js` `column_spacing`
at 19:47:36–19:47:38, during app-grid construction.

## Where it throws

Shell 50.1 `vendor/gnome-shell` `e0fdc4c13` on that guest.

`messageList.js` 1750 is the notification list inside the calendar
(`CalendarMessageList` parents a `MessageView` in an `St.ScrollView`):

```javascript
} else if (this._adjBinding.source === null) {
```

`_adjBinding` is assigned in one place, `MessageView.vfunc_set_adjustments`:

```javascript
this._adjBinding = new GObject.BindingGroup();
```

`boxpointer.js` 267 is the popover's child allocate, after the popover
has tried to place itself:

```javascript
vfunc_allocate(box) {
    if (this._sourceActor && this._sourceActor.mapped) {
        this._reposition(box);
        this._updateFlip(box);
    }
    this.set_allocation(box);
    // ...
    this.bin.allocate(childBox);   // line 267, enters MessageView
}
```

`_reposition` writes the on-screen position with
`allocationBox.set_origin(...)`. The box it is given is the origin until
that write. The child allocate then throws, so this `vfunc_allocate` does
not finish. The popover stays at the top left. The first opens can place
it; once this throw starts, later allocates leave it there.

## Why `_adjBinding` is missing

`calendar.js` builds the list as
`new St.ScrollView({ child: this._messageView })`.

`ScrollView.child` then calls `set_adjustments` on that child
(`src/client/libst-rpc-16/overrides/ScrollView.override.vala`). The same
override is what `libst-rpc-18.so` is built from.

`Viewport.set_adjustments` only stores the two adjustments
(`src/client/libst-rpc-16/overrides/Viewport.override.vala`). It does not
run `MessageView.vfunc_set_adjustments`, which is the only assignment of
`_adjBinding`. The allocate that follows still reads
`this._adjBinding.source`.

## LLM efforts

- 2026-11-05 19:59 HKT. User: calendar popover on the emulator sticks at
  the top left after working once or twice; check the logs and file a
  bug. Local `~/.cache/gnome-shell-rpc/` logs are from 2026-11-04 10:10
  and are an overview-drop smoke, not this session. `192.168.88.197`
  does not answer. `alan@192.168.122.115` is up, hostname `ubuntu2604`,
  Shell 50.1, session from 19:47:10. Read the client log. Four
  `_adjBinding` throws at 19:57:10 through 19:57:56, stack
  `messageList.js:1750` from `boxpointer.js:267`, immediately after the
  `DateMenuButton` mapped criticals at 19:57:07. Confirmed those lines in
  the guest's Shell 50.1 tree and the `ScrollView.child` /
  `Viewport.set_adjustments` overrides. Did not edit `src/`.
