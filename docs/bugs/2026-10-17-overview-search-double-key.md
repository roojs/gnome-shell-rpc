# Overview search doubles the first character

**Status:** open. Showing the overview search page and pressing one letter
inserts that letter twice. Later letters in the same word are inserted once.

The hand session is the nested Weston debug session that is still up.
`mutter-rpc.debug.log` records one `t` press at 16:52:32.698 and its release
at 16:52:32.778. The client log for that press delivers `key-press-event`
three times and `text-changed` twice:

```text
16:52:32.699  notification method=captured-event
16:52:32.708  Clutter.keysym_to_unicode
16:52:32.715  notification method=key-press-event
16:52:32.716  notification method=text-changed
16:52:32.720  notification method=key-press-event
16:52:32.727  Clutter.keysym_to_unicode
16:52:32.729  notification method=key-press-event
16:52:32.730  notification method=text-changed
```

The same shape is on the `t` that starts `ter` at 16:52:24.251. The following
`e` and `r` each have one `key-press-event` and one `text-changed`. Mutter
logged one press per letter. The extra insert is client delivery of the
first key, not a repeated hardware event.

Logs:

- `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`
- `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log`

## LLM efforts

### 2026-10-17 16:53 report from the live session

Read the 16:52:24 and 16:52:32 key presses already in the Weston logs. No
product code was changed for this failure.
