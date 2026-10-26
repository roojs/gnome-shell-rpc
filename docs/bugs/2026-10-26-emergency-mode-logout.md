# Emergency mode Log Out does not end the session

**Status:** ⏳ open. Recorded 2026-10-26 on the virtual machine, during the demo test. Logout was unreliable on that machine. The failure seen was Emergency mode's Log Out. It was the only failure in that test.

On a normal desktop Emergency mode leaves the applications up, with Log Out at the top right, and that Log Out returns to the login screen.

Here it does not. The session stayed up.

`alan@192.168.88.197` did not answer, so this file has no session log yet. The logs on this machine stop at 2026-10-23.

System-menu Log Out is [`done/2026-10-06-system-menu-logout.md`](done/2026-10-06-system-menu-logout.md), closed 2026-10-07. Crash-screen Log Out is [`done/2026-10-06-crash-screen-logout.md`](done/2026-10-06-crash-screen-logout.md), closed 2026-10-10.

## Steps

### 1. Emergency mode removes the notice and leaves Log Out

`src/server/rpc/SpawnClient.vala`, the Emergency mode choice:

```vala
this.crash_actors.remove(notice);
notice.destroy();
```

On a normal desktop the notice goes away. The backdrop and the top-right Log Out stay. Open windows are gathered onto the active workspace.

Here that is the screen the Log Out was pressed on.

### 2. That Log Out asks the session to end

The top-right Log Out and the notice's Log Out both call `on_crash_logout`. The top-right one is what Emergency mode leaves behind.

```vala
logout.button_release_event.connect((e) => {
    logout.reactive = false;
    this.on_crash_logout.begin();
    return true;
});
```

```vala
yield bus.call(
    "org.gnome.SessionManager", "/org/gnome/SessionManager",
    "org.gnome.SessionManager", "Logout",
    new GLib.Variant("(u)", 1), null,
    GLib.DBusCallFlags.NONE, -1, null);
```

On a normal desktop `Logout(1)` ends the session. If that call fails, the same method asks logind `Session.Terminate`, and then `context.terminate()`.

Here it does not work as expected. The session stayed up. The log that would say which of those three ran is not in this file yet.

## LLM efforts

### 2026-10-26 report from the demo test

The virtual machine (`alan@192.168.88.197`) did not answer: `ssh: connect to host 192.168.88.197 port 22: No route to host`. `~/.cache/gnome-shell-rpc/` on this machine was last written 2026-10-23 16:40. No emergency-mode or logout line from the demo session was read. `src/` not edited.
