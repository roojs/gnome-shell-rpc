# Barrier construct setter runs before the lease

**User goal:** nested mutter-rpc + gnome-shell-rpc stays up and answers pointer and keyboard. From [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md).

**Status:** ⏳ open

**Seen:** 2026-09-24 17:07:49, `org.gnome.ShellRpc.debug.log`.

GJS creates the barrier with a property bag. That is `g_object_new`. GObject sets construct properties first, then runs the class `construct` block. The log is that order: seven `set_property` criticals, then `.new`.

```js
this._rightPanelBarrier = new Meta.Barrier({
    backend: global.backend,
    x1: primary.x + primary.width, y1: primary.y,
    x2: primary.x + primary.width, y2: primary.y + this.panelBox.height,
    directions: Meta.BarrierDirection.NEGATIVE_X,
});
```

`layout.js:593`. `flags` is not in that bag. It is still construct-only, so GObject sets it to the default and its setter runs too.

```text
file src/Meta_window_generated.vala: line 385: uncaught error: RPC Meta-Barrier.set_property: no rpc_lid on MetaBarrier (g-io-error-quark, 0)
file src/Meta_window_generated.vala: line 400: uncaught error: RPC Meta-Barrier.set_property: no rpc_lid on MetaBarrier (g-io-error-quark, 0)
file src/Meta_window_generated.vala: line 415: uncaught error: RPC Meta-Barrier.set_property: no rpc_lid on MetaBarrier (g-io-error-quark, 0)
file src/Meta_window_generated.vala: line 430: uncaught error: RPC Meta-Barrier.set_property: no rpc_lid on MetaBarrier (g-io-error-quark, 0)
file src/Meta_window_generated.vala: line 445: uncaught error: RPC Meta-Barrier.set_property: no rpc_lid on MetaBarrier (g-io-error-quark, 0)
file src/Meta_window_generated.vala: line 460: uncaught error: RPC Meta-Barrier.set_property: no rpc_lid on MetaBarrier (g-io-error-quark, 0)
file src/Meta_window_generated.vala: line 475: uncaught error: RPC Meta-Barrier.set_property: no rpc_lid on MetaBarrier (g-io-error-quark, 0)
file src/Meta_window_generated.vala: line 366: uncaught error:  (oll-mrpc-rpc-error-code-quark, -32602)
```

## Generated constructor and properties

`build/src/Meta_window_generated.vala`. One class. The class `construct` is line 356. The property get/set blocks follow it. The positional constructor is line 480. GJS does not call that positional constructor.

```vala
public uint64 rpc_lid { get; set construct; default = 0; }
construct {
    if (this.rpc_lid != 0) {
        return;
    }
    var t = this.get_type();
    while (t != GLib.Type.INVALID) {
        if (OLLMrpc.Bin.gtype_to_alias == null || !OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
            t = t.parent();
            continue;
        }
        var response = GnomeShellRpc.call_value(OLLMrpc.Bin.gtype_to_alias.get(t) + ".new");
        this.rpc_lid = (response.retval.get_object() as OLLMrpc.Live.Handle).rpc_lid;
        return;
    }
    GLib.error("lease construct: no Bin-registered ancestor for %s", this.get_type().name());
}
public Backend? backend {
    get {
        var response = GnomeShellRpc.call_value(
            "Meta-Barrier.get_property", this,
            OLLMrpc.args("s", "backend"));
        /* ... */
    }
    construct {
        GnomeShellRpc.call_value(
            "Meta-Barrier.set_property", this,
            OLLMrpc.args("so", "backend", value));
    }
}
public BarrierDirection directions {
    get { /* Meta-Barrier.get_property "directions" */ }
    construct {
        GnomeShellRpc.call_value(
            "Meta-Barrier.set_property", this,
            OLLMrpc.args("su", "directions", value));
    }
}
public BarrierFlags flags {
    get { /* Meta-Barrier.get_property "flags" */ }
    construct {
        GnomeShellRpc.call_value(
            "Meta-Barrier.set_property", this,
            OLLMrpc.args("su", "flags", value));
    }
}
public int32 x1 {
    get { /* Meta-Barrier.get_property "x1" */ }
    construct {
        GnomeShellRpc.call_value(
            "Meta-Barrier.set_property", this,
            OLLMrpc.args("si", "x1", value));
    }
}
public int32 x2 {
    get { /* Meta-Barrier.get_property "x2" */ }
    construct {
        GnomeShellRpc.call_value(
            "Meta-Barrier.set_property", this,
            OLLMrpc.args("si", "x2", value));
    }
}
public int32 y1 {
    get { /* Meta-Barrier.get_property "y1" */ }
    construct {
        GnomeShellRpc.call_value(
            "Meta-Barrier.set_property", this,
            OLLMrpc.args("si", "y1", value));
    }
}
public int32 y2 {
    get { /* Meta-Barrier.get_property "y2" */ }
    construct {
        GnomeShellRpc.call_value(
            "Meta-Barrier.set_property", this,
            OLLMrpc.args("si", "y2", value));
    }
}
public Barrier(Backend backend, int32 x1, int32 y1, int32 x2, int32 y2, BarrierDirection directions, BarrierFlags flags) throws GLib.Error
{
    Object();
    var response = GnomeShellRpc.call_value("Meta-Barrier.new", null, OLLMrpc.args("oiiiiuu", backend, (int) x1, (int) y1, (int) x2, (int) y2, (uint) directions, (uint) flags));
    var _stub = response.retval.get_object() as OLLMrpc.Live.Handle;
    this.rpc_lid = _stub.rpc_lid;
}
```

`rpc_lid` is still 0 while those `construct` setters run, so each `set_property` throws. The class `construct` then calls `Meta-Barrier.new` with no arguments. That constructor takes `backend, x1, y1, x2, y2, directions, flags`, so the server answers `-32602`.

### ⏳ 🔷 One `new` with the property list

**Where:** the property `construct` setters stash the value. The class `construct` block reads that stash and sends one `new`.

The instance exists before the property setters run, so the stash can hang off `this`. Same call as `Context.override.vala` `this.set_data("gsr-client-main-loop", loop)`.

**🔷** Each property `construct` setter copies `value` into a `GLib.Value` array on `this`. It does not call `set_property`.

```vala
construct {
    var props = this.get_data<GLib.GenericArray<GLib.Value>>("gsr-ctor-props");
    if (props == null) {
        props = new GLib.GenericArray<GLib.Value>();
        this.set_data("gsr-ctor-props", props);
    }
    var names = this.get_data<GLib.GenericArray<string>>("gsr-ctor-names");
    if (names == null) {
        names = new GLib.GenericArray<string>();
        this.set_data("gsr-ctor-names", names);
    }
    var copy = GLib.Value(value.type());
    value.copy(ref copy);
    names.add("backend");
    props.add(copy);
}
```

`directions`, `flags`, `x1`, `x2`, `y1`, `y2` do the same with their own name. `flags` is included because GObject sets that default too.

**🔷** That class `construct` is emitted only when the class has construct properties. `Barrier` has them, so it gets this block. A class with none keeps the existing `construct` that calls `.new` with no property list.

**🔷** After the `new` returns, both arrays are dropped. The `rpc_lid != 0` path drops them too and does not send `new`. That is a wire object: the server already built it.

```vala
construct {
    var names = this.get_data<GLib.GenericArray<string>>("gsr-ctor-names");
    var props = this.get_data<GLib.GenericArray<GLib.Value>>("gsr-ctor-props");
    this.set_data("gsr-ctor-names", null);
    this.set_data("gsr-ctor-props", null);
    if (this.rpc_lid != 0) {
        return;
    }
    var response = GnomeShellRpc.call_value(
        "Meta-Barrier.new", null,
        OLLMrpc.args(/* names, props */));
    this.rpc_lid = (response.retval.get_object() as OLLMrpc.Live.Handle).rpc_lid;
}
```

**🚫** `Meta-Barrier.set_property` from a property `construct` setter before `rpc_lid` is set.

**🚫** `Meta-Barrier.new` with an empty argument list.

**🚫** Emitting this property-list `construct` on a class that has no construct properties.
