imports.gi.versions.LiveInterfaceGirGate = '1.0';

const Fixture = imports.gi.LiveInterfaceGirGate;
const peer = new Fixture.Peer();

if (peer == null)
	throw new Error('FAIL live-interface-gir-gate: constructor returned null');

print('PASS live-interface-gir-gate');
