# ScrollViewFade: shader-type setter runs inside get_effect's reply

**Status:** ✔️ **closed** (2026-09-28) — user: scroll-view fade shader type is fixed.

The hand override is gone. `shader-type` now matches the `.new` argument `shader_type`, so the construct setter calls `rpc_ctor_stash` and `construct` calls `Clutter-ShaderEffect.new` with `rpc_ctor_get`. A different leaf (`St-ScrollViewFade`) still uses its own zero-arg `.new`. `set_property` is not called.

**Plan:** [`../../plans/0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)

**Not** the Terminal click ([`../2026-09-27-clicked-signal-misses-vfunc.md`](../2026-09-27-clicked-signal-misses-vfunc.md)). The shell gets through overview and search, then dies while laying out a scroll view.

The **client** is `gnome-shell-rpc`. The **server** is `mutter-rpc`.

## 1. The effect already exists on the server

On the **client**, layout asks an actor for its fade effect. `Clutter-Actor.get_effect` is still waiting on its reply. The reply contains the effect. Decoding it builds a client `St.ScrollViewFade`.

`ScrollViewFade` extends `Clutter.ShaderEffect`. The lease construct does not pass the shader type. It calls `.new` with no arguments. After that line the server object exists, and `shader-type` is already closed.

```vala
/* client, St.ScrollViewFade construct — generated */
var response = GnomeShellRpc.call_value(OLLMrpc.Bin.gtype_to_alias.get(t) + ".new");
this.rpc_lid = (response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
```

On the **server**, that object is an `StScrollViewFade`. Real Clutter marks the property construct-only. The constructor of the subclass is the only place that may set it. Default is fragment.

```xml
<!-- Clutter-16.gir, Clutter.ShaderEffect -->
<property name="shader-type" writable="1" construct-only="1"
          default-value="COGL_SHADER_TYPE_FRAGMENT"/>
```

There is a client constructor that does pass the type, `ShaderEffect(Cogl.ShaderType)`. `ScrollViewFade` does not use it. The lease walk above is what runs.

## 2. The construct setter sends set_property anyway

`shader_type` is generated as a construct property. The setter does not remember the value. It always calls the server.

```vala
/* client, Clutter_generated.vala — ShaderEffect.shader_type */
construct {
    GnomeShellRpc.call_value(
        "Clutter-ShaderEffect.set_property", this,
        OLLMrpc.args("si", "shader-type", value));
}
```

GObject runs that setter while the client is still inside `get_effect`. The log order is the call, with no reply in between:

- `Clutter-Actor.get_effect` goes out
- `Clutter-ShaderEffect.set_property` goes out before that reply is finished

`St.ScrollView` already refuses this shape. Its policy properties are not `construct`, because a setter that RPCs during `Object.new` runs inside the reply parse and desynchronizes the socket. `shader_type` is that setter.

## 3. The server refuses, and the client reads the reply as a new message

On the **server**, `g_object_set` of `shader-type` on the existing `StScrollViewFade` logs that a construct property cannot be set after construction. The object is unchanged.

On the **client**, the parser is still in the `get_effect` reply. The nested `set_property` reads the next byte of that reply as the start of a new message. The byte is `0x00`. `Client.vala` turns that into `GLib.error`, and the process exits. The server then sees `Connection reset by peer`.

```text
expected object type byte, got 0x00
```

## What this is not

It is not the class-slot call in `Signals.emit`. That call is out. `style-changed` notifications in the same boot parsed normally.

It is not a missing `shader-type` on the wire name. The name is correct. The call is the wrong moment, and the server property is already closed.
