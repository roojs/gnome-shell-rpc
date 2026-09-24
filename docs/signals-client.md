# Client-side signals

This document describes signals in the `gnome-shell-rpc` GJS client process.

```text
GJS client process
├── generated Meta / Clutter / St proxy GObjects
├── local GJS-defined GObjects
├── Runtime.signal_subs
├── Runtime.handlers
└── OLLMrpc.Client

Mutter server process
└── real Meta / Clutter / St GObjects
```

The proxy and server objects are different GObjects in different processes.

For the other half of the boundary, see [Server-side signals](signals-server.md). For a property whose accessor is JavaScript, see [GJS-overridden properties](gjs-overridden-properties.md).

## Terminology

| Term | Meaning |
| --- | --- |
| **proxy** | A client-side GObject representing a leased server object. |
| **lease id** | The connection-local `rpc_lid` identifying that object on the wire. |
| **client signal** | A named GObject signal registered on a client proxy or a client-only GJS object. |
| **client class closure / class slot** | A default handler slot on the client GObject class, exposed to GJS as `vfunc_*` where GI describes it as a virtual function. |
| **client subscription record** | `Runtime.signal_subs[lease id][signal name]`, recording that the server was asked to forward that signal. |
| **client callback handler** | A handler in `GiStub.Runtime.handlers` for a synchronous server invocation. |

## Three distinct signal locations

```text
1. server object signal
   process: Mutter server
   direct GJS access: no

2. generated proxy signal
   process: GJS client
   direct GJS access: connect / disconnect / emit

3. GJS-defined signal
   process: GJS client
   direct GJS access: connect / disconnect / emit
```

No automatic relationship exists between these rows.

## Signal definitions imported from GIR

The generator converts GIR signal metadata into a client-side Vala signal.
Every generated Vala source identifier has a `signal_` prefix:

```vala
// Input: GIR signal metadata
// Output: generated client proxy declarations
[CCode (cname = "style-changed")]
public signal void signal_style_changed();

[CCode (cname = "stopped")]
public signal void signal_stopped(bool is_finished);
```

The prefix exists only in Vala source. `CCode (cname)` keeps the stock GObject,
GIR, GJS, and RPC name:

```text
Vala source identifier: signal_style_changed
GObject / GIR / GJS:    style-changed
RPC notification method: style-changed
```

Vala code uses the prefixed member:

```vala
transition.signal_stopped.connect((transition, finished) => {
    // ...
});
```

The generated typelib exposes the stock name to GJS:

```js
const id = object.connect('stopped', (_object, finished) => {
    // ...
});
object.disconnect(id);
```

```vala
// GIR: detailed="1"
[CCode (cname = "captured-event")]
[Signal (detailed = true)]
public virtual signal bool signal_captured_event(Clutter.Event event) {
    return false;
}
```

```text
generated signal declaration -> local client GObject metadata
generated signal declaration -/> server RPC subscription

unmapped return/argument type -> generator gap
signal:Type.name deny entry   -> signal omitted
```

## Signals authored in Vala or GJS

```vala
// Client-local Vala signal
public signal void changed();
```

```js
// Client-local GJS signal
const Example = GObject.registerClass({
    Signals: {
        changed: {},
    },
}, class Example extends GObject.Object {});
```

```text
Vala public signal -> local
GJS Signals entry  -> local
GJS metadata scan  -> not implemented
automatic RPC      -> not implemented
```

## Client-side name collisions

### What GIR asks the client stub to represent

```text
one conceptual operation
├── named GObject signal
├── class-struct callback / class closure
├── introspected virtual function
└── sometimes a callable C/GI method
```

For example, stock `St.Button::clicked` has a GObject signal and a `StButtonClass.clicked` class closure. GNOME Shell overrides the latter as:

```js
vfunc_clicked(button) {
    this.activate(button);
}
```

Emitting the stock signal is expected to invoke that overridden class closure according to the signal's run flags.

### Current generator representation

Vala cannot declare a signal and a method with the same source-language
identifier. The `signal_` prefix leaves the stock identifier available for a
callable method or property.

```text
GIR signal without a matching class field
  -> [CCode (cname = "stock-name")]
  -> public signal ... signal_name(...)

GIR class field matching a signal on that class
  -> emit at the field's physical GIR position
  -> [CCode (cname = "stock-name")]
  -> public virtual signal ... signal_name(...) { default body }

callable method with the same stock name
  -> emit independently under the stock Vala method name
```

For example:

```vala
[CCode (cname = "clicked")]
public virtual signal void signal_clicked(int clicked_button) {
}
```

The generated C registers this as:

```c
g_signal_new(
    "clicked",
    ST_TYPE_BUTTON,
    G_SIGNAL_RUN_LAST,
    G_STRUCT_OFFSET(StButtonClass, clicked),
    // ...
);
```

This is one GObject signal with `StButtonClass.clicked` as its class closure,
not the old pair of an ordinary signal plus an independent `clicked_vfunc`
method. `signal_prefer`, `clicked_vfunc`, `style_changed_vfunc`, and the
`Actor.destroy_rpc` naming workaround have been removed.

The generated external views are:

```text
Vala signal:       signal_clicked
GObject signal:    clicked
GIR/GJS signal:    clicked
C class field:     StButtonClass.clicked
GJS class override: vfunc_clicked(...)
```

### What is proved, and what is still broken

The current `class-struct-offset-gate` proves that the generated class layout
has the stock `clicked` and `style_changed` offsets. It also proves that GIR
and GObject expose `clicked`, `style-changed`, detailed
`captured-event::touchpad`, and both the `Clutter.Text.activate()` method and
`activate` signal under their stock names.

That structural proof is not an end-to-end delivery proof. In particular,
prefixing and virtualizing a signal does not request its server-side
subscription:

```text
AppIcon defines vfunc_clicked()
  -/> generated connect() call
  -/> Runtime.ensure_signal_subscribe(button, "clicked")
  -/> server RPC-Live-Subscribe.rpc_signal
```

There is currently no `clicked` subscription call site. Therefore the new
class-closure representation can be correct while search-result clicks still
fail before a client `"clicked"` emission occurs. A focused gate must separate:

```text
1. local emit("clicked") -> GJS vfunc_clicked()
2. RPC notification "clicked" -> local emit -> GJS vfunc_clicked()
3. policy/timing that creates the server subscription
```

`style-changed` has a different temporary path. The old post-mint
`Clutter.Actor` subscription is gone: notification delivery inside a
synchronous `show()` RPC re-entered GJS and crashed. The generated `style` and
`style_class` setters currently emit `signal_style_changed()` after their RPC
reply returns. This is marked `local_emit_after` in `St.overrides`.

`clicked` is temporarily subscribed after `Helper-Actor.create` when the client
type exposes the signal. The generated virtual signal now owns the stock class
closure; the remaining work is to prove a real click notification reaches
`AppIcon.vfunc_clicked()`.

See [Prefix generated Vala signals](bugs/2026-09-23-prefix-generated-vala-signals.md),
[Search result click does not launch](bugs/2026-09-22-search-result-click-no-launch.md),
and [`style-changed` manual subscription](bugs/2026-09-22-style-changed-manual-subscription.md).

## GJS connection is local

```js
proxy.connect('stopped', handler);
```

```text
GJS .connect()       -> local GObject handler
GJS .connectObject() -> local lifetime-managed handler
GJS .disconnect()    -> local handler removal

none of these:
  -> call Shell.signal_connect
  -> call GiStub.Runtime
  -> send RPC-Live-Subscribe.rpc_signal
  -> remove a server subscription
```

`src/shell-js/signals.js` wraps those three prototype methods and would call `Shell.signal_connect`. The extra gresource is registered at `resource:///org/gnome/shell-rpc/signals.js`; the host does not eval it yet, so GJS `.connect()` is still local-only.

## Proxy identity and lease ids

```text
generated proxy
  implements OLLMrpc.Live.Handle
  rpc_lid = lease id

Runtime.register_handle(proxy)
  -> OLLMrpc.Client.proxies[rpc_lid] = proxy

call_value(method, proxy, args)
  -> Request.lease_id = proxy.rpc_lid
  -> object arguments become lease ids
```

## Requesting a server subscription

The explicit client entry points are:

```vala
GiStub.Runtime.ensure_signal_subscribe(object, signal_name);
Shell.signal_connect(object, signal_name); // → ensure_signal_subscribe
```

```text
ensure_signal_subscribe(object, signal_name)
  -> require object.rpc_lid != 0
  -> Client.proxies[rpc_lid] = object
  -> dedupe Runtime.signal_subs[rpc_lid][signal_name]
  -> synchronous RPC-Live-Subscribe.rpc_signal
  -> record local subscription after success
```

`Shell.signal_disconnect` → `Runtime.ensure_signal_unsubscribe` → `RPC-Live-Subscribe.unsubscribe`. The GJS wrap does not call disconnect yet.

```text
safe:   reply decoded -> lease assigned -> subscribe
unsafe: proxy constructor -> nested subscribe while reply is being decoded
```

Current manual call sites are:

| Object path | Signal |
| --- | --- |
| `Meta.get_display()` | `workareas-changed` |
| `St.Entry.clutter_text` | `text-changed`, `key-focus-in`, `key-focus-out` |
| `Clutter.Actor.get_transition()` | `stopped` |
| `St.Adjustment.add_transition()` | `stopped` |
| `Meta.Laters` stage setup | `before-update` |
| Post-mint Helper-Actor construction | `clicked` when present; temporary until generated virtual-signal subscription policy |

There is no generated or automatic subscription when the first GJS handler is connected. `Shell.signal_connect` is the GJS-visible relay; wrapping `.connect()` to call it is [`0.8.6`](plans/0.8.6-connect-driven-subscribe.md).

## Receiving and dispatching a server notification

The client half of the generic flow is:

```text
OLLMrpc.Notification { id, method, args }
  -> OLLMrpc.Client.notification
  -> GiStub.Runtime subscription/proxy checks
  -> g_signal_emitv() on the client proxy
  -> local GJS/Vala handlers
```

The preceding server half is documented in [Server-side signals](signals-server.md#forwarding-a-server-signal).

`GiStub.Runtime` accepts a notification only when:

- `OLLMrpc.Client.proxies` contains `notification.id`; and
- `Runtime.signal_subs[id]` contains `notification.method`.

It then looks up the local signal metadata with `GLib.Signal.parse_name()`, constructs one `GValue` for the proxy plus one for each declared parameter, transforms the received values to the declared types, and calls `g_signal_emitv()`.

Named signal arguments are carried in `Notification.args` in GIR order. The `subscribe-signal-args-gate` and `subscribe-boxed-signal-arg-gate` cover scalar and registered boxed arguments.

Current special cases and limitations are:

- `key-press-event` with no wire arguments is emitted using `Clutter.get_current_event()`, because `Clutter.Event` is not transported.
- A missing argument remains the zero/default `GValue` for its declared type.
- A missing `Clutter.Frame` boxed argument is replaced with an empty frame to satisfy its marshaller.
- An unknown signal name is silently ignored.

## Client handling of `notify::property`

```text
server notify::property
  -> Notification.message = property converted to string
  -> OLLMrpc.Client sets property on existing proxy
  -> local GObject notify handler may run
  -> GiStub.Runtime receives client.notification
```

The generic runtime notification handler still requires an explicit `signal_subs` entry before it will perform its own by-name re-emission. This means `notify::` currently has a property-update path and a possible explicit signal path, rather than one fully unified contract.

`notify::` copies a server property value onto the proxy. It does not run a JavaScript getter or setter. That callback is [GJS-overridden properties](gjs-overridden-properties.md).

`Rpc.Server` also sends bespoke `notify::title` notifications for tracked windows; that path does not originate in `RPC-Live-Subscribe`.

## Client emission

```js
object.emit('name', value); // client proxy only
```

```vala
object.changed();                           // client proxy only
GLib.Signal.emit_by_name(object, "changed"); // client proxy only
```

```text
client local emit -/> server object

required server action
  -> call RPC method
  -> server method changes real object
  -> real object may emit server signal
```

Examples of intentional local emission include:

- `Workspace.set_builtin_struts()` locally emitting `workareas-changed` after its RPC call; and
- Actor relays locally emitting key or style signals for connected GJS handlers.

## Client handling of returns and multiple handlers

```js
proxy.connect('signal', handlerA);
proxy.connect('signal', handlerB);
proxy.connect('signal', handlerC);
```

```text
one Notification
  -> one local GObject emission
  -> handlerA / handlerB / handlerC
  -> results discarded
```

```vala
Runtime.signal_emitv(
    values,
    signal_id,
    detail,
    null // no return-value storage
);
```

```text
Notification result field -> absent
reply to server           -> absent
```

The generic subscription mechanism is therefore only sound for notification-style signals whose server behavior does not depend on a client return value.

Operations requiring a result use the separate synchronous callback path:

```text
OLLMrpc.Live.Invoke { callback id, reply id, args }
  -> GiStub.Runtime callback handler
  -> RPC-Live-Callback.reply(reply id, return/out values)
```

`GiStub.Runtime.callback_bind()` allocates one callback id and stores one client handler. Each invocation has a separate reply id, so nested invocation replies can be correlated.

This path carries boolean event results, preferred-size out values, allocation chain decisions, and callback errors. It models one class-slot override or callback, not a list of ordinary signal listeners.

## Client-side gaps

```text
connect-driven subscription         -> absent
Vala signal source prefix           -> implemented
generated signal/class closure      -> structurally implemented; live delivery unproved
virtual-signal subscription policy  -> absent
generic signal return transport     -> absent
client-to-server signal emit        -> absent
disconnect/subscription accounting  -> absent
subscribe during reply construction -> unsafe
unified notify:: handling           -> absent
per-type manual exceptions          -> present
```

## Client debugging checklist

```text
1. Does GIR contain the signal and mappable types?
2. Did the generator emit it, or did method/property/deny win?
3. Does the proxy have rpc_lid != 0?
4. Does Client.proxies[rpc_lid] contain that proxy?
5. Did ensure_signal_subscribe() run after lease creation?
6. Did Notification { id, method, args } arrive?
7. Does Runtime.signal_subs[id] contain method?
8. Does the client GType contain a compatible signal?
9. Is the generated Vala member named signal_* but its C/GObject name stock?
10. Is this a virtual signal whose class closure occupies the stock field?
11. Is the consumer connect(), or actually a vfunc_* override?
12. Does the operation require a return value?
```

## Client source map

| Concern | Source |
| --- | --- |
| GIR signal and class-slot generation | `src/gi-stub-gen/Generator.vala` |
| Enable class-slot generation | `src/gi-stub-gen/St.overrides`, `src/gi-stub-gen/Clutter.overrides` |
| Proxy registration, subscribe, receive, emit | `src/gi-stub/Runtime.vala` |
| GJS-visible subscribe relay (not stock Shell) | `src/shell-gi/Signals.vala` |
| GJS connect wrap (resource; not eval'd yet) | `src/shell-js/signals.js` |
| Lease ids in normal RPC calls | `src/namespace.vala` |
| Vfunc capability detection | `src/gi-stub/VfuncRelay.vala` |
| Actor client relays | `src/gi-stub/overrides-clutter/Actor.override.vala` |
| Current style class-slot bridge | `src/gi-stub/overrides-st/Widget.override.vala` |
| Client `notify::` property update | libocrpc `Client.vala` |
| Named argument gates | `tests/call-sync-repro/subscribe-signal-args-gate.vala`, `subscribe-boxed-signal-arg-gate.vala` |
