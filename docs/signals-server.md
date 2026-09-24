# Server-side signals

This document describes signals in the Mutter server process. The server owns the real Meta, Clutter, and St GObjects.

For proxy declarations and GJS dispatch, see [Client-side signals](signals-client.md). For a property whose accessor is JavaScript, see [GJS-overridden properties](gjs-overridden-properties.md).

## Server state

Each RPC connection owns its leases, subscriptions, and callbacks:

```text
connection
├── leases
│   └── lease id -> real server GObject
├── signal_subs
│   └── lease id
│       └── signal name -> Subscription
└── callbacks
    └── callback id -> Live.Hook
```

These tables have different purposes:

```text
signal_subs -> asynchronous GObject signal notification
callbacks   -> synchronous vfunc/callback invocation with reply
```

## Registration

`Rpc.Server.start()` enables libocrpc live-handle services:

```vala
OLLMrpc.rpc_register(true);
```

This registers `RPC-Live-Subscribe`. The repository then replaces the stock callback handler:

```vala
Rpc.LiveCallback.rpc_register();
```

The generic subscription implementation is external:

```text
libocrpc/Live/Subscribe.vala
libocrpc/Live/Subscription.vala
libocrpc/Transport/Connection.vala
```

The replacement callback implementation is local:

```text
src/rpc/LiveCallback.vala
```

## Receiving a subscription

The client sends:

```text
Request.method   = "RPC-Live-Subscribe.rpc_signal"
Request.lease_id = <server object lease>
Request.args     = ["stopped"]
```

The server validates:

```vala
if (!request.connection.leases.has_key(id)) {
    reply_error(INVALID_PARAMS);
}

if (name.length == 0) {
    reply_error(INVALID_PARAMS);
}
```

It stores one row per connection, lease, and name:

```text
signal_subs[lease_id][signal_name] = Subscription {
    connection,
    id     = lease_id,
    method = signal_name,
    hid    = native_handler_id,
}
```

Repeated subscription is idempotent:

```vala
if (subs.get(id).has_key(name)) {
    request.reply(new Response());
    return;
}
```

There is no second native handler and no subscription reference count.

## Connecting the real server signal

### Named signal

For an ordinary signal, libocrpc installs a closure on the leased server object:

```vala
var closure = new GLib.Closure.simple(
    (uint) GLib.Closure.SIZE,
    subscription
);

closure.set_marshal(
    (GLib.ClosureMarshal) Subscription.emit
);

subscription.hid = GLib.Signal.connect_closure(
    obj,
    name,
    closure,
    false
);
```

Examples:

```text
stopped
style-changed
before-update
captured-event::touchpad
```

### Property notification

`notify::property` uses a separate path:

```vala
subscription.hid = obj.notify[property_name].connect((pspec) => {
    var current = GLib.Value(typeof(string));
    obj.get_property(pspec.name, ref current);

    connection.write(new Notification() {
        method = "notify::" + pspec.name,
        id = lease_id,
        message = current.get_string() ?? "",
    });
});
```

Current limitations:

```text
property value -> converted to string
Notification.args -> empty
Notification.message -> property text
```

## Forwarding a server signal

GObject invokes the subscription closure with:

```text
param_values[0] = emitting server object
param_values[1] = first signal argument
param_values[2] = second signal argument
...
```

`Subscription.emit()` drops the instance and asks `OLLMrpc.Bin.TypeOverride.pack_params` for the notification fields. A registered type becomes several ordinary fields. Any other argument stays one bin value.

```vala
var packed = OLLMrpc.Bin.TypeOverride.pack_params(param_values);

connection.write(new Notification() {
    method = subscription.method,
    id = subscription.id,
    args = packed,
});
```

`Clutter.Event` is registered from the compositor as `GnomeShellRpc.Rpc.Helper.ClutterEventOverride`. One event becomes five fields: type, x, y, button, key symbol (`idduu`). The button is read only for button and pad-button events. The key symbol is read only for key press and key release.

Wire shape:

```text
Notification {
    method = "stopped",
    id     = <lease id>,
    args   = [true],
}
```

End-to-end direction:

```text
real server GObject
  -> native signal emission
  -> libocrpc Subscription.emit()
  -> OLLMrpc.Notification
  -> client Runtime
  -> local proxy signal
  -> GJS handlers
```

The client half is documented in [Client-side signals](signals-client.md#receiving-and-dispatching-a-server-notification).

## Signal return values

The generic signal subscription path is one-way:

```text
server signal
  -> Notification
  -> client handlers

no Response
no reply id
no result sent back
```

The server closure receives a return slot:

```vala
public static void emit(
    GLib.Closure closure,
    GLib.Value? return_value,
    GLib.Value[] param_values,
    void* invocation_hint,
    void* marshal_data
)
```

The current implementation ignores `return_value`.

The client also discards local results:

```vala
Runtime.signal_emitv(
    values,
    signal_id,
    detail,
    null // no return-value storage
);
```

Therefore:

```text
void notification signal          -> supported shape
non-void signal affecting server  -> unsupported shape
```

## Multiple client handlers

The server installs at most one native subscription handler:

```text
(connection, lease id, signal name) -> one Subscription
```

The client may attach many local handlers:

```js
proxy.connect('stopped', handlerA);
proxy.connect('stopped', handlerB);
proxy.connect('stopped', handlerC);
```

One server notification triggers one local client emission. Local GObject dispatch runs the client handlers.

Their return values are not aggregated or returned to the server.

## Unsubscribe and cleanup

Explicit unsubscribe:

```text
Request.method   = "RPC-Live-Subscribe.unsubscribe"
Request.lease_id = <lease>
Request.args     = ["stopped"]
```

Server action:

```vala
GLib.SignalHandler.disconnect(
    connection.leases.get(id),
    connection.signal_subs.get(id).get(name).hid
);

connection.signal_subs.get(id).unset(name);
```

All subscriptions for a lease are removed when `RPC-Live-Remote.rpc_unref` releases the export hold:

```text
rpc_unref(lease)
  -> disconnect every signal_subs[lease][name]
  -> remove signal_subs[lease]
  -> remove lease
```

All subscriptions are also removed when the connection stops:

```text
connection.stop()
  -> disconnect every stored handler id
  -> clear signal_subs
  -> clear callbacks
  -> clear leases
```

The current client runtime can call `unsubscribe` via `Runtime.ensure_signal_unsubscribe` / `Shell.Signals.disconnect`. GJS `.disconnect(id)` uses `Shell.Signals.disconnect_id`.

## Bespoke server notifications

`src/rpc/Server.vala` sends application notifications outside `RPC-Live-Subscribe`.

Window creation:

```vala
display.window_created.connect((meta_window) => {
    connection.write(new OLLMrpc.Notification() {
        method = "Window.created",
        object_type = "Window",
        id = connection.export(meta_window),
    });
});
```

Window removal:

```text
Meta.Window::unmanaged
  -> Notification {
       method = "Window.closed",
       id = existing_window_lease,
     }
```

Title update:

```text
Meta.Window::notify::title
  -> Notification {
       method = "notify::title",
       id = existing_window_lease,
       message = meta_window.title,
     }
```

These notifications:

```text
do not use connection.signal_subs
do not originate from RPC-Live-Subscribe
are consumed by application-level notification handlers
```

## Vfunc and callback hooks

Vfuncs use `connection.callbacks`, not `connection.signal_subs`.

Registration:

```text
client Runtime.callback_bind(handler)
  -> RPC-Live-Callback.register
  -> server callbacks[callback_id] = Live.Hook
```

Binding:

```text
Helper-Actor.add_hook {
    lease_id,
    vfunc_id,
    callback_id,
}
```

Invocation and reply:

```text
server class slot / helper
  -> Live.Hook.emit(args)
  -> Live.Invoke {
       id       = callback_id,
       reply_id = correlation_id,
       args,
     }
  -> client handler
  -> RPC-Live-Callback.reply {
       correlation_id,
       return values,
     }
  -> Hook.reply_args
```

Examples of returned values:

```text
event             -> bool stop
captured_event    -> bool stop
preferred_width   -> min, natural
preferred_height  -> min, natural
allocate          -> chain/fallthrough decision
```

Each invocation has a separate reply id, allowing nested calls on the same callback row.

## Signals and vfunc hooks are not interchangeable

Connected handler:

```js
widget.connect('style-changed', handler);
```

Class closure:

```js
vfunc_style_changed() {
    // ...
}
```

Event vfunc with a return:

```js
vfunc_event(event) {
    return Clutter.EVENT_STOP;
}
```

These require different behavior:

```text
connect handler -> local signal emission
class closure   -> correct GObject class-slot dispatch
event vfunc     -> synchronous server reply
```

`Helper-Actor` owns vfunc hooks. Some client Actor relays additionally emit local signals.

Adding a server subscription can make this run:

```js
button.connect('clicked', handler);
```

without making this run:

```js
vfunc_clicked(button) {
    // class closure
}
```

That is the current `signal_prefer` class-closure bug, documented in [Client-side signals](signals-client.md#client-side-name-collisions).

## Server-side gaps

```text
subscription refcounts       -> absent
client disconnect tracking   -> absent
generic signal return values -> absent
client-to-server signal emit -> absent
notify:: typed values        -> absent; current value is a string
```

Manual and bespoke paths currently coexist:

```text
generic RPC-Live-Subscribe
bespoke Window notifications
Helper-Actor vfunc hooks
client-local signal re-emission
```

## Server debugging checklist

```text
1. Does connection.leases contain Request.lease_id?
2. Does connection.signal_subs[lease_id][name] exist?
3. Was the native handler connected to the intended real object?
4. Does that object emit the exact signal or detailed signal name?
5. Can every signal argument be encoded by libocrpc?
6. Does Notification.id equal the proxy's lease id?
7. Does Notification.method equal the client subscription name?
8. Does the operation require a return value?
9. If it requires a result, should it use Live.Hook instead?
10. Is this a generic subscription or a bespoke application notification?
```

## Server source map

| Concern | Source |
| --- | --- |
| Server registration and bespoke notifications | `src/rpc/Server.vala` |
| Server Actor peer and vfunc hooks | `src/rpc/helper/ClutterActor.vala` |
| Hook argument/result handling | `src/rpc/helper/LayoutHooks.vala` |
| Callback registration and replies | `src/rpc/LiveCallback.vala` |
| Generic subscribe implementation | libocrpc `Live/Subscribe.vala`, `Live/Subscription.vala` |
| Connection subscription storage and cleanup | libocrpc `Transport/Connection.vala`, `Live/Remote.vala` |
| Notification wire type | libocrpc `Notification.vala` |
| Synchronous hook implementation | libocrpc `Live/Hook.vala` |
| Named argument gates | `tests/call-sync-repro/subscribe-signal-args-gate.vala`, `subscribe-boxed-signal-arg-gate.vala` |
