# A click notification comes back, and the client does not launch

**Status:** ⏳ open. `Signals.emit` calls the class slot after `emitv` only for `clicked`. A hold on 2026-09-28 09:32 reached `READY=1`, then the client vanished. Last client line is `St-Bin.get_child` with `notify::allocation` in flight. Mutter stayed up. A live click still has to show `Helper-AppLaunch`.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Seen from:** [`2026-09-24-overview-picker-preview-gone.md`](2026-09-24-overview-picker-preview-gone.md). Clicking Terminal does not start it. Calling `Shell.App.launch` directly does.

The **client** is `gnome-shell-rpc`. The **server** is `mutter-rpc`. This is the order things happen.

## Seen (2026-09-28 09:00)

Live nest, `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`. Three presses: 09:00:49.851, 09:00:51.044, 09:00:51.244.

Each press logs `notification method=button-press-event`, then `notification method=clicked` about 120ms later (09:00:49.968, 09:00:51.177, 09:00:51.329). After each `clicked` the next lines are `before-update` and the in-flight `St-Widget.get_theme_node` reply. No `JS ERROR` on that notification. No `Helper-AppLaunch` anywhere in the log. `Signals.emit` is still `emitv` only (`src/shell-gi/Signals.vala`).

The same presses throw earlier, on `button-press-event`:

```
JS ERROR: Could not locate clutter_event_get_device
_onButtonPress@resource:///org/gnome/shell/ui/dnd.js:184
_onCapturedEvent@resource:///org/gnome/shell/ui/searchController.js:311
```

`dnd.js:184` is `event.get_device()`. That is the button-press handler. The server still sent `clicked`. The launch is still the missing class handler on that signal.

## 1. The object is created

On the **client**, the app icon is constructed. `create_with_overrides` in `Actor.override.vala` asks the server for a button. The reply is a lease. After that line, the client has three things:

- `this`, the shell object
- `this.get_type()`, the JavaScript class (`Gjs_…`)
- `this.rpc_lid`, the server button that create just made

```c
/* client, create_with_overrides */
response = GnomeShellRpc.call_value ("Helper-Actor.create", ...);
this.rpc_lid = response.args.get (0).get_uint64 ();
```

## 2. The client subscribes, with what it has then

Still in that function, still on the **client**, before any click. It does not send a function and it does not send a byte offset. It sends the object from step 1 and the string `"clicked"`.

```c
/* client, create_with_overrides, immediately after the lease */
if (GLib.Signal.lookup ("clicked", this.get_type ()) != 0)
	ensure_signal_subscribe (this, "clicked");
```

`Signal.lookup` is true because `Gjs_…` inherits our generated `St.Button`, and that class has a signal named `clicked`. It does not read `klass->clicked`. Every `St.Button` passes, whether or not the JavaScript class defined `vfunc_clicked`.

The read that does notice a virtual is earlier in this same function, and it is only `Clutter.Actor` against `StWidget` (`VfuncRelay.overridden`). `clicked` is not in that list. Create does not carry it. Nothing at construction says `vfunc_clicked` was defined.

Signal registration is the `connect` wrap in `src/shell-js/signals.js`. JavaScript calls `connect('clicked', fn)`, and the wrap tells the server. `AppIcon` does not call `connect` for this. It defines `vfunc_clicked` on the class. GJS writes that into `klass->clicked` at class init and does not tell us. There is no signal that a `vfunc_` method was defined. The same read as `overridden`, on `St.Button` / `clicked`, is the moment we can see it. That read is not done.

`ensure_signal_subscribe` is `Shell.Signals.connect (this, "clicked", 0)`:

```c
/* client, Signals.connect */
/* walk parents, skip Gjs_ names, stop at St.Button, confirm it has "clicked" */
if (!exists_on_peer (obj, "clicked"))
	return 0;

GnomeShellRpc.call_value ("RPC-Live-Subscribe.rpc_signal",
	obj, OLLMrpc.args ("s", "clicked"));
```

`obj` is `this` from step 1. The server picks the button from `obj.rpc_lid`. The argument is only `"clicked"`. The client also remembers, locally, lease → this object, and lease → the name `"clicked"`.

## 3. The user clicks

On the **server**, that button's `clicked` runs. Mutter notices the subscription from step 2: this lease, the name `clicked`. It sends a notification. The notification is the lease, the name `clicked`, and the button number. Nothing else.

## 4. The client receives it

On the **client**, the handler from step 2 runs.

Where it looks up: `notif.id` is the lease from step 1. `proxies.get (notif.id)` is `this`, the same shell object. `notif.method` is the string `"clicked"`.

```c
/* client, Signals.vala — notification */
var target = proxies.get (notif.id);
Signals.emit (target, notif.method, notif.args);
```

What it calls: the subscription from step 2. The name on the notification is `"clicked"`. `Signals.emit` looks that name up on the object and emits that signal.

```c
/* client, Signals.emit */
GLib.Signal.parse_name ("clicked", obj.get_type (), &signal_id, ...);
Signals.emitv (vals, signal_id, detail, NULL);
```

That is the whole lookup. The JavaScript object does not have a method named `clicked`. `AppIcon` in `vendor/gnome-shell/js/ui/appDisplay.js` defines this method:

```js
/* vendor/gnome-shell/js/ui/appDisplay.js — class AppIcon */
vfunc_clicked(button) {
    this._removeMenuTimeout();
    this.activate(button);
}
```

`vfunc_` is GJS's prefix, not ours. A JavaScript class overrides a C virtual named `clicked` by defining `vfunc_clicked`. GJS writes that method into the C field `klass->clicked`. Emitting the signal `clicked` is supposed to call that field. The shell never does `connect('clicked', ...)`.

Our Vala name is the other way around. The signal owns the Vala name `signal_clicked` (C name `"clicked"`). The virtual is `clicked_vfunc`, with `vfunc_name = "clicked"`, so its C field is also `klass->clicked`. Same field as GJS's `vfunc_clicked`. Two spellings, one slot.

The Vala we generate for that one signal is two members. From `St_generated.vala`:

```vala
/* the signal. C name "clicked" is the string in the subscribe and the notification */
[CCode (cname = "clicked")]
public signal void signal_clicked (int32 clicked_button);

/* the default handler. vfunc_name = "clicked" is the class field GJS fills from vfunc_clicked */
[CCode (cname = "gsr_button_clicked_vfunc", vfunc_name = "clicked")]
public virtual void clicked_vfunc (int32 clicked_button) {
}
```

Valac turns those into:

```c
/* client, St.Button class init */
klass->clicked = slot_button_real_clicked_vfunc;   /* the field vfunc_clicked overwrites */
g_signal_new ("clicked", TYPE_SLOT_BUTTON, G_SIGNAL_RUN_LAST,
	0, ...);                                       /* the signal Signals.emit fires */
```

GJS then does `klass->clicked =` the JavaScript `vfunc_clicked`. Same field. `Signals.emit` fires the signal created by `g_signal_new`, not `clicked_vfunc` by name.

## 5. Firing that signal does not call `vfunc_clicked`

`g_signal_new` was passed `0`. That means the signal has no default handler. `emitv` runs `connect('clicked')` handlers only. There are none. It does not call `klass->clicked`, so `vfunc_clicked` does not run, and `activate` does not run. The notification was the `clicked` signal. The launch is the default handler of that signal, and this registration left the handler out.

## Gate

`tests/clicked-slot-emit-gate` is only step 5, in one process. `g_signal_new (..., 0, ...)` and a subclass that sets `klass->clicked`. Emit leaves that function at 0 calls.

The gate then tells GLib, at class init, to call `klass->clicked` when the signal is emitted. The function runs: `hits=1`, exit 0. That tell is not in the shell. Step 2 does not send it.

Doing that call while `call_poll` is still inside JavaScript crashed the client ([`2026-09-23-prefix-generated-vala-signals.md`](2026-09-23-prefix-generated-vala-signals.md)). The gate runs it from `main`.

## Design

`signal_overrides` is in `Actor.override.vala` and runs from `construct`. The class-slot call is in `Signals.emit` after `emitv`, and only when the virtual is `clicked`.

**⏳ 🔷** One method on `Clutter.Actor`, `signal_overrides`, called from the existing `construct` after `create_with_overrides`. It calls itself on the parent type. No class names are passed in. No second constructor. The name is two words. `register_overridden_signals` is four, which the coding standard rejects.

**ℹ️** `VfuncRelay.overridden` already walks `Clutter.Actor` and sends those with create. It caches by type, so it cannot be called again for another class. This method is the same compare, for every parent `gtype_to_alias` already knows.

**ℹ️** `connect()` never sees `vfunc_clicked`. `AppIcon` does not call it.

**🚫** A `while` walk. **🚫** Naming `St.Button` or `clicked` at the call.

### Remove

`src/gi-stub/overrides-clutter/Actor.override.vala`, the `Signal.lookup ("clicked")` block inside `create_with_overrides`, and the `Signal.lookup ("style-changed")` block in `construct`.

### Add

Call, in `construct`, after `create_with_overrides`:

```vala
this.signal_overrides(this.get_type());
```

The first call is this object. It registers the parent before itself. The leaf is not compared with itself. A parent with no alias (`Gjs_…`) is skipped. A virtual is subscribed only when this object's pointer differs from that parent and the name is a signal. `allocate` is not a signal, so it stays on the create list.

```vala
/**
 * Subscribe each signal whose virtual this object replaced.
 *
 * Called from construct with this object's type. Calls itself
 * on the parent first. A type with no alias is skipped. The
 * leaf is not compared with itself.
 *
 * @param t parent type to compare against this object
 */
private void signal_overrides(GLib.Type t)
{
	if (t == GLib.Type.INVALID) {
		return;
	}
	this.signal_overrides(t.parent());
	if (t == this.get_type()) {
		return;
	}
	if (OLLMrpc.Bin.gtype_to_alias == null) {
		return;
	}
	if (!OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
		return;
	}
	var alias = OLLMrpc.Bin.gtype_to_alias.get(t);
	var dot = alias.index_of("-");
	if (dot < 0) {
		return;
	}
	var ns = alias.substring(0, dot);
	var class_name = alias.substring(dot + 1);
	var leaf = this.get_type();
	foreach (var name in OLLMrpc.Gi.vfunc_names(ns, class_name)) {
		var ours = OLLMrpc.Gi.vfunc_slot(leaf, ns, class_name, name);
		var plain = OLLMrpc.Gi.vfunc_slot(t, ns, class_name, name);
		if (ours == plain) {
			continue;
		}
		var signal_name = name.replace("_", "-");
		if (GLib.Signal.lookup(signal_name, leaf) == 0) {
			continue;
		}
		GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe(this, signal_name);
	}
}
```

### Add

Inside `Signals.emit`, after `emitv`. **🚫** a new function. `g_signal_new` was passed `0`, so `emitv` does not call the method. The call is the pointer already in the class, written in `emit` itself.

**🚫** Do not limit this call to one signal name. A name check hides a null `closure.marshal`. `g_signal_type_cclosure_new` reads the class function, then calls `closure.marshal`. That field is unset, so the call jumps to address 0 when the class function is non-null. A null class function returns inside the meta marshaller and does not crash. Set `g_cclosure_marshal_generic` before `invoke`. The call stays for every replaced virtual.

`g_signal_type_cclosure_new` returns a floating closure with one ref. `sink()` before `invoke()` frees it, and `invoke()` hits `g_closure_ref` (`ref_count > 0`). Invoke first, then sink. That was the 09:11 boot stop, on `notification method=event`.

Hold `nested-weston-hold` (not a settle SIGKILL). `READY=1` at 09:31:42. Client log ends 09:32:07.907:

```
id=11712 method=St-Bin.get_child
notification method=notify::allocation
property 'allocation' of object class 'StWidget' is not writable
replied id=11712
```

No further client line. `gnome-shell-rpc` is gone. `mutter-rpc` is still up. Same stop as the earlier invoke: `notify::allocation` during `St-Bin.get_child`, while `call_poll` is inside JavaScript. `style-changed` had just been notified (09:32:07.851–07.871). That notification's class function is set, so the unset marshaller is what jumps to address 0. Do not answer that by naming `clicked`.
