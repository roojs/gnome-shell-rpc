# GJS-overridden properties

This document describes GObject properties whose accessor is JavaScript.

In-process GNOME Shell, `g_object_get()` and `g_object_set()` on an overridden property call the JavaScript getter or setter. Out of process the real Meta, Clutter, and St object lives in Mutter, and the override lives on a different GObject in the GJS client. A server read or write of that property is still expected to call the JavaScript version and, for a read, to use the value it returns.

```text
GJS client process
├── generated proxy properties (RPC to the server)
├── client-local properties
└── GJS property overrides (getter / setter)

Mutter server process
└── real Meta / Clutter / St properties
```

The proxy and server objects are different GObjects in different processes.

Signal delivery and class-closure hooks are documented in [Client-side signals](signals-client.md) and [Server-side signals](signals-server.md). A property override uses the same kind of synchronous callback as a vfunc hook. It is a different table from `signal_subs`.

## Terminology

| Term | Meaning |
| --- | --- |
| **stock property** | A GIR property whose value lives on the real server object. |
| **generated proxy property** | The client Vala property the generator emits for a stock property. Its get/set body is an RPC. |
| **client-local property** | A generated auto-property marked `local=1` or `props=local`. No RPC. |
| **GJS property** | A property installed by `GObject.registerClass({ Properties })` on a shell class. |
| **override** | `GObject.ParamSpec.override(name, Parent)`. The subclass replaces the parent accessor. |
| **property vfunc** | The GObject class `get_property` / `set_property` slot. `g_object_get()` and `g_object_set()` call it. |

## Four property locations

```text
1. server stock property
   process: Mutter server
   accessor: C get_property / set_property, or the C getter/setter function
   direct GJS access: through the generated proxy property

2. generated proxy property
   process: GJS client
   accessor: Vala get/set that calls the server
   direct GJS access: obj.name / obj.name = value

3. client-local property
   process: GJS client
   accessor: Vala auto-property
   direct GJS access: obj.name / obj.name = value

4. GJS override
   process: GJS client
   accessor: JavaScript getter and/or setter
   server access: expected to call that JavaScript accessor
```

No automatic relationship exists between rows 1 and 4. Emitting a generated proxy property does not install an override callback.

## Stock property: client calls the server

The generator turns a GIR object property into a client Vala property. The body calls the server. Two wire shapes exist.

A GIR getter or setter method, when it is a single wireable value:

```text
JS: button.icon_name
  -> generated getter
  -> St-Button.get_icon_name
  -> server C getter
```

A property with no usable method uses the stock GObject property RPC. `property-smoke.js` reads two of these:

```text
JS: mm.night_light_supported
  -> Meta-MonitorManager.get_property("night-light-supported")
  -> server g_object_get
  -> C property vfunc on the real object

JS: ctx.unsafe_mode
  -> Meta-Context.get_property("unsafe-mode")
  -> server g_object_get
```

```vala
public string icon_name {
    get {
        // RPC St-Button.get_icon_name, or St-Button.get_property("icon-name")
    }
    set {
        // RPC the matching setter
    }
}
```

This path is the JavaScript caller and the C implementation. It is the opposite direction from an override.

`notify::property` is also this direction. The server reads its own value and sends it to the client. See [Client handling of `notify::property`](signals-client.md#client-handling-of-notifyproperty). That update does not enter a JavaScript setter.

## Client-local property

`Type.prop local=1` or `Type props=local` in a `*.overrides` file emits an auto-property and no RPC:

```text
Text.attributes        local=1
Text.font_description  local=1
ScrollViewFade.fade_margins  local=1
```

```text
JS read/write -> client field
server get/set -> server field
```

GJS can construct these with a literal (`new Clutter.Text({ attributes })`). The server object keeps its own value.

## What an override is

`ParamSpec.override` tells GObject that this subclass implements a property already declared on a parent class or interface. GJS then installs `get_property` / `set_property` on that JavaScript class. `g_object_get()` and `g_object_set()` on an instance of the subclass enter those slots, which call the JavaScript getter and setter.

Shell interface implementation:

```js
export const CloseDialog = GObject.registerClass({
    Implements: [Meta.CloseDialog],
    Properties: {
        'window': GObject.ParamSpec.override('window', Meta.CloseDialog),
    },
}, class CloseDialog extends GObject.Object {
    get window() {
        return this._window;
    }

    set window(window) {
        this._window = window;
    }
});
```

`Meta.CloseDialog:window` and `Meta.InhibitShortcutsDialog:window` are construct-only and writable. The shell stores the window itself. There is no C field behind the getter.

Shell class override of a widget property:

```js
export const QuickToggle = GObject.registerClass({
    Properties: {
        'icon-name': GObject.ParamSpec.override('icon-name', St.Button),
        // title, subtitle, gicon are new GJS properties, not overrides
    },
}, class QuickToggle extends St.Button {
    // ...
});
```

`icon-name` already exists on `St.Button`. The override replaces it for `QuickToggle` instances so the value follows the child `St.Icon` through `bind_property()`. A new name such as `title` exists only on the JavaScript class. Mutter has no `St.Button:title` to call.

In-process dispatch:

```text
g_object_get(instance, "window", &value)
  -> G_OBJECT_GET_CLASS(instance)->get_property
  -> GJS property vfunc
  -> JavaScript get window()
  -> value returned to the caller

g_object_set(instance, "window", value)
  -> G_OBJECT_GET_CLASS(instance)->set_property
  -> GJS property vfunc
  -> JavaScript set window(value)
```

The JavaScript names follow GJS: GObject `icon-name` is `iconName` or `icon_name` on the prototype. The `Properties` key stays the hyphenated GObject name.

An override with no hand-written getter still belongs to the JavaScript class. GJS keeps the value in its own property storage. `g_object_get()` on that instance still enters the GJS vfunc. It does not enter the parent C `get_property`.

## What the server call is expected to do

When Mutter already holds the instance and reads or writes the property, the call is expected to run the JavaScript accessor of that instance's class.

```text
server g_object_get(dialog, "window")
  -> client JavaScript get window()
  -> returned Meta.Window used by the server caller

server g_object_set(toggle, "icon-name", name)
  -> client JavaScript set iconName(name)
  -> server set returns after the setter finishes
```

A get is synchronous. The server caller uses the returned value. A set is synchronous. Later reads, bindings, and `notify` on that instance observe the setter's result.

That is the same shape as a vfunc hook:

```text
server property vfunc
  -> synchronous callback
  -> client JavaScript getter or setter
  -> reply
       get: the property value
       set: completion
```

See [Vfunc and callback hooks](signals-server.md#vfunc-and-callback-hooks). `OLLMrpc.Live.Invoke` already carries a callback id, a reply id, arguments, and return values. A property override needs that reply. A `Notification` cannot carry the getter's return value back to the server caller.

The C function that implements the parent property is a different call. `st_button_get_icon_name()` reads the button's child icon directly. It does not consult a subclass property vfunc. `g_object_get(button, "icon-name")` does. On a `QuickToggle`, the in-process property read is the override.

## Interface properties on the client stub

The generator emits each GIR interface property as an abstract Vala property so `ParamSpec.override` has a parent property to override:

```vala
public abstract Meta.Window window { get; construct; }
```

The comment in `emit_interface_properties` names this case: `InhibitShortcutsDialog.window` for GJS `ParamSpec.override`. The abstract property has no RPC body. The JavaScript getter and setter are the implementation.

`WindowManager` returns that object to Mutter:

```js
_createCloseDialog(shellwm, window) {
    return new CloseDialog.CloseDialog(window);
}
```

The signal is `Shell.WM::create-close-dialog`. In-process, Mutter stores the returned object and later reads `window` from it. That read is `g_object_get()` on a JavaScript instance, so it runs `get window()`.

Out of process the return value crosses into Mutter as a leased object. The lease's `get_property("window")` is expected to call the same JavaScript getter. The client abstract property declaration does not create that callback.

## Class overrides and the generated proxy

`QuickToggle` extends the generated `St.Button` proxy. Two accessors then exist for one GObject name:

```text
St.Button instance
  icon-name -> generated getter/setter -> server St.Button

QuickToggle instance
  icon-name -> ParamSpec.override -> JavaScript accessor
```

A JavaScript read of `quickToggle.iconName` uses the override. It does not run the generated RPC getter. A JavaScript read of `button.icon_name` on a plain `St.Button` proxy does run the RPC.

A server `g_object_get()` on the leased `St.Button` still runs the C property. The override callback is what would make that server read enter the `QuickToggle` getter when the leased object's client class overrode the property.

`bind_property()` uses `g_object_get()` and `g_object_set()`. In-process, both ends of `QuickToggle`'s `icon-name` binding run property vfuncs. If one end is the server object and the other is the override, each direction of the binding is a synchronous callback.

## What exists today

| Piece | State |
| --- | --- |
| Generated object property, client get/set RPCs to the server | present |
| `Type.get_property` / `Type.set_property` for properties with no method | present |
| Abstract interface properties for `ParamSpec.override` | present, declaration only |
| `local=1` / `props=local` auto-properties | present |
| Record of which GJS class overrode which property | absent |
| Server `g_object_get` → JavaScript getter, reply with the value | absent |
| Server `g_object_set` → JavaScript setter, reply on completion | absent |

Current paths:

```text
JS read of a stock proxy property
  -> RPC
  -> server C accessor

JS read of an overridden property
  -> local JavaScript getter

server g_object_get of a stock property
  -> server C accessor

server g_object_get of a property the client class overrode
  -> server C accessor
  -/> JavaScript getter
```

## Override callback and the other property paths

```text
stock proxy get/set     client calls server, server value is the result
client-local property   client field only
notify::property        server value copied onto the proxy
GJS override get/set    server calls JavaScript, JavaScript value is the result
vfunc hook              server calls JavaScript, reply carries the vfunc result
signal subscription     server notifies the client, no result comes back
```

Registering a `notify::icon-name` subscription does not install the override callback. Connecting a signal does not either. `Helper-Actor.add_hook` binds class slots such as `event` and `allocate`. It has no property-name argument.

## Gaps

```text
discover GJS ParamSpec.override on a registered class -> absent
bind server get_property / set_property to that override -> absent
synchronous reply of the getter value                 -> absent
synchronous completion of the setter                  -> absent
construct-only override passed across create-close-dialog -> absent
bind_property across the process boundary            -> absent
```

The abstract interface property is enough for GJS to install the override on the client object. It is not a server hook.

## Debugging checklist

```text
1. Is the GObject name declared on a parent class or interface?
2. Does the shell class use ParamSpec.override for that name?
3. Does the prototype define get/set, or does GJS store the value?
4. Is the caller g_object_get / g_object_set / bind_property?
5. Or is the caller a C function that reads a private field?
6. Which process holds the instance being read?
7. If it is the server instance, is there a callback to the client override?
8. Does the caller use the returned value? Then the reply has to carry it.
9. Is this actually a stock proxy property, whose RPC runs the other way?
10. Is this a local=1 property, which never leaves the client?
```

## Source map

| Concern | Source |
| --- | --- |
| Object property → RPC get/set | `src/gi-stub-gen/Generator.vala` `emit_object_properties` |
| Interface property → abstract Vala property | `src/gi-stub-gen/Generator.vala` `emit_interface_properties` |
| Client-local property flag | `src/gi-stub-gen/Generator.vala` `property_is_local`; `Clutter.overrides`, `St.overrides` |
| Property GValue wire | `src/gjs-embed/property-smoke.js`; libocrpc Gi `get_property` / `set_property` |
| `Shell.WM::create-close-dialog` | `src/shell-gi/WM.vala` |
| Shell overrides | `vendor/gnome-shell/js/ui/closeDialog.js`, `inhibitShortcutsDialog.js`, `quickSettings.js` |
| Shell hands the object to Mutter | `vendor/gnome-shell/js/ui/windowManager.js` `_createCloseDialog` |
| Closest existing server → JS callback | `src/rpc/LiveCallback.vala`, `src/rpc/helper/ClutterActor.vala` |
| `notify::` server → client value copy | [Client-side signals](signals-client.md#client-handling-of-notifyproperty) |
