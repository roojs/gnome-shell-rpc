# `ClutterBoxLayout` child minimum height is `-12`

**Status:** ✔️ archived 2026-09-25. The startup frame gate removes the
split-process exposure window. Three short live proofs and one 30-second
stay-up proof reached ready without the negative-height abort.

**Plan:**
[`0.8 init and interaction`](../../plans/0.8-init-complete-and-interaction.md)

## Failure

Stock `QuickSettingsLayout` computes:

```js
const spacing = (rows.length - 1) * rowSpacing;
```

During initial construction, the empty grid had:

```text
rows=0 row_spacing=12 spacing=-12
min=-12 nat=-12
```

The complete live ancestry was visible and mapped:

```text
Quick Settings grid
StBoxLayout
StBin
BoxPointer
menu wrapper
uiGroup
MetaStage
```

`ClutterBoxLayout` correctly rejected the mapped child minimum height.
Clamping the value would only have hidden the exposure path.

## Root cause

Stock `PanelMenu.Button.setMenu()` performs:

```js
Main.uiGroup.add_child(this.menu.actor);
this.menu.actor.hide();
```

In stock GNOME Shell, synchronous JavaScript construction and Clutter frames
run on the same thread. A frame cannot observe the temporary state between
those statements.

In this project, `add_child()` is a synchronous RPC boundary. Mutter's main
loop could dispatch a frame while the shell client was still waiting for the
reply, before JavaScript reached `hide()`.

The live trace proved that ordering:

```text
add visible wrapper
wrapper becomes mapped
before-update runs
empty grid returns min=-12
ClutterBoxLayout aborts
```

The RPC queue was not at fault. Nested notifications while `call_poll()`
waits are an existing, tested contract.

## Rejected changes

- **🚫** No negative-height clamp.
- **🚫** No `panelMenu.js` or `quickSettings.js` patch.
- **🚫** No idle callback, timeout, or deferred notification.
- **🚫** No generic RPC queue-order change.
- **🚫** No manually added `style-changed` hook.

The suspicious manual style subscription was temporarily removed and the
failure reproduced unchanged. Quick Settings explicitly subscribes to
`style-changed`; that separate design issue remains open.

## Proof

The focused add-before-hide smoke reproduced the exposure:

```text
exposed-before-hide wrapper-mapped=true min=-12 nat=-12
FAIL add_child dispatched layout before hide
```

The paired hidden-tree smoke passed:

```text
wrapper visible=false mapped=false
grid preferred min=-12 nat=-12
mappedDuringMeasure=false
ok
```

A temporary native probe then used Mutter's public frame-clock API:

- `clutter_actor_peek_stage_views()`
- `clutter_stage_view_get_frame_clock()`
- `clutter_frame_clock_inhibit()`
- `clutter_frame_clock_uninhibit()`

Two runs proved:

- zero `before-update` notifications before release;
- the existing pending frame resumed after 10.3 ms and 11.5 ms;
- no negative preferred height;
- no `ClutterBoxLayout` abort.

This proved inhibition, rather than dropped scheduling requests, was the
correct production mechanism.

## Implemented boundary

The client remains the startup driver:

```text
server spawns client
client calls RPC-Bootstrap.begin_shell_startup
server inhibits every current stage-view frame clock
client evaluates unchanged stock init.js
server continues servicing synchronous RPC
stock shell calls Meta.Context.notify_ready
server uninhibits the clocks in that RPC turn
pending frame runs after the turn returns
```

Implemented files:

- `src/rpc/StartupFrameGate.vala`
- `src/rpc/Bootstrap.vala`
- `src/rpc/Connection.vala`
- `src/rpc/Server.vala`
- `src/rpc/helper/Context.vala`
- `src/rpc/helper/namespace.vala`
- `src/shell-client/ShellApplication.vala`
- `src/meson.build`

`StartupFrameGate`:

- owns the active shell connection;
- inhibits each current stage-view frame clock once;
- reconciles `stage-views-changed`;
- permits only the owner to release an active gate;
- releases automatically when the owner connection stops.

`Clutter.StageView.get_frame_clock()` is absent from the installed VAPI.
The implementation binds the real public C symbol:

```vala
[CCode (cname = "clutter_stage_view_get_frame_clock",
	cheader_filename = "clutter/clutter.h")]
private static extern Clutter.FrameClock frame_clock(Clutter.StageView view);
```

The server creates the gate after assigning its display, passes it to helper
registration, and injects it into `Bootstrap` at the original late
registration point.

Constructing `Bootstrap` before OCRPC and GI registration was tested and
rejected because it changed registration order and produced:

```text
unknown alias 'Clutter-OffscreenEffect'
```

## Production result

Two consecutive stay-up runs produced equivalent boundaries. The second:

```text
15:50:44.580956 RPC-Bootstrap.begin_shell_startup
15:50:47.464574 READY=1
15:50:47.464668 Meta-Context.notify_ready
15:50:47.467152 notification method=before-update
```

Both had:

```text
before_update_before_release=0
negative_height_or_abort=0
```

An additional 30-second stay-up run reached:

```text
15:55:52.387891 READY=1
15:55:52.388296 Meta-Context.notify_ready
15:55:55.814062 Meta.is_restart
```

It remained alive until the configured timeout with
`before_update_before_release=0`.

The normal prove also reached `READY=1` and `Meta.is_restart`; its SIGKILL
was the harness's documented early stop, not a compositor crash.

## Remaining validation

- **⏳ 🔷** Add a focused owner/non-owner frame-gate contract.
- **⏳ 🔷** Prove disconnect cleanup balances every inhibit.
- **⏳ 🔷** Prove stage-view replacement balances inhibit counts.

These are hardening gates. The original live negative-height failure is
closed by repeated production boot proofs.

## Related

- [`style-changed manual subscription`](../2026-09-22-style-changed-manual-subscription.md)
- [`text get-layout`](2026-09-25-text-get-layout-pango-layout.md)
