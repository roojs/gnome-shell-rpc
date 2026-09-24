# Notification close click dies in `captured-event`

**User goal:** nested mutter-rpc + gnome-shell-rpc stays up and answers pointer and keyboard. From [`../../plans/0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md).

**Status:** ✅ closed 2026-09-24. The event is stacked in `ClutterEventOverride`. `Signals.emit` calls `release_params` after `emitv`.

**Seen:** 2026-09-24 16:01:52. Clicking the notification close does not dismiss it.

```text
notification method=captured-event
JS ERROR: Error: 920754400 is not a valid value for enumeration EventType
_onCapturedEvent@resource:///org/gnome/shell/ui/searchController.js:310
```

`searchController.js`:

```js
_onCapturedEvent(actor, event) {
    if (event.type() === Clutter.EventType.BUTTON_PRESS) {
```

`event.type()` is `920754400`. That throw happens before the banner close handler runs.

## `unpack` frees the event

**Where:** `src/shell-gi/ClutterEventOverride.vala` `unpack`.

```vala
var ev = Clutter.Event.from_local(
    (Clutter.EventType) fields.get(index).get_int(),
    (float) fields.get(index + 1).get_double(),
    (float) fields.get(index + 2).get_double(),
    fields.get(index + 3).get_uint(),
    0,
    fields.get(index + 4).get_uint());
var v = GLib.Value(typeof(Clutter.Event));
v.set_pointer(ev);
return v;
```

`build/src/libshell-gi-16.so.p/shell-gi/ClutterEventOverride.c`:

```c
g_value_init (&_tmp17_, G_TYPE_POINTER);
v = _tmp17_;
g_value_set_pointer (&v, ev);
*result = v;
_clutter_event_free0 (ev);
```

`set_pointer` stores the address. `_clutter_event_free0` frees that event before `Signals.emit` runs the handler. `event.type()` reads the freed event.

**ℹ️** The `get_key_symbol` guards in `ClutterHelper.get_current_event` and `LayoutHooks.measure_event` do not touch this path.

### ✔️ 🔷 `TypeOverride.release`

**ℹ️** OLLMchat `docs/bugs/2026-09-24-type-override-release.md`.

**Where:** `libocrpc/Bin/TypeOverride.vala`

**Add:**

```vala
/**
 * Drop one value this override kept alive for {@link unpack}.
 *
 * Default does nothing.
 */
public virtual void release()
{
}

/**
 * Call {@link release} once per parameter that has an override.
 *
 * @param param_types signal parameter types, not including the instance
 */
public static void release_params(GLib.Type[] param_types)
{
    foreach (var type in param_types) {
        var helper = TypeOverride.lookup(type);
        if (helper == null) {
            continue;
        }
        helper.release();
    }
}
```

### ✔️ 🔷 Stack on `ClutterEventOverride`

**Where:** `src/shell-gi/ClutterEventOverride.vala`

**Add:**

```vala
static Gee.ArrayList<Clutter.Event>? held;

/**
 * Drop the event pushed by the latest {@link unpack}.
 */
public override void release()
{
    if (held == null || held.size == 0) {
        return;
    }
    held.remove_at(held.size - 1);
}
```

**Replace:**

```vala
			var ev = Clutter.Event.from_local(
				(Clutter.EventType) fields.get(index).get_int(),
				(float) fields.get(index + 1).get_double(),
				(float) fields.get(index + 2).get_double(),
				fields.get(index + 3).get_uint(),
				0,
				fields.get(index + 4).get_uint());
			var v = GLib.Value(typeof(Clutter.Event));
			v.set_pointer(ev);
			return v;
```

**Replace with:**

```vala
			var ev = Clutter.Event.from_local(
				(Clutter.EventType) fields.get(index).get_int(),
				(float) fields.get(index + 1).get_double(),
				(float) fields.get(index + 2).get_double(),
				fields.get(index + 3).get_uint(),
				0,
				fields.get(index + 4).get_uint());
			if (ClutterEventOverride.held == null) {
				ClutterEventOverride.held = new Gee.ArrayList<Clutter.Event>();
			}
			ClutterEventOverride.held.add(ev.copy());
			var v = GLib.Value(typeof(Clutter.Event));
			v.set_pointer(ClutterEventOverride.held.get(
				ClutterEventOverride.held.size - 1));
			return v;
```

`ev.copy()` is the stacked event. `set_pointer` points at that. `_clutter_event_free0(ev)` still frees the local.

### ✔️ 🔷 Pop after the handler

**Where:** `src/shell-gi/Signals.vala` `emit`

**Replace:**

```vala
			Signals.emitv(vals, signal_id, detail, null);
```

**Replace with:**

```vala
			Signals.emitv(vals, signal_id, detail, null);
			OLLMrpc.Bin.TypeOverride.release_params(query.param_types);
```
