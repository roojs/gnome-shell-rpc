# `ClutterBoxLayout` child minimum height is `-12`

**Status:** ✔️ startup frame gate implemented and live-proven.
The original failure exited Mutter with `ec=133` after 4s.

**Plan:**
[`0.8 init and interaction`](../plans/0.8-init-complete-and-interaction.md)

## Debugging contract

This bug is being handled prove-first:

1. reproduce the real boot death;
2. trace how the negative value reaches a mapped actor;
3. add a focused **FAIL** gate for that path;
4. make only the minimal change proven by the gate;
5. require the focused gate and full nested boot to pass.

Do not clamp the value at the RPC boundary, patch stock
`QuickSettingsLayout`, or add a timing/defer workaround. Those changes would
only mask the path that incorrectly measures the empty layout while mapped.

## Reproduction

`mutter-rpc.debug.log`, last lines:

```text
preferred-height base type=StWidget for=-1 min=-12 nat=-12
ClutterBoxLayout child unnamed [GnomeShellRpcRpcHelperActor] minimum height: -12.000000 < 0 for width 182.000000
```

Then `nested-weston-prove: mutter exited ec=133 after 4s`.

- The client is in `Clutter-Actor.allocate`.
- The socket closes.
- There is no `JS ERROR` or `READY=1`.
- There is no `Helper-Text.get_layout`.
- `get_preferred_height` logs `-12` from the base measure in
  `src/rpc/helper/ClutterActor.vala`.
- The box layout rejects that value.

## Proven value flow

The value is produced by stock `QuickSettingsLayout`:

```js
const spacing = (rows.length - 1) * rowSpacing;
```

The existing `quicksettings-layout-neg-smoke` reproduces the arithmetic with
an empty grid:

```text
rows=0 row_spacing=12 spacing=-12
min=-12 nat=-12
FAIL
```

The live failing peer has also been identified as the Quick Settings grid
shape: a `St.Widget` using `GnomeShellRpcRpcHelperLayoutManager`, parented by
an `St.BoxLayout`. At the fatal measurement both it and its parent are
visible and mapped. Clutter is therefore correct not to ignore the child;
the unresolved defect is why this incomplete empty grid is mapped and
measured.

## Hypotheses tested and rejected

### A reduced hidden tree does not map

`src/gjs-embed/quicksettings-hidden-tree-smoke.js` builds the relevant
wrapper → BoxPointer-like widget → bin → box → negative-height grid
hierarchy. It hides the detached wrapper before adding it to the stage and
mirrors `uiGroup`'s re-entrant `child-added` stacking RPC plus
`before-update`. It passes:

```text
wrapper visible=false mapped=false
grid preferred min=-12 nat=-12
exposedBeforeHide=false
mappedDuringMeasure=false
ok
```

Therefore the negative value itself is safe while its tree is hidden, even
under the same notification re-entrancy. The failing distinction is that the
live tree is published while still visible.

### The first hide-before-add probe was inconclusive

A temporary debug-only wrapper hid `menu.actor` before the stock `setMenu()`
call. Full boot still died with the same Quick Settings `-12`, so the wrapper
was removed. The probe did not log that the registered GObject class actually
dispatched through the replaced JavaScript prototype method. It therefore
does **not** disprove add-before-hide ordering and must not be treated as
fix evidence.

## Live ancestry trace

A temporary server diagnostic printed the complete ancestry when the base
preferred height became negative:

```text
0 HelperActor client-type=StWidget                    visible=1 mapped=1
1 StBoxLayout                                         visible=1 mapped=1
2 StBin                                               visible=1 mapped=1
3 HelperActor client-type=Gjs_ui_boxpointer_BoxPointer visible=1 mapped=1
4 HelperActor client-type=StWidget                    visible=1 mapped=1
5 HelperActor client-type=Gjs_ui_layout_UiActor name=uiGroup visible=1 mapped=1
6 MetaStage                                           visible=1 mapped=1
```

This closes an important gap: it is not merely the grid and its immediate
box. The Quick Settings BoxPointer and the menu's outer wrapper are both
visible and mapped under `uiGroup` when the grid is empty. The reduced hidden
tree passes because its wrapper and BoxPointer stay hidden; the live path
has made both ancestors visible.

## Proven exposure window

The visibility-transition trace and RPC order identify the live flow:

```text
13:45:57.516748 BoxPointer visible=1 mapped=0, parent=outer StWidget
13:45:57.536349 client sends Clutter.Actor.add_child
13:45:57.537563 client receives style-changed
13:45:57.538431 outer StWidget visible=1 mapped=1, parent=uiGroup
13:45:57.538859 client receives child-added
13:45:57.540037 client receives before-update; layout callbacks begin
13:45:57.579453 empty grid returns min=-12 while mapped
13:45:57.593830 ClutterBoxLayout aborts
```

No `Clutter.Actor.hide` request for this wrapper occurs between the
`add_child` and the abort. Stock `PanelMenu.Button.setMenu()` performs:

```js
Main.uiGroup.add_child(this.menu.actor);
this.menu.actor.hide();
```

In-process GNOME Shell completes both statements before the main loop lays
out the newly attached tree. Here `add_child` is a synchronous RPC boundary:
the server maps the visible wrapper, then `style-changed`, `child-added`, and
`before-update` are dispatched back into the client. Their nested preferred
size/allocation RPCs run before the original JavaScript caller resumes, so
JavaScript never reaches the following `hide()`. This explains both
questions:

- `-12` comes from measuring the empty Quick Settings grid;
- Clutter does not ignore it because every ancestor through `uiGroup` is
  already visible and mapped.

The focused gate below pins this RPC add-visible-then-hide exposure window.
The temporary server diagnostics used for the ancestry trace were removed
after capturing the evidence.

## Focused FAIL gate

`quicksettings-add-hide-race-smoke` now reproduces the ordering without the
full panel. It attaches a visible Quick Settings-shaped tree, mirrors
`uiGroup`'s `child-added` stacking callback, and records whether
`before-update` measures its `-12` grid before the caller can hide it:

```text
quicksettings-add-hide-race-smoke:
  exposed-before-hide wrapper-mapped=true min=-12 nat=-12
quicksettings-add-hide-race-smoke:
  FAIL add_child dispatched layout before hide
```

This is the required red reproducer for an *unserialized* turn. A bootstrap
serialization fix should not change generic RPC scheduling, so this smoke is
expected to remain red when run outside the bootstrap turn. The post-fix gate
must instead prove that no frame is dispatched during the serialized turn.

## Local invariant proved by the paired gates

RPC calls are observable scheduling boundaries. Code spanning two calls
cannot rely on the in-process assumption that Clutter will wait until the
next JavaScript statement before laying out the tree.

The paired gates establish the invariant needed here:

```text
add visible wrapper → notifications/layout can observe it → FAIL
hide detached wrapper → add hidden wrapper → remains unmapped → PASS
```

This proves that making the tree valid before publication would avoid this
specific death:

- construct the menu wrapper hidden, or hide it before parenting;
- then add it to `uiGroup`;
- later `show()` remains the explicit publication used when the menu opens.

That ordering is also already used elsewhere in stock GNOME Shell for actors
that must not become observable when parented (`visible: false` before
`add_child`). It requires no idle callback, timeout, or clamping.

It is not yet the preferred production fix. Stock
`PanelMenu.Button.setMenu()` currently adds and then hides, while this
project follows upstream and forbids shipping a vendor-JavaScript override.
The gates do not authorize inferring hidden state generically from actor
type, size, or a future `hide()` call.

## Upstream execution model explains the real mismatch

Stock GNOME Shell evaluates `init.js` in Mutter. `init.js` starts Mutter's
main loop, then invokes `main.start()` from that same main-loop thread.
Synchronous UI construction therefore blocks the thread that could process
a Clutter frame. In stock, the frame clock cannot observe the temporary
state between:

```js
Main.uiGroup.add_child(this.menu.actor);
this.menu.actor.hide();
```

This project moved JavaScript to another process. Mutter's main loop keeps
running while the client performs thousands of synchronous construction
RPCs, so a frame can observe states that are unobservable upstream. That is
the broader design mismatch; Quick Settings is simply the first temporary
state that violates a Clutter size contract.

The upstream-shaped solution direction is therefore a serialized synchronous
bootstrap turn, not a menu patch:

- run initial shell construction while Mutter services the RPC connection
  but does not dispatch ordinary main-loop/frame sources;
- allow nested synchronous RPC on that connection, as current hook polling
  already requires;
- end the turn at the same logical yield where upstream returns control to
  Mutter's main loop;
- then resume normal Mutter frame dispatch.

This is not an idle/defer mechanism and does not reorder notifications. It
recreates upstream's rule that synchronous shell initialization and Clutter
frames do not execute concurrently. In the current `main.js`, panel
construction occurs in `_initializeUI()` before its first `await`, so it is
inside that synchronous turn upstream. The split client needs an explicit
owned handshake for the equivalent yield. It still needs a focused FAIL gate
and an audit of the exact start/end boundary before implementation;
`READY=1` must not be assumed to be the right boundary without proof.

## Proposed live implementation

### Scope correction

- **🔷** Production JavaScript changes are out of scope.
- **🚫** Do not add an owned startup JavaScript adapter.
- **🚫** Do not patch stock GNOME Shell JavaScript.
- **ℹ️** The earlier `startup-turn.js` proposal violated this boundary.
- **ℹ️** A Vala-only frame gate is now proved by the native probe.

The following production shape is implemented.

### Production runs

The compositor and shell client build completed. Two consecutive isolated
live runs used only `scripts/weston-gsr-prove.sh`. The first produced:

```text
15:47:55.501625 RPC-Bootstrap.begin_shell_startup
15:47:58.564986 READY=1
15:47:58.565355 Meta-Context.notify_ready
15:47:58.567539 notification method=before-update
```

The second reproduced the boundary:

```text
15:50:44.580956 RPC-Bootstrap.begin_shell_startup
15:50:47.464574 READY=1
15:50:47.464668 Meta-Context.notify_ready
15:50:47.467152 notification method=before-update
```

- **✔️** No `before-update` notification ran between gate start and release.
- **✔️** The pending frame ran after `notify_ready` returned.
- **✔️** No negative preferred height or `ClutterBoxLayout` abort occurred.
- **✔️** Frames and startup RPC continued until the 15-second harness timeout.
- **✔️** No JavaScript, idle, timeout, clamp, or queue-order change was added.

### No-source proof of concept

Temporary debugger files live under ignored `build/`.
No product or stock JavaScript file was changed.

The probe:

1. breaks on both Clutter frame-clock scheduling functions;
2. suppresses scheduling while startup RPC continues;
3. releases scheduling at the existing
   `Meta.Context.notify_ready()` call;
4. runs only through `scripts/weston-gsr-prove.sh`.

Two isolated runs produced the same ordering:

```text
READY=1
Meta-Context.notify_ready
startup-frame-corridor: ... releasing frames
notification method=before-update
```

Both runs proved:

- **ℹ️** Nested startup RPC reached `notify_ready`.
- **ℹ️** Zero `before-update` notifications ran before release.
- **ℹ️** The mapped empty-grid negative-height abort did not occur.
- **ℹ️** Frame notifications resumed after release.
- **ℹ️** Mutter stayed alive until the prove harness stopped it.

This proves that excluding frames while startup RPC proceeds is sufficient
to avoid this failure without changing JavaScript.

It does **not** prove the production boundary:

- **⏳ 💩** `notify_ready` is only the probe's release marker.
- **⏳ 💩** The debugger drops schedule requests instead of preserving one
  pending frame.
- **ℹ️** The first frame arrived about two seconds after release.
- **🚫** Do not implement the debugger mechanism.
- **🚫** Do not accept `notify_ready` without a narrower boundary audit.

### Frame-clock inhibition follow-up

Mutter exports the preservation API:

- **ℹ️** `clutter_frame_clock_inhibit()`
- **ℹ️** `clutter_frame_clock_uninhibit()`
- **ℹ️** `clutter_actor_peek_stage_views()`
- **ℹ️** `clutter_stage_view_get_frame_clock()`

The final temporary native probe:

- **ℹ️** Loads a helper into Mutter only.
- **ℹ️** Enumerates stage views at `Rpc.Server.start()`.
- **ℹ️** Inhibits each view clock through the public API.
- **ℹ️** Uninhibits at `Meta.Context.notify_ready`.
- **ℹ️** Leaves stock and product JavaScript unchanged.

Two isolated runs produced:

- **ℹ️** One stage frame clock found and inhibited.
- **ℹ️** Zero `before-update` notifications before release.
- **ℹ️** `READY=1` and `Meta.Context.notify_ready` reached.
- **ℹ️** First pending frame after `10.3 ms` and `11.5 ms`.
- **ℹ️** No negative preferred height.
- **ℹ️** No `ClutterBoxLayout` abort.
- **ℹ️** Normal frames until the prove harness timeout.

This proves the public inhibit/uninhibit mechanism preserves and releases
the pending frame. It replaces the earlier schedule-dropping probe.

Early debugger and symbol-interposition attempts were inconclusive.
They are not part of the proof.

### Callback corridor rejected

Stock `init.js` installs a `setMainLoopHook()` that:

1. queues `Main.start()` on the client GLib loop;
2. calls `global.context.run_main_loop()`.

Therefore `eval_module_file(init.js)` does not return at the startup yield.
A callback wrapped around that call would remain active for the shell
lifetime.

- **🚫** Do not add the earlier `run_startup_turn(callback)` design.
- **🚫** Do not use `Connection.emit_wait_poll()` as a shell-lifetime loop.

### Control flow

**ℹ️ Control direction:** the client remains the driver.

```text
server spawns client
client connects
Vala host calls begin_shell_startup
server inhibits every stage-view frame clock
Vala host evaluates stock init.js
server continues servicing all RPC
stock JS calls Meta.Context.notify_ready
server uninhibits the clocks in that RPC turn
pending frame runs after the turn returns
```

### Add — `StartupFrameGate`

**New file:** `src/rpc/StartupFrameGate.vala`

**✔️ Add:**

```vala
namespace GnomeShellRpc.Rpc
{
	public class StartupFrameGate : GLib.Object
	{
		private Clutter.Actor stage;
		private Gee.HashSet<Clutter.FrameClock> clocks = new Gee.HashSet<Clutter.FrameClock>();
		private ulong stage_views_changed_id;
		private ulong connection_stopped_id;

		[CCode (cname = "clutter_stage_view_get_frame_clock",
			cheader_filename = "clutter/clutter.h")]
		private static extern Clutter.FrameClock frame_clock(Clutter.StageView view);

		public Connection? connection { get; private set; }

		public StartupFrameGate(Meta.Display display)
		{
			this.stage = display.get_context().get_backend().get_stage();
		}

		public bool begin(Connection connection)
		{
			if (this.connection != null) {
				return false;
			}

			this.connection = connection;
			this.connection_stopped_id = connection.stopped.connect(() => {
				if (this.connection == connection) {
					this.release_internal();
				}
			});
			this.stage_views_changed_id = this.stage.stage_views_changed.connect(
				this.reconcile_views);
			this.reconcile_views();

			if (this.clocks.size == 0) {
				this.release_internal();
				return false;
			}
			return true;
		}

		public bool release(Connection connection)
		{
			if (this.connection == null) {
				return true;
			}
			if (this.connection != connection) {
				return false;
			}
			this.release_internal();
			return true;
		}

		private void reconcile_views()
		{
			var current = new Gee.HashSet<Clutter.FrameClock>();
			foreach (var view in this.stage.peek_stage_views()) {
				var clock = StartupFrameGate.frame_clock(view);
				current.add(clock);
				if (!this.clocks.contains(clock)) {
					clock.inhibit();
				}
			}

			foreach (var clock in this.clocks) {
				if (!current.contains(clock)) {
					clock.uninhibit();
				}
			}
			this.clocks = current;
		}

		private void release_internal()
		{
			if (this.stage_views_changed_id != 0) {
				this.stage.disconnect(this.stage_views_changed_id);
				this.stage_views_changed_id = 0;
			}
			if (this.connection != null && this.connection_stopped_id != 0) {
				this.connection.disconnect(this.connection_stopped_id);
				this.connection_stopped_id = 0;
			}
			foreach (var clock in this.clocks) {
				clock.uninhibit();
			}
			this.clocks.clear();
			this.connection = null;
		}
	}
}
```

**Contract:**

- **✔️** One gate shared by `Bootstrap` and the context helper.
- **✔️** One public owning `Rpc.Connection`.
- **✔️** One strong reference per inhibited `Clutter.FrameClock`.
- **✔️** One inhibit count per stored clock.
- **✔️** A `stage-views-changed` handler while active.

**✔️ `begin(connection)`:**

1. reject a second active owner;
2. remember the requesting connection;
3. enumerate `stage.peek_stage_views()`;
4. call the real C frame-clock getter, then `inhibit()` once per clock;
5. connect the stage-view and connection-stop handlers.

**✔️ `reconcile_views()`:**

- inhibit newly added view clocks once;
- uninhibit removed view clocks once;
- leave unchanged clocks untouched.

**✔️ `release(connection)`:**

1. reject a non-owner while active;
2. disconnect lifecycle handlers;
3. call `uninhibit()` once on every stored clock;
4. clear the owner and clock set.

`uninhibit()` preserves the pending frame.
No manual `schedule_update()` is required.

### Add — client-owned start RPC

**File:** `src/rpc/Bootstrap.vala`

**✔️ Remove:**

```vala
public Meta.Display meta_display { get; private set; }

public static void rpc_register()
{
	OLLMrpc.Bin.register("Bootstrap", typeof(Bootstrap));
	OLLMrpc.Request.add_class(
		"RPC-Bootstrap", typeof(Bootstrap),
		"get_display", "",
		null
	);
}

public static Bootstrap bind(Meta.Display display)
{
	var bootstrap = new Bootstrap();
	bootstrap.meta_display = display;
	return bootstrap;
}
```

**✔️ Replace with:**

```vala
public Meta.Display meta_display { get; private set; }
public StartupFrameGate gate { get; private set; }

public static void rpc_register()
{
	OLLMrpc.Bin.register("Bootstrap", typeof(Bootstrap));
	OLLMrpc.Request.add_class(
		"RPC-Bootstrap", typeof(Bootstrap),
		"get_display", "",
		"begin_shell_startup", "",
		null
	);
}

public static Bootstrap bind(Meta.Display display, StartupFrameGate gate)
{
	var bootstrap = new Bootstrap();
	bootstrap.meta_display = display;
	bootstrap.gate = gate;
	return bootstrap;
}
```

**✔️** The server creates the gate after assigning `this.display` and injects
it with `Bootstrap.bind(this.display, frame_gate)`.

Constructing `Bootstrap` before the existing OCRPC and GI registration block
was tested and rejected. It changed registration order and failed with:

```text
unknown alias 'Clutter-OffscreenEffect'
```

The final code leaves `Bootstrap` construction at the original late
registration point. Only the already-created gate is passed into `bind()`.

**✔️ Remove the boundary before `get_display()`:**

```vala
	public void get_display(OLLMrpc.Request request)
	{
```

**✔️ Replace with:**

```vala
public void begin_shell_startup(OLLMrpc.Request request)
{
	if (!this.gate.begin((Connection) request.connection)) {
		request.connection.reply_error(
			request, (int) OLLMrpc.RpcErrorCode.INVALID_REQUEST);
		return;
	}
	request.reply(new OLLMrpc.Response() {
		id = request.id,
	});
}

	public void get_display(OLLMrpc.Request request)
	{
```

- **✔️** Pass `request.connection` to `gate.begin()`.
- **✔️** Reply after every current frame clock is inhibited.
- **✔️** Reject another connection while the gate is active.

This is an owned bootstrap RPC.
It is not a stock GI method.

### Change — default client launch

**File:** `src/shell-client/ShellApplication.vala`

**✔️ Remove:**

```vala
if (script.has_prefix("resource://")
		|| script.contains("/ui/init.js")
		|| script.contains("/gjs-embed/")) {
	uint8 module_status = 0;
	ok = ctx.eval_module_file(script, out module_status);
	status = module_status;
} else {
	ok = ctx.eval_file(script, out status);
}
```

**✔️ Replace with:**

```vala
if (script == INIT_MODULE || script.has_suffix("/ui/init.js")) {
	GnomeShellRpc.call_value("RPC-Bootstrap.begin_shell_startup");
}
if (script.has_prefix("resource://")
		|| script.contains("/ui/init.js")
		|| script.contains("/gjs-embed/")) {
	uint8 module_status = 0;
	ok = ctx.eval_module_file(script, out module_status);
	status = module_status;
} else {
	ok = ctx.eval_file(script, out status);
}
```

**Ordering:**

1. complete existing context and preload setup;
2. call `RPC-Bootstrap.begin_shell_startup`;
3. evaluate the unchanged stock `init.js`.

- **✔️** Apply this only to the product `init.js` path.
- **🔷** Keep named smoke scripts on their current direct path.
- **✔️** Do not evaluate `init.js` after begin-RPC failure.

### Change — stock `notify_ready` server handler

**File:** `src/rpc/helper/Context.vala`

**✔️ Remove:**

```vala
public class Context : GLib.Object
{
	public static void rpc_register()
	{
		var helper = new Context();
		OLLMrpc.Request.add_class(
			"Helper-Context", typeof(Context),
			"terminate_with_error", "sis",
			null
		);
		OLLMrpc.Request.register_live("Helper-Context", helper);

		OLLMrpc.Request.add_class(
			"Meta-Context", typeof(Context),
			"terminate", "",
			null
		);
		OLLMrpc.Request.register_live("Meta-Context", helper);
	}

	public void terminate_with_error(
}
```

**✔️ Replace with:**

```vala
public class Context : GLib.Object
{
	private StartupFrameGate gate;

	public Context(StartupFrameGate gate)
	{
		this.gate = gate;
	}

	public static void rpc_register(StartupFrameGate gate)
	{
		var helper = new Context(gate);
		OLLMrpc.Request.add_class(
			"Helper-Context", typeof(Context),
			"terminate_with_error", "sis",
			null
		);
		OLLMrpc.Request.register_live("Helper-Context", helper);

		OLLMrpc.Request.add_class(
			"Meta-Context", typeof(Context),
			"terminate", "",
			"notify_ready", "",
			null
		);
		OLLMrpc.Request.register_live("Meta-Context", helper);
	}

	public void notify_ready(OLLMrpc.Request request)
	{
		if (!this.gate.release((GnomeShellRpc.Rpc.Connection) request.connection)) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_REQUEST);
			return;
		}

		((Meta.Context) request.connection.leases.get(
			(int) request.lease_id)).notify_ready();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});
	}

	public void terminate_with_error(
}
```

1. if the gate is active, require the owning connection;
2. release the gate;
3. call the real `Meta.Context.notify_ready()`;
4. reply to the RPC.

Uninhibition occurs inside the RPC turn.
The pending frame cannot dispatch until that turn returns.

When no gate is active, preserve the current stock call behavior.

### Change — disconnect cleanup

**File:** `src/rpc/Connection.vala`

**✔️ Remove:**

```vala
private int emit_poll_depth = 0;

public Connection(GLib.SocketConnection? stream = null)
{
	GLib.Object(stream: stream);
}

public override void emit_wait_poll()
{
```

**✔️ Replace with:**

```vala
private int emit_poll_depth = 0;
private bool stopped_emitted = false;

public signal void stopped();

public Connection(GLib.SocketConnection? stream = null)
{
	GLib.Object(stream: stream);
}

public override void stop()
{
	if (this.stopped_emitted) {
		base.stop();
		return;
	}

	this.stopped_emitted = true;
	base.stop();
	this.stopped();
}

public override void emit_wait_poll()
{
```

- **✔️** Add an idempotent `stopped` signal.
- **✔️** Emit it once from the `stop()` override.
- **✔️** Connect cleanup only while the connection owns the gate.

A disconnect must uninhibit all clocks.
It must not leave Mutter permanently frame-blocked.

### Change — server wiring

**File:** `src/rpc/Server.vala`

**✔️ Remove:**

```vala
this.display = display;
OLLMrpc.rpc_register(true);
```

**✔️ Replace with:**

```vala
this.display = display;
var frame_gate = new StartupFrameGate(display);
OLLMrpc.rpc_register(true);
```

**✔️ Remove:**

```vala
Rpc.Helper.rpc_register();
```

**✔️ Replace with:**

```vala
Rpc.Helper.rpc_register(frame_gate);
```

**✔️ Remove:**

```vala
var bootstrap = Bootstrap.bind(this.display);
OLLMrpc.Request.register("RPC-Bootstrap", bootstrap);
```

**✔️ Replace with:**

```vala
var bootstrap = Bootstrap.bind(this.display, frame_gate);
OLLMrpc.Request.register("RPC-Bootstrap", bootstrap);
```

The late `Bootstrap.bind()` location is deliberate. It preserves the existing
OCRPC, helper, and GI registration order.

**File:** `src/rpc/helper/namespace.vala`

**✔️ Remove:**

```vala
public void rpc_register()
{
	SoundPlayer.rpc_register();
	// Existing registrations.
	Context.rpc_register();
	Settings.rpc_register();
}
```

**✔️ Replace with:**

```vala
public void rpc_register(StartupFrameGate gate)
{
	SoundPlayer.rpc_register();
	// Existing registrations.
	Context.rpc_register(gate);
	Settings.rpc_register();
}
```

**File:** `src/meson.build`

**✔️ Remove:**

```meson
'rpc/Bootstrap.vala',
'rpc/Daemon.vala',
```

**✔️ Replace with:**

```meson
'rpc/Bootstrap.vala',
'rpc/StartupFrameGate.vala',
'rpc/Daemon.vala',
```

1. create one gate after the display is assigned;
2. pass that gate to helper registration;
3. inject the same gate when Bootstrap is constructed at its original point;
4. add `rpc/StartupFrameGate.vala` to compositor sources.

### Remove / do not add

- **🚫** No copied or patched `panelMenu.js`.
- **🚫** No copied or patched `quickSettings.js`.
- **🚫** No new startup JavaScript adapter.
- **🚫** No layout clamp.
- **🚫** No idle, timeout, worker thread, or deferred notification.
- **🚫** No generic RPC ordering change.

### Boundary

- **🔷 Start:** client RPC immediately before evaluating stock `init.js`.
- **✔️ End:** the existing `Meta.Context.notify_ready` RPC.
- **🚫 Not:** process spawn.
- **🚫 Not:** `startup-complete`.
- **ℹ️** This is wider than the exact upstream synchronous turn.

### Proof

**⏳ 🔷 Add a frame-gate contract:**

```text
schedule server frame marker
owner opens startup frame gate
client performs nested synchronous RPC
assert marker remains pending
non-owner cannot release gate
owner calls Meta.Context.notify_ready
assert one pending frame runs
```

**⏳ 🔷 Required results:**

- **⏳ 🔷** `reentrant-emit-call-gate` remains PASS.
- **⏳ 🔷** Frame-gate contract is PASS.
- **⏳ 🔷** Disconnect gate releases every clock.
- **⏳ 🔷** Stage-view replacement balances inhibit counts.
- **✔️** Add-before-hide remains the red outside-turn control.
- **✔️** Hidden-tree smoke remains PASS.
- **✔️** Two full boots had no mapped empty-grid abort.
- **✔️** Two full boots reached ready and stayed up to the harness timeout.

### Open points

- **⏳ 💩** Audit work suppressed until `notify_ready`.
- **⏳ 💩** Decide whether a narrower existing Vala-visible marker exists.
- **⏳ 💩** Confirm `stage-views-changed` fires before a replacement clock
  can dispatch.

Failure of any open point means revise the boundary.
Do not ship the debugger, preload helper, or timing logic.

## RPC queue semantics are not the fix

An initial interpretation called in-flow notification dispatch a libocrpc
ordering defect. That was not established and has been retracted.

`OLLMrpc.Client.call_poll()` explicitly promises to demultiplex
`Live.Invoke` **and** `Notification` messages while waiting. The existing
`notif-nested-call-gate` intentionally proves that a notification handler can
make a nested synchronous call before the outer `call_poll()` returns.
Moving notifications to an idle callback or dispatching them only after
`call_poll()` returns would reverse that contract, create out-of-band work,
and risk breaking frame-sensitive handlers such as `before-update`.

The trace proves that this established queue behavior exposes an in-process
GNOME Shell assumption between `add_child()` and `hide()`. It does not prove
that the queue behavior is wrong. Any eventual fix needs its own FAIL-backed
contract at the consumer/RPC boundary; changing generic notification
scheduling is not currently an allowed candidate.

## Manual `style-changed` subscription checked

The suspicious post-mint block in
`src/gi-stub/overrides-clutter/Actor.override.vala` was removed temporarily,
rebuilt, and tested. Full boot still produced the same `style-changed`,
mapped Quick Settings ancestry, `-12`, and `ec=133`.

That block is not this failure's subscription path: it only runs for
non-helper subclasses minted through a registered ancestor. The Quick
Settings grid is a Helper-Actor, and stock `QuickSettingsLayout` explicitly
does:

```js
this._container?.connectObject('style-changed',
    () => this._containerStyleChanged(), this);
```

The explicit connection legitimately requests the remote signal and updates
`row_spacing` to 12. The temporary removal has therefore been reverted.
The broader design remains open in
[`style-changed manual subscription`][style-subscription].
Removing it is not a fix for this bug.

## Not this bug

`Clutter.Text.get_layout` —
[`text get-layout`](done/2026-09-25-text-get-layout-pango-layout.md).

[style-subscription]: 2026-09-22-style-changed-manual-subscription.md
