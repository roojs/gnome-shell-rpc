/**
 * 0.8.6 principle: wrapping GObject.Object.prototype.connect intercepts
 * GJS .connect() and still delivers the local handler.
 *
 *   gjs src/gjs-embed/connect-wrap-principle-smoke.js
 *
 * No mutter, no Runtime, no RPC. PASS is wrap-saw-name + handler payload.
 */
const {GObject} = imports.gi;

const Probe = GObject.registerClass({
    Signals: {
        pinged: {param_types: [GObject.TYPE_STRING]},
    },
}, class Probe extends GObject.Object {});

const hits = [];

function wrap(method) {
    const orig = GObject.Object.prototype[method];
    if (typeof orig !== 'function') {
        throw new Error(`${method}: not a function on Object.prototype`);
    }
    GObject.Object.prototype[method] = function (...args) {
        const name = args[0];
        hits.push(`${method}:${name}`);
        return orig.apply(this, args);
    };
}

wrap('connect');
wrap('connect_after');
if (typeof GObject.Object.prototype.connect_object === 'function') {
    wrap('connect_object');
}

const obj = new Probe();
const lifetime = new GObject.Object();
let fromConnect = null;
let fromAfter = null;
let fromObject = null;

obj.connect('pinged', (_o, payload) => {
    fromConnect = payload;
});
obj.connect_after('pinged', (_o, payload) => {
    fromAfter = payload;
});
obj.connect_object('pinged', (_o, payload) => {
    fromObject = payload;
}, lifetime, GObject.ConnectFlags.DEFAULT);

obj.emit('pinged', 'hello');

function requireHit(token) {
    if (hits.indexOf(token) < 0) {
        throw new Error(`wrap missed ${token}; hits=${hits.join(',')}`);
    }
}

requireHit('connect:pinged');
requireHit('connect_after:pinged');
requireHit('connect_object:pinged');
if (fromConnect !== 'hello') {
    throw new Error(`connect handler payload=${fromConnect}`);
}
if (fromAfter !== 'hello') {
    throw new Error(`connect_after handler payload=${fromAfter}`);
}
if (fromObject !== 'hello') {
    throw new Error(`connect_object handler payload=${fromObject}`);
}

print(`hits=${hits.join(',')}`);
print('PASS connect-wrap-principle-smoke');
