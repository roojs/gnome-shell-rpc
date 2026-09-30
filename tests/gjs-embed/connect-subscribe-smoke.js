/**
 * 0.8.6 smoke for {@link src/shell-js/signals.js}. Host also evals this wrap.
 *
 *   gjs src/gjs-embed/connect-subscribe-smoke.js
 *
 * PASS: wrap records a subscribe for every .connect(); local handlers still
 * run; connect_after / connect_object included. Lease filtering is Vala.
 */
const {GObject} = imports.gi;

imports.searchPath.unshift('src/shell-js');
const {Signals} = imports.signals;

const LeasedProbe = GObject.registerClass({
    GTypeName: 'GsrConnectSubscribeLeasedProbe',
    Properties: {
        'rpc-lid': GObject.ParamSpec.uint64(
            'rpc-lid', '', '',
            GObject.ParamFlags.READWRITE | GObject.ParamFlags.CONSTRUCT,
            0, 0x7fffffff, 0
        ),
    },
    Signals: {
        pinged: {param_types: [GObject.TYPE_STRING]},
    },
}, class LeasedProbe extends GObject.Object {});

const subs = [];
imports.gi.versions.Shell = '16';
const ShellNs = imports.gi.Shell;
ShellNs.Signals.connect = function (obj, name) {
    subs.push({lid: Number(obj.rpc_lid), name});
};
ShellNs.Signals.disconnect_id = function () {};

const leased = new LeasedProbe({rpc_lid: 7});
const unleased = new LeasedProbe({rpc_lid: 0});
const plain = new GObject.Object();
const lifetime = new GObject.Object();

let fromConnect = null;
let fromAfter = null;
let fromObject = null;
let fromUnleased = null;

leased.connect('pinged', (_o, payload) => {
    fromConnect = payload;
});
leased.connect_after('pinged', (_o, payload) => {
    fromAfter = payload;
});
leased.connect_object('pinged', (_o, payload) => {
    fromObject = payload;
}, lifetime, GObject.ConnectFlags.DEFAULT);

unleased.connect('pinged', (_o, payload) => {
    fromUnleased = payload;
});
plain.connect('notify', () => {});

leased.connect('pinged', () => {});

leased.emit('pinged', 'hello');
unleased.emit('pinged', 'unleased');

Signals.uninstall();

function fail(message) {
    throw new Error(message);
}

if (fromConnect !== 'hello') {
    fail(`connect handler payload=${fromConnect}`);
}
if (fromAfter !== 'hello') {
    fail(`connect_after handler payload=${fromAfter}`);
}
if (fromObject !== 'hello') {
    fail(`connect_object handler payload=${fromObject}`);
}
if (fromUnleased !== 'unleased') {
    fail(`unleased handler payload=${fromUnleased}`);
}

const leasedNames = subs.filter(row => row.lid === 7).map(row => row.name);
if (leasedNames.length !== 4) {
    fail(`expected 4 leased subscribes, got ${JSON.stringify(subs)}`);
}
if (leasedNames.filter(n => n === 'pinged').length !== 4) {
    fail(`leased names=${leasedNames.join(',')}`);
}

print(`subs=${JSON.stringify(subs)}`);
print('PASS connect-subscribe-smoke');
