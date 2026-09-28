# Layout stores a box, then tells the client

**Status:** ⏳ open. The GIR property `allocation` is read-only. `relay_allocation` stores the box on the server. It is not a new GIR method. `notify::allocation` arrives as `notify::allocation-relay`.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Seen from:** [`2026-09-24-notify-allocation-not-writable.md`](2026-09-24-notify-allocation-not-writable.md).

The **client** is `gnome-shell-rpc`. The **server** is `mutter-rpc`. This is the order things happen.

## Seen

Three runs on 2026-09-28.

- 12:16. The **client** received the notification and updated its own box. The session reached ready.
- 12:43. The **server** was never told the box. It logged actors with no allocation.
- 12:48. The **client** notification also told the **server** the box. The session died.

## 1. Mutter calls our actor's allocate

On the **server**, the actor is `Helper.Actor` in `src/rpc/helper/ClutterActor.vala`. It extends `St.Widget`. We created it earlier with `Helper-Actor.create`.

Mutter calls `allocate` on that object. The function that runs is our override in that file.

If this actor has no allocate callback, our override calls `base.allocate` and this flow stops.

```c
/* server, src/rpc/helper/ClutterActor.vala — our override */
public override void allocate (Clutter.ActorBox box) {
	var hook = this.vfuncs.get (ActorVfuncIds.allocate_id);
	if (hook == null) {
		base.allocate (box);
		return;
	}
	if (LayoutHooks.measure_allocate (hook, this, box))
		return;
	base.allocate (box);
}
```

## 2. That override calls the callback

Still on the **server**. `measure_allocate` in `src/rpc/helper/LayoutHooks.vala` fires the callback the client registered when the actor was created.

The arguments are the actor's lease and the box. The client answers with one boolean. `true` tells our override to call `base.allocate`. `false` tells it to stop.

```c
/* server, src/rpc/helper/LayoutHooks.vala */
hook.emit (OLLMrpc.args ("tdddd",
	lease, box.x1, box.y1, box.x2, box.y2));
```

The callback was registered on the **client**, in `create_with_overrides` in `src/gi-stub/overrides-clutter/Actor.override.vala`. `bind_vfunc("allocate")` returns `relay_allocate`. That id is sent in `Helper-Actor.create` and stored on the server actor.

## 3. The callback runs relay_allocate

On the **client**, the callback is `relay_allocate` in `Actor.override.vala`. It rebuilds the box and calls the function in this actor's allocate slot.

```c
/* client, src/gi-stub/overrides-clutter/Actor.override.vala */
uint64 relay_allocate () {
	return Runtime.callback_bind ((call) => {
		box.x1 = (float) call.args.get (1).get_double ();
		box.y1 = (float) call.args.get (2).get_double ();
		box.x2 = (float) call.args.get (3).get_double ();
		box.y2 = (float) call.args.get (4).get_double ();
		vfunc_call_void_pointer (this, offset_of_allocate, &box);
	});
}
```

`vfunc_call_void_pointer` is `src/gi-stub/c-vfunc-relay.c`. It reads the function pointer on this object's class and calls it. The object is the client actor, the same GJS object.

## 4. That slot is the shell's JavaScript

The function in the slot is `vfunc_allocate` on the actor's JavaScript class. GJS put it there. For a widget that does not define one, the slot is still the parent class, and `relay_allocate` tells the server to use `base.allocate`.

This JavaScript is gnome-shell's ui code, running in the client.

A widget's `vfunc_allocate` then calls `set_allocation` on that same actor. That method is `Clutter.Actor.set_allocation`. GJS exposes it as `actor.set_allocation(box)`. The shell calls it to store the box on the actor.

```js
/* gnome-shell JavaScript, on the actor. Our smoke copies panel.js WorkspaceDot. */
vfunc_allocate(box) {
	this.set_allocation(box);
}
```

## 5. The client records the box

On the **client**, the JavaScript line is a method call on the actor:

```js
this.set_allocation(box);
```

GJS looks up a method named `set_allocation` on that actor. The function it finds is the setter of our `allocation` property, in `Actor.override.vala`.

```c
/* client, Actor.override.vala — this is the function GJS calls */
public ActorBox allocation {
	set {
		this.allocation_relay = value;
	}
}
```

The setter saves the box on the client actor. Allocate stops here.

## 6. The correct state

This is the end of the allocate call. Both sides have the box Mutter passed in.

- On the **server**, `Helper.Actor` holds that box.
- On the **client**, the actor's `allocation` property holds that same box.

That is the state we want every time. The answer in step 2 does not change it.

## 7. The server sends `notify::allocation`

On the **server**, `Helper.Actor`'s `allocation` changes. The handler that sends the message is hand-written, not generated. It is `rpc_signal` in `/home/alan/gitlive/OLLMchat/libocrpc/Live/Subscribe.vala`. `name` is the string the client subscribed, so for this property `name` is `notify::allocation`. The handler listens to `name` with the `notify::` prefix removed, which is the property `allocation`. The message it writes uses that same `name`.

```vala
/* /home/alan/gitlive/OLLMchat/libocrpc/Live/Subscribe.vala — rpc_signal */
if (name.has_prefix ("notify::")) {
	subscription.hid = obj.notify[name.substring (8)].connect ((pspec) => {
		var current = GLib.Value (pspec.value_type);
		obj.get_property (pspec.name, ref current);
		var helper = OLLMrpc.Bin.TypeOverride.lookup (pspec.value_type);
		var packed = new Gee.ArrayList<GLib.Value?> ();
		if (helper != null) {
			foreach (var field in helper.pack (current)) {
				packed.add (field);
			}
		}
		if (helper == null) {
			packed.add (current);
		}
		request.connection.write (new Notification () {
			method = name,
			id = id,
			args = packed
		});
	});
}
```

`helper` in that handler is `OLLMrpc.Bin.TypeOverride.lookup(pspec.value_type)`. The class is `OLLMrpc.Bin.TypeOverride` in `/home/alan/gitlive/OLLMchat/libocrpc/Bin/TypeOverride.vala`. `lookup` uses the GType of the value. For this property the type is `Clutter.ActorBox`, and the registered object is `GnomeShellRpc.Rpc.Helper.ActorBoxOverride` in `src/rpc/helper/ActorBoxOverride.vala`. `pack` is given the box and returns four numbers. It is not given the property name.

```vala
/* src/rpc/helper/ActorBoxOverride.vala */
public override Gee.ArrayList<GLib.Value?> pack (GLib.Value src)
{
	var box = (Clutter.ActorBox*) src.get_boxed ();
	return OLLMrpc.args ("dddd",
		(double) box.x1, (double) box.y1,
		(double) box.x2, (double) box.y2);
}
```

The client has its own copy, `Shell.ActorBoxOverride` in `src/shell-gi/ActorBoxOverride.vala`. `Client.vala` calls `unpack` on that to rebuild the box. The property name is still `method` on the message, not something `pack` or `unpack` chooses.

That message arrives in libocrpc `Client.vala`. The box is rebuilt, and the next line writes a property on the client actor.

```c
/* client, libocrpc Client.vala — what it does now */
var prop_name = notif.method.substring (8);   /* "allocation" */
proxies.get (notif.id).set_property (prop_name, box);
this.notification (notif);
```

`set_property` is `g_object_set_property`. It looks up a property by the name in the message and calls its setter. No GIR method, no FFI.

The message says `allocation` because that is the name the client subscribed. On the server, `method = name` in that same handler. The server actor's property is `allocation`. `allocation_relay` exists only on the client actor, so the server cannot listen to it.

**🔷** `OLLMrpc.Bin.TypeOverride` gains `rpc_signal_alias(string name)`. The base class returns `name`. `lookup` stays by GType. This method receives the signal name, `notify::allocation`.

`src/rpc/helper/ActorBoxOverride.vala` overrides it. When `name` is `notify::allocation`, it returns `notify::allocation-relay`. Vala installs the property as `allocation-relay`. Any other name is returned unchanged. The override is registered for every `ActorBox`, so it must not rename every property of that type.

`Subscribe.rpc_signal` still listens to `allocation` on `Helper.Actor`. When it writes the message, `method` is `rpc_signal_alias(name)`. `name` is already `notify::allocation`. `Client.vala` already sets the property named in the message, so it sets `allocation-relay`. `allocation` on the client keeps a getter and has no setter.

`Signals.vala` does not choose this name. The one hardcoded name there is `init-xserver`: the shell connects it with a `Gio.Task`, packing that task onto the wire killed the session, so `connect` returns without subscribing. It has nothing to do with allocation.

`allocation_relay` already stores the box and tells listeners:

```c
/* client, Actor.override.vala — the write step 7 should hit */
public ActorBox allocation_relay {
	set {
		this.allocation_priv = value;
		this.notify_property ("allocation");
	}
}
```

JavaScript `this.set_allocation(box)` from step 5 then has its own function, because `allocation` no longer has a setter.

```c
/* client, Actor.override.vala — what the setter does today */
public ActorBox allocation {
	set {
		this.allocation_relay = value;
	}
}
```

Today `set_property("allocation", box)` still enters that setter, which assigns `allocation_relay` and returns. The 12:16 run ended there and the session reached ready. The 12:48 run called `Helper.Actor` from inside that setter, and the session died.

## Proposed fix

**⏳** **🔷** Three edits. The server still listens to `allocation`. The message name changes. The client property `allocation` has no setter.

### Add

`/home/alan/gitlive/OLLMchat/libocrpc/Bin/TypeOverride.vala`, on `OLLMrpc.Bin.TypeOverride`. Default returns the name it was given.

```vala
/**
 * Signal name to write on a notify message.
 *
 * Called from {@link OLLMrpc.Live.Subscribe.rpc_signal} with the
 * subscribed name. The default returns that name unchanged.
 *
 * @param name subscribed signal, including ''notify::''
 * @return name to store in {@link OLLMrpc.Notification.method}
 */
public virtual string rpc_signal_alias(string name)
{
	return name;
}
```

### Add

`src/rpc/helper/ActorBoxOverride.vala`. This class is registered for every `ActorBox`. The argument is the full subscribed name.

```vala
public override string rpc_signal_alias(string name)
{
	if (name == "notify::allocation") {
		return "notify::allocation-relay";
	}
	return name;
}
```

### Remove

`/home/alan/gitlive/OLLMchat/libocrpc/Live/Subscribe.vala`, the `helper` check and the write inside the `notify::` handler. The listen, `obj.notify[name.substring(8)]`, stays.

```vala
var packed = new Gee.ArrayList<GLib.Value?>();
if (helper != null) {
	foreach (var field in helper.pack(current)) {
		packed.add(field);
	}
}
if (helper == null) {
	packed.add(current);
}
request.connection.write(new Notification() {
	method = name,
	id = id,
	args = packed
});
```

### Replace with

`rpc_signal_alias` is called on `helper` inside the check that already calls `pack`. `name` is `notify::allocation`.

```vala
var packed = new Gee.ArrayList<GLib.Value?>();
var method_name = name;
if (helper != null) {
	foreach (var field in helper.pack(current)) {
		packed.add(field);
	}
	method_name = helper.rpc_signal_alias(name);
}
if (helper == null) {
	packed.add(current);
}
request.connection.write(new Notification() {
	method = method_name,
	id = id,
	args = packed
});
```

`Client.vala` is unchanged. `notify::allocation-relay` makes it call `set_property("allocation-relay", box)`.

### Replace

`src/gi-stub/overrides-clutter/Actor.override.vala`. `allocation` is readable. The setter goes, so JavaScript `this.set_allocation(box)` is no longer this property.

```vala
public ActorBox allocation {
	get {
		return this.allocation_priv;
	}
}
```
