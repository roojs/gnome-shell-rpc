# Client-side signals

This document describes signals in the `gnome-shell-rpc` GJS client process.

```text
GJS client process
├── generated Meta / Clutter / St proxy GObjects
├── local GJS-defined GObjects
├── signals.js  (GObject.Object.prototype connect / disconnect wrap)
├── Shell.Signals  (subs, refs, gjs_ids, Notification re-emit)
├── Runtime.handlers  (synchronous Live.Invoke)
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
| **client subscription record** | `Shell.Signals.subs[lease id][signal name]` → our handler id. The server was asked to forward that name. `refs` counts local connects that share the name. `gjs_ids` maps the GJS handler id to ours. |
| **client callback handler** | A handler in `Gsr.Client.Rpc.handlers` for a synchronous server invocation. |

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
server subscribe   -> only a name that exists on the leased peer
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
  -> plain virtual at that byte: name_vfunc, vfunc_name = stock name
  -> the signal is not virtual, so valac does not park it at the end
  -> [CCode (cname = "stock-name")]
  -> public signal ... signal_name(...)

callable method with the same stock name
  -> emit independently under the stock Vala method name
```

A virtual signal would be the class closure and would also move every
later field, including `allocate`. The signal and the slot are therefore
separate. `Shell.Signals.emit` runs `connect()` handlers with
`g_signal_emitv`, then calls the plain virtual when this object's class
replaced that slot. That call is how `vfunc_clicked` runs.

```text
Vala signal:        signal_clicked
GObject signal:     clicked
GIR/GJS signal:     clicked
C class field:      clicked_vfunc at the typelib byte
GJS class override: vfunc_clicked(...)
```

### What is proved, and what is still broken

The current `class-struct-offset-gate` proves that the generated class layout
has the stock `clicked` and `style_changed` offsets. It also proves that GIR
and GObject expose `clicked`, `style-changed`, detailed
`captured-event::touchpad`, and both the `Clutter.Text.activate()` method and
`activate` signal under their stock names.

Prefixing a signal does not itself request a server subscription. Icon
launch runs `vfunc_clicked` through the path below. Two client paths
request the subscription:

```text
GJS .connect('clicked', handler)
  -> signals.js wrap
  -> Shell.Signals.connect
  -> Gsr-Clutter-Actor.add_signals

Helper-Actor.create returned, type has signal "clicked"
  -> Runtime.ensure_signal_subscribe(actor, "clicked")
  -> same Shell.Signals.connect
```

`vfunc_clicked` is the plain virtual on the client class. It is not a
helper hook. The notification re-emits `clicked`, and `Shell.Signals.emit`
then calls that virtual when the leaf class replaced the slot.

`style-changed` still has a temporary split. Notification delivery inside a
synchronous `show()` RPC re-entered GJS and crashed, so the generated `style`
and `style_class` setters emit `signal_style_changed()` after their RPC reply
returns (`local_emit_after` in `St.overrides`). The `.new` lease path
(BaseIcon / `St.Bin`, not Helper-Actor) still calls
`ensure_signal_subscribe(actor, "style-changed")` when the type has that
signal, so the server's later emission can reach GJS `.connect` handlers.

See [Prefix generated Vala signals](bugs/done/2026-09-23-prefix-generated-vala-signals.md)
and [Overview picker](bugs/done/2026-09-24-overview-picker-preview-gone.md).
The live overview complaint is [boot flicker](bugs/2026-09-30-overview-boot-flicker.md).
[`style-changed` manual subscription](bugs/done/2026-09-22-style-changed-manual-subscription.md)
was taken off the board on 2026-09-30. The setter bridge above is still the code.
Archived: [search click](bugs/done/2026-09-22-search-result-click-no-launch.md).

## GJS connection

```js
proxy.connect('stopped', handler);
```

```text
GJS .connect() / .connect_after() / .connect_object()
  -> original GObject.prototype.* (GJS handler id unchanged)
  -> Shell.Signals.connect(obj, name, gjs_handler_id)
       leased -> Gsr-Clutter-Actor.add_signals (string array; one name is still an array)
       else   -> 0, local handler only

GJS .disconnect(id)
  -> Shell.Signals.disconnect_id(obj, gjs_handler_id)
  -> original GObject.prototype.disconnect
```

`src/client/gresource/signals.js` is `resource:///org/gnome/shell-rpc/signals.js`. The host evals it and `Signals.install()` before `init.js`. Vala `.connect()` still needs `Gsr.Client.Rpc.ensure_signal_subscribe`.

## Proxy identity and lease ids

```text
generated proxy
  implements OLLMrpc.Live.Interface
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
Gsr.Client.Rpc.ensure_signal_subscribe(object, signal_name);
Shell.Signals.connect(object, signal_name, gjs_handler_id);
```

```text
ensure_signal_subscribe(object, signal_name)
  -> Shell.Signals.connect
  -> require object.rpc_lid != 0
  -> Client.proxies[rpc_lid] = object
  -> dedupe Shell.Signals.subs[rpc_lid][signal_name]
  -> Gsr-Clutter-Actor.add_signals
  -> record local subscription after success
```

`Shell.Signals.disconnect_id` → `RPC-Live-Subscribe.unsubscribe` when the last local handler for that name drops. GJS `.disconnect(id)` uses that path.

```text
safe:   reply decoded -> lease assigned -> subscribe
unsafe: proxy constructor -> nested subscribe while reply is being decoded
```

Current Vala-only manual call sites (GJS `.connect()` uses the wrap):

| Object path | Signal |
| --- | --- |
| `Meta.Laters` stage setup | `before-update` |
| Actor lease construct | `style-changed` when present |

GJS `.connect()` / `.connect_after()` / `.connect_object()` go through `src/client/gresource/signals.js`.

## Receiving and dispatching a server notification

The client half of the generic flow is:

```text
OLLMrpc.Notification { id, method, args }
  -> OLLMrpc.Client.notification
  -> Shell.Signals subscription/proxy checks
  -> g_signal_emitv() on the client proxy
  -> local GJS/Vala handlers
  -> plain virtual, when the leaf class replaced that slot
```

The preceding server half is documented in [Server-side signals](signals-server.md#forwarding-a-server-signal).

`Shell.Signals` accepts a notification only when:

- `OLLMrpc.Client.proxies` contains `notification.id`; and
- `Shell.Signals.subs[id]` contains `notification.method`.

It then looks up the local signal metadata with `GLib.Signal.parse_name()`, constructs one `GValue` for the proxy plus one for each declared parameter, transforms the received values to the declared types, and calls `g_signal_emitv()`.

Named signal arguments are carried in `Notification.args`. `Shell.Signals.emit` calls `OLLMrpc.Bin.TypeOverride.fill_params`, which walks the signal's parameter types. A registered type consumes the field count from its override. Any other parameter consumes one field. The `subscribe-signal-args-gate` and `subscribe-boxed-signal-arg-gate` cover scalar and registered boxed arguments.

`Clutter.Event` is one `Gsr.Shared.ClutterEventState` (`Shell.ClutterEventOverride`). `unpack` builds the compact event with `apply_state`. Getters read that state.

Current limitations are:

- A missing argument remains the zero/default `GValue` for its declared type.
- A missing `Clutter.Frame` boxed argument is replaced with an empty frame to satisfy its marshaller.
- An unknown signal name is silently ignored.

## Client handling of `notify::property`

```text
server notify::property
  -> Notification.message = property converted to string
  -> OLLMrpc.Client sets property on existing proxy
  -> local GObject notify handler may run
  -> Shell.Signals receives client.notification
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
one Notification, reply_id == 0
  -> one local GObject emission
  -> handlerA / handlerB / handlerC
  -> bool discarded

one Notification, reply_id != 0
  -> Shell.Signals.emit
  -> BOOLEAN return stored; any other return type passes null to emitv
  -> RPC-Live-Callback.reply(reply_id, bool)
```

A `reply_id` of 0 is the delivery when the server does not read the handler result. A non-zero `reply_id` is the blocking subscribe: [Blocking signal subscribe](bugs/2026-10-10-blocking-signal-subscribe.md).

Operations requiring a result use the separate synchronous callback path:

```text
OLLMrpc.Live.Invoke { callback id, reply id, args }
  -> Gsr.Client.Rpc callback handler
  -> RPC-Live-Callback.reply(reply id, return/out values)
```

`Gsr.Client.Rpc.callback_bind()` allocates one callback id and stores one client handler. Each invocation has a separate reply id, so nested invocation replies can be correlated.

This path carries boolean event results, preferred-size out values, allocation chain decisions, and callback errors. It models one class-slot override or callback, not a list of ordinary signal listeners.

## What the signal bridge does

```text
connect-driven subscription         -> Shell.Signals via signals.js
Vala signal source prefix           -> signal_* , GObject name stock
class slot                          -> plain virtual; Shell.Signals.emit calls it when the leaf replaced the slot
overridden-signal subscribe         -> Actor.signal_overrides
disconnect                          -> client refcount, then RPC-Live-Subscribe.unsubscribe
notify::                            -> typed value in Notification.args
Clutter.Event argument              -> one ClutterEventState
```

A local `emit` stays on the client object. The server object changes through an RPC method, which may then emit.

Event signals on the `add_signals` hand list (`leave-event`, the other button and key events, `long-press`) set `Subscription.blocking`. The server waits, and the client sends the handler bool on `RPC-Live-Callback.reply` before that wait ends. [Blocking signal subscribe](bugs/2026-10-10-blocking-signal-subscribe.md). `event` and `captured-event` are on that list and also already wait as `relay=1` hooks.

`Widget.set_style` still emits `style-changed` locally after the RPC reply (`local_emit_after` in `St.overrides`). Subscribing that signal from inside `show()` re-entered GJS.

## Client debugging checklist

```text
1. Does GIR contain the signal and mappable types?
2. Did the generator emit it, or did method/property/deny win?
3. Does the proxy have rpc_lid != 0?
4. Does Client.proxies[rpc_lid] contain that proxy?
5. Did ensure_signal_subscribe() run after lease creation?
6. Did Notification { id, method, args } arrive?
7. Does Shell.Signals.subs[id] contain method?
8. Does the client GType contain a compatible signal?
9. Is the generated Vala member named signal_* but its C/GObject name stock?
10. Did the leaf replace the plain virtual for this signal?
11. Is the consumer connect(), or actually a vfunc_* override?
12. Does the operation require a return value?
```

## Client source map

| Concern | Source |
| --- | --- |
| GIR signal and class-slot generation | `src/generator/Generator.vala` |
| Enable class-slot generation | `src/client/libst-rpc-16/St.overrides`, `src/client/libmutter-clutter-rpc-16/Clutter.overrides` |
| Subscribe, receive, re-emit | `src/client/libshell-16/Signals.vala` |
| GJS connect wrap (host eval before init.js) | `src/client/gresource/signals.js` |
| Lease ids and callback bind | `src/client/rpc/namespace.vala` |
| Actor `signal_overrides` | `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala` |
| Event wire | `src/client/libshell-16/ClutterEventOverride.vala`, `src/shared/ClutterEventState.vala` |
| Client `notify::` property update | libocrpc `Client.vala` |
| Named argument gates | `tests/call-sync-repro/subscribe-signal-args-gate.vala`, `subscribe-boxed-signal-arg-gate.vala` |
