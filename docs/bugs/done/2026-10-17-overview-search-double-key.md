# Overview search doubles the first character

**Status:** closed 2026-10-19. The first overview search letter was inserted
twice. `Shell.Global.bind_display` re-emitted stage `key-press-event` on
top of the GJS connect subscription. The hook no longer emits that signal.
Smoke `overview-search-double-key: ok` at 19:07:50 (`first="t"` `second="te"`).

The 2026-10-17 16:52 Weston logs are gone; later nests replaced them.
`mutter-rpc.debug.log` recorded one `t` press at 16:52:32.698 and its release
at 16:52:32.778. The client log for that press delivered `key-press-event`
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
logged one press per letter. The extra insert was client delivery of the
first key, not a repeated hardware event.

The first letter was handled on the stage: the search entry did not have
key focus yet, so `SearchController._onStageKeyPress` ran `startSearch`,
which focused the entry and called `clutter_text.event()`. That stage
emission reached the client twice. `Shell.Global.bind_display` emitted
`key-press-event` locally from the stage event hook, and the GJS `connect`
subscription emitted it again. Each run inserted the character. A later letter
was delivered to `Clutter.Text` first. The text handler stopped the bubble, so
the stage path did not run and the letter was inserted once.

Reproduction:

```bash
GSR_NESTED_TIMEOUT=90 GI_META_SMOKE=overview-search-double-key \
  ./scripts/agent-nested-smoke-prove.sh
```

Pass line: `overview-search-double-key: ok`. Fail line:
`overview-search-double-key: miss doubled`.

## LLM efforts

### 2026-10-17 16:53 report from the live session

Read the 16:52:24 and 16:52:32 key presses already in the Weston logs. No
product code was changed for this failure.

### 2026-10-18 code path and smoke

The 16:52 logs had been replaced. One stage key reaches the client twice:
the `bind_display` event hook emits `key-press-event` locally, then the
GJS subscription notifies and emits it again. Both run
`SearchController.startSearch`, which calls `clutter_text.event()`. A
later letter is handled by `Clutter.Text` and does not bubble to the stage.

`tests/gjs-embed/overview-search-double-key.js`. Before the hook change,
one `fire_key` at 18:59:31 logged two `Clutter.keysym_to_unicode`, two
`Gsr-Clutter-Actor.deliver_event`, and two `text-changed`. The entry read
in that same turn was still empty, so the smoke said `miss first=""`.

After dropping the local emit in `Global.bind_display` and reading
`entry.clutter_text.get_text()` on a short timeout:

```text
19:07:50.220 overview-search-double-key: before="" first="t" focus= modal=1 visible=true
19:07:50.750 overview-search-double-key: second="te"
19:07:50.750 overview-search-double-key: ok
```

Command:

```bash
GSR_NESTED_TIMEOUT=90 GI_META_SMOKE=overview-search-double-key \
  ./scripts/agent-nested-smoke-prove.sh
```

Some boots die in panel-menu allocate (`global.stage.context is null`
after the socket closes). The smoke hides panel menus before `main.start`,
same as `overview-drop-workspace-smoke`. The passing line is in
`~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`.
