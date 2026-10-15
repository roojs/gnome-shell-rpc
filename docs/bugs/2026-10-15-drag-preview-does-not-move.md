# Drag begins but the overview preview does not move

**Status:** a nested-Weston overview drag now survives the old scale-transition
gap and emits `drag-begin`, but the preview displacement is still zero after
the pointer moved outside it. The smoke fails with
`miss preview-moved dx=0`.

The reproduction is:

```bash
GI_META_SMOKE=overview-thumbnail-drag-smoke \
GI_META_SMOKE_CMD='gedit --new-window' \
GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
GSR_WESTON_PIXMAN=1 \
GSR_NESTED_TIMEOUT=90 \
./scripts/agent-nested-smoke-prove.sh
```

2026-10-15 09:13 result:

```text
overview-thumbnail-drag-smoke: drag 399.4765625,296.162109375 size=478.203125x339.52734375
overview-thumbnail-drag-smoke: after began=true inDrag=true dx=0
overview-thumbnail-drag-smoke: miss Error: miss preview-moved dx=0
nested-weston-prove: stop (smoke-fail) after 11s
```

The old failure did not occur. `dnd.js` read `scale-x` again 403ms after the
transition was created; the transition was present. `new-frame` then arrived
and the client called `Clutter-Actor.set_position`.

```text
09:13:44.634  Clutter-Actor.get_transition id=19602
09:13:44.635  Clutter-Actor.get_transition id=19604
09:13:45.038  Clutter-Actor.get_transition id=19612
09:13:45.110  notification method=new-frame
09:13:45.118  Clutter-Actor.set_position id=19760
09:13:45.120  preview displacement read as zero
```

The scale lifetime fix is recorded in
[`2026-10-14-drag-scale-gone.md`](2026-10-14-drag-scale-gone.md). Do not
reintroduce the rejected transition hold.

## LLM efforts

### 2026-10-15 split after the scale fix

The patched libocrpc void-signal gate passed. `before-update` was added to the
consumer blocking list. The 35-check signal-reentrancy suite had no unexpected
failures. The Weston drag smoke then moved past `transition-gone` and exposed
this zero-displacement failure.
