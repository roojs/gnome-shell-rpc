/**
 * 0.8.6 — GJS connect wrap.
 *
 * Resource: resource:///org/gnome/shell-rpc/signals.js
 * Not evaluated by ShellApplication yet (host inject is a later cut).
 *
 *   imports.searchPath.unshift('src/shell-js');
 *   const {Signals} = imports.signals;
 *   Signals.install();
 *
 * Wraps GObject.Object.prototype connect / connect_after / connect_object /
 * disconnect. Local {@code orig.connect} still attaches the GJS handler and
 * that GJS handler id is what this wrap returns. It is also passed to
 * {@code Shell.Signals.connect} so {@code obj.disconnect(id)} can drop the
 * wire ref. Vala mints a separate handler id for the subscribe table.
 */
const {GObject} = imports.gi;

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
            imports.gi.Shell.Signals.disconnect(this, id);
            return Signals._orig_disconnect.call(this, id);
        };
        Signals._installed = true;
    }

    static uninstall() {
        if (!Signals._installed) {
            return;
        }
        GObject.Object.prototype.connect = Signals._orig_connect;
        GObject.Object.prototype.connect_after = Signals._orig_connect_after;
        GObject.Object.prototype.connect_object = Signals._orig_connect_object;
        GObject.Object.prototype.disconnect = Signals._orig_disconnect;
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
