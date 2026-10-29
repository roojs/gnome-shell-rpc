# Emergency mode Log Out has no pointer and ignores the click

**Status:** ⏳ open. User 2026-10-29, on the new emulator. After Emergency mode, the top-right "Log Out" does not show a pointer when the mouse is over it, and a click does nothing.

The 2026-10-26 report was the same control on the virtual machine: the session stayed up. `alan@192.168.88.197` was not read then. It was not read this turn.

Logs on this machine do not name that screen. `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log` mtime 2026-10-29 15:16 ends on panel motion (`ClutterActor.vala:452` `type=5` `Gjs_ui_panel_QuickSettings`). No `client exited`, no `SessionManager.Logout`. `weston-autolaunch-prove.log` still ends `nested-weston-prove: mutter exited ec=1` from the menu-expander prove.

The control is the `Clutter.Text` `logout` in `src/server/rpc/SpawnClient.vala` `on_crash`. Emergency mode destroys the notice and leaves this text. Enter sets `Meta.Cursor.POINTER`. Leave sets `Meta.Cursor.DEFAULT`. `gsr-server` rebuilt with that.

`on_crash_logout` calls `SessionManager.Logout(1)`, then logind `Session.Terminate` on `session/auto`, then `context.terminate()`. A Weston click of that control can end this login. That click is not the prove.

The headless copy of that text is picked, and press and release both arrive. The cursor sprite stays the same until enter calls `Meta.Display.set_cursor(POINTER)` and leave calls `DEFAULT`. That is `tests/call-sync-repro/logout-text-pointer-gate`, `PASS`. The same enter and leave calls are now on the product text.

The click that does not end the session is still open. Delivery is not the miss. `on_crash_logout` can return after `Logout` without ending the session, and the handler has already set `reactive` false.

## Steps

### 1. Emergency mode leaves the top-right Log Out

`src/server/rpc/SpawnClient.vala`. The Emergency mode choice destroys only the notice. The backdrop and the top-right `logout` text stay.

### 2. Pointer cursor

Hover on a shell button changes the cursor from JavaScript. This text is created on the server after the client has exited, so that path is gone. Enter on the text now calls `display.set_cursor(POINTER)`. Leave calls `DEFAULT`.

### 3. The click handler is `button_release_event`

```vala
logout.button_release_event.connect((e) => {
    logout.reactive = false;
    this.on_crash_logout.begin();
    return true;
});
```

The first delivery sets `reactive` false, then asks the session to end. A `Logout` call that returns without ending the session leaves the text on screen and dead to a later click.

## LLM efforts

### 2026-10-26 report from the demo test

The virtual machine (`alan@192.168.88.197`) did not answer: `ssh: connect to host 192.168.88.197 port 22: No route to host`. `~/.cache/gnome-shell-rpc/` on this machine was last written 2026-10-23 16:40. No emergency-mode or logout line from the demo session was read. `src/` not edited.

### 2026-10-29 headless text

`meson compile -C build tests/call-sync-repro/logout-text-pointer-gate` then `timeout 20 ./build/tests/call-sync-repro/logout-text-pointer-gate` (outside the sandbox; the sandbox cannot open a Wayland lock). First run, no `set_cursor`: `text mapped=1 size=64x23 at=720,12 picked=text`, `enter=1 press=1 release=1 sprite 0x5ab1dd058000 -> 0x5ab1dd058000`, `FAIL logout-text-pointer-gate: cursor unchanged`. The server `pick` class handler was then installed in the gate as well. Baseline stayed `enter=1 press=1 release=1`. Enter `META_CURSOR_POINTER` and leave `META_CURSOR_DEFAULT`: `pointer sprite away=0x5da18f62a0e0 hover=0x5da18f628960`, `PASS logout-text-pointer-gate`. Those two connects were copied onto `logout` in `SpawnClient.vala`. `meson compile -C build src/gsr-server` linked. Weston click of Log Out was not run.

### 2026-10-29 read the logs that exist

User: on the new emulator the Log Out text shows no pointer on hover, and a click does nothing. `mutter-rpc.debug.log` mtime 2026-10-29 15:16, tail is panel `type=5` motion, no crash line. `weston-autolaunch-prove.log` tail is still `nested-weston-prove: mutter exited ec=1` and `could not load cursor 'dnd-copy'` / `dnd-none`. `rg` of that mutter log for `client exited`, `Emergency`, `SessionManager.Logout` found nothing. `src/` not edited.
