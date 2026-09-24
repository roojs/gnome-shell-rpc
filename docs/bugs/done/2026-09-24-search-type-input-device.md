# Typing in search drops the connection

**User goal:** nested mutter-rpc + gnome-shell-rpc stays up and answers pointer and keyboard. From [`../../plans/0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md).

**Status:** ✅ closed 2026-09-24. `unpack` uses `set_pointer`. `InputDeviceOverride` drops `MetaInputDeviceX11`.

**Seen:** 2026-09-24 14:49:57–14:50:01. Typed `ter` in overview search.

## 1. `captured-event` parameter `event`

```text
notification method=captured-event
g_value_set_boxed: assertion 'G_VALUE_HOLDS_BOXED (value)' failed
JS ERROR: TypeError: event is null
_onCapturedEvent@resource:///org/gnome/shell/ui/searchController.js:310
```

**ℹ️** `build/src/libshell-gi-16.so.p/shell-gi/ClutterEventOverride.c` compiles `unpack` as:

```c
g_value_init (&_tmp17_, G_TYPE_POINTER);
v = _tmp17_;
g_value_set_boxed (&v, ev);
*result = v;
_clutter_event_free0 (ev);
```

### ✔️ 🔷 Replace `src/shell-gi/ClutterEventOverride.vala` `unpack`

**Replace:**

```vala
			var v = GLib.Value(typeof(Clutter.Event));
			v.set_boxed(ev);
			return v;
```

**Replace with:**

```vala
			var v = GLib.Value(typeof(Clutter.Event));
			v.set_pointer(ev);
			return v;
```

## 2. `Clutter.Seat` `device-added` argument

```text
14:50:01.231808 Updating keyboard mapping
14:50:01.269203 connection write error: Unregistered class type schema: MetaInputDeviceX11
14:50:01.282632 Error receiving data: Connection reset by peer
```

`clutter/clutter/clutter-seat.c`:

```c
signals[DEVICE_ADDED] =
  g_signal_new (I_("device-added"),
                G_TYPE_FROM_CLASS (object_class),
                G_SIGNAL_RUN_LAST,
                0, NULL, NULL, NULL,
                G_TYPE_NONE, 1,
                CLUTTER_TYPE_INPUT_DEVICE);
```

```c
device = clutter_event_get_source_device (event);

switch (clutter_event_type (event))
  {
    case CLUTTER_DEVICE_ADDED:
      g_signal_emit (seat, signals[DEVICE_ADDED], 0, device);
      break;
    case CLUTTER_DEVICE_REMOVED:
      g_signal_emit (seat, signals[DEVICE_REMOVED], 0, device);
      break;
```

`Clutter-16.gir` `class Seat`:

```xml
<glib:signal name="device-added" when="last">
  <parameters>
    <parameter name="object" transfer-ownership="none">
      <type name="InputDevice"/>
    </parameter>
  </parameters>
</glib:signal>
```

That `object` argument, on this nested X11 seat, is a `MetaInputDeviceX11`.

`libocrpc/Bin/TypeOverride.vala` `pack_params`:

```vala
var src = param_values[i];
var helper = TypeOverride.lookup(src.type());
if (helper == null) {
    packed.add(src);
    continue;
}
foreach (var field in helper.pack(src)) {
    packed.add(field);
}
```

`src.type()` is `Clutter.InputDevice`. `src.get_object()` is the `MetaInputDeviceX11`.

### ✔️ 🔷 Add `src/rpc/helper/InputDeviceOverride.vala`

```vala
namespace GnomeShellRpc.Rpc.Helper
{
	public class InputDeviceOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get {
				return typeof(Clutter.InputDevice);
			}
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			var device = src.get_object();
			if (device != null
					&& device.get_type().name() == "MetaInputDeviceX11") {
				return new Gee.ArrayList<GLib.Value?>();
			}
			var fields = new Gee.ArrayList<GLib.Value?>();
			fields.add(src);
			return fields;
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 0;
			return GLib.Value(typeof(Clutter.InputDevice));
		}
	}
}
```

### ✔️ 🔷 Add the file next to the event override

**Where:** `src/meson.build`

**Add:**

```meson
  'rpc/helper/InputDeviceOverride.vala',
```

**Where:** `src/rpc/helper/namespace.vala` `rpc_register`, after the `ClutterEventOverride` register.

**Add:**

```vala
		OLLMrpc.Bin.TypeOverride.register(new InputDeviceOverride());
```

**🚫** A `device-added` / `MetaInputDeviceX11` check in `libocrpc` `Subscription.emit`.

**🚫** Skipping every `device-added` / `device-removed` in `Signals.connect`.

**🚫** Registering `MetaInputDeviceX11`.
