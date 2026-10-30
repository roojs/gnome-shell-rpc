imports.gi.versions.PolkitInitiateShape = '1.0';

const Shape = imports.gi.PolkitInitiateShape;
const GObject = imports.gi.GObject;
const mode = ARGV[0];

if (mode !== 'length' && mode !== 'strv') {
	print('FAIL polkit-initiate-shape: mode ' + mode);
	imports.system.exit(1);
}

const agent = mode === 'length' ? new Shape.LengthAgent() : new Shape.StrvAgent();
let names = null;
agent.connect('initiate', (_obj, _actionId, _message, _iconName, _cookie, userNames) => {
	names = userNames;
});
agent.fire();

if (mode === 'length') {
	print('FAIL polkit-initiate-shape: length signal returned to JS');
	imports.system.exit(1);
}
const id = GObject.signal_lookup('initiate', agent.constructor.$gtype);
const query = GObject.signal_query(id);
const last = query.n_params > 0 ? query.param_types[query.n_params - 1].name : 'none';
if (query.n_params !== 5 || last !== 'GStrv') {
	print('FAIL polkit-initiate-shape: n_params=' + query.n_params + ' last=' + last);
	imports.system.exit(1);
}
if (names === null || names.length !== 1 || names[0] !== 'alan') {
	print('FAIL polkit-initiate-shape: strv names=' + names);
	imports.system.exit(1);
}
print('PASS polkit-initiate-shape: n_params=5 last=GStrv user_names=[alan]');
