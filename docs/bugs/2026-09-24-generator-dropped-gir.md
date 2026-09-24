# Generator dropped GIR construct properties and interfaces

**User goal:** nested mutter-rpc + gnome-shell-rpc stays up and answers pointer and keyboard. From [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md).

**Status:** ⏳ open

**Seen:** 2026-09-24 16:34:51 and 16:34:57.

```text
JS ERROR: Error: Property MetaBarrier.backend is not writable
_updatePanelBarrier@resource:///org/gnome/shell/ui/layout.js:593
```

```js
this._rightPanelBarrier = new Meta.Barrier({
    backend: global.backend,
```

```text
JS ERROR: TypeError: Object is of type St.Bin - cannot convert to ClutterAnimatable
_easeActorProperty@resource:///org/gnome/shell/ui/environment.js:229
expand@resource:///org/gnome/shell/ui/messageList.js:627
```

```js
this._bodyBin.ease_property('@layout.expansion', 1, {
```

`environment.js:229` is `actor.find_property(propName)`. `find_property` is on `Clutter.Animatable`.

## `Meta.Barrier.backend` is get-only

`Meta-16.gir` `class Barrier`:

```xml
<property name="backend"
          writable="1"
          construct-only="1"
          transfer-ownership="none">
  <type name="Backend"/>
</property>
```

`build/src/mutter-rpc-16.vapi`:

```vala
public Meta.Backend? backend { [CCode (cname = "barrier_get_backend_gprop")] get; }
```

`src/gi-stub-gen/Generator.vala` turns that into a readable property:

```vala
if (!write_method) {
    /*
     * Construct-only: GIR marks writable + construct-only
     * with a getter and no setter. Emit as readable-only.
     */
    if (read_method || read_gprop) {
        if (gprop_ok
            && (flags & GLib.ParamFlags.CONSTRUCT_ONLY) == 0) {
            write_gprop = true;
        } else {
            writable = false;
        }
    }
}
```

## `St.Widget` does not implement `Clutter.Animatable`

`St-16.gir` `class Widget` and `class Bin`:

```xml
<implements name="Clutter.Animatable"/>
```

`build/src/st-rpc-16.vapi`:

```vala
public class Widget : Clutter.Actor {
```

`St.Adjustment` does implement it. `src/gi-stub-gen/Generator.vala` `emit_object_implements` skips an interface whose namespace is not `St`. `Clutter.Animatable` is that skip. The comment says a foreign interface is added by an override `Type.implements=Clutter.Animatable`. `Widget` has no such override, and generation still succeeds.

### ⏳ 🔷 Generator reads the GIR flags

**Where:** `src/gi-stub-gen/Generator.vala` `emit_object_properties` / `emit_object_implements`.

**🔷** `CONSTRUCT_ONLY` is read with the other property flags. It sets a gprop `construct` accessor and does not look for a setter method. No gprop wire is a skipped property and generation stops.

**🔷** `emit_object_implements` emits a foreign interface as `Namespace.Name`. `St.Widget` gets `Clutter.Animatable`. Atk, Gio, and `Clutter.Content` stay on `St.deny`.

**🚫** Leaving `Meta.Barrier.backend` get-only.

**🚫** A `Widget` override as the only record that `Clutter.Animatable` was skipped.
