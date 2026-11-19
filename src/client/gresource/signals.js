/**
 * 0.8.6 — GJS connect wrap.
 *
 * Resource: resource:///org/gnome/shell-rpc/signals.js
 * Host evals this file before init.js; {@code Signals.install()} runs at load.
 *
 *   imports.searchPath.unshift('src/shell-js');
 *   const {Signals} = imports.signals;
 *
 * Wraps GObject.Object.prototype connect / connect_after / connect_object /
 * disconnect. Local {@code orig.connect} still attaches the GJS handler and
 * that GJS handler id is what this wrap returns. It is also passed to
 * {@code Shell.Signals.connect} so {@code obj.disconnect(id)} can drop the
 * wire ref. Vala mints a separate handler id for the subscribe table.
 */
const {GObject, Clutter} = imports.gi;

var Signals = class Signals {
    static install() {
        if (Signals._installed) {
            throw new Error('Signals already installed');
        }
        Signals._orig_connect = GObject.Object.prototype.connect;
        Signals._orig_connect_after = GObject.Object.prototype.connect_after;
        Signals._orig_connect_object = GObject.Object.prototype.connect_object;
        Signals._orig_disconnect = GObject.Object.prototype.disconnect;
        GObject.Object.prototype.connect = function (name, ...rest) {
            const id = Signals._orig_connect.call(this, name, ...rest);
            imports.gi.Shell.Signals.connect(this, name, id);
            return id;
        };
        GObject.Object.prototype.connect_after = function (name, ...rest) {
            const id = Signals._orig_connect_after.call(this, name, ...rest);
            imports.gi.Shell.Signals.connect(this, name, id);
            return id;
        };
        GObject.Object.prototype.connect_object = function (name, ...rest) {
            const id = Signals._orig_connect_object.call(this, name, ...rest);
            imports.gi.Shell.Signals.connect(this, name, id);
            return id;
        };
        GObject.Object.prototype.disconnect = function (id) {
            imports.gi.Shell.Signals.disconnect_id(this, id);
            return Signals._orig_disconnect.call(this, id);
        };
        Signals._installed = true;
        // Stock gir puts enabled on ActorMeta. GJS does not inherit
        // it onto ClickGesture. A constructor hash throws, and a later
        // assignment becomes a field. The server gesture stays enabled.
        if (Clutter.ClickGesture) {
            const Original = Clutter.ClickGesture;
            Object.defineProperty(Original.prototype, 'enabled', {
                configurable: true,
                enumerable: true,
                get() {
                    return this.get_enabled();
                },
                set(value) {
                    this.set_enabled(value);
                },
            });
            const Wrapped = function ClickGesture(props) {
                let rest = props;
                let enabled = false;
                let hasEnabled = false;
                if (props
                    && Object.prototype.hasOwnProperty.call(props, 'enabled')) {
                    hasEnabled = true;
                    enabled = props.enabled;
                    rest = {};
                    for (const key of Object.keys(props)) {
                        if (key !== 'enabled')
                            rest[key] = props[key];
                    }
                }
                const gesture = rest ? new Original(rest) : new Original();
                if (hasEnabled)
                    gesture.set_enabled(!!enabled);
                return gesture;
            };
            Wrapped.prototype = Original.prototype;
            Object.setPrototypeOf(Wrapped, Original);
            Clutter.ClickGesture = Wrapped;
            Signals._orig_bind_property = GObject.Object.prototype.bind_property;
            GObject.Object.prototype.bind_property = function (
                sourceProp, target, targetProp, flags = 0) {
                if (target instanceof Original && targetProp === 'enabled') {
                    const propKey = sourceProp.replace(/-/g, '_');
                    const invert =
                        (flags & GObject.BindingFlags.INVERT_BOOLEAN) !== 0;
                    const sync = () => {
                        const v = !!this[propKey];
                        target.set_enabled(invert ? !v : v);
                    };
                    let id = this.connect('notify::' + sourceProp, sync);
                    if ((flags & GObject.BindingFlags.SYNC_CREATE) !== 0)
                        sync();
                    return {
                        unbind: () => {
                            if (id) {
                                this.disconnect(id);
                                id = 0;
                            }
                        },
                    };
                }
                return Signals._orig_bind_property.call(
                    this, sourceProp, target, targetProp, flags);
            };
        }
    }

    static uninstall() {
        if (!Signals._installed) {
            return;
        }
        GObject.Object.prototype.connect = Signals._orig_connect;
        GObject.Object.prototype.connect_after = Signals._orig_connect_after;
        GObject.Object.prototype.connect_object = Signals._orig_connect_object;
        GObject.Object.prototype.disconnect = Signals._orig_disconnect;
        if (Signals._orig_bind_property) {
            GObject.Object.prototype.bind_property = Signals._orig_bind_property;
            Signals._orig_bind_property = null;
        }
        Signals._orig_connect = null;
        Signals._orig_connect_after = null;
        Signals._orig_connect_object = null;
        Signals._orig_disconnect = null;
        Signals._installed = false;
    }
};

Signals._installed = false;
Signals._orig_connect = null;
Signals._orig_connect_after = null;
Signals._orig_connect_object = null;
Signals._orig_disconnect = null;
Signals._orig_bind_property = null;

Signals.install();
